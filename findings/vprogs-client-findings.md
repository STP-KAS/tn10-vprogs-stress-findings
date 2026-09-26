# vprogs client-side findings (TN10, 25–26 Sep 2026)

Times CEST. "Round N" refers to the table in the [README](../README.md). All runs were on my own TN10 node (kaspad 2.1.0, single node
`n0` from 25 Sep 21:33). My storm traffic was a large share of TN10 load, so treat these as "under this kind of load" results.

Versions: vprogs `release-candidate` `3a61c0b` (= `fix/reorg-boundary-duplicate-bundles`, which vprog-tictactoe pinned at the time),
vprogs master `f9b84a8` for my own guest, vprog-tictactoe `ba05d92`.

> **Status per the PR #165 author (26 Sep 16:34 CEST):** 1 and 2 fixed in [#165](https://github.com/kaspanet/vprogs/pull/165) (draft);
> 3 tracked in [#103](https://github.com/kaspanet/vprogs/issues/103); 4 tracked in [#166](https://github.com/kaspanet/vprogs/issues/166);
> 5 open (draft issue, not filed: [`../drafts/issue-fee-cap-multiplier.md`](../drafts/issue-fee-cap-multiplier.md)); 6 operational constraint;
> 8 mechanisms targeted by #165. Details: [README, Upstream response](../README.md#upstream-response-26-sep).

---

## 1. Activity txs starve at `normal_buckets[0]` under a flood. Addressed by PR #165

**Setup (round 3, 26 Sep 00:15–01:07).** My own small vprog guest (`grok-deskfloor`: balance / floor / debit / move), release runner,
16 issuers × 20 UTXOs, dev-mode exec (no proofs). Storm at full throttle, 10× node minimum (~1,000 sompi/g).
Fee choice: `normal` (upstream `Wallet` behaviour), `priority`, `x2` (2× normal), or fixed.

| Run | L1 load | Fee | Moves/s issued | Exec p50 / p90 / p99 | Failures |
|---|---|---|---|---|---|
| t2 | full, 10× | normal (573 sompi/g) | ~8 (target 20) | 83 s / 101 s / – | 4,871 no-funds in ~5 min |
| r1 | 1k TPS bg | priority | 130–138 (CPU-bound) | 3.1 / 4.1 / 5.6 s | 0 |
| r1 | full, 10× | priority (~4.5k sompi/g) | 100–130 for ~50 s, then 0 | – | issuers broke: ~900 TKAS in 11.5 min |
| r2 | full, 10× | 2× normal (~1.1k) | 22–34 (target 80) | 9.5 / 18.6 / 23 s | 5,953 no-funds |

Mechanism: at the normal rate every activity tx sits below the flood in the feerate ordering. The issuer's UTXOs are all in flight,
and new moves fail with no funds. Round 4 at a fixed 2,000 sompi/g (2× storm): 37,963 moves in 12 min of full storm, all executed,
p50 8.1 s / p90 14.4 s.

**PR #165:** `Wallet::fee_policy` now uses `priority_bucket.feerate` for every funded build.

## 2. Carrier txs always paid the relay floor. Addressed by PR #165

`build::carrier::signed_carrier_transaction` priced with `min_fee(params, &probe)`. vprog-tictactoe goes through
`app_kit::fund_and_submit` → `signed_lane_action_tx` / `signed_deposit_tx` → the carrier builder, so no knob could raise it.

| Window (round 4) | Games finished | GAME_FAIL | Game p50 |
|---|---|---|---|
| storm off, 06:42:40–06:43:44 | 40 | 0 | 14.0 s |
| full storm (~1,000 sompi/g), 06:43:44–06:55:44 | 8 (all in first 6 s) | 1,223 | – |
| storm off, 06:57:10–07:04:52 | 119 | 0 | 15.1 s |
| full storm 2, 07:04:52–07:07:36 | 1 | 104 | – |

A wRPC proxy that raised `getFeeEstimate` to ≥2,000 sompi/g changed nothing for carriers (verified).

**PR #165:** `SignedCarrierTx` / `CarrierTxArgs` / `PayToAddressTx` take a `FeePolicy`. vprog-tictactoe `f128efd` passes
`wallet.fee_policy()`, and `803a120` does the same for browser-built carriers.

## 3. Carrier: first UTXO only, then `assert!` panic. Open

- vprog-tictactoe `driver/src/scenario.rs`: `let (outpoint, entry) = candidates.into_iter().next()?;`
- `l1/wallet/src/build/carrier.rs`: `assert!(args.entry.amount > extra_value + fee, "funding UTXO amount {} too small for extra outputs {} + fee {}", ...)`.

The first candidate isn't necessarily the largest. Once coins fragment, the task panics:
- round 3, 26 Sep 01:07: all 8 `ttloop` workers, after ~170 games (`funding UTXO amount 98955500 too small for extra outputs 100000000`);
- round 3, 01:17: all 8 workers of the next run (0.4 TKAS deposit, `carrier.rs:62`);
- round 4, 06:58:56: 4 of 4 workers with fragmented keys (`funding UTXO amount 14913800 too small for extra outputs 40000000`). Workers with fresh 20 × 3 TKAS keys had 0 panics.

Suggestion: choose the largest candidate (or combine inputs), and return `Err` so the caller can retry or consolidate.

## 4. In-mempool coin reuse on carrier and payout paths. Open

`Wallet` has `build_activity_excluding` / `prepare_settlement_excluding`, but `build_signed_carrier` and `pay_to_address` have no
in-flight exclusion. The scenario relies on a fixed 2 s step delay.

| Condition (round 3, 12 `ttloop` workers) | Games finished | Failed |
|---|---|---|
| step delay 0, low load | 2 | 12 of 14 |
| 1k TPS background | 419 | 251 |
| full storm, 10× | 5 | **1,322** (of 1,327) |

Every failure was `already spent by transaction ... in the mempool`: the previous step was still unconfirmed and the next step
picked the same UTXO. With PR #165's higher fee, steps will confirm sooner, so this should happen less, but the race stays.

## 5. No fee cap / multiplier / bump. Open (and slightly sharper after PR #165)

- Priority bucket under my flood was ~4.5k sompi/g vs the flood's ~1,000: **~900 TKAS in 11.5 min** for one runner (finding 1).
- Everything now prices at the priority bucket. Anyone flooding at a high feerate raises every vprogs client's cost, with no upper bound.
- PR #165 carrier: when the target rate is unreachable for the single input, fee = `available − min_viable_change` (asserted in
  `carrier_degrades_to_the_cap_when_the_target_is_unreachable`). During a spike one move can spend nearly the whole coin.
- No RBF/bump for an already-stuck tx. The fee is chosen once at build time.

Suggestion: optional cap (`min(priority, k × normal)` or an absolute sompi/g max), and a bump after N seconds in the mempool.

## 6. `utxoindex` required; panics instead of clear errors. Open

- 25 Sep 21:30, `examples/tn10-runtime` (rc `3a61c0b`), node without index:
  `thread 'main' panicked at l1/wallet/src/lib.rs:167:56: fetch spendable utxos: RpcSubsystem("Method unavailable. Run the node with the --utxoindex argument.")`
- Enabling `--utxoindex` on the existing TN10 datadir (25 Sep 23:52:42 → 26 Sep 00:11:17): **1,115 s** resync, RPC and P2P down,
  no progress output. Total node downtime 1,153 s. Index size **~13 GB**; free disk went 40 → ~11 GB.
- 26 Sep 07:10: in the pruning disk emergency the 13 GB index was the only thing that could go. After that, upstream vprogs and
  tic-tac-toe could not run on my node, which is why rounds 5–6 used index-free runners.
- `zk/backend/risc0/settler/src/confirm.rs` `poll_outpoint`: `.expect("get_utxos_by_addresses")`. PR #165 calls
  `covenant_liveness` (→ `poll_outpoint`) on both supersede paths, so an RPC failure there panics the settler task.

Suggestion: check `getServerInfo().hasUtxoIndex` at startup with a readable error, and turn `expect` into a handled error/retry. A doc line
on index size and resync time would also help.

## 7. Storage mass vs high fees on small coins (KIP-9)

- Round 1 (measured with SDK 2.1.0 `calculateStorageMass`): 0.5 TKAS 1-in-2-out = **20,001 grams**, so only ~25 per block. 1-in-1-out 0.5 TKAS = 4 grams.
- Round 5, 26 Sep 09:22–09:50: a 150× storm fee (0.0965 TKAS/tx) on ~0.25 TKAS coins pushed storage mass to ~69k grams/tx.
  The effective feerate fell to ~140 sompi/g, blocks were 87% storage-mass-full, and network TPS dropped to 300–440. Back to 10× at 09:51.
- Rounds 5–6 runners used big inputs (10–24 TKAS per chain) with 1-in-1-out moves: tiny storage mass, and p50 latency ~0.6–1.0 s at 20k–60k sompi/g.

PR #165's fixpoint prices over the normalized max mass including storage mass, which fits this. The remaining point is cost on small
coins (finding 5).

## 8. Hosted tic-tac-toe settlement lag (mechanisms targeted by PR #165 per its author; not retested)

- 25 Sep 20:12 CEST probe of the hosted demo: last settlement DAA **580,229,488**, virtual DAA **580,293,545**, a gap of
  **64,057 DAA** (≈ 85.4 min at 12.5 DAA/s from an 8-second rate sample; ≈ 107 min at the 10 BPS target), `settlementMoved=false`,
  while the L2 tip moved 57 during the sample. Settlement moved later (settled DAA 580,940,363 at ~15:31 CEST on 26 Sep, per
  [build-opinion CHECKS](https://github.com/STP-KAS/tn10-vprogs-build-opinion/blob/main/CHECKS.md)).
- A campaign against the hosted demo that evening (last status 21:45:58): 1,220 sends, 10,349 send failures, **0 finished games,
  1,534 game failures**. I did not isolate the cause (the frozen settlement, the fee floor and coin reuse are all candidates).
- PR #165 describes a settler loop re-feeding superseded bundles (~3 Hz for hours) and a DA "latest settlement" row frozen on lanes
  without withdrawals. Either would look like this from outside. I can't tell which, if either, it was.
