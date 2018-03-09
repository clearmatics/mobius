// Copyright (c) 2016-2017 Clearmatics Technologies Ltd

// SPDX-License-Identifier: LGPL-3.0+

pragma solidity ^0.4.18;

import './LinkableRing.sol';


/**
* Each ring is given a globally unique ID which consist of:
*
*  - contract address
*  - incrementing nonce
*  - token address
*  - denomination
*
* When a Deposit is made for a specific Token and Denomination
* the Mixer will return the Ring GUID. The lifecycle of each Ring
* can then be monitored using the following events which demarcate
* the state transitions:
*
* MixerDeposit
*   For each Deposit a MixerDeposit message is emitted, this includes
*   the Ring GUID, the X point of the Stealth Address, and the Token
*   address and Denomination.
*
* MixerReady
*   When a Ring is full and withdrawals can be made a RingReady
*   event is emitted, this includes the Ring GUID and the Message
*   which must be signed to Withdraw.
*
* MixerWithdraw
*   For each Withdraw a MixerWithdraw message is emitted, this includes
*   the Token, Denomination, Ring GUID and Tag of the withdrawer.
*
* MixerDead
*   When all participants have withdrawn their tokens from a Ring the
*   MixerDead event is emitted, this specifies the Ring GUID.
*/
contract Mixer
{
    using LinkableRing for LinkableRing.Data;

    struct Data {
        bytes32 guid;
        uint256 denomination;
        address token;
        LinkableRing.Data ring;
    }

    mapping(bytes32 => Data) internal m_rings;

    /** With a public key, lookup which ring it belongs to */
    mapping(uint256 => bytes32) internal m_pubx_to_ring;

    /** Rings which aren't full yet, H(token,denom) -> ring_id */
    mapping(bytes32 => bytes32) internal m_filling;

    /** Nonce used to generate Ring Messages */
    uint256 internal m_ring_ctr;

    /**
    * Token has been deposited into a Mixer Ring
    */
    event MixerDeposit(
        bytes32 indexed ring_id,
        uint256 indexed pub_x,
        address token,
        uint256 value
    );

    /**
    * Token has been withdraw from a Mixer Ring
    */
    event MixerWithdraw(
        bytes32 indexed ring_id,
        uint256 tag_x,
        address token,
        uint256 value
    );

    /**
     * A Mixer Ring is Full, Tokens can now be withdrawn from it
     */
    event MixerReady( bytes32 indexed ring_id, bytes32 message );

    /**
    * A Mixer Ring has been fully with withdrawn, the Ring is dead.
    */
    event MixerDead( bytes32 indexed ring_id );


    function Mixer()
        public
    {
        // Nothing ...
    }


    /**
    * Lookup an unfilled/filling ring for a given token and denomination,
    * this will create a new unfilled ring if none exists. When the ring
    * is full the 'filling' ring will be deleted.
    */
    function lookupFillingRing (address token, uint256 denomination)
        internal returns (bytes32, Data storage)
    {
        // The filling ID allows quick lookup for the same Token and Denomination
        var filling_id = sha256(token, denomination);
        var ring_guid = m_filling[filling_id];
        if( ring_guid != 0 )
            return (filling_id, m_rings[ring_guid]);

        // The GUID is unique per Mixer instance, Nonce, Token and Denomination
        ring_guid = sha256(address(this), m_ring_ctr, filling_id);

        Data storage entry = m_rings[ring_guid];

        // Entry must be initialized only once
        require( 0 == entry.denomination );
        require( entry.ring.Initialize(ring_guid) );

        entry.guid = ring_guid;
        entry.token = token;
        entry.denomination = denomination;

        m_ring_ctr += 1;
        m_filling[filling_id] = ring_guid;

        return (filling_id, entry);
    }


    /**
    * Given a GUID of a full Ring, return the Message to sign
    */
    function Message (bytes32 ring_guid)
        public view returns (bytes32)
    {
        Data storage entry = m_rings[ring_guid];
        LinkableRing.Data storage ring = entry.ring;

        // Entry is empty, non-existant ring
        require( 0 != entry.denomination );

        return ring.Message();
    }


    /**
    * deposit tokens of a specific denomination which can only be withdrawn
    * by providing a ring signature by one of the public keys.
    */
    function DepositEther (address token, uint256 denomination, uint256 pub_x, uint256 pub_y)
        public payable returns (bytes32)
    {
        require( token == 0);
        require( denomination == msg.value );

        // Denomination must be positive power of 2, e.g. only 1 bit set
        require( denomination != 0 && 0 == (denomination & (denomination - 1)) );

        // Public key can only exist in one ring at a time
        require( 0 == uint256(m_pubx_to_ring[pub_x]) );

        bytes32 filling_id;
        Data storage entry;
        (filling_id, entry) = lookupFillingRing(token, denomination);

        LinkableRing.Data storage ring = entry.ring;

        require( ring.AddParticipant(pub_x, pub_y) );

        // Associate Public X point with Ring GUID
        // This allows the ring to be recovered with the public key
        // Without having to monitor/replay the RingDeposit events
        var ring_guid = entry.guid;
        m_pubx_to_ring[pub_x] = ring_guid;
        MixerDeposit(ring_guid, pub_x, token, denomination);

        // When full, emit the GUID as the Ring Message
        // Participants need to sign this Message to Withdraw
        if( ring.IsFull() ) {
            delete m_filling[filling_id];
            MixerReady(ring_guid, ring.Message());
        }

        return ring_guid;
    }

    function DepositERC223 (address token, uint256 denomination, uint256 pub_x, uint256 pub_y)
        public returns (bytes32)
    {
        // This function is NON PAYABLE
        uint256 codeLength;
        assembly {
            codeLength := extcodesize(token)
        }

        require( token != 0 && codeLength > 0);
        // require( denomination == msg.value ); --> No need for this line as the function is not payable anymore

        ERC223Token erc223Token = ERC223Token(token);
        // In order for the function to succeed, the Mixer as to be allowed to spend the
        // denomination on behalf of the caller of the Deposit() method
        erc223Token.transferFrom(msg.sender, this, denomination)

        // Denomination must be positive power of 2, e.g. only 1 bit set
        require( denomination != 0 && 0 == (denomination & (denomination - 1)) );

        // Public key can only exist in one ring at a time
        require( 0 == uint256(m_pubx_to_ring[pub_x]) );

        bytes32 filling_id;
        Data storage entry;
        (filling_id, entry) = lookupFillingRing(token, denomination);

        LinkableRing.Data storage ring = entry.ring;

        require( ring.AddParticipant(pub_x, pub_y) );

        // Associate Public X point with Ring GUID
        // This allows the ring to be recovered with the public key
        // Without having to monitor/replay the RingDeposit events
        var ring_guid = entry.guid;
        m_pubx_to_ring[pub_x] = ring_guid;
        MixerDeposit(ring_guid, pub_x, token, denomination);

        // When full, emit the GUID as the Ring Message
        // Participants need to sign this Message to Withdraw
        if( ring.IsFull() ) {
            delete m_filling[filling_id];
            MixerReady(ring_guid, ring.Message());
        }

        return ring_guid;
    }


    /**
    * To Withdraw a Token of Denomination from the Ring, one of the Public Keys
    * must provide a Signature which has a unique Tag. Each Tag can only be used
    * once.
    */
    function Withdraw (bytes32 ring_id, uint256 tag_x, uint256 tag_y, uint256[] ctlist)
        public returns (bool)
    {
        Data storage entry = m_rings[ring_id];
        LinkableRing.Data storage ring = entry.ring;

        // Entry is empty, non-existant ring
        require( 0 != entry.denomination );

        require( ring.IsFull() );

        require( ring.SignatureValid(tag_x, tag_y, ctlist) );

        // Tag must be added before withdraw
        ring.TagAdd(tag_x);

        MixerWithdraw(ring_id, tag_x, entry.token, entry.denomination);

        // TODO: add ERC-223 support
        msg.sender.transfer(entry.denomination);

        // When Tags.length == Pubkeys.length, the ring is dead
        // Remove mappings and delete ring
        if( ring.IsDead() ) {
            for( uint i = 0; i < ring.pubkeys.length; i++ ) {
                delete m_pubx_to_ring[ring.pubkeys[i].X];
            }
            delete m_rings[ring_id];
            MixerDead(ring_id);
        }

        return true;
    }

    function WithdrawERC223 (bytes32 ring_id, uint256 tag_x, uint256 tag_y, uint256[] ctlist)
        public returns (bool)
    {
        Data storage entry = m_rings[ring_id];
        LinkableRing.Data storage ring = entry.ring;

        // Entry is empty, non-existant ring
        require( 0 != entry.denomination );

        require( ring.IsFull() );

        require( ring.SignatureValid(tag_x, tag_y, ctlist) );

        // Tag must be added before withdraw
        ring.TagAdd(tag_x);

        MixerWithdraw(ring_id, tag_x, entry.token, entry.denomination);

        // TODO: add ERC-223 support
        ERC223Token erc223Token = ERC223Token(entry.token);
        erc223Token.transfer(msg.sender, entry.denomination);

        // When Tags.length == Pubkeys.length, the ring is dead
        // Remove mappings and delete ring
        if( ring.IsDead() ) {
            for( uint i = 0; i < ring.pubkeys.length; i++ ) {
                delete m_pubx_to_ring[ring.pubkeys[i].X];
            }
            delete m_rings[ring_id];
            MixerDead(ring_id);
        }

        return true;
    }


    function () public {
        revert();
    }
}
