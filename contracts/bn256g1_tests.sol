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

		if( x.X != 0x28af4f278e71322e8e155dce4641e18ddb8ce0d4cee01d8ea9d052cf564e9029 || x.Y != 0x71c77766b8f58944c18c66df8edac3c4ff5ab15e246e5f7457ae4fd6adb939c )
			return false;

		if( bn256g1.ScalarBaseMult(0).IsOnCurve() )
			return false;

		return true;
	}

	function testHashToPoint()
		public constant returns (bool)
	{
		var p = bn256g1.HashToPoint(sha256("hello world"));
		if( ! p.IsOnCurve() )
			return false;

		if( p.X != 0x28203c60efb85d8b7c3d81b455f9a2e34be9370a0d272f3ac4e316f112efcde6 || p.Y != 0x291b92bad2135d3a6e051f97b49fb98afc23aceb4b5f4953d146a248d0cf45a4 )
			return false;

		return true;
	}

	function testNegate()
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

	function testModExp()
		public constant returns (bool)
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