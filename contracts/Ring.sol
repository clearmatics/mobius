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
        uint256 guid;
        uint256 denomination;
        address token;
        bn256g1.Point hash;
        bn256g1.Point[] pubkeys;
        uint256[] tags;
    }


    /**
    * Have all possible Tags been used, one for each Public Key
    */
    function IsDead (Data self)
        internal view returns (bool)
    {
        return self.tags.length == self.pubkeys.length;
    }


    /**
    * Does the X component of a Public Key exist in the Ring?
    */
    function PubExists (Data storage self, uint256 pub_x)
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
    function TagExists (Data storage self, uint256 pub_x)
        internal view returns (bool)
    {
        for( uint i = 0; i < self.tags.length; i++ ) {
            if( self.tags[i] == pub_x ) {
                return true;
            }
        }
        return false;
    }


    function IsInitialized (Data storage self)
        internal view returns (bool)
    {
        return self.denomination == 0;
    }


    /**
    * Initialise the Ring.Data structure with a token and denomination
    */
    function Initialize (Data storage self, uint256 guid, address token, uint256 denomination)
        internal returns (bool)
    {
        require( denomination != 0 );
        require( guid != 0 );

        // Denomination indicates Ring.Data struct has been initialized
        if( ! IsInitialized(self) )
            return false;

        // Denomination must be positive power of 2, e.g. only 1 bit set
        if( 0 == (denomination & (denomination - 1)) )
            return false;

        // TODO: validate whether `token` is a valid ERC-223 contract

        self.guid = guid;
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

        // Fill Ring with Public Keys
        //  R = {h ← H(h, y)}
        self.hash.X = uint256(sha256(self.hash.X, pub.X, pub.Y));
        self.pubkeys.push(pub);

        if( IsFull(self) ) {
            // h ← H(h, m)
            // XXX: this won't be unique, need to mix-in other things
            //      m = (token, denomination)
            //      but, m should be (token, denomination, randomentropy?)
            self.hash.X = uint256(sha256(self.hash.X, self.token, self.denomination));
            self.hash = bn256g1.HashToPoint(self.hash.X);
        }

        return true;
    }


    /**
    * Generates an ordered hash segment for each public key in the ring
    *
    *   a ← g^t + y^c
    *   b ← h^t + τ^c
    *
    * Where:
    *
    *   - y is a pubkey in R
    *   - h is the root hash
    *   - τ is the tag
    *   - c is a random
    *
    * Each segment is used when verifying the ring:
    *
    *   sum({c...}) = H(R, m, τ, {a,b...})
    */
    function _ringLink( uint256 previous_hash, uint256 cj, uint256 tj, bn256g1.Point tau, bn256g1.Point h, bn256g1.Point yj )
        internal constant returns (uint256 ho)
    {       
        bn256g1.Point memory yc = yj.ScalarMult(cj);

        // a ← g^t + y^c
        bn256g1.Point memory a = bn256g1.ScalarBaseMult(tj).PointAdd(yc);

        // b ← h^t + τ^c
        bn256g1.Point memory b = h.ScalarMult(tj).PointAdd(tau.ScalarMult(cj));

        return uint256(sha256(previous_hash, a.X, a.Y, b.X, b.Y));
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
    *
    * Must call TagAdd(tag_x) after a valid signature, if an existing
    * tag exists the signature is invalidated to prevent double-spend
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

        // h ← H(h, τ)
        uint256 hashout = uint256(sha256(self.hash.X, tag_x, tag_y));
        uint256 csum = 0;

        for (uint i = 0; i < self.pubkeys.length; i++) {         
            // h ← {H(h, a, b)}
            // sum({c...})
            uint256 cj = ctlist[2*i];
            uint256 tj = ctlist[2*i+1];
            hashout = _ringLink(hashout, cj, tj, bn256g1.Point(tag_x, tag_y), self.hash, self.pubkeys[i]);
            csum = addmod(csum, cj, bn256g1.Prime());
        }

        hashout %= bn256g1.Prime();
        return hashout == csum;
    }
}
