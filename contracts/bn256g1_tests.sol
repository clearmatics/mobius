// Copyright (c) 2016-2018 Clearmatics Technologies Ltd

// SPDX-License-Identifier: LGPL-3.0+

pragma solidity ^0.4.19;

import './bn256g1.sol';

contract bn256g1_tests {
	using bn256g1 for bn256g1.Point;

	function testIsOnCurve() public view returns (bool) {
		var g = bn256g1.generator();

		require(g.isOnCurve());

		var x = g.scalarMult(uint256(sha256("1")));

		require(x.isOnCurve());
		require(x.X == 0x28af4f278e71322e8e155dce4641e18ddb8ce0d4cee01d8ea9d052cf564e9029);
		require(x.Y == 0x71c77766b8f58944c18c66df8edac3c4ff5ab15e246e5f7457ae4fd6adb939c);
		require(!bn256g1.scalarBaseMult(0).isOnCurve());

		return true;
	}

	function testHashToPoint() public view returns (bool) {
		var p = bn256g1.hashToPoint(sha256("hello world"));

		require(p.isOnCurve());
		require(p.X == 18149469767584732552991861025120904666601524803017597654373315627649680264678);
		require(p.Y == 18593544354303197021588991433499968191850988132424885073381608163097237734820);

		return true;
	}

	function testNegate() public view returns (bool) {
		var g = bn256g1.generator();
		var x = g.pointAdd(g.negate());

		require(x.isInfinity());

		return true;
	}

	function testIdentity() public view returns (bool) {
		require(bn256g1.scalarBaseMult(0).isInfinity());

		return true;
	}

	function testEquality() public view returns (bool) {
		var g = bn256g1.generator();
		var a = g.scalarMult(9).pointAdd(g.scalarMult(5));
		var b = g.scalarMult(12).pointAdd(g.scalarMult(2));

		require(a.equal(b));

		return true;
	}

	function testOrder() public view returns (bool) {
		var z = bn256g1.scalarBaseMult(bn256g1.genOrder());
		require(z.isInfinity());

		var one = bn256g1.scalarBaseMult(1);
		var x = z.pointAdd(one);
		require(x.X == one.X && x.Y == one.Y);

		return true;
	}

	function testModExp() public view returns (bool) {
		uint256 a;

		a = bn256g1.expMod(33, 2, 100);
		require(a == 89);

		a = bn256g1.expMod(50, 2, 100);
		require(a == 0);

		a = bn256g1.expMod(51, 2, 100);
		require(a == 1);

		return true;
	}
}
