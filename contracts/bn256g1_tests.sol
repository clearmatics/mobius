pragma solidity ^0.4.18;

import './bn256g1.sol';

contract bn256g1_tests
{
	using bn256g1 for bn256g1.Point;

	function testOnCurve()
		public constant returns (bool)
	{
		var g = bn256g1.Generator();
		if( ! g.IsOnCurve() )
			return false;
			
		var x = g.ScalarMult(uint256(sha256("1")));
		if( ! x.IsOnCurve() )
		    return false;

		if( x.X != 18402258484067100825836416533206638046709953333460439275068607944552700874793 || x.Y != 3216486158313018618592493241388793958480998389453172132732084762339402552220 )
			return false;

		if( bn256g1.ScalarBaseMult(0).IsOnCurve() )
			return false;

		return true;
	}

	function testHashToPoint()
		public constant returns (bool)
	{
		var p = bn256g1.HashToPoint(sha256("hello world"));
		return p.IsOnCurve();
	}

	function testGenerator()
		public constant returns (bool)
	{
		var g = bn256g1.Generator();
		var x = g.PointAdd(g.Negate());
		return x.IsInfinity();
	}

	function testIdentity()
		public constant returns (bool)
	{
		return bn256g1.ScalarBaseMult(0).IsInfinity();
	}

	function testEquality()
		public constant returns (bool)
	{
		var g = bn256g1.Generator();
		var a = g.ScalarMult(9).PointAdd(g.ScalarMult(5));
		var b = g.ScalarMult(12).PointAdd(g.ScalarMult(2));
		return a.Equal(b);
	}

	function testOrder()
		public constant returns (bool)
	{
		var z = bn256g1.ScalarBaseMult(bn256g1.Order());
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
}