# Notes on kaspanet/vprogs PR #165 (read-only)

PR: https://github.com/kaspanet/vprogs/pull/165, "l1/wallet, settler, runner: settlement liveness under congestion and competitors".
Opened 26 Sep 2026 13:22 CEST as a draft on top of `fix/reorg-boundary-duplicate-bundles`. Commits `36a6d38`, `bf3509c`, `494aacc`, `081af9b`.
When I read it (26 Sep ~15:00 CEST), `release-candidate` already pointed at `081af9b`, and vprog-tictactoe pinned it in `f128efd`.

> **Update 26 Sep ~16:50 CEST:** the PR now has a 5th commit, `bcebf59` (16:32 CEST, Clippy fix in the fee-policy tests; Clippy and
> Format pass), and `release-candidate` points at it. The author replied with a mapping of my findings: see the
> [README, Upstream response](../README.md#upstream-response-26-sep). The notes below are from the `081af9b` read.

This is my reading as an outside tester. I may be wrong about intent. Questions, not demands.

## What it changes (my reading)
1. **Wallet fees** (`l1/wallet/src/lib.rs`, `build/carrier.rs`, `build/payout.rs`). Every funded build fetches `get_fee_estimate` and
   targets `priority_bucket.feerate` (was `normal_buckets[0]` for activity/settlement, and the relay floor for carriers/payouts).
   The fee is solved as a fixpoint over the normalized max mass, including storage mass. A carrier that can't reach the target
   pays `available − min_viable_change` (never below the floor). If the estimate RPC fails, it falls back to the floor.
2. **Settler** (`zk/backend/risc0/settler/src/worker.rs`). On both supersede paths it re-reads the settlement watch and adopts the
   competitor's tip. If `covenant_liveness` says the bundle's base covenant outpoint is spent on chain, it deletes the bundle's
   journal entry, so the aggregate prover's resume stops re-feeding it. The journal is now one handle shared by prover and settler.
3. **Runner** (`runner/src/exit_index.rs`). New `ExitIndexer::on_settlement_observed` hook fires for every observed settlement, so the
   served "latest settlement" advances even on lanes without withdrawals. It is journaled so a rollback re-serves the newest surviving tip.

## How it maps to what I saw
- (1) matches my findings 1 and 2 (default fee starves activity; carriers stuck at the floor).
- (2)/(3) target the mechanisms behind the 64,057-DAA hosted settlement lag I saw on 25 Sep 20:12 (finding 8), per the PR author's reply. Not retested.

## Questions / suggestions
1. **Chain check trusts index absence** (medium confidence). `covenant_liveness` = one `poll_outpoint` with `max_polls = 1`.
   `Timeout` (outpoint not in the `get_utxos_by_addresses` result) maps to `Spent`, and `Spent` deletes the journal entry. Could a lagging
   or rebuilding utxoindex, or a reorg that removed the tx that *created* the base outpoint, produce a false `Spent` and drop a
   range that still needs settling? A second read, or checking the spending tx's acceptance, might be safer.
2. **`expect` on RPC** (fairly confident). `poll_outpoint` does `.expect("get_utxos_by_addresses")`. Now that it runs on the supersede
   path, a transient RPC error (or a node without `--utxoindex`) panics the settler task.
3. **Integration coverage** (fairly confident). `runner/tests/two_provers_contend.rs` wires the settler with `journal: None`, so the
   delete/resolve path is only covered by unit tests with a stubbed liveness closure.
4. **Unbounded in-memory journal** (low severity, acknowledged in a code comment). Every observed settlement pushes an `Observed` entry,
   and nothing trims below the lowest floor.
5. **Degrade-to-cap on carriers** (design question). With a fee spike or a small coin, one carrier can pay almost the whole coin as fee.
   A cap, or at least a warning log when this path fires, might avoid surprises. There is also no cap or multiplier on the priority rate itself.
6. **Stale feerate on retries** (small, in vprog-tictactoe rather than the PR). `fee_policy()` is fetched once before `fund_and_submit`,
   so all retry attempts reuse the same rate.
7. **Not covered by the PR (now tracked: carrier panic in #103, coin reuse in #166; utxoindex is an operational constraint):** first-UTXO `assert!` panic in the carrier path, in-mempool coin reuse on the
   carrier/payout paths, and the `utxoindex` startup requirement. See [vprogs-client-findings.md](vprogs-client-findings.md) 3, 4, 6.
8. CI: Clippy failed on the PR head (5 × "unnecessary use of `clone` to create a slice from a reference" in new tests in `carrier.rs` / `payout.rs`). Fixed in `bcebf59`.
