// Copyright (c) 2016-2018 Clearmatics Technologies Ltd

// SPDX-License-Identifier: LGPL-3.0+

pragma solidity ^0.4.19;

import './LinkableRing.sol';
import './ERC223ReceivingContract.sol';

/*
 * Declare the ERC20Compatible interface in order to handle ERC20 tokens transfers
 * to and from the Mixer. Note that we only declare the functions we are interested in,
 * namely, transferFrom() (used to do a Deposit), and transfer() (used to do a withdrawal)
**/
contract ERC20Compatible {
    function transferFrom(address from, address to, uint256 value) public;
    function transfer(address to, uint256 value) public;
}

/*
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
 * LogMixerDeposit
 *   For each Deposit a LogMixerDeposit message is emitted, this includes
 *   the Ring GUID, the X point of the Stealth Address, and the Token
 *   address and Denomination.
 *
 * LogMixerReady
 *   When a Ring is full and withdrawals can be made a LogMixerReady
 *   event is emitted, this includes the Ring GUID and the Message
 *   which must be signed to Withdraw.
 *
 * LogMixerWithdraw
 *   For each Withdraw a LogMixerWithdraw message is emitted, this includes
 *   the Token, Denomination, Ring GUID and Tag of the withdrawer.
 *
 * LogMixerDead
 *   When all participants have withdrawn their tokens from a Ring the
 *   LogMixerDead event is emitted, this specifies the Ring GUID.
**/

contract Mixer is ERC223ReceivingContract {
    using LinkableRing for LinkableRing.Data;

    struct Data {
        bytes32 guid;
        uint256 denomination;
        address token;
        LinkableRing.Data ring;
    }

    mapping(bytes32 => Data) internal m_rings;

    // With a public key, lookup which ring it belongs to
    mapping(uint256 => bytes32) internal m_pubx_to_ring;

    // Rings which aren't full yet, H(token,denom) -> ring_id
    mapping(bytes32 => bytes32) internal m_filling;

    // Nonce used to generate Ring Messages
    uint256 internal m_ring_ctr;

    // Token has been deposited into a Mixer Ring
    event LogMixerDeposit(
        bytes32 indexed ring_id,
        uint256 indexed pub_x,
        address token,
        uint256 value
    );

    // Token has been withdraw from a Mixer Ring
    event LogMixerWithdraw(
        bytes32 indexed ring_id,
        uint256 tag_x,
        address token,
        uint256 value
    );

    // A Mixer Ring is Full, Tokens can now be withdrawn from it
    event LogMixerReady(bytes32 indexed ring_id, bytes32 message);

    // A Mixer Ring has been fully withdrawn, the Ring is dead
    event LogMixerDead(bytes32 indexed ring_id);

    function Mixer() public {
        // Nothing
    }

    function () public {
        revert();
    }

    /*
     * Given a GUID of a full Ring, return the Message to sign
    **/
    function message(bytes32 ring_guid)
        public view returns (bytes32)
    {
        Data storage entry = m_rings[ring_guid];
        LinkableRing.Data storage ring = entry.ring;

        // Entry is empty, non-existant ring
        require(0 != entry.denomination);

        return ring.message();
    }

    /*
     * Deposit a specific denomination of Ethers which can only be withdrawn
     * by providing a ring signature by one of the public keys.
    **/
    function depositEther(address token, uint256 denomination, uint256 pub_x, uint256 pub_y)
        public payable returns (bytes32)
    {
        require(token == 0);
        require(denomination == msg.value);

        bytes32 ring_guid = depositLogic(token, denomination, pub_x, pub_y);
        return ring_guid;
    }

    /*
     * Deposit a specific denomination of ERC20 compatible tokens which can only be withdrawn
     * by providing a ring signature by one of the public keys.
    **/
    function depositERC20Compatible(address token, uint256 denomination, uint256 pub_x, uint256 pub_y)
        public returns (bytes32)
    {
        uint256 codeLength;
        assembly {
            codeLength := extcodesize(token)
        }

        require(token != 0 && codeLength > 0);
        bytes32 ring_guid = depositLogic(token, denomination, pub_x, pub_y);

        // Call to an untrusted external contract done at the end of the function for security measures
        ERC20Compatible untrustedErc20Token = ERC20Compatible(token);
        untrustedErc20Token.transferFrom(msg.sender, this, denomination);

        return ring_guid;
    }

    /*
     * To Withdraw a denomination of Ethers from the Ring, one of the Public Keys
     * must provide a Signature which has a unique Tag. Each Tag can only be used
     * once.
    **/
    function withdrawEther(bytes32 ring_id, uint256 tag_x, uint256 tag_y, uint256[] ctlist)
        public returns (bool)
    {
        Data memory entry = withdrawLogic(ring_id, tag_x, tag_y, ctlist);
        msg.sender.transfer(entry.denomination);

        return true;
    }

    /*
     * To Withdraw a denomination of ERC20 compatible tokens from the Ring, one of the Public Keys
     * must provide a Signature which has a unique Tag. Each Tag can only be used
     * once.
    **/
    function withdrawERC20Compatible(bytes32 ring_id, uint256 tag_x, uint256 tag_y, uint256[] ctlist)
        public returns (bool)
    {
        Data memory entry = withdrawLogic(ring_id, tag_x, tag_y, ctlist);

        // Call to an untrusted external contract done at the end of the function for security measures
        ERC20Compatible untrustedErc20Token = ERC20Compatible(entry.token);
        untrustedErc20Token.transfer(msg.sender, entry.denomination);

        return true;
    }

    /*
     * Lookup an unfilled/filling ring for a given token and denomination,
     * this will create a new unfilled ring if none exists. When the ring
     * is full the 'filling' ring will be deleted.
    **/
    function lookupFillingRing(address token, uint256 denomination)
        internal returns (bytes32, Data storage)
    {
        // The filling ID allows quick lookup for the same Token and Denomination
        var filling_id = sha256(token, denomination);
        var ring_guid = m_filling[filling_id];
        if(ring_guid != 0) {
            return (filling_id, m_rings[ring_guid]);
        }

        // The GUID is unique per Mixer instance, Nonce, Token and Denomination
        ring_guid = sha256(address(this), m_ring_ctr, filling_id);

        Data storage entry = m_rings[ring_guid];

        // Entry must be initialized only once
        require(0 == entry.denomination);
        require(entry.ring.initialize(ring_guid));

        entry.guid = ring_guid;
        entry.token = token;
        entry.denomination = denomination;

        m_ring_ctr += 1;
        m_filling[filling_id] = ring_guid;

        return (filling_id, entry);
    }

    function depositLogic(address token, uint256 denomination, uint256 pub_x, uint256 pub_y)
        internal returns (bytes32)
    {
        // Denomination must be positive power of 2, e.g. only 1 bit set
        require(denomination != 0 && 0 == (denomination & (denomination - 1)));

        // Public key can only exist in one ring at a time
        require(0 == uint256(m_pubx_to_ring[pub_x]));

        bytes32 filling_id;
        Data storage entry;
        (filling_id, entry) = lookupFillingRing(token, denomination);

        LinkableRing.Data storage ring = entry.ring;

        require(ring.addParticipant(pub_x, pub_y));

        // Associate Public X point with Ring GUID
        // This allows the ring to be recovered with the public key
        // Without having to monitor/replay the RingDeposit events
        var ring_guid = entry.guid;
        m_pubx_to_ring[pub_x] = ring_guid;
        LogMixerDeposit(ring_guid, pub_x, token, denomination);

        // When full, emit the GUID as the Ring Message
        // Participants need to sign this Message to Withdraw
        if(ring.isFull()) {
            delete m_filling[filling_id];
            LogMixerReady(ring_guid, ring.message());
        }

        return ring_guid;
    }

    function withdrawLogic(bytes32 ring_id, uint256 tag_x, uint256 tag_y, uint256[] ctlist)
        internal returns (Data)
    {
        Data storage entry = m_rings[ring_id];
        LinkableRing.Data storage ring = entry.ring;

        // Entry is empty, non-existant ring
        require(0 != entry.denomination);

        require(ring.isFull());

        require(ring.isSignatureValid(tag_x, tag_y, ctlist));

        // Tag must be added before withdraw
        ring.tagAdd(tag_x);

        LogMixerWithdraw(ring_id, tag_x, entry.token, entry.denomination);

        // We want to return a copy of the entry in order to be able to access
        // the token and denomination fields of this object.
        // Since the following instructions might delete the entry in the storage
        // we save it in a memory variable and return it to the calling function.
        Data memory entrySaved = entry;

        // When Tags.length == Pubkeys.length, the ring is dead
        // Remove mappings and delete ring
        if(ring.isDead()) {
            for(uint i = 0; i < ring.pubkeys.length; i++) {
                delete m_pubx_to_ring[ring.pubkeys[i].X];
            }
            delete m_rings[ring_id];
            LogMixerDead(ring_id);
        }

        return entrySaved;
    }
}
