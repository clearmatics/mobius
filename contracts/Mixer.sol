// Copyright (c) 2016-2017 Clearmatics Technologies Ltd

// SPDX-License-Identifier: (LGPL-3.0+ AND GPL-3.0)


pragma solidity ^0.4.18;

import './bn256g1.sol';
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
    * Lookup an unfilled/filling ring for a given token and denomination
    * This will create a new ring if none exists
    */
    function lookupFillingRing (address token, uint256 denomination)
        internal returns (Ring.Data storage)
    {
        var filling_id = uint256(sha256(token, denomination));
        uint256 ring_guid = m_filling[filling_id];
        if( ring_guid != 0 )
            return m_rings[ring_guid];

        ring_guid = uint256(sha256(m_ring_ctr, filling_id));

        // Ensure ring GUID isn't already in use, just incase
        if( 0 != m_rings[ring_guid].denomination )
            revert();

        Ring.Data storage ring = m_rings[ring_guid];
        if( ! ring.Initialize(ring_guid, token, denomination) )
            revert();

        m_ring_ctr += 1;
        m_filling[filling_id] = ring_guid;

        return ring;
    }


    /**
    * Deposit tokens of a specific denomination which can only be withdrawn by providing
    * a ring signature of one of the public keys.
    */
    function Deposit (address token, uint256 denomination, uint256 pub_x, uint256 pub_y)
        public returns (uint256)
    {      
        // TODO: verify token is a valid ERC-223 contract

        Ring.Data storage ring = lookupFillingRing(token, denomination);

        if( ! ring.AddParticipant(pub_x, pub_y) )
            revert();

        m_pubx_to_ring[pub_x] = ring.guid;
        RingDeposit(ring.guid, pub_x, token, denomination);

        if( ring.IsFull() ) {
            RingReady(ring.guid);
        }

        return ring.guid;
    }


    function Withdraw (uint256 ring_id, uint256 tag_x, uint256 tag_y, uint256[] ctlist)
        public 
    {
        Ring.Data storage ring = m_rings[ring_id];

        if( ! ring.IsFull() )
            revert();

        if( ! ring.SignatureValid(tag_x, tag_y, ctlist) )
            revert();

        ring.TagAdd(tag_x);

        // TODO: add ERC-223 support
        msg.sender.transfer(ring.denomination);
        
        RingWithdraw(ring_id, tag_x, ring.token, ring.denomination);

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
