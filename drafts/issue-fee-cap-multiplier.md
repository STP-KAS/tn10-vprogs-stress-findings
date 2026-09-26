# DRAFT — not filed

> This is a draft for a possible issue on [kaspanet/vprogs](https://github.com/kaspanet/vprogs). **It has not been filed.**
> It follows the suggestion in [PR #165's thread](https://github.com/kaspanet/vprogs/pull/165#issuecomment-5847102090) that a fee cap
> could be a follow-up issue "with your storm numbers attached". Testnet-10 only. Numbers come from my own public logs, linked below.
> Where a number is not in a published file, this draft says so.

---

**Suggested title:** `l1/wallet: configurable fee cap / multiplier for priority-bucket pricing`

## Problem

After PR #165, every funded build fetches `get_fee_estimate` and pays the **priority bucket as-is**, over the node's feerate-ordering
mass (compute, transient, storage). That fixes starvation, which was a real problem in my runs (see #165). But there is no upper bound:

- The priority bucket follows whoever is flooding the mempool. On a busy network, one heavy sender at a high feerate sets the price
  every vprogs issuer, carrier and settlement then pays.
- The only bound is the carrier's degrade-to-cap. It applies only when the funding UTXO is too small to reach the target. It then pays
  "everything except the minimum viable change", which is a bound on the coin, not on the price.
- There is no multiplier, fixed-fee option, absolute per-tx maximum, or fee bump for a tx that is already stuck.

So an operator can't say "pay at most X", and a flood can drain an issuer that would rather wait.

## Evidence (TN10, 25–26 Sep 2026, my own runs)

**Caveat first:** my own traffic was a large share of TN10 load in these windows (77 % of selected-chain accepted txs in a 20-min
round-7 window; there was also at least one external flood on 26 Sep morning). So these are "under load I created" numbers. They show the
mechanism, not typical TN10 conditions.

| # | What | Numbers | Source |
|---|---|---|---|
| E1 | **Priority bucket vs the flood, round 3** (upstream `Wallet`, own vprog guest, storm at ~1,000 sompi/g) | `priority_bucket` ≈ 4.5k sompi/g, **~4.5× the flood fee**. It worked (p50 3.1 s at 130 moves/s at 1k-TPS background) but under the full storm the issuers **burned ~900 TKAS in 11.5 min**, went broke, and logged 3,436 no-funds failures. At `normal_buckets[0]` (573 sompi/g) moves starved (p50 83 s); at 2× normal (~1,100) ~30 moves/s, p50 9.5 s; a fixed 2,000 sompi/g ran 37,963 moves, all executed, p50 8.1 s (round 4). | [`data/round3-fee-policy.csv`](../data/round3-fee-policy.csv), [round-3 README](https://github.com/STP-KAS/grok-bot-vprogs-round3/blob/main/README.md), [round-3 draft issues](https://github.com/STP-KAS/grok-bot-vprogs-round3/blob/main/upstream-issues/README.md) |
| E2 | **The priority bucket moves a lot, round 6** (node `getFeeEstimate`, sampled every 30 s, 12:23–13:22 CEST, 119 samples) | priority 100 → **7,304.6** sompi/g (median 466); priority / normal ratio median **2.5×**, p95 4.5×, max **8.4×** (12:23, while my storm was still running). Normal bucket median 186. | [round-6 `logs/feerate.jsonl`](https://github.com/STP-KAS/grok-bot-vprogs-round6/blob/main/logs/feerate.jsonl) |
| E3 | **Paying more stops helping, round 1** (plain L1 probes during a 57.5-min overload, 117 per tier) | 1×: p50 7.0 s, max 105 s. 2×: max 48 s. 5×: max 39 s. **10×: max 3.7 s. 100×: max 3.7 s** (nothing extra for 10× the price). | [`data/fee-tier-probes-round1.csv`](../data/fee-tier-probes-round1.csv) |
| E4 | **A very high fee on small coins backfires (KIP-9), round 5** | Storm at 150× (0.0965 TKAS/tx) on ~0.25 TKAS coins: change shrank, storage mass rose to **~69k grams/tx**, effective feerate fell to **~140 sompi/g**, blocks were 87 % storage-mass-full, network TPS fell to 300–440. One lane's 1-in-2-out fee exceeded its input (negative change). The ~69k figure is from my run notes, not recomputed from a raw tx. | [round-5 notes](https://github.com/STP-KAS/grok-bot-vprogs-round5/blob/main/findings/round5-notes.md), [round-5 README](https://github.com/STP-KAS/grok-bot-vprogs-round5/blob/main/README.md) |
| E5 | **Carriers under a flood, rounds 3–4** (before #165, relay-floor carriers) | Full storm: 5 games finished / 1,322 failed; 8 / 1,223 in 12 min. Games resumed within ~100 s of the storm stopping. This is the starvation #165 fixes; it is here to show what the other side of the trade (waiting) costs. | [`data/ttt-under-load.csv`](../data/ttt-under-load.csv) |
| E6 | **Fees vs miner coinbase, round 7** (10 min, 16:03–16:13 CEST, selected-chain blocks only, runners at max(2 × normal, 200) sompi/g) | All TN10 fees 611.1 TKAS; **my runners paid 458.5 TKAS (75 % of all fees)**; 521.5 TKAS of fee value landed with my miners → **net fee cost −63 TKAS** in that window. Fee per finished game ≈ 0.10 TKAS at 200 sompi/g. So on TN10 the flood-setter can also be the fee collector; an issuer that isn't mining has no such offset. One quiet-ish window; not valid for the storm hours. | [round-7 README](https://github.com/STP-KAS/tn10-vprogs-round7-ideas/blob/main/README.md), [round-7 `logs/ledger2.jsonl`](https://github.com/STP-KAS/tn10-vprogs-round7-ideas/blob/main/logs/ledger2.jsonl) |
| E7 | **Round 8** (running 26 Sep 16:34–18:35 CEST) | **Pending.** No round-8 fee numbers are published yet. | — |
| E8 | **PR #165 retest (new code, `bcebf59`)** — *added 26 Sep evening* | **Not run.** Build and harness were ready, but a fresh `--utxoindex` resync did not fit on my disk (see the README section "Retest of #165"). **No new-code numbers exist**; E1–E6 are all old-code numbers. | README |


What I have *not* measured: the PR #165 wallet itself under a flood (a retest was attempted 26 Sep but not run, E8), and how often its degrade-to-cap path fires.

## Proposed options (any subset; maintainers know the trade-offs better)

1. **Max feerate cap:** `min(priority, max_feerate)` in `FeePolicy` (sompi/gram), configurable per `Wallet`.
2. **Multiplier on the normal bucket:** `min(priority, k × normal_buckets[0])`, e.g. `k = 2`. My round 6–8 runners used `max(2 × normal, 200)`
   (rounds 6–7); in round 7 that was ≈ 0.10 TKAS per finished game (E6).
3. **Fixed feerate option** for operators who want predictable cost (round 4 ran well at a fixed 2,000 sompi/g, E1).
4. **Absolute per-tx max fee** (sompi), checked after the mass fixpoint, so a large-mass settlement or a small-coin carrier can't pay more
   than X in one tx. Return an error (see #103) instead of building.
5. **Fee bump / RBF for stuck txs:** if a capped tx is not accepted after N seconds, rebuild at a higher rate up to the cap. Refresh the
   estimate per retry.
6. **Degrade behavior:** make the carrier's degrade-to-cap optional (error vs "pay all but min change"), and log a warning with the fee
   paid when it fires.

## Acceptance criteria (suggested)

- `FeePolicy` (or the `Wallet` config) can express a cap as a max feerate and/or a multiplier of the normal bucket; default stays as in #165.
- An absolute per-tx max fee exists; exceeding it returns a typed error, not a panic and not a silent drain.
- The carrier's degrade-to-cap is configurable and logged when it fires.
- Unit tests: estimate with priority ≫ normal (e.g. the 8.4× ratio in E2) → paid feerate equals the cap; small coin + cap → error or
  bounded fee per config.
- Optional: a bump path that re-prices a stuck tx up to the cap after a timeout.

## Caveats

- My traffic was a large share of TN10 load, so "the flood sets the price" was often my own flood.
- The priority numbers in E1 are from the pre-#165 wallet with a custom runner choosing the policy; #165 now normalizes over full mass,
  which is better and could change the absolute numbers.
- Testnet only. No claim about mainnet fee dynamics.

Thanks to the vprogs authors, and to Maxim for the mapping in #165.
