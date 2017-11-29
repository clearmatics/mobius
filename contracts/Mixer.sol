// Copyright (c) 2016-2017 Clearmatics Technologies Ltd

// SPDX-License-Identifier: (LGPL-3.0+ AND GPL-3.0)


pragma solidity ^0.4.18;

import './Ring.sol';

contract Mixer
{
    using Ring for Ring.Data;

    mapping(uint256 => Ring.Data) internal m_rings;

    /** With a public key, lookup which ring it belongs to */
    mapping(uint256 => uint256) internal m_pubx_to_ring;

    /** Rings which aren't full yet, H(token,denom) -> ring_id */
    mapping(uint256 => uint256) internal m_filling;

    uint256 m_ring_ctr;


    event RingDeposit( uint256 ring_id, uint256 pub_x, address token, uint256 value );
    event RingWithdraw( uint256 ring_id, uint256 tag_x, address token, uint256 value );
    event RingReady( uint256 ring_id );
    event RingDead( uint256 ring_id );


    /**
    * Lookup an unfilled/filling ring for a given token and denomination,
    * this will create a new unfilled ring if none exists. When the ring
    * is full the 'filling' ring will be deleted.
    */
    function lookupFillingRing (address token, uint256 denomination)
        internal returns (uint256, Ring.Data storage)
    {
        var filling_id = uint256(sha256(token, denomination));
        uint256 ring_guid = m_filling[filling_id];
        if( ring_guid != 0 )
            return (filling_id, m_rings[ring_guid]);

        ring_guid = uint256(sha256(m_ring_ctr, filling_id));

        // Ensure ring GUID isn't already in use, just incase
        if( 0 != m_rings[ring_guid].denomination )
            revert();

        Ring.Data storage ring = m_rings[ring_guid];
        if( ! ring.Initialize(ring_guid, token, denomination) )
            revert();

        m_ring_ctr += 1;
        m_filling[filling_id] = ring_guid;

        return (filling_id, ring);
    }


    /**
    * Deposit tokens of a specific denomination which can only be withdrawn
    * by providing a ring signature by one of the public keys.
    */
    function Deposit (address token, uint256 denomination, uint256 pub_x, uint256 pub_y)
        public returns (uint256)
    {      
        // TODO: verify token is a valid ERC-223 contract

        uint256 filling_id;
        Ring.Data storage ring;
        (filling_id, ring) = lookupFillingRing(token, denomination);

        if( ! ring.AddParticipant(pub_x, pub_y) )
            revert();

        // Associate Public X point with Ring GUID
        // This allows the ring to be recovered with the public key
        // Without having to monitor/replay the RingDeposit events
        m_pubx_to_ring[pub_x] = ring.guid;
        RingDeposit(ring.guid, pub_x, token, denomination);

        if( ring.IsFull() ) {
            delete m_filling[filling_id];
            RingReady(ring.guid);
        }

        return ring.guid;
    }


    /**
    * To Withdraw a Token of Denomination from the Ring, one of the Public Keys
    * must provide a Signature which has a unique Tag. Each Tag can only be used
    * once.
    */
    function Withdraw (uint256 ring_id, uint256 tag_x, uint256 tag_y, uint256[] ctlist)
        public 
    {
        Ring.Data storage ring = m_rings[ring_id];

        if( ! ring.IsFull() )
            revert();

        if( ! ring.SignatureValid(tag_x, tag_y, ctlist) )
            revert();

        // Tag must be added before withdraw
        ring.TagAdd(tag_x);

        RingWithdraw(ring_id, tag_x, ring.token, ring.denomination);

        // TODO: add ERC-223 support
        msg.sender.transfer(ring.denomination);

        // When Tags.length == Pubkeys.length, the ring is dead
        // Remove mappings and delete ring
        if( ring.IsDead() ) {
            for( uint i = 0; i < ring.pubkeys.length; i++ ) {
                delete m_pubx_to_ring[ring.pubkeys[i].X];
            }
            delete m_rings[ring_id];
            RingDead(ring.guid);
        }
    }


    function () public {
        revert();
    }
}
