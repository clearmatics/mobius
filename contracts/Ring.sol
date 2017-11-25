
// Copyright (c) 2016-2017 Clearmatics Technologies Ltd

// SPDX-License-Identifier: (LGPL-3.0+ AND GPL-3.0)

pragma solidity ^0.4.18;

import './ERC20.sol';
import './bn256g1.sol';

contract Ring{
    function Ring(uint participants, uint payments, address token) public {
        Participants = participants;
        
        if (token == 0) {
            UsingToken = false;

            PaymentAmount = payments;
            
        } else {
            UsingToken = true;
        
            PaymentAmount = payments;
            Token = ERC20Interface(token);
        }
       
        // Broadcast the ring is available      
        AvailableForDeposit();   
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
    
    function deposit(uint256 pubx, uint256 puby, uint256 value) public payable {
        // Throw if no message chosen
        if (Started != true) {
            revert();
        }

        // Throw if ring already full
        if (pubKeyx.length >= Participants) {
            revert();
        } 
        
        // Throw if the sender does not have the funds
        if ((!UsingToken) && (msg.value != PaymentAmount)) {
             revert();       
        } else if ((UsingToken) && (value != PaymentAmount)) {
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
        uint xcubed = mulmod(mulmod(pubx, pubx, bn256g1.Order()), pubx, bn256g1.Order());

        // Checking y^2 = x^3 + 3 is sufficient as only integers exist in solidity
        if (addmod(xcubed, 3, bn256g1.Order()) != mulmod(puby, puby, bn256g1.Order())) {
            revert();
        }       
        
        if (UsingToken) {
            bool success = Token.transferFrom(msg.sender, this, value);
            
            if (success != true) {
                revert();            
            }
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

            // Security parameter. P(fail) = 1/(2^k)
            uint k = 999;
            uint256 z = bn256g1.Order() + 1;
            z = z / 4;
            for (i = 0; i < k; i++) {
                uint256 beta = addmod(mulmod(mulmod(hashx, hashx, bn256g1.Order()), hashx, bn256g1.Order()), 3, bn256g1.Order());
                hashy = expMod(beta, z, bn256g1.Order());
                if (beta == mulmod(hashy, hashy, bn256g1.Order())) {
                    return;
                }
                
                hashx = (hashx + 1) % bn256g1.Order();
            }            
        }
    } 
    
    function withdraw(uint256 tagx, uint256 tagy, uint[] ctlist) public {
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
        uint csum = 0;

        for (i = 0; i < Participants; i++) {          
            uint256 cj = ctlist[2*i];
            uint256 tj = ctlist[2*i+1];      

            bn256g1.Point memory y = bn256g1.Point(pubKeyx[i], pubKeyy[i]);
            bn256g1.Point memory yc = bn256g1.ScalarMult(y, cj); // y^c = G^(xc)
            bn256g1.Point memory Gt = bn256g1.ScalarBaseMult(tj); // G^t
            Gt = bn256g1.PointAdd(Gt, yc); // == G^t + y^c
            hashList.push(Gt.X);
            hashList.push(Gt.Y);

            bn256g1.Point memory tauc = bn256g1.ScalarMult(bn256g1.Point(tagx, tagy), cj);
            bn256g1.Point memory H = bn256g1.ScalarMult(bn256g1.Point(hashx, hashy), tj); //H(m||R)^t
            H = bn256g1.PointAdd(H, tauc);            
            hashList.push(H.X);
            hashList.push(H.Y);
           
            csum = addmod(csum, cj, bn256g1.Prime());
        }

        var hashout = uint256(sha256(commonHashList, hashList)) % bn256g1.Prime();
        delete hashList;
                
        if (hashout == csum) {
            bool output;
            
            if (UsingToken) {            
                output = Token.transferFrom(this, msg.sender, PaymentAmount);
            } else {
                output = msg.sender.send(PaymentAmount);
            }
            
            if (output == true) {
                // Signature and send successful 
                tagList.push(tagx);

                Withdrawals += 1;
                WithdrawEvent();

                if (Withdrawals == Participants) {
                    Started = false;
                    Withdrawals = 0;
                    
                    delete pubKeyx;
                    delete pubKeyy;

                    delete commonHashList;

                    delete tagList;
                    
                    WithdrawFinished();
                    AvailableForDeposit();
                }
                return;
            } else {
                // Signature verified, but send failed - this is bad so need to throw
                revert();
            }
        }

        // Signature didn't verify
        BadSignature();
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

    event AvailableForDeposit();
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

    // Creating arrays needed to store the submitted public keys 
    uint[] public pubKeyx;
    uint[] public pubKeyy; 
    
    // Precalculate withdraw values
    uint private hashx; 
    uint private hashy; 
    uint[] private commonHashList;        
    
    uint[] hashList; 
    
    // Withdrawl tags    
    uint[] private tagList;

    // Token to use
    bool private UsingToken;
    ERC20Interface private Token;


    // Builtins


    function expMod(uint256 _base, uint256 _exponent, uint256 _modulus)
        public constant returns (uint256 retval)
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

