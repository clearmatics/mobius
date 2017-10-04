pragma solidity ^0.4.2;

contract Mobius {

    uint256 constant q = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F;
    uint256 constant a = 0;
    uint256 constant b = 7;

    function EC() {
    }

    function _jAdd( uint256 x1, uint256 z1,
                    uint256 x2, uint256 z2) constant
        returns(uint256 x3, uint256 z3) {
        (x3, z3) = ( addmod(mulmod(z2, x1, q), mulmod(x2, z1, q), q), mulmod(z1, z2, q) );
    }

    function _jSub( uint256 x1, uint256 z1,
                    uint256 x2, uint256 z2) constant
        returns(uint256 x3, uint256 z3) {
        (x3, z3) = ( addmod(mulmod(z2, x1, q), mulmod(q - x2, z1, q), q), mulmod(z1, z2 , q) );
    }

    function _jMul( uint256 x1, uint256 z1,
                    uint256 x2, uint256 z2) constant
        returns(uint256 x3, uint256 z3) {
        (x3, z3) = (mulmod(x1, x2, q), mulmod(z1, z2, q));
    }

    function _jDiv( uint256 x1, uint256 z1,
                    uint256 x2, uint256 z2) constant
        returns(uint256 x3, uint256 z3) {
        (x3, z3) = (mulmod(x1, z2, q), mulmod(z1, x2, q));
    }

    function inverse(uint256 a)  //inverts an element, a, of the finite field
        returns(uint256 inva) {
        uint256 t = 0;
        uint256 newT = 1;
        uint256 r = q;
        uint256 newR = a;
        uint256 p;
        while (newR != 0) {
            p = r / newR;
            (t, newT) = (newT, addmod(t, (q - mulmod(p, newT, q)), q));
            (r, newR) = (newR, r - p * newR);
        }

        return t;
    }


    function _ecAdd(uint256 x1, uint256 y1, uint256 z1,
                   uint256 x2, uint256 y2, uint256 z2) constant
        returns(uint256 x3, uint256 y3, uint256 z3) {
        uint256 l;
        uint256 lz;
        uint256 da;
        uint256 db;

        if ((x1 == 0) && (y1 == 0)) {
            // 0 + P = P
            return (x2, y2, z2);
        }

        if ((x2 == 0) && (y2 == 0)) {
            // P + 0 = P
            return (x1, y1, z1);
        }

        if ((x1 == x2) && (y1 == y2)) {
            // P + P = 2P
            (l, lz) = _jMul(x1, z1, x1, z1);
            (l, lz) = _jMul(l, lz, 3, 1);
            (l, lz) = _jAdd(l, lz, a, 1);
            (da, db) = _jMul(y1, z1, 2, 1);
        } else {
            (l, lz) = _jSub(y2, z2, y1, z1);
            (da, db)  = _jSub(x2, z2, x1, z1);
        }

        (l, lz) = _jDiv(l, lz, da, db);

        (x3, da) = _jMul(l, lz, l, lz);
        (x3, da) = _jSub(x3, da, x1, z1);
        (x3, da) = _jSub(x3, da, x2, z2);

        (y3, db) = _jSub(x1, z1, x3, da);
        (y3, db) = _jMul(y3, db, l, lz);
        (y3, db) = _jSub(y3, db, y1, z1);

        if (da != db) {
            x3 = mulmod(x3, db, q);
            y3 = mulmod(y3, da, q);
            z3 = mulmod(da, db, q);
        } else {
            z3 = da;
        }
    }

    function _ecDouble(uint256 x1,uint256 y1,uint256 z1) constant
        returns(uint256 x3,uint256 y3,uint256 z3) {
        (x3, y3, z3) = _ecAdd(x1, y1, z1, x1, y1, z1);
    }

    function _ecMul(uint256 d, uint256 x1, uint256 y1, uint256 z1) constant
        returns(uint256 x3, uint256 y3, uint256 z3)
    {
        uint256 remaining = d;
        uint256 px = x1;
        uint256 py = y1;
        uint256 pz = z1;
        uint256 acx = 0;
        uint256 acy = 0;
        uint256 acz = 1;

        // 0P = 0
        if (d == 0) {
            return (0, 0, 1);
        }

        // For d =/= 0, use double and add
        while (remaining != 0) {
            if ((remaining & 1) != 0) {
                (acx, acy, acz) = _ecAdd(acx, acy, acz, px, py, pz);
            }
            remaining = remaining / 2;
            (px, py, pz) = _ecDouble(px, py, pz);
        }

        (x3, y3, z3) = (acx, acy, acz);
    }

    function scalarBaseMul(uint256 k) constant
        returns(uint256 px, uint256 py) {
        uint256 x;
        uint256 y;
        uint256 z;
        (x, y, z) = _ecMul(k, gx, gy, 1);
        z = inverse(z);
        px = mulmod(x, z, q);
        py = mulmod(y, z, q);
    }

    function ecMul(uint256 ax, uint256 ay, uint256 k) constant
        returns(uint256 px, uint256 py) {
        // With a priv key, B pub key, this computes aB.
        // Then other party can compute bA and you've got your shared secret set up :)
        uint256 x;
        uint256 y;
        uint256 z;
        (x, y, z) = _ecMul(k, ax, ay, 1);
        z = inverse(z);
        px = mulmod(x, z, q);
        py = mulmod(y, z, q);
    }

    function ecAdd(uint256 ax, uint256 ay, uint256 bx, uint256 by) constant
        returns(uint256 px, uint256 py) {
        uint256 x;
        uint256 y;
        uint256 z;
        (x, y, z) = _ecAdd(ax, ay, 1, bx, by, 1);
        z = inverse(z);
        px = mulmod(x, z, q);
        py = mulmod(y, z, q);
    }

    function expMod(uint256 b, uint256 e, uint256 m) constant returns (uint256 o) {
       if (b == 0) {
          return 0;
       }
       if (e == 0) {
          return 1;
       }
       if (m == 0) {
          throw;
       }
       o = 1;
       uint256 bit = 2 ** 255;
       assembly {
          loop:
             jumpi(end, iszero(bit))
             // Loop unrolling for optimisation!!!
             o := mulmod(mulmod(o, o, m), exp(b, iszero(iszero(and(e, bit)))), m)
             o := mulmod(mulmod(o, o, m), exp(b, iszero(iszero(and(e, div(bit, 2))))), m)
             o := mulmod(mulmod(o, o, m), exp(b, iszero(iszero(and(e, div(bit, 4))))), m)
             o := mulmod(mulmod(o, o, m), exp(b, iszero(iszero(and(e, div(bit, 8))))), m)
             bit := div(bit, 16)
             jump(loop)
          end:
       }
    }

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

	event CurvePoint(
		uint x,
		uint y
	);

	event BadSignature();
	event WithdrawEvent();
	event WithdrawReady();
	event WithdrawFinished();

	// Number of participants chosen by the party deploying contract.
	uint public Participants;
	uint public PaymentAmount;
	bytes32 public Message;
	bool public Started = false;
	uint public Withdrawals = 0;
	// Creating arrays needed to store the submitted public keys :)
	uint[] pubKeyx;
	uint[] pubKeyy;

	uint fieldOrder = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F;
	uint genOrder = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;
	uint gx = 0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798;
	uint gy = 0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8;

	// Payable contracts need an empty, parameter-less function
	// so funds mistakenly sent are returned to their mistaken owner :)

	function () {
		throw;
	}

	function Ring(uint participants, uint payments){
		Participants = participants;
		PaymentAmount = payments * 1 ether;
	}

	function start(){
		// If this ring is initialized, throw to prevent someone wiping the ring state
		if (Started)
			throw;

		Started = true;
		// Message = block.blockhash(block.number-1);

		// This value is for the test suite
		Message = bytes32(0x50b44f86159783db5092ebe77fb4b9cc29e445e54db17f0e8d2bed4eb63126fc);

		// Broadcast the message for the newly started ring
		RingMessage(Message);
	}

	uint[] commonHashList;

	function deposit(uint256 pubx, uint256 puby) payable {

		// Throw if no message chosen
		if (Started != true){
			throw;
		}

		// Throw if ring already full
		if (pubKeyx.length >= Participants) {
			throw;
		}

		// Throw if incorrect value sent
		if (msg.value != PaymentAmount) {
			throw;
		}

		// Throw if participant is already in this ring -- accepting would lock
        // money forever as each linkable ring signature allows one withdrawal
		for (i = 0; i < pubKeyx.length; i++){
			if (pubKeyx[i] == pubx)
				throw;
		}

		// Throw if submitted pubkey not a valid point on curve
		// Accepting would lock money in the contract forever -- there would
		// be no private key with which to generate the signature to release it

		uint xcubed = mulmod(mulmod(pubx, pubx, fieldOrder), pubx, fieldOrder);

		// Checking y^2 = x^3 + 7 is sufficient as only integers exist in solidity

		if(addmod(xcubed, 7, fieldOrder) != mulmod(puby, puby, fieldOrder)) {
			throw;
		}

		// If all the above are satisfied, add to ring :)

		pubKeyx.push(pubx);
		pubKeyy.push(puby);

		// Broadcast event that a participant has joined the ring
		NewParticipant(pubx, puby);

		if (pubKeyx.length == Participants){
			WithdrawReady();
			for (j = 0; j < Participants; j++){
				commonHashList.push(pubKeyx[j]);
			}
			for (j = 0; j < Participants; j++){
				commonHashList.push(pubKeyy[j]);
			}

			commonHashList.push(uint256(Message));
		}
	}

	uint j; uint i; uint csum; uint hashx; uint hashy;
	uint yjx; uint yjy; uint cj; uint tj; uint Htx; uint Hty;
	uint gtx; uint gty; uint ycx; uint ycy; uint taucx; uint taucy;
	uint[] tagList; uint[] hashList; bool output;

	function withdraw(uint tagx, uint tagy, uint[] ctlist) {

		// Throw if ring hasn't been started
		if (Started != true)
			throw;

		// Throw if ring isn't yet full
		if (pubKeyx.length != Participants) {
			throw;
		}

		// Throw if tag has already been seen
		for (i = 0; i < tagList.length; i++) {
			if (tagList[i] == tagx) {
				throw;
			}
		}

		// Form H(R||m)
		hashx = uint256(sha256(pubKeyx, pubKeyy, Message));
		(hashx, hashy) = gety(hashx);

		csum = 0;

		for (j = 0; j < Participants; j++) {
			yjx = pubKeyx[j];
			yjy = pubKeyy[j];
			cj = ctlist[2*j];
			tj = ctlist[2*j+1];
			// t.H(R)
			(Htx, Hty) = ecMul(hashx, hashy, tj);
			// t.g
			(gtx, gty) = ecMul(gx, gy, tj);
			// c.y (= xc.g)
			(ycx, ycy) = ecMul(yjx, yjy, cj);
			// c.tag (= xc.H(R))
			(taucx, taucy) = ecMul(tagx, tagy, cj);
			// Construct t.G + c.Y
			(gtx, gty) = ecAdd(gtx, gty, ycx, ycy);
			// Construct t.H + c.tag
			(Htx, Hty) = ecAdd(Htx, Hty, taucx, taucy);

			/* fieldJacobianToBigAffine `normalizes' values before returning -
			normalize uses fast reduction on special form of secp256k1's prime! :D */


			hashList.push(gtx);
			hashList.push(gty);
			hashList.push(Htx);
			hashList.push(Hty);
			csum = addmod(csum, cj, genOrder);
		}

		var hashout = uint256(sha256(commonHashList, hashList)) % genOrder;
		csum = csum % genOrder;
		if (hashout == csum) {
			output = msg.sender.send(PaymentAmount);
			if (output == true) {
				tagList.push(tagx);
				// Signature and send successful
				Withdrawals += 1;
				delete hashList;
				WithdrawEvent();
				if (Withdrawals == Participants){
					Started = false;
					Withdrawals = 0;
					delete pubKeyx;
					delete pubKeyy;
					delete tagList;
					delete commonHashList;
					WithdrawFinished();
				}
				return;
			}
			else {
				// Signature verified, but send failed - this is bad so need to throw
				throw;
			}
		}
		// Signature didn't verify
		delete hashList;
		BadSignature();
	}

	function gety(uint256 x) constant returns (uint256 y, uint256) {
		// Security parameter. P(fail) = 1/(2^k)
		uint k = 999;
		uint256 z = fieldOrder + 1;
		z = z / 4;

		for (uint i = 0; i < k; i++) {
			uint256 beta = addmod(mulmod(mulmod(x, x, fieldOrder), x, fieldOrder), 7, fieldOrder);
			y = expMod(beta, z, fieldOrder);
			if (beta == mulmod(y, y, fieldOrder)) {
				return (x, y);
			}
			x = (x + 1) % fieldOrder;
		}
	}

	function expmod(uint256 b, uint256 e, uint256 m) constant returns (uint256) {
		if (b == 0) {
			return 0;
		}
		if (e == 0) {
			return 1;
		}
		if (m == 0) {
			return 0;
		}
		uint256 o = 1;
		uint256 bit = 57896044618658097711785492504343953926634992332820282019728792003956564819968;
		while (bit > 0) {
			uint bitval = 0;
			if(e & bit > 0) bitval = 1;
			o = mulmod(mulmod(o, o, m), b ** bitval, m);
			bitval = 0;
			if(e & (bit / 2) > 0) bitval = 1;
			o = mulmod(mulmod(o, o, m), b ** bitval, m);
			bitval = 0;
			if(e & (bit / 4) > 0) bitval = 1;
			o = mulmod(mulmod(o, o, m), b ** bitval, m);
			bitval = 0;
			if(e & (bit / 8) > 0) bitval = 1;
			o = mulmod(mulmod(o, o, m), b ** bitval, m);
			bit = (bit / 16);
		}
		return o;
	}

}

