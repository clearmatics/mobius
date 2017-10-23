pragma solidity ^0.4.2;


contract Ring {
    function Ring(uint participants, uint payments) public {
        Participants = participants;
        PaymentAmount = payments * 1 ether;
    }

    // Payable contracts need an empty, parameter-less function
    // so funds mistakenly sent are returned to their mistaken owner   
    function () public {
        revert();
    } 

    function start() public {
        // If this ring is initialized, throw to prevent someone wiping the ring state
        if (Started) {
            revert();
        }

        Started = true;
        // Message = block.blockhash(block.number-1);

        // This value is for the test suite
        Message = bytes32(0x50b44f86159783db5092ebe77fb4b9cc29e445e54db17f0e8d2bed4eb63126fc);

        // Broadcast the message for the newly started ring
        RingMessage(Message);
    }
    
    function deposit(uint256 pubx, uint256 puby) public payable {
        // Throw if no message chosen
        if (Started != true) {
            revert();
        }

        // Throw if ring already full
        if (pubKeyx.length >= Participants) {
            revert();
        }

        // Throw if incorrect value sent
        if (msg.value != PaymentAmount) {
            revert();
        }

        // Throw if participant is already in this ring -- accepting would lock
        // money forever as each linkable ring signature allows one withdrawal
        for (uint i = 0; i < pubKeyx.length; i++) {
            if (pubKeyx[i] == pubx) {
                revert();
            }
        }

        // Throw if submitted pubkey not a valid point on curve
        // Accepting would lock money in the contract forever -- there would
        // be no private key with which to generate the signature to release it
        uint xcubed = mulmod(mulmod(pubx, pubx, FIELD_ORDER), pubx, FIELD_ORDER);

        // Checking y^2 = x^3 + 7 is sufficient as only integers exist in solidity
        if (addmod(xcubed, 7, FIELD_ORDER) != mulmod(puby, puby, FIELD_ORDER)) {
            revert();
        }

        // If all the above are satisfied, add to ring :)
        pubKeyx.push(pubx);
        pubKeyy.push(puby);

        // Broadcast event that a participant has joined the ring
        NewParticipant(pubx, puby);

        if (pubKeyx.length == Participants) {
            WithdrawReady();
            
            for (i = 0; i < Participants; i++) {
                commonHashList.push(pubKeyx[i]);
            }
            
            for (i = 0; i < Participants; i++) {
                commonHashList.push(pubKeyy[i]);
            }

            commonHashList.push(uint256(Message));
            
            hashx = uint256(sha256(pubKeyx, pubKeyy, Message));
            (hashx, hashy) = gety(hashx);            
        }
    } 
    
    function withdraw(uint tagx, uint tagy, uint[] ctlist) public {
        // Throw if ring hasn't been started
        if (Started != true) {
            revert();
        }    

        // Throw if ring isn't yet full
        if (pubKeyx.length != Participants) {
            revert();
        }

        // Throw if tag has already been seen
        for (uint i = 0; i < tagList.length; i++) {
            if (tagList[i] == tagx) {
                revert();
            }
        }

        // Form H(R||m)
        csum = 0;

        for (i = 0; i < Participants; i++) {
            yjx = pubKeyx[i];
            yjy = pubKeyy[i];
            cj = ctlist[2*i];
            tj = ctlist[2*i+1];
            // t.H(R)
            (Htx, Hty) = ecMul(hashx, hashy, tj);
            // t.g
            (gtx, gty) = ecMul(GX, GY, tj);
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
            csum = addmod(csum, cj, GEN_ORDER);
        }

        var hashout = uint256(sha256(commonHashList, hashList)) % GEN_ORDER;
        csum = csum % GEN_ORDER;
        if (hashout == csum) {
            bool output = msg.sender.send(PaymentAmount);
            if (output == true) {
                tagList.push(tagx);
                // Signature and send successful
                Withdrawals += 1;
                delete hashList;
                WithdrawEvent();
                if (Withdrawals == Participants) {
                    Started = false;
                    Withdrawals = 0;
                    delete pubKeyx;
                    delete pubKeyy;
                    delete tagList;
                    delete commonHashList;
                    WithdrawFinished();
                }
                return;
            } else {
                // Signature verified, but send failed - this is bad so need to throw
                revert();
            }
        }

        // Signature didn't verify
        delete hashList;
        BadSignature();
    }  
    
    function gety(uint256 x) private constant returns (uint256 y, uint256) {
        // Security parameter. P(fail) = 1/(2^k)
        uint k = 999;
        uint256 z = FIELD_ORDER + 1;
        z = z / 4;

        for (uint i = 0; i < k; i++) {
            uint256 beta = addmod(mulmod(mulmod(x, x, FIELD_ORDER), x, FIELD_ORDER), 7, FIELD_ORDER);
            y = expMod(beta, z, FIELD_ORDER);
            if (beta == mulmod(y, y, FIELD_ORDER)) {
                return (x, y);
            }
            x = (x + 1) % FIELD_ORDER;
        }
    }   
    
    // withdrawl variable, used to avoid local variable overflowing the stack
    uint csum; 
    uint yjx; 
    uint yjy; 
    uint cj; 
    uint tj;
    uint Htx; 
    uint Hty;
    uint gtx; 
    uint gty; 
    uint ycx; 
    uint ycy;        
    uint taucx;
    uint taucy;           
    
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

    event BadSignature();
    event WithdrawEvent();
    event WithdrawReady();
    event WithdrawFinished();


    uint constant FIELD_ORDER = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F;
    uint constant GEN_ORDER = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;
    uint constant GX = 0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798;
    uint constant GY = 0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8;
 
    // Number of participants chosen by the party deploying contract.
    uint public Participants;
    
    uint public PaymentAmount;
    
    bytes32 public Message;
    
    bool public Started = false;
    uint public Withdrawals = 0;

    // Creating arrays needed to store the submitted public keys :)
    uint[] pubKeyx;
    uint[] pubKeyy; 
    
    uint hashx; 
    uint hashy;
        
    uint[] commonHashList;        
    
    uint[] hashList; 
    uint[] tagList;

    //
    // ECLib   
    //

    function _jAdd(
        uint256 x1, 
        uint256 z1, 
        uint256 x2, 
        uint256 z2) private constant 
        returns(uint256 x3, uint256 z3) 
    {
        (x3, z3) = (addmod(mulmod(z2, x1, Q_CONSTANT), mulmod(x2, z1, Q_CONSTANT), Q_CONSTANT), mulmod(z1, z2, Q_CONSTANT) );
    }

    function _jSub(
        uint256 x1,
        uint256 z1,
        uint256 x2, 
        uint256 z2) private constant 
        returns(uint256 x3, uint256 z3)
    {
        (x3, z3) = ( addmod(mulmod(z2, x1, Q_CONSTANT), mulmod(Q_CONSTANT - x2, z1, Q_CONSTANT), Q_CONSTANT), mulmod(z1, z2 , Q_CONSTANT) );
    }

    function _jMul(
        uint256 x1,
        uint256 z1,
        uint256 x2,
        uint256 z2) private constant 
        returns(uint256 x3, uint256 z3)
    {
        (x3, z3) = (mulmod(x1, x2, Q_CONSTANT), mulmod(z1, z2, Q_CONSTANT));
    }

    function _jDiv(
        uint256 x1,
        uint256 z1,
        uint256 x2, 
        uint256 z2) private constant 
        returns(uint256 x3, uint256 z3)
    {
        (x3, z3) = (mulmod(x1, z2, Q_CONSTANT), mulmod(z1, x2, Q_CONSTANT));
    }

    function inverse(uint256 element) private constant //inverts an element, a, of the finite field
        returns(uint256 inva)
    {
        uint256 t = 0;
        uint256 newT = 1;
        uint256 r = Q_CONSTANT;
        uint256 newR = element;
        uint256 p;
        while (newR != 0) {
            p = r / newR;
            (t, newT) = (newT, addmod(t, (Q_CONSTANT - mulmod(p, newT, Q_CONSTANT)), Q_CONSTANT));
            (r, newR) = (newR, r - p * newR);
        }

        return t;
    }

    function _ecAdd(
        uint256 x1, 
        uint256 y1, 
        uint256 z1,
        uint256 x2, 
        uint256 y2, 
        uint256 z2) private constant
        returns(uint256 x3, uint256 y3, uint256 z3)
    {
        uint256 ly;
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
            (ly, lz) = _jMul(x1, z1, x1, z1);
            (ly, lz) = _jMul(ly, lz, 3, 1);
            (ly, lz) = _jAdd(ly, lz, A_CONSTANT, 1);
            (da, db) = _jMul(y1, z1, 2, 1);
        } else {
            (ly, lz) = _jSub(y2, z2, y1, z1);
            (da, db)  = _jSub(x2, z2, x1, z1);
        }

        (ly, lz) = _jDiv(ly, lz, da, db);

        (x3, da) = _jMul(ly, lz, ly, lz);
        (x3, da) = _jSub(x3, da, x1, z1);
        (x3, da) = _jSub(x3, da, x2, z2);

        (y3, db) = _jSub(x1, z1, x3, da);
        (y3, db) = _jMul(y3, db, ly, lz);
        (y3, db) = _jSub(y3, db, y1, z1);

        if (da != db) {
            x3 = mulmod(x3, db, Q_CONSTANT);
            y3 = mulmod(y3, da, Q_CONSTANT);
            z3 = mulmod(da, db, Q_CONSTANT);
        } else {
            z3 = da;
        }
    }

    function _ecDouble(uint256 x1, uint256 y1, uint256 z1) private constant
        returns(uint256 x3,uint256 y3,uint256 z3)
    {
        (x3, y3, z3) = _ecAdd(x1, y1, z1, x1, y1, z1);
    }

    function _ecMul(
        uint256 d,
        uint256 x1,
        uint256 y1,
        uint256 z1) private constant
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

    function ecMul(uint256 ax, uint256 ay, uint256 k) private constant
        returns(uint256 px, uint256 py) 
    {
        // With a priv key, B pub key, this computes aB.
        // Then other party can compute bA and you've got your shared secret set up :)
        uint256 x;
        uint256 y;
        uint256 z;
        (x, y, z) = _ecMul(k, ax, ay, 1);
        z = inverse(z);
        px = mulmod(x, z, Q_CONSTANT);
        py = mulmod(y, z, Q_CONSTANT);
    }

    function ecAdd(
        uint256 ax, 
        uint256 ay, 
        uint256 bx, 
        uint256 by) private constant
        returns(uint256 px, uint256 py)
    {
        uint256 x;
        uint256 y;
        uint256 z;
        (x, y, z) = _ecAdd(ax, ay, 1, bx, by, 1);
        z = inverse(z);
        px = mulmod(x, z, Q_CONSTANT);
        py = mulmod(y, z, Q_CONSTANT);
    }

    function expMod(uint256 base, uint256 e, uint256 m) private constant returns (uint256 o) {
        if (base == 0) {
            return 0;
        }
        
        if (e == 0) {
            return 1;
        }
        
        if (m == 0) {
            revert();
        }
        
        o = 1;
        uint256 bit = 2 ** 255;
        
        while (bit > 0) {        
            assembly {
                // Loop unrolling for optimisation!!!
                o := mulmod(mulmod(o, o, m), exp(base, iszero(iszero(and(e, bit)))), m)
                o := mulmod(mulmod(o, o, m), exp(base, iszero(iszero(and(e, div(bit, 2))))), m)
                o := mulmod(mulmod(o, o, m), exp(base, iszero(iszero(and(e, div(bit, 4))))), m)
                o := mulmod(mulmod(o, o, m), exp(base, iszero(iszero(and(e, div(bit, 8))))), m)
                bit := div(bit, 16)
            }
        }
    }
  
    uint256 constant Q_CONSTANT = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F;
    uint256 constant A_CONSTANT = 0;
}

