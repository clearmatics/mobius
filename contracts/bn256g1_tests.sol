pragma solidity ^0.4.18;

import './bn256g1.sol';

contract bn256g1_tests
{
	using bn256g1 for bn256g1.Point;

	function testGenerator1_1()
		public constant returns (bool)
	{
		bn256g1.Point memory g = bn256g1.Generator();
		bn256g1.Point memory x = g.PointAdd(g.Negate());
		return x.X == 0 && x.Y == 0;
	}

	function testIdentity()
		public constant returns (bool)
	{
		return bn256g1.ScalarBaseMult(0).IsInfinity();
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

	function testMul()
		public constant returns (bool)
	{
		bn256g1.Point memory p;

		// @TODO The points here are reported to be not well-formed
		p.X = 14125296762497065001182820090155008161146766663259912659363835465243039841726;
		p.Y = 16229134936871442251132173501211935676986397196799085184804749187146857848057;
		p = p.ScalarMult( 13986731495506593864492662381614386532349950841221768152838255933892789078521);

		return
			p.X == 18256332256630856740336504687838346961237861778318632856900758565550522381207 &&
			p.Y == 6976682127058094634733239494758371323697222088503263230319702770853579280803;
	}
}