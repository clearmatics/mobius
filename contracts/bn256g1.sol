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
*    p ≡ 3 (mod 4)
*    b = (c^4 + d^6) or b = (c^6 + 4d^4), for c,d ∈ 𝔽*_p
*    sqrt(a) = a^((p+1)/4)
*
* The 𝔾2 finite field 𝔽_p^2 can be represented as 𝔽_p[i]/(i^2 + 1)
*
* The primes `p` (field modulus) and `n` (order) are given by:
*
*   p = p(u) = 36u^4 + 36u^3 + 24u^2 + 6u + 1
*   n = n(u) = 36u^4 + 36u^3 + 18u^2 + 6u + 1
*
* The BN field 𝔽_p contains a primitive cube root of unity, this makes
* it very easy to implement using integer operations.
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
*   u = ???
*   a = 5472060717959818805561601436314318772174077789324455915672259473661306552146
*/
library bn256g1
{
    // p = p(u) = 36u^4 + 36u^3 + 24u^2 + 6u + 1
    uint256 internal constant FIELD_P = 0x30644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd47;

    // n = n(u) = 36u^4 + 36u^3 + 18u^2 + 6u + 1
    uint256 internal constant ORDER_N = 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000001;

    uint256 internal constant CURVE_B = 3;


    function Order() internal pure returns (uint256) {
        return ORDER_N;
    }


    function Field() internal pure returns (uint256) {
        return FIELD_P;
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
        return Point(p.X, FIELD_P - (p.Y % FIELD_P));
    }


    /**
    * Using a hashed value as the initial starting X point, find the
    * nearest (X,Y) point on the curve. The input must be hashed first.
    *
    * Example:
    *
    *   HashToPoint(sha256("hello world"))
    *
    * This implements the try-and-increment method of hashing a scalar
    * into a curve point. For more information see:
    *
    *  - https://www.normalesup.org/~tibouchi/papers/bnhash-scis.pdf
    *    A Note on Hashing to BN Curves
    *
    *  - https://iacr.org/archive/crypto2009/56770300/56770300.pdf
    *    How to Hash into Elliptic Curves
    */
    function HashToPoint(bytes32 s)
        internal constant returns (Point)
    {
        uint256 beta = 0;
        uint256 y = 0;
        uint256 x = uint256(s) % ORDER_N;

        while( true ) {
            (beta, y) = _findYforX(x);

            // y^2 == beta
            if( beta == mulmod(y, y, FIELD_P) ) {
                return Point(x, y);
            }

            x = addmod(x, 1, FIELD_P);
        }
    }


    function _findYforX(uint256 x)
        internal constant returns (uint256, uint256)
    {
        // beta = (x^3 + b) % p
        uint256 beta = addmod(mulmod(mulmod(x, x, FIELD_P), x, FIELD_P), CURVE_B, FIELD_P);

        // y^2 = x^3 + b
        // So this acts like: y = sqrt(beta)
        uint256 a = (FIELD_P + 1) / 4;
        uint256 y = expMod(beta, a, FIELD_P);

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
        uint256 p_squared = mulmod(p.X, p.X, FIELD_P);
        uint256 p_cubed = mulmod(p_squared, p.X, FIELD_P);
        return addmod(p_cubed, CURVE_B, FIELD_P) == mulmod(p.Y, p.Y, FIELD_P);
    }


    function ScalarBaseMult(uint256 x)
        internal constant returns (Point r)
    {
        return ScalarMult(Generator(), x);
    }


    // sum of two points
    function PointAdd(Point p1, Point p2)
        internal constant returns (Point r)
    {
        uint[4] memory input;
        input[0] = p1.X;
        input[1] = p1.Y;
        input[2] = p2.X;
        input[3] = p2.Y;
        bool success;
        assembly {
            success := call(sub(gas, 2000), 6, 0, input, 0x80, r, 0x40)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid }
        }
        require(success);
    }


    // Multiply point by a scalar
    function ScalarMult(Point p, uint s)
        internal constant returns (Point r)
    {
        uint[3] memory input;
        input[0] = p.X;
        input[1] = p.Y;
        input[2] = s;
        bool success;
        assembly {
            success := call(sub(gas, 2000), 7, 0, input, 0x60, r, 0x40)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid }
        }
        require (success);
    }


    function expMod(uint256 _base, uint256 _exponent, uint256 _modulus)
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