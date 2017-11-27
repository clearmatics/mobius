// Copyright (c) 2016-2017 Clearmatics Technologies Ltd

// SPDX-License-Identifier: (LGPL-3.0+ AND GPL-3.0)


pragma solidity ^0.4.18;

import './bn256g1.sol';
import './Ring.sol';

contract Mixer
{
    using Ring for Ring.Data;

    mapping(uint256 => Ring.Data) internal m_rings;
    mapping(uint256 => uint256) internal m_pubx_to_ring;

    event RingMessage(
        bytes32 message
    );

    event RingResult(
        uint success
    );

    event NewParticipant(
        uint x,
        uint y
    );

    event AvailableForDeposit();
    event BadSignature();
    event WithdrawEvent();
    event WithdrawReady();
    event WithdrawFinished();


    function Mixer () public {

    }


    function Deposit (address token, uint256 denomination, uint256 pub_x, uint256 pub_y)
        public
    {
        var ring_id = uint256(sha256(token, denomination));
        Ring.Data storage ring = m_rings[ring_id];

        ring.Initialize(token, denomination);

        if( ! ring.AddParticipant(pub_x, pub_y) )
            revert();

        if( ring.IsFull() ) {
            for( uint i = 0; i < ring.pubkeys.length; i++ ) {
                m_pubx_to_ring[ring.pubkeys[i].X] = ring.hash.X;
            }
        }
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

        msg.sender.transfer(ring.denomination);
    }


    function () public {
        // TODO: allow people to send ETH in any denomination to this contract
        //       put it in the appropriate ring, and emit events
        revert();
    }
}
