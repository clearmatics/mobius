// Copyright (c) 2016-2017 Clearmatics Technologies Ltd

// SPDX-License-Identifier: LGPL-3.0+

pragma solidity ^0.4.18;

/**
* This module wraps the alt_bn128 G1 Elliptic Curve functions into
* a helpful and consistent library which provides familiar function
* names and usage to Elliptic Curve libraries in other languages.
*
* This curve is described in the IACR paper 2010/429
*
*  - https://eprint.iacr.org/2010/429
*    A Family of Implementation-Friendly BN Elliptic Curves
*
* Specified in the following EIPs:
*
*  - https://github.com/ethereum/EIPs/pull/213
*  - https://github.com/ethereum/EIPs/pull/212
*
* The 𝔾1 curve is of the form:
*
*   (E_b : y^2 = x^3 + b) over 𝔽_p
*
* Where:
*
*   p ≡ 3 (mod 4)
*   b = 3
*   sqrt(a) = a^((p+1)/4)
*
* The primes `p` (field modulus) and `n` (order) are given by:
*
*   p = p(u) = 36u^4 + 36u^3 + 24u^2 + 6u + 1
*   n = n(u) = 36u^4 + 36u^3 + 18u^2 + 6u + 1
*
* The BN field 𝔽_p contains a primitive cube root of unity, this makes
* it very easy to implement using integer operations on a computer.
*
* For more details, refer to the IACR paper, we have tried to ensure
* that the variable names and comments throughout this library make it
* easier for cryptographers, mathematicians and programmers alike to 
* use the same terminology across multiple domains without confusion.
*
* The parameters used by the ALT_BN128 curve implemented in Ethereum are:
*
*   p = 21888242871839275222246405745257275088696311157297823662689037894645226208583
*   n = 21888242871839275222246405745257275088548364400416034343698204186575808495617
*   b = 3
*   u = 4965661367192848881
*   a = 5472060717959818805561601436314318772174077789324455915672259473661306552146
*/
library bn256g1
{
    // p = p(u) = 36u^4 + 36u^3 + 24u^2 + 6u + 1
    uint256 internal constant FIELD_ORDER = 0x30644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd47;

    // Number of elements in the field (often called `q`)
    // n = n(u) = 36u^4 + 36u^3 + 18u^2 + 6u + 1
    uint256 internal constant GEN_ORDER = 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000001;

    uint256 internal constant CURVE_B = 3;

    // a = (p+1) / 4
    uint256 internal constant CURVE_A = 0xc19139cb84c680a6e14116da060561765e05aa45a1c72a34f082305b61f3f52;


    function GenOrder() internal pure returns (uint256) {
        return GEN_ORDER;
    }


    function FieldOrder() internal pure returns (uint256) {
        return FIELD_ORDER;
    }


    struct Point {
        uint256 X;
        uint256 Y;
    }


    function Infinity ()
        internal pure returns (Point)
    {
        return Point(0, 0);
    }


    function Generator ()
        internal pure returns (Point)
    {
        return Point(1, 2);
    }


    function Equal(Point a, Point b)
        internal pure returns (bool)
    {
        return a.X == b.X && a.Y == b.Y;
    }


    /// @return the negation of p, i.e. p.add(p.negate()) should be zero.
    function Negate(Point p)
        internal pure returns (Point)
    {
        if (p.X == 0 && p.Y == 0)
            return Point(0, 0);
        // TODO: SubMod function?
        return Point(p.X, FIELD_ORDER - (p.Y % FIELD_ORDER));
    }


    /**
    * Using a hashed value as the initial starting X point, find the
    * nearest (X,Y) point on the curve. The input must be hashed first.
    *
    * Example:
    *
    *   HashToPoint(sha256("hello world"))
    *
    * XXX: this isn't constant time!
    *
    * This implements the try-and-increment method of hashing a scalar
    * into a curve point. For more information see:
    *
    *  - https://iacr.org/archive/crypto2009/56770300/56770300.pdf
    *    How to Hash into Elliptic Curves
    *
    *  - https://www.normalesup.org/~tibouchi/papers/bnhash-scis.pdf
    *    A Note on Hashing to BN Curves
    */
    function HashToPoint(bytes32 s)
        internal view returns (Point)
    {
        uint256 beta = 0;
        uint256 y = 0;

        // XXX: Gen Order (n) or Field Order (p) ?
        uint256 x = uint256(s) % GEN_ORDER;

        while( true ) {
            (beta, y) = FindYforX(x);

            // y^2 == beta
            if( beta == mulmod(y, y, FIELD_ORDER) ) {
                return Point(x, y);
            }

            x = addmod(x, 1, FIELD_ORDER);
        }
    }


    /**
    * Given X, find Y
    *
    *   where y = sqrt(x^3 + b)
    *
    * Returns: (x^3 + b), y
    */
    function FindYforX(uint256 x)
        internal view returns (uint256, uint256)
    {
        // beta = (x^3 + b) % p
        uint256 beta = addmod(mulmod(mulmod(x, x, FIELD_ORDER), x, FIELD_ORDER), CURVE_B, FIELD_ORDER);

        // y^2 = x^3 + b
        // this acts like: y = sqrt(beta)
        uint256 y = expMod(beta, CURVE_A, FIELD_ORDER);

        return (beta, y);
    }


    function IsInfinity(Point p)
        internal pure returns (bool)
    {
        return p.X == 0 && p.Y == 0;
    }


    /**
    * Verify if the X and Y coordinates represent a valid Point on the Curve
    *
    * Where the G1 curve is: x^2 = x^3 + b
    */
    function IsOnCurve(Point p)
        internal pure returns (bool)
    {
        uint256 p_squared = mulmod(p.X, p.X, FIELD_ORDER);
        uint256 p_cubed = mulmod(p_squared, p.X, FIELD_ORDER);
        return addmod(p_cubed, CURVE_B, FIELD_ORDER) == mulmod(p.Y, p.Y, FIELD_ORDER);
    }


    /**
    * Multiply the curve generator by a scalar
    */
    function ScalarBaseMult(uint256 x)
        internal view returns (Point r)
    {
        return ScalarMult(Generator(), x);
    }


    // sum of two points
    function PointAdd(Point p1, Point p2)
        internal view returns (Point r)
    {
        uint256[4] memory input;
        input[0] = p1.X;
        input[1] = p1.Y;
        input[2] = p2.X;
        input[3] = p2.Y;
        bool success;
        assembly {
            success := staticcall(sub(gas, 2000), 6, input, 0x80, r, 0x40)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid }
        }
        require(success);
    }


    // Multiply point by a scalar
    function ScalarMult(Point p, uint256 s)
        internal view returns (Point r)
    {
        uint256[3] memory input;
        input[0] = p.X;
        input[1] = p.Y;
        input[2] = s;
        bool success;
        assembly {
            success := staticcall(sub(gas, 2000), 7, input, 0x60, r, 0x40)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid }
        }
        require (success);
    }


    function expMod(uint256 _base, uint256 _exponent, uint256 _modulus)
        internal view returns (uint256 retval)
    {
        bool success;
        uint256[1] memory output;
        uint256[6] memory input;
        input[0] = 0x20;        // baseLen = new(big.Int).SetBytes(getData(input, 0, 32))
        input[1] = 0x20;        // expLen  = new(big.Int).SetBytes(getData(input, 32, 32))
        input[2] = 0x20;        // modLen  = new(big.Int).SetBytes(getData(input, 64, 32))
        input[3] = _base;
        input[4] = _exponent;
        input[5] = _modulus;
        assembly {
            success := staticcall(sub(gas, 2000), 5, input, 0xc0, output, 0x20)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid }
        }
        require(success);
        return output[0];
    }
}
