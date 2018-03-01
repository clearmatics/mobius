// Copyright (c) 2016-2017 Clearmatics Technologies Ltd

// SPDX-License-Identifier: LGPL-3.0+

pragma solidity ^0.4.18;

import {bn256g1 as Curve} from './bn256g1.sol';


/**
* This contract implements the Franklin Zhang linkable ring signature
* algorithm as used by the Möbius whitepaper (IACR 2017/881):
*
* - https://eprint.iacr.org/2017/881.pdf
*
* Abstract:
* 
* "Cryptocurrencies allow users to securely transfer money without
*  relying on a trusted intermediary, and the transparency of their
*  underlying ledgers also enables public verifiability. This openness,
*  however, comes at a cost to privacy, as even though the pseudonyms
*  users go by are not linked to their real-world identities, all
*  movement of money among these pseudonyms is traceable. In this paper,
*  we present Möbius, an Ethereum-based tumbler or mixing service. Möbius
*  achieves strong notions of anonymity, as even malicious senders cannot
*  identify which pseudonyms belong to the recipients to whom they sent
*  money, and is able to resist denial-of-service attacks. It also
*  achieves a much lower off-chain communication complexity than all
*  existing tumblers, with senders and recipients needing to send only
*  two initial messages in order to engage in an arbitrary number of
*  transactions."
*
* However, this specific contract introduces the following differences
* in comparison to the white paper:
*
*  - P256k1 replaced with ALT_BN128 (as per EIP-213)
*  - The Message signed by Participants has changed
*  - The Ring contract is now a library
*  - The Ring Data stores the Token, Denomination and GUID
*  - Ring is a fixed size
*  - One SHA256 iteration per public key on verify
*
*
* Initialise Ring (R):
*
*   h = H(guid...)
*   for y in R
*       h = H(h, y)
*   m = HashToPoint(h)
*
*
* Verify Signature (σ):
*
*   c = 0
*   h = H(m, τ)
*   for j,c,t in σ
*       y = R[j]
*       a = g^t + y^c
*       b = m^t + τ^c
*       h = H(h, a, b)
*       csum += c
*   h == csum
*
*
* The Verify Signature routine differs from the Mobius whitepaper and 
* is slightly less efficient because it performs one H() operation 
* per public key, instead of appending all items to be hashed into a 
* list then hashing the result.
*
* Potential Performance improvements:
*
*  - Switch to SHA3
*  - Reduce number of hash operations in verify (requires more memory, but only 1 hash)
*  - Reduce number of storage operations
*  - Use 'identity' precompiled contract
*/
library LinkableRing
{
    using Curve for Curve.Point;
    uint256 public constant RING_SIZE = 4;

    struct Data {        
        Curve.Point hash;
        Curve.Point[] pubkeys;
        uint256[] tags;
    }


    /**
    * The message to be signed to withdraw from the ring once it's full
    */
    function Message (Data storage self)
        internal view returns (bytes32)
    {
        require( IsFull(self) );

        return bytes32(self.hash.X);
    }


    /**
    * Have all possible Tags been used, one for each Public Key
    * If the ring has not been initialized it is considered Dead.
    */
    function IsDead (Data storage self)
        internal view returns (bool)
    {
        return self.hash.X == 0 || (self.tags.length >= RING_SIZE && self.pubkeys.length >= RING_SIZE);
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
        return self.hash.X != 0;
    }


    /**
    * Initialise the Ring.Data structure with a token and denomination
    */
    function Initialize (Data storage self, bytes32 guid)
        internal returns (bool)
    {
        require( uint256(guid) != 0 );
        require( self.hash.X == 0 );

        self.hash.X = uint256(guid);

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
        require( ! IsFull(self) );

        // accepting duplicate public keys would lock money forever
        // as each linkable ring signature allows only one withdrawal
        require( ! PubExists(self, pub_x) );

        Curve.Point memory pub = Curve.Point(pub_x, pub_y);
        require( pub.IsOnCurve() );

        // Fill Ring with Public Keys
        //  R = {h ← H(h, y)}
        self.hash.X = uint256(sha256(self.hash.X, pub.X, pub.Y));
        self.pubkeys.push(pub);

        if( IsFull(self) ) {
            // h ← H(h, m)
            self.hash = Curve.HashToPoint(bytes32(self.hash.X));
        }

        return true;
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
    * Generates an ordered hash segment for each public key in the ring
    *
    *   a ← g^t + y^c
    *   b ← h^t + τ^c
    *
    * Where:
    *
    *   - y is a pubkey in R
    *   - h is the root hash
    *   - τ is the public key tag (unique per message)
    *   - c is a random point
    *
    * Each segment is used when verifying the ring:
    *
    *   h, sum({c...}) = H(h, {(τ,a,b)...})
    */
    function _ringLink( uint256 previous_hash, uint256 cj, uint256 tj, Curve.Point tau, Curve.Point h, Curve.Point yj )
        internal view returns (uint256 ho)
    {       
        Curve.Point memory yc = yj.ScalarMult(cj);

        // a ← g^t + y^c
        Curve.Point memory a = Curve.ScalarBaseMult(tj).PointAdd(yc);

        // b ← h^t + τ^c
        Curve.Point memory b = h.ScalarMult(tj).PointAdd(tau.ScalarMult(cj));

        return uint256(sha256(previous_hash, a.X, a.Y, b.X, b.Y));
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
        require( IsFull(self) );

        // If tag exists, the signature is no longer valid
        // Remember, the tag must be saved to the ring afterwards
        require( ! TagExists(self, tag_x) );

        // h ← H(h, τ)
        uint256 hashout = uint256(sha256(self.hash.X, tag_x, tag_y));
        uint256 csum = 0;

        for (uint i = 0; i < self.pubkeys.length; i++) {         
            // h ← H(h, a, b)
            // sum({c...})
            uint256 cj = ctlist[2*i] % Curve.GenOrder();
            uint256 tj = ctlist[2*i+1] % Curve.GenOrder();
            hashout = _ringLink(hashout, cj, tj, Curve.Point(tag_x, tag_y), self.hash, self.pubkeys[i]);
            csum = addmod(csum, cj, Curve.GenOrder());
        }

        hashout %= Curve.GenOrder();
        return hashout == csum;
    }
}
