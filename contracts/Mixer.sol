pragma solidity ^0.4.18;

import './bn256g1.sol';

contract Mixer {
	using bn256g1 for bn256g1.Point;
	uint256 public constant RING_SIZE = 4;

	struct Ring {
		uint256 denomination;
		address token;
		bn256g1.Point hash;
		bn256g1.Point[] pubkeys;
		uint256[] tags;
	}

	mapping(bytes32 => Ring) internal m_rings;
	mapping(uint256 => bytes32) internal m_pubx_to_ring;

	function Mixer () public {

	}

	function () public {
		revert();
	}

	function Deposit (address _token, uint256 _pub_x, uint256 _pub_y)
		public payable
	{
		uint256 denomination = msg.value;
		bn256g1.Point memory pub = bn256g1.Point(_pub_x, _pub_y);

		// verify value is a power of 2
		//   this is required for payment splitting
		if( 0 == denomination || 0 == (msg.value & (msg.value - 1)) ) {
			revert();
		}

		// Check validity of public key
		if( ! pub.IsOnCurve() ) {
			revert();
		}

		// Lookup ring
		//   XXX: this is a temporary hack, replace with something better
		bytes32 ring_id = sha256(_token, denomination);
		Ring storage ring = m_rings[ring_id];

		// Ring must not be full
		if( ring.pubkeys.length == RING_SIZE ) {
			revert();
		}
		// If ring is empty, initialise it
		else if( ring.pubkeys.length == 0 ) {
			ring.denomination = denomination;
			ring.token = _token;
		}

		// Verify the public key doesn't exist in the ring
		//   accepting duplicate public keys would lock money forever
		//   as each linkable ring signature allows only one withdrawal
		for( uint i = 0; i < ring.pubkeys.length; i++ ) {
			if( ring.pubkeys[i].X == pub.X ) {
				revert();
			}
		}

		ring.pubkeys.push(pub);

		if( ring.pubkeys.length == RING_SIZE ) {
			// XXX: the ring.hash must be unique
			//      hash all of public keys to provide a ring guid
			ring.hash = bn256g1.HashToPoint(ring_id);
		}
	}


	function Withdraw (bytes32 ring_id, uint256 _tag_x, uint256 _tag_y, uint[] ctlist)
		public
	{
		bn256g1.Point memory tag = bn256g1.Point(_tag_x, _tag_y);
		Ring storage ring = m_rings[ring_id];
		if( ring.pubkeys.length != RING_SIZE ) {
			revert();
		}

		// tags are unique, a duplicate tag = double spend
		for( uint i = 0; i < ring.tags.length; i++ ) {
			if( ring.tags[i] == tag.X )  {
				revert();
			}
		}

		uint256 hashout = 0; // begin with commonHashList

        // Form H(R||m)
        uint csum = 0;
		uint256 cj;
		uint256 tj;

        for (i = 0; i < ring.pubkeys.length; i++) {          
            cj = ctlist[2*i];
            tj = ctlist[2*i+1];      

            // y^c = G^(xc)
            bn256g1.Point memory yc = ring.pubkeys[i].ScalarMult(cj);

            // G^t + y^c
            bn256g1.Point memory Gt = bn256g1.ScalarBaseMult(tj).PointAdd(yc);

            hashout ^= uint256(sha256(Gt.X));
            hashout ^= uint256(sha256(Gt.Y));

            //H(m||R)^t
            bn256g1.Point memory H = ring.hash.ScalarMult(tj).PointAdd(tag.ScalarMult(cj));

            hashout ^= uint256(sha256(H.X));
            hashout ^= uint256(sha256(H.Y));
            
            csum = addmod(csum, cj, bn256g1.Prime());
        }

        hashout %= bn256g1.Prime();

        return hashout == csum;
	}


	function _expMod(uint256 _base, uint256 _exponent, uint256 _modulus)
        internal constant returns (uint256 retval)
    {
        bool success;
        uint[3] memory input;
        input[0] = _base;
        input[1] = _exponent;
        input[2] = _modulus;
        assembly {
            success := call(sub(gas, 2000), 5, 0, input, 0x60, retval, 0x20)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid }
        }
        require(success);
    }
}