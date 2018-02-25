// Copyright (c) 2016-2018 Clearmatics Technologies Ltd

// SPDX-License-Identifier: LGPL-3.0+

pragma solidity ^0.4.18;

contract BenchmarkMixer
{
    /**
    * BenchmarkEvent used to compare the performances of the Mixer contract during benchmarks
    * using such an event helps us to capture the amount of time necessary to run the
    * Mixer contract logic. Moreover it gives us a good basis to interpret the gas cost
    * of a payment being sent through Mobius.
    */
    event MixerBenchmarkEvent();

    function Mixer()
        public
    {
        // Nothing ...
    }

    /**
    * BenchmarkDeposit handles a call from the client and triggers
    * a MixerBenchmarkEvent event and returns. The purpose of this "empty"
    * function is to compare the time/gasCost to run this function with the
    * time/gasCost it takes to run the functions of the Mixer contract.
    * By doing so, we ought to benchmark "exactly" the instructions representing
    * the logic of the Mixer. This helps us measuring the overhead of the Mixer.
    */
    function BenchmarkDeposit (address token, uint256 denomination, uint256 pub_x, uint256 pub_y)
        public payable returns (bytes32)
    {
        MixerBenchmarkEvent();
        return 123456;
    }

    /**
    * BenchmarkWithdraw handles a call from the client and triggers
    * a MixerBenchmarkEvent event and returns. The purpose of this "empty"
    * function is to compare the time/gasCost to run this function with the
    * time/gasCost it takes to run the functions of the Mixer contract.
    * By doing so, we ought to benchmark "exactly" the instructions representing
    * the logic of the Mixer. This helps us measuring the overhead of the Mixer.
    */
    function BenchmarkWithdraw (bytes32 ring_id, uint256 tag_x, uint256 tag_y, uint256[] ctlist)
        public returns (bool)
    {
        MixerBenchmarkEvent();
        return true;
    }

    function () public {
        revert();
    }
}
