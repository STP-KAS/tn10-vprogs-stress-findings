# Kaspa TN10 stress test, with vprogs and tic-tac-toe (25–26 Sep 2026)

**Testnet-10 only.** Nothing here touched mainnet. No keys, seeds or wallet files are in this repo.

> **One person, one LLM, one desktop.** All of the load this test put on TN10 came from **one individual's setup**:
> **one LLM (Grok) used in two forms**, plus **one personal desktop**:
> - **Grok Bot** ran in its own sandbox computer and drove the node, miners, transaction storm and runners. It also operated my PC.
> - **Grok Build** was run from PowerShell on my PC.
> - My PC is an ordinary personal desktop.
>
> It was not a coordinated group and not dedicated infrastructure. It was one LLM plus one individual's desktop. (TN10 also saw at
> least one external flood on 26 Sep morning that was not ours. See round 5.)

This is a hobbyist stress test of Kaspa **Testnet-10 (TN10)**. It ran for about **17 hours**, from **25 Sep 20:12 to 26 Sep 13:16 CEST**.
The goal was simple: test, test, test the network under load. Push TN10 as hard as this one-person setup could, find what breaks first,
and see how real apps behave while blocks are full. At the same time I tried to run
[vprogs](https://github.com/kaspanet/vprogs) and the [vprog tic-tac-toe](https://github.com/biryukovmaxim/vprog-tictactoe) under that load.
I'm sharing it because [kaspanet/vprogs PR #165](https://github.com/kaspanet/vprogs/pull/165) touches several of the same areas.
Thanks to the vprogs authors for publishing working code on a public testnet. That is what made any of this possible.

All times are **CEST (UTC+2)**. Numbers come from my node logs and my private run reports. Where something is a guess, it says so.

> **Big caveat:** my own traffic was a large share of TN10 load on those days (there was also at least one external flood on
> 26 Sep morning). So "X happened under load" here often means "under load I created". Correlation with anything in PR #165 is
> **not proof** that my test caused or motivated it.

---

## 1. The stress test

### How it was done
- **Own TN10 node:** kaspad 2.1.0 on one 8-core / 16 GB box. Two nodes at first, one from 25 Sep 21:33 to save disk. Mempool cap 100k (`--ram-scale=0.1`), `--async-threads=4`.
- **Own miners:** CPU/GPU `kaspa-miner` processes on my node, so blocks kept coming and fees partly flowed back. In one measured window they found ~65% of TN10 blocks. That share varied, and I cut the miners to 2 at 12:20 on 26 Sep.
- **Transaction storm:** a supervisor plus 8–9 sender workers and ~800 throwaway wallets, sending 1-in-1-out transfers (mostly P2SH anyone-can-spend to keep mass low), plus one 0.5 TKAS payment lane.
- **Runners:**
  - the **original** upstream tools: vprogs `tn10-runtime`, tic-tac-toe `ttd` + `ttflow` + a looping game driver;
  - my own small vprog guest (`grok-deskfloor`) with a load runner;
  - later, my own **index-free** runners (see setups below).
- **KNS runner (round 6):** bulk KNS name creates on TN10 with random `[a-z0-9]` names (length 1–8, sometimes 15) and random throwaway owners, via commit/reveal against the public KNS TN10 indexer.
- **Safety guards:**
  - mempool gate/taper, keeping my node under its 100k cap (gate ~70–85k, hard brake 78–95k depending on the round);
  - disk floor: taper and pause at ~8–13 GB free, plus a "disk dropping fast" latch;
  - RAM floor 1 GB;
  - node crash/unsynced latch;
  - senders stopped by exact process id only.
- **Measurement:** kaspad's own "Processed N blocks … transactions" line every 10 s (network TPS), node mempool/disk samples every 10 s, fee-tier probe transactions, and runner logs with submit → accepted latency.

### One LLM in two forms (plus one desktop)
Everything was done by **one LLM, Grok**, working for me in two forms, plus my own PC. There was no other operator, group or server fleet.
- **Grok Bot** ran in its own sandbox computer. It ran the node, miners, storm, runners, monitoring, guards and the reports (rounds 1–6 below). It also operated my PC, for example the tic-tac-toe campaign against the hosted demo on 25 Sep evening.
- **Grok Build** was run from PowerShell on my PC and did separate wallet load tests from its own wallet. On 25 Sep ~21:20 CEST it tested **through the public TN10 wRPC resolver, not my node**:
  - 660 minimum-fee 1-in-1-out sweeps in two waves, 552 and **1,162 tx/s offered** (the second wave lasted 0.29 s), all included;
  - 24 × 0.5 TKAS payments at storage mass 20,000 (KIP-9);
  - it played one tic-tac-toe game on the hosted demo, and all L1 txs were included. But the demo's `/api/state` stayed at `l2_tip` 566,858 and **settled DAA 580,229,488** for the whole session, the same frozen settlement point I saw (finding 8).

  Its measured packing ceilings: ~3,079 tx/s for minimum 1-in-1-out txs, ~250 tx/s when every payment makes a 0.5 TKAS output.
  I funded its wallet with ~96.6k TKAS (21:17) and ~300k TKAS (22:47) from my storm pools. What it sent after that is **not in my
  logs**, so I treat it as an unmeasured extra sender (still part of the same one-person setup) during round 2.

### Duration and rounds
**Total: 25 Sep 20:12 → 26 Sep 13:16 CEST ≈ 17 h.** The storm itself started at 20:54 on 25 Sep. There were short gaps for node
restarts, the utxoindex rebuild (~19 min) and the 26 Sep 07:10 disk emergency.

| Round | Window (CEST) | Duration | Setup | Fee policy | Key result |
|---|---|---|---|---|---|
| 1 | 25 Sep 20:12–22:46 | ~2 h 34 m | Node break test; storm ramp → full throttle, 57.5-min overload (21:48–22:46); fee-tier probes; first vprogs try | storm 1.2× min (120 sompi/g) | Network TPS median ~5.7k at full throttle, 10 s peak 9,274 in the overload; mempool max 99,967, 30,298 evictions; one kaspad mempool-cap panic (21:12); upstream vprogs runtime panicked (no utxoindex) |
| 2 | 25 Sep 22:47 → 26 Sep 06:31 | ~7 h 44 m | Harder full throttle; utxoindex restart; then ~1k TPS baseline with short full-throttle windows; ended by disk taper | 2× (200) from 22:47, **10× (~1,000)** from 00:15 | 10 s peak **12,175** TPS; mempool max ~88k; storm fees ~197.8k TKAS; disk was the binding limit |
| 3 | 25 Sep 23:48 → 26 Sep 01:13 (+ overnight) | ~1 h 25 m + overnight runs | Node with `--utxoindex`; **original** tic-tac-toe (local `ttd`) + my own vprog guest; storm at 1k background vs full; one short burst | storm 10×; vprog runs at normal / priority / 2× normal | Default fee starves moves (p50 83 s); priority works but costly; ttt 5 games vs 1,322 failures under full storm |
| 4 | 26 Sep 06:38–09:20 | ~2 h 42 m | "Full gusto" windows (storm + own vprog + original ttt), disk emergency, then a paced run | storm 10×, then **6×** from 07:46; own vprog fixed 2,000 sompi/g | Full gusto 1: 3.56k tx/s ours, ~5.0k network; paced 1,219 tx/s for 1 h 32 m (~6.7 M txs); ttt 8 games in 12 min of storm; utxoindex lost at 07:10 |
| 5 | 26 Sep 09:22–10:35 | ~1 h 13 m | **Own index-free runners** (ttt + small state machines) at high fee, storm alongside; external flood present | storm **150×** (09:22–09:50, backfired), then 10×; runners 20k–60k sompi/g | 1.04 M runner txs, 63,614 games, sub-second p50; mempool max 85,827 |
| 6 | 26 Sep 10:35–13:16 | ~2 h 41 m | Index-free runners at full speed; storm lowered at 12:21, stopped 12:50; KNS random-name runner from 12:25; miners cut to 2 | runners 5,000 sompi/g, then from **12:22: 2× the node's normal estimate (min 200)** for everything | **~10.1 M runner txs**, ~1,057 tx/s avg (1,191 at full speed), 600,055 games, mempool max 78,319; KNS 1,883 names created |

### Setups used
- **Original vprogs / tic-tac-toe runners** (rounds 1, 3, 4): upstream code as published. They **need a node with `--utxoindex`**, which cost an 18.5-min rebuild and 13 GB, and they use the upstream wallet's fee logic (see findings). After the index was deleted in the disk emergency they could not run on my node.
- **Own vprog guest** (rounds 3–4): a small RISC Zero guest on vprogs master (balance / floor / debit / move, with deliberately impossible debits), dev-mode exec, with a runner that let me choose the fee (normal / priority / multiple / fixed).
- **Own index-free runners** (rounds 5–6): *not* the vprogs runtime and no ZK. They are chains of 1-in-1-out L1 transactions carrying game/program state in the payload. Each chain tracks its own UTXO locally (it built the tx that created it), so no `utxoindex` is needed. Latency comes from the `virtual-chain-changed` subscription. They show what the L1 fee/UTXO layer can sustain, not vprogs execution or settlement.
- **Storm modes:** off; throttled (~1k TPS "baseline" background); paced (rate chosen to last until a target time within disk/funds); "full gusto"/full throttle (as fast as the guards allow); short bursts (a scheduler for 5-min bursts existed, but only one ~32 s burst ran before I switched to continuous full throttle).
- **KNS** (round 6): random-name bulk creates as another kind of real app load. The public KNS indexer lagged ~235k DAA behind during the run.

---

## 2. Fee strategy

I changed fees round by round to see how priority works under load, both for my own traffic and for everyone else's.

| When (CEST) | Fee | Why / what happened |
|---|---|---|
| 25 Sep 20:54–22:46 | storm **1.2×** min (120 sompi/g; node min 100, 1–10 rejected as non-standard) | Cheapest flood. Probes at 1× waited p50 7.0 s / max 105 s; 10× got ≤3.7 s every time; 100× bought nothing extra |
| 22:47 | storm **2×** (200) | Harder push; network TPS ~7.7k median over the next hour |
| 26 Sep 00:15 | storm **10×** (~1,000) | High enough that the upstream wallet's "normal" estimate (532–573) sat below it, so default-fee vprogs/ttt txs starved |
| 07:46 | storm **6×** | Paced run: at 10× funds ran out before disk; at 6× disk and funds balanced |
| 09:22–09:50 | storm **150×** (0.0965 TKAS/tx) | **Backfired.** On ~0.25 TKAS coins the big fee shrank the change, KIP-9 storage mass rose to ~69k grams/tx, the effective feerate fell to ~140 sompi/g, blocks were 87% storage-mass-full, and network TPS fell to 300–440 |
| 09:51 | storm back to **10×** | |
| 09:22–12:22 | index-free runners **20k–60k**, later **5,000** sompi/g on big (10–24 TKAS) inputs | Large inputs keep storage mass tiny, so high feerates really bought priority: p50 ~0.6–1.0 s even with a 60k+ mempool |
| from 12:22 | everything at **max(2 × node `getFeeEstimate` normal bucket, 200)** sompi/g, recomputed every 30 s | "Double the standard." Went 1,729 at 12:23 → ~380 by 12:25–12:48 as the storm stopped. Late in the round latency rose (p50 ~5–35 s) because of an external backlog |

**For others:** while my storm paid more than the floor, anyone at the minimum fee waited ~7 s typically and up to ~1.5–2 min.
The node evicted low-feerate txs at the cap (30,298 in one hour), and apps that price at the floor (like the original tic-tac-toe
carriers) stalled until the storm stopped. That was the point of the test, but it means my load visibly affected other TN10
users during those hours.

**Gross fees** (TKAS; about 57% of coinbase value, fees included, came back to my own miners):
- storm: ~13.6k in the round-1 overload, ~197.8k in round 2, ~26k in the round-4 paced run;
- index-free runners: ~954k in round 5 and ~685k in round 6;
- KNS: ~134k in name prices.

---

## 3. Other load results

- **Illegal moves:**
  - My own vprog guest (rounds 3–4) *submitted* deliberately impossible debits. The guest executed **0 of 3,518** (round 3) and **0 of 4,291** (round 4). Correct.
  - The index-free runners attempted 207,770 (round 5) + 2,026,964 (round 6) illegal moves. All were refused client-side before any transaction was built, so "0 executed" there is by construction, not a vprogs result.
- **Mempool:** repeatedly ~99.97k without a crash after the first panic; one near-miss at 96,546 (26 Sep 07:28), because worker reaction lag makes stop-start gating unsafe at thousands of tx/s. Drain after a stop: 54k → <1k in 85 s.
- **Disk** was the real long-run limit: ~2 GB/h at 1k TPS, ~7–9 GB/h at 3.5–5k TPS, plus the pruning spike (see node section).

---

## 4. vprogs / tic-tac-toe findings

Evidence numbers are from my logs. Detail for each: [`findings/vprogs-client-findings.md`](findings/vprogs-client-findings.md).

### Probably addressed by PR #165

1. **vprogs moves starve at the wallet's default "normal" fee under a flood.** `Wallet` priced activity at `normal_buckets[0]`. That was 532–573 sompi/g while my storm paid ~1,000 sompi/g (round 3).
   - Normal fee: exec p50 **83 s** / p90 101 s, and **4,871** out-of-funds failures in ~5 min (all issuer UTXOs stuck in the mempool).
   - `priority_bucket` (~4.5k sompi/g): p50 **3.1 s** at 130 moves/s.
   - 2× normal: ~30 moves/s, p50 9.5 s.

   PR #165 switches every funded build to the priority bucket.
2. **Tic-tac-toe carrier txs always paid the relay-floor fee** (`min_fee` in `build/carrier.rs`) with no setting to change it (round 4).
   - **0 games finished during 12 min** of storm at ~1,000 sompi/g (1,223 GAME_FAIL). Games resumed ~100 s after the storm stopped.
   - A proxy that raised `getFeeEstimate` had no effect, because carriers never read it.

   PR #165 adds `FeePolicy` to carrier and payout builds, and tic-tac-toe now passes it (vprog-tictactoe `f128efd`, `803a120`).

### Still open, as far as I can tell

3. **Carrier funding uses only the first UTXO and `assert!`s (panics) when it is too small.** Tic-tac-toe takes `candidates.into_iter().next()`, and `carrier.rs` asserts `entry.amount > extra_value + fee`.
   - Round 3: **8 of 8** workers died after ~170 games once coins fragmented (`funding UTXO amount 98955500 too small for extra outputs 100000000`).
   - Round 4: **4 of 4** workers died (`14913800 too small for extra outputs 40000000`).

   Higher fees will fragment coins faster. Suggestion: pick the largest coin or combine inputs, and return an error instead of panicking.
4. **Carrier and payout builds can reuse a coin that is already spent in the mempool.** The `*_excluding` variants exist for activity and settlement, not for carriers or payouts.
   - Step delay 0: 12 of 14 games failed even at low load.
   - At 1k TPS background: 251 of 670 games failed.
   - Under the full storm: **1,322 of 1,327** games failed with `already spent by transaction ... in the mempool`.

   Suggestion: track in-flight outpoints, or chain on the unconfirmed change output.
5. **No fee cap or multiplier, and no bump for stuck txs.**
   - At the priority bucket (~4.5× the flood fee), my issuers burned **~900 TKAS in 11.5 min** and went broke (round 3).
   - Pricing at the priority bucket means whoever floods sets the price.
   - In PR #165, a carrier that can't reach the target rate degrades to "pay everything except the minimum viable change" (a unit test checks this). One move during a fee spike could burn most of a game coin.

   Suggestion: optional cap (e.g. `min(priority, k × normal)` or an absolute max), plus RBF/bump after N seconds.
6. **`utxoindex` is required, and the missing-index path panics.**
   - Without `--utxoindex`, the upstream TN10 runtime panicked at startup: `fetch spendable utxos: RpcSubsystem("Method unavailable. Run the node with the --utxoindex argument.")`.
   - Enabling the index on an existing TN10 datadir took **1,115 s (18.5 min)** with RPC/P2P down and no progress output. It needed **~13 GB**.
   - In the round 4 disk emergency the 13 GB index was the only thing I could delete.
   - The settler's `poll_outpoint` (used by `covenant_liveness`, which PR #165 now calls on the supersede path too) does `.expect("get_utxos_by_addresses")`, so an RPC error there panics the task.

   Suggestion: a startup check (`hasUtxoIndex`) with a clear error, and errors instead of `expect` on that path.
7. **Storage mass makes a very high fee counterproductive on small coins (KIP-9).**
   - A 150× fee on ~0.25 TKAS coins shrank the change so much that storage mass rose to ~69k grams/tx. The effective feerate fell to ~140 sompi/g, blocks became 87% storage-mass-full, and network TPS dropped to 300–440 (round 5).
   - A 0.5 TKAS 1-in-2-out payment is 20,001 grams, so only ~25 fit per block (round 1).

   PR #165's fee solver accounts for storage mass, which is good. The cost of reaching a target rate on a small coin can still be very high (see 5).
8. **Hosted tic-tac-toe settlement looked frozen.** At 25 Sep 20:12 CEST the demo's last settlement was at DAA 580,229,488 vs virtual DAA 580,293,545, a gap of 64,057 DAA ≈ **85 min**, and it was not moving while the L2 tip advanced.
   - A campaign against the hosted demo in the same evening had 0 finished games and 1,534 game failures. I did not isolate the cause.
   - PR #165 fixes 2 (superseded bundles re-fed forever) and 3 (served settlement tip frozen on lanes without withdrawals) describe symptoms like this. **Unproven** that it's the same thing.

### Node-side observations (not vprogs, but they affect anyone running vprogs on TN10)

- **Pruning needs big transient disk.** The TN10 pruning-point move at 07:03 on 26 Sep grew consensus data **75 → 89 GB in ~5 min** with the storm off. Free disk hit 0 and I had to kill the node and delete the utxoindex. Pruning moves were ~12 h apart.
- **Public explorer/indexer stalled.** The TN10 explorer's transaction database (api-tn10 / kaspa.stream) stopped at **25 Sep 21:55:38**, about 7 minutes into my full-throttle overload. It was still stalled the next morning. My load is a plausible trigger, not a proven one.
- **kaspad mempool cap panic.** kaspad 2.1.0 panicked once at the mempool cap (`100001 > 100000`) on 25 Sep 21:12. A restart also loses the whole mempool (58k txs lost once).

---

## 5. Notes on the PR #165 diff (questions, lower confidence)

Read-only review of commits `36a6d38`..`081af9b`. Details: [`findings/pr165-notes.md`](findings/pr165-notes.md).

- **Stale feerate across retries (small).** In vprog-tictactoe the fee policy is fetched once before `fund_and_submit`, so retries reuse the same rate. Is that intended?
- **Chain check trusts index absence (medium confidence).** `covenant_liveness` treats "outpoint not returned by `get_utxos_by_addresses`" after **one** poll as "spent in a chain block", and the journal entry is then deleted. Could a lagging or rebuilding utxoindex, or a reorg that removed the creating settlement, make it delete a bundle that should stay queued?
- **Thin integration coverage (fairly confident).** `two_provers_contend` runs the settler with `journal: None`, so the new delete path is only covered by unit tests with a stubbed liveness closure.
- **Unbounded journal (known, low severity).** Every observed settlement now adds an in-memory `Observed` entry to a journal that is never trimmed (the code comment acknowledges this). On a long-running lane it grows with every settlement.
- **Drain-the-coin on unreachable target (design question).** See finding 5. Maybe log a warning, or add a cap?
- **CI:** Clippy failed on the PR (5 × `unnecessary use of clone` in the new tests). Cosmetic.

---

## 6. Suggested retest (not run yet)

A bounded 30–60 min run on the PR branch (`081af9b`) + vprog-tictactoe `803a120`, on a node with `--utxoindex`:
1. Unmodified `ttloop` / `ttflow` games and a vprog runner under a moderate storm at a fixed fee multiple (e.g. 2× and 10× the node minimum).
2. Measure:
   - games finished during the storm (was 0);
   - fee per game and per move;
   - how often the degrade-to-cap path fires;
   - carrier `assert!` panics (finding 3);
   - in-mempool reuse failures (finding 4).
3. A settler/prover lane with a competing prover, to see the supersede resolution and the served tip advancing.

Practical costs on my side: ~18.5 min node downtime and ~13 GB to rebuild the utxoindex, a release build (5–9 GB), and it has to be timed away from a TN10 pruning move.

---

## Related repos (all public)

| Repo | What |
|---|---|
| [grok-bot-vprogs-round1-public](https://github.com/STP-KAS/grok-bot-vprogs-round1-public) | Round 1: node/mempool break test, fee-tier probes, first vprogs attempts, hosted tic-tac-toe campaign (clean copy, history squashed) |
| [grok-bot-vprogs-round2](https://github.com/STP-KAS/grok-bot-vprogs-round2) | Round 2: full throttle 2× → 10×, 1k baseline, disk taper |
| [grok-bot-vprogs-round3](https://github.com/STP-KAS/grok-bot-vprogs-round3) | Round 3: utxoindex restart, upstream tic-tac-toe + own vprog guest under the storm, draft upstream issues |
| [grok-bot-vprogs-round4](https://github.com/STP-KAS/grok-bot-vprogs-round4) | Round 4: full-gusto windows, pruning disk emergency, paced 6× run, draft upstream issues U1–U3 |
| [grok-bot-vprogs-round5](https://github.com/STP-KAS/grok-bot-vprogs-round5) | Round 5: own index-free runners, 150× fee backfire |
| [grok-bot-vprogs-round6](https://github.com/STP-KAS/grok-bot-vprogs-round6) | Round 6: index-free runners at full speed, ~10.1 M txs, KNS random-name runner |
| [grok-bot-explorer-rewards-check](https://github.com/STP-KAS/grok-bot-explorer-rewards-check) | TN10 explorer/indexer stall at 25 Sep 21:55:38 |
| [vprogs-tn-desk-public](https://github.com/STP-KAS/vprogs-tn-desk-public) | SilverScript v1 / vprogs desk note and Windows desk campaign (clean copy, history squashed) |
| [grok-build-vprogs](https://github.com/STP-KAS/grok-build-vprogs) | Grok Build's wallet load test via public wRPC and its hosted tic-tac-toe game |

## Files

| Path | Content |
|---|---|
| `README.md` | This summary |
| [`findings/vprogs-client-findings.md`](findings/vprogs-client-findings.md) | Findings 1–8 with evidence and suggestions |
| [`findings/pr165-notes.md`](findings/pr165-notes.md) | What PR #165 changes (my reading) and the questions above |
| [`findings/node-observations.md`](findings/node-observations.md) | Node-side observations (disk/pruning, explorer stall, mempool) |
| [`data/rounds-summary.json`](data/rounds-summary.json) | Aggregate numbers per round |
| [`data/round3-fee-policy.csv`](data/round3-fee-policy.csv) | Own-vprog fee-policy runs (round 3) |
| [`data/ttt-under-load.csv`](data/ttt-under-load.csv) | Tic-tac-toe games vs load (rounds 3–4) |
| [`data/fee-tier-probes-round1.csv`](data/fee-tier-probes-round1.csv) | Plain L1 tx inclusion latency by fee tier during the 57.5-min overload |
| [`tools/summarize.py`](tools/summarize.py) | Prints the round table from `data/rounds-summary.json` |
| [`tools/secret-scan.sh`](tools/secret-scan.sh) | Pre-push scan used for this repo |

The runner scripts are not included (they carry local paths and key-handling code). Happy to describe how they work.

Versions: kaspad 2.1.0 (TN10), vprogs `release-candidate` `3a61c0b` / PR head `081af9b`, vprogs master `f9b84a8`, vprog-tictactoe `ba05d92` → `803a120`.
