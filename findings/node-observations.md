# Node-side observations (TN10, kaspad 2.1.0)

Not vprogs bugs, but they matter to anyone running vprogs infrastructure on TN10 under load. Times CEST.

## Pruning-point move needs large transient disk
- The TN10 pruning-point moves I saw were at ~07:02 and ~18:50 on 25 Sep and 07:03:19 on 26 Sep (≈ every 12 h).
- 26 Sep 07:03–07:10, storm already off, mempool 0: pruning + RocksDB compaction grew consensus data **75 → 89 GB** at ~50 MB/s.
  Free disk went 9.9 GB → 0 by ~07:10. Shutdown hung inside pruning. I had to SIGKILL the node and delete the 13 GB utxoindex.
  The DB was not corrupted: after restart it was at tip within seconds, and pruning completed at 07:23–07:24.
- Budget: TN10 held ~42 h of blocks (1.52 M) = ~75 GB consensus on my node, plus 13 GB utxoindex. Disk grew ~2 GB/h at 1k TPS and ~7–9 GB/h at 3.5–5k TPS.

## Public explorer / indexer stall
- The TN10 explorer's transaction database (api-tn10.kaspa.org, apparently also kaspa.stream) stopped at **25 Sep 21:55:38.262**
  (accepting blue score ≈ 568,828,507), network-wide, not only for my addresses. Balances and hashrate stayed live because they come from kaspad.
- 21:55 was ~7 min into my full-throttle overload (~6.9k network TPS, mempool ~47k at 21:55:06 on my node). Plausible trigger, not proven.
- Still stalled the next morning (06:45).

## Mempool
- 25 Sep 21:12:50: kaspad panicked at the mempool cap (`100001 > 100000`, `validate_and_insert_transaction.rs:123`). This was the cap
  I lowered with `--ram-scale=0.1`; the v2.1.0 default count cap is 1,000,000 (`mining/src/mempool/config.rs`), not tested.
- The mempool is not persisted: a restart dropped 58,035 txs on my second node (21:11).
- Later overloads touched ~99.97k repeatedly with 30,298 evictions and no panic. One near-miss on 26 Sep 07:28: 96,546, with 6,223 evictions.
- Drain after stopping the storm: 54,294 → <1k in 85 s (26 Sep 06:55).

## Inclusion latency by fee (plain L1 txs, 57.5-min overload 21:48–22:46, 117 probes per tier)
See [`../data/fee-tier-probes-round1.csv`](../data/fee-tier-probes-round1.csv). 1× min fee: p50 7.0 s, max 105 s. 10× min fee: max 3.7 s. 100× bought nothing extra.
