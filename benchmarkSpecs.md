# Benchmark

## Pre-requisites

- We do all the orbital commands before the benchmark (key generation/key stealthing, ring signature generation)

Test 1: Measure the time/gas it takes to do only one Deposit (time span between Alice calling the Contract's function and receiving the MixerDeposit event)
Test 2: The same the Withdrawal

Test 3: Single ring of size 4 (arbitrary chosen) with Deposit and Withdrawal
Test 4: Test 1 x multiple times
Test 5: Flow of TXs of 2 different denominations sent in an alternating manner

Test 6: 1 super big ring
Test 7: Multiple super big rings

Edge case tests: Find the correlation between time increase (and gas consumption) and the ring size (the idea is to plot the graph x = size of ring and y = f(x) = time (average time))


# Reflexions

- There is a balance to find between ring denomination and ring size:
    - privacy issue and side channel leaks for big denominations (bank transfer) --> If a bank wants to do a transfer of 100 million dollars through Mobius, then it might be possible for someone analyzing the blockchain to actually infer that this transfer has been done by some banks or "big fishs" that has done such a transfer, so banks might want to split big transfers into a huge set of small ones --> Need to have big rings --> Big rings are good for privacy but also harder to fill
    - Too large ring sizes can be hard to fill and Bob might need to wait for days for the ring to be complete (time problem)
    - Might need to monitor the rings (priority between rings that have to be filled ?)
    - "Decloak key" feature for legal reasons ?
