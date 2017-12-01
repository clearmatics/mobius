// Copyright (c) 2016-2017 Clearmatics Technologies Ltd

// SPDX-License-Identifier: LGPL-3.0+

pragma solidity ^0.4.18;

import './bn256g1.sol';

contract bn256g1_tests
{
	using bn256g1 for bn256g1.Point;

	function testOnCurve()
		public returns (bool)
	{
		var g = bn256g1.Generator();
		if( ! g.IsOnCurve() )
			return false;
			
		var x = g.ScalarMult(uint256(sha256("1")));
		if( ! x.IsOnCurve() )
		    return false;

		if( x.X != 0x28af4f278e71322e8e155dce4641e18ddb8ce0d4cee01d8ea9d052cf564e9029 || x.Y != 0x71c77766b8f58944c18c66df8edac3c4ff5ab15e246e5f7457ae4fd6adb939c )
			return false;

		if( bn256g1.ScalarBaseMult(0).IsOnCurve() )
			return false;

		return true;
	}

	function testHashToPoint()
		public returns (uint)
	{
		var p = bn256g1.HashToPoint(sha256("hello world"));
		if( ! p.IsOnCurve() )
			return 1;

		if( p.X != 18149469767584732552991861025120904666157684532372229697400814503441427125781 )
			return 2;
			
		if( p.Y != 12637099731924609165048400529156461867563382406599203914231688990943216740974 )
		    return 3;
		
		return 0;
	}

	function testNegate()
		public returns (bool)
	{
		var g = bn256g1.Generator();
		var x = g.PointAdd(g.Negate());
		return x.IsInfinity();
	}

	function testIdentity()
		public returns (bool)
	{
		return bn256g1.ScalarBaseMult(0).IsInfinity();
	}

	function testEquality()
		public returns (bool)
	{
		var g = bn256g1.Generator();
		var a = g.ScalarMult(9).PointAdd(g.ScalarMult(5));
		var b = g.ScalarMult(12).PointAdd(g.ScalarMult(2));
		return a.Equal(b);
	}

	function testOrder()
		public returns (bool)
	{
		var z = bn256g1.ScalarBaseMult(bn256g1.GenOrder());
		if( ! z.IsInfinity() ) {
			return false;
		}

		var one = bn256g1.ScalarBaseMult(1);
		var x = z.PointAdd(one);
		if( x.X != one.X || x.Y != one.Y ) {
			return false;
		}

		return true;
	}

	function testModExp()
		public returns (bool)
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