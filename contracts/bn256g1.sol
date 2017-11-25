pragma solidity ^0.4.18;

library bn256g1 {
	uint256 constant PRIME = 0x30644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd47;
	uint256 constant ORDER = 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000001;	

	struct Point {
        uint X;
        uint Y;
    }

    function Generator () public returns (Point) {
    	return Point(1, 2);
    }

    function ScalarBaseMult(uint256 x) public constant returns (Point r) {
    	return ScalarMult(Generator(), x);
    }

    // sum of two points
	function PointAdd(Point p1, Point p2) public constant returns (Point r) {
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
    function ScalarMult(Point p, uint s) public constant returns (Point r) {
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
}