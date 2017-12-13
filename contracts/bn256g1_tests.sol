// Copyright (c) 2016-2017 Clearmatics Technologies Ltd

// SPDX-License-Identifier: LGPL-3.0+

pragma solidity ^0.4.18;

import './bn256g1.sol';

contract bn256g1_tests
{
	using bn256g1 for bn256g1.Point;

	function testOnCurve()
		public view returns (bool)
	{
		var g = bn256g1.Generator();
		require( g.IsOnCurve() );
			
		var x = g.ScalarMult(uint256(sha256("1")));
		require( x.IsOnCurve() );

		require( x.X == 0x28af4f278e71322e8e155dce4641e18ddb8ce0d4cee01d8ea9d052cf564e9029 );

		require( x.Y == 0x71c77766b8f58944c18c66df8edac3c4ff5ab15e246e5f7457ae4fd6adb939c );

		require( ! bn256g1.ScalarBaseMult(0).IsOnCurve() );

		return true;
	}

	function testHashToPoint()
		public view returns (bool)
	{
		var p = bn256g1.HashToPoint(sha256("hello world"));
		require( p.IsOnCurve() );

		require( p.X == 18149469767584732552991861025120904666601524803017597654373315627649680264678 );
			
		require( p.Y == 18593544354303197021588991433499968191850988132424885073381608163097237734820 );
		
		return true;
	}

	function testNegate()
		public view returns (bool)
	{
		var g = bn256g1.Generator();
		var x = g.PointAdd(g.Negate());
		require( x.IsInfinity() );
		return true;
	}

	function testIdentity()
		public view returns (bool)
	{
		require( bn256g1.ScalarBaseMult(0).IsInfinity() );
		return true;
	}

	function testEquality()
		public view returns (bool)
	{
		var g = bn256g1.Generator();
		var a = g.ScalarMult(9).PointAdd(g.ScalarMult(5));
		var b = g.ScalarMult(12).PointAdd(g.ScalarMult(2));
		require( a.Equal(b) );
		return true;
	}

	function testOrder()
		public view returns (bool)
	{
		var z = bn256g1.ScalarBaseMult(bn256g1.GenOrder());
		require( z.IsInfinity() );

		var one = bn256g1.ScalarBaseMult(1);
		var x = z.PointAdd(one);
		require( x.X == one.X && x.Y == one.Y );
		return true;
	}

	function testModExp()
		public view returns (bool)
	{
		uint256 a;

		a = bn256g1.expMod(33, 2, 100);
		require( a == 89 );

		a = bn256g1.expMod(50, 2, 100);
		require( a == 0 );

		a = bn256g1.expMod(51, 2, 100);
		require( a == 1 );

		return true;
	}
}
