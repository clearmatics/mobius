pragma solidity ^0.4.18;

/**
* bn256g1 Wraps the BN256 G1 Elliptic Curve functions into a 
* helpful and consistent library which provides familiar function
* names and usage to Elliptic Curve libraries in other languages.
*/
library bn256g1 {
	uint256 internal constant PRIME = 0x30644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd47;
	uint256 internal constant ORDER = 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000001;	


	function Order() internal pure returns (uint256) {
		return ORDER;
	}


	function Prime() internal pure returns (uint256) {
		return PRIME;
	}


	struct Point {
        uint X;
        uint Y;
    }


    function Generator ()
    	internal pure returns (Point)
    {
    	return Point(1, 2);
    }


    function HashToPoint(uint256 s)
    	internal constant returns (Point)
    {
    	uint256 beta = 0;
    	uint256 y = 0;
    	uint256 x = s;

    	while( true ) {
    		(beta, y) = _findYforX(x);

    		// y^2 == beta
    		if( beta == mulmod(y, y, ORDER) ) {
    			return Point(x, y);
    		}

    		x = addmod(x, 1, ORDER);
    	}
    }


    function _findYforX(uint256 x)
    	internal constant returns (uint256, uint256)
    {
    	uint256 z = (ORDER + 1) / 4;

    	// beta = (x^3 + 3) % N
    	uint256 beta = addmod(mulmod(mulmod(x, x, ORDER), x, ORDER), 3, ORDER);
    	
    	uint256 y = expMod(beta, z, ORDER);

        return (beta, y);
    }


    function IsOnCurve(Point p)
    	internal pure returns (bool)
    {
    	uint256 xx = mulmod(p.X, p.X, ORDER);
    	uint256 xxx = mulmod(xx, p.X, ORDER);
    	return addmod(xxx, 3, ORDER) == mulmod(p.Y, p.Y, ORDER);
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

contract bn256g1_test {
	
}