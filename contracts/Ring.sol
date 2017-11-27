// Copyright (c) 2016-2017 Clearmatics Technologies Ltd

// SPDX-License-Identifier: (LGPL-3.0+ AND GPL-3.0)

pragma solidity ^0.4.18;

import './ERC20.sol';
import './bn256g1.sol';

library Ring
{
    using bn256g1 for bn256g1.Point;
    uint256 public constant RING_SIZE = 4;

    struct Data {
        uint256 denomination;
        address token;
        bn256g1.Point hash;
        bn256g1.Point[] pubkeys;
        uint256[] tags;
    }


    /**
    * Does the X component of a Public Key exist?
    */
    function PubExists (Data self, uint256 pub_x)
        internal view returns (bool)
    {
        for( uint i = 0; i < self.pubkeys.length; i++ ) {
            if( self.pubkeys[i].X == pub_x ) {
                return true;
            }
        }
        return false;
    }


    /**
    * Does the X component of a Tag exist?
    */
    function TagExists (Data self, uint256 pub_x)
        internal constant returns (bool)
    {
        for( uint i = 0; i < self.tags.length; i++ ) {
            if( self.tags[i] == pub_x ) {
                return true;
            }
        }
        return false;
    }


    function IsInitialized (Data storage self)
        internal returns (bool)
    {
        return self.denomination == 0;
    }


    /**
    * Initialise the Ring.Data structure with a token and denomination
    */
    function Initialize (Data storage self, address token, uint256 denomination)
        internal returns (bool)
    {
        // Denomination indicates Ring.Data struct has been initialized
        if( ! IsInitialized(self) )
            return false;

        // Denomination must be positive power of 2, e.g. only 1 bit set
        if( denomination == 0 || 0 == (msg.value & (msg.value - 1)) )
            return false;

        // TODO: validate whether `token` is a valid ERC223 contract

        self.token = token;
        self.denomination = denomination;

        return true;
    }


    /**
    * Maximum number of participants reached
    */
    function IsFull (Data storage self)
        internal view returns (bool)
    {
        return self.pubkeys.length == RING_SIZE;
    }


    /**
    * Add the Public Key to the ring as a ring participant
    */
    function AddParticipant (Data storage self, uint256 pub_x, uint256 pub_y)
        internal returns (bool)
    {
        if( IsFull(self) )
            return false;

        // accepting duplicate public keys would lock money forever
        // as each linkable ring signature allows only one withdrawal
        if( PubExists(self, pub_x) )
            return false;

        bn256g1.Point memory pub = bn256g1.Point(pub_x, pub_y);
        if( ! pub.IsOnCurve() )
            return false;


        self.hash.X ^= uint256(sha256(pub.X, pub.Y));
        self.pubkeys.push(pub);

        if( IsFull(self) ) {
            // TODO: mix-in block height, time, other stuff
            bytes32 ring_id = sha256(self.token, self.denomination);
            self.hash = bn256g1.HashToPoint(bytes32(uint256(ring_id) ^ self.hash.X));
        }

        return true;
    }


    function _ringLink( uint256 cj, uint256 tj, bn256g1.Point tag, bn256g1.Point hash, bn256g1.Point pub )
        internal constant returns (uint256 ho)
    {       
        // y^c = G^(xc)
        bn256g1.Point memory yc = pub.ScalarMult(cj);

        // G^t + y^c
        bn256g1.Point memory Gt = bn256g1.ScalarBaseMult(tj).PointAdd(yc);

        //H(m||R)^t
        bn256g1.Point memory H = hash.ScalarMult(tj).PointAdd(tag.ScalarMult(cj));

        return uint256(sha256(Gt.X, Gt.Y, H.X, H.Y));
    }


    /**
    * Save the tag, which will invalidate any future signatures from the same tag
    */
    function TagAdd (Data storage self, uint256 tag_x)
        internal
    {
        self.tags.push(tag_x);
    }


    /**
    * Verify whether or not a Ring Signature is valid
    */
    function SignatureValid (Data storage self, uint256 tag_x, uint256 tag_y, uint256[] ctlist)
        internal view returns (bool)
    {
        // Ring must be full before signatures can be accepted
        if( ! IsFull(self) )
            return false;

        // If tag exists, the signature is no longer valid
        // Remember, the tag must be saved to the ring afterwards
        if( TagExists(self, tag_x) )
            return false;

        bn256g1.Point memory tag = bn256g1.Point(tag_x, tag_y);
        uint256 hashout = 0; // begin with commonHashList
        uint csum = 0;
        uint256 cj;
        uint256 tj;

        for (uint i = 0; i < self.pubkeys.length; i++) {         
            cj = ctlist[2*i];
            tj = ctlist[2*i+1];
            hashout ^= _ringLink(cj, tj, tag, self.hash, self.pubkeys[i]);
            csum = addmod(csum, cj, bn256g1.Prime());
        }

        hashout %= bn256g1.Prime();

        return hashout == csum;
    }
}
