# Peak Momentum EA — MT5 reconstruction

A complete MetaTrader 5 Expert Advisor in pure MQL5 that reproduces the **observable**
trading behaviour of the "peak momentum" scalper shown in the reference video:
tick-based micro-momentum detection → a dynamically trailed stop order → fixed
take profit ≈ 10 price units → a peak-momentum-decay trailing stop.

**File:** `PeakMomentumEA.mq5` (single file, no external dependencies beyond `<Trade\Trade.mqh>`)

---

## 1. What this is, and what it is not

**This is** a technically defensible reconstruction built only from externally observable
behaviour: entry/exit prices, profits, order types, order comments and timing visible in
the video.

**This is not** the original proprietary algorithm. Nobody outside the original author can
know that from a screen recording. Every component that had to be inferred is exposed as a
configurable input so it can be tested, optimised or switched off — nothing is hidden in the code.

The video is not tick data. It shows a handful of trades on a large demo account. It is
evidence about *mechanics* (order types, TP distance, trade duration, comment text), not
evidence about *profitability*.

---

## 2. Installation

1. Copy `PeakMomentumEA.mq5` to
   `<MT5 data folder>/MQL5/Experts/PeakMomentumEA.mq5`
   (MT5 → File → Open Data Folder)
2. Open it in MetaEditor and press **F7** (Compile).
3. In MT5, refresh the Navigator, drag the EA onto a **US30.x M1** chart.
4. Enable **Algo Trading** and, in the EA dialog, allow live trading.
5. Start on a **demo account**.

Requirements: MetaTrader 5 build 3000+ (any modern build), a broker that allows
BUY STOP / SELL STOP orders on the symbol, and hedging or netting mode (both work —
the EA holds at most one position).

---

## 3. The reconstructed strategy

### 3.1 From observation to implementation

| Observation in the video | Implementation |
|---|---|
| US30.x, M1, 0.10 lots, both directions | `TradeSymbol` (empty = chart symbol), fixed lot mode, default `FixedLot = 0.10` |
| Trades last seconds, very frequent | Momentum measured on **ticks**, not candles; `CooldownSeconds = 1` |
| BUY STOP orders visibly placed **and re-priced** | Pending manager (`ManagePending()`): one stop order that follows the market every tick |
| Pending price moves with the market | `desired = Ask + PendingDistance` (BUY) / `Bid − PendingDistance` (SELL), re-issued when the difference exceeds `PendingModifyThresholdPoints` |
| Entry 50106.07 → TP 50116.07; entry 50132.03 → TP 50122.03 | Fixed `TakeProfitPriceUnits = 10.0`, recomputed from the **actual fill price** after the order triggers |
| One trade closed at exactly +10.00 USD | Full TP hit (0.10 lots × 10.0 units × contract 10 ≈ 10.00 USD) |
| Many trades close far below TP, at +3.28 / +3.78 | Peak-momentum decay trailing stop tightens as momentum fades |
| "S/L shown at exit" equals the exit price | The exit is a **stop** that was trailed up to the current price, not a market close |
| A losing trade of ≈ −0.03 (SELL 50103.03 → 50103.06) | Loss of roughly one spread → modelled by the **momentum reversal exit** (`CloseOnMomentumReversal`), not by a wide stop |
| Comment `peak momentum` | `UseDistinctPendingComment = false` keeps the pending comment at `peak momentum` so the filled position inherits it (see §6.3) |
| No martingale, no grid | Lot size is constant by construction; explicitly enforced (§3.5) |

### 3.2 Momentum engine (`CMomentumEngine`)

Pure tick engine, independent of the chart timeframe. A ring buffer stores
`(time_msc, mid price)`. The reference sample is the newest sample that is **both**
at least `MomentumLookbackTicks` ticks and `MomentumLookbackMilliseconds` milliseconds old.

```
delta        = midNow − midRef
velocity     = delta_in_points / elapsedSeconds          (EMA-smoothed)
acceleration = (velocity − previousVelocity) / dt        (EMA-smoothed)
breakout     = clamp((mid − midOfRange) / halfRange, −1, +1)
```

`breakout` uses the high/low of the lookback window **excluding the current tick**, so a
price pushing through the recent range scores near ±1.

```
score = ( normVelocity·VelocityWeight
        + normAcceleration·AccelerationWeight
        + breakout·BreakoutWeight ) / (sum of weights)      →  −1 … +1
```

Direction gate (all three must agree):

```
BUY  : score ≥ +MomentumThreshold  AND velocity ≥ +MinimumPriceVelocity  AND normAcc ≥ +MomentumAccelerationThreshold
SELL : score ≤ −MomentumThreshold  AND velocity ≤ −MinimumPriceVelocity  AND normAcc ≤ −MomentumAccelerationThreshold
```

A direction is only *confirmed* after `ConfirmationTicks` consecutive qualifying ticks —
this is the multi-tick stability filter that stops a single random tick from firing an entry.

No indicator, no candle value, no future data is read. Every decision uses only the ticks
that have already arrived.

### 3.3 Order flow

```
FAST TICK DATA → momentum score → confirmed direction
      → BUY STOP at Ask + PendingDistance  (or SELL STOP at Bid − PendingDistance)
      → order re-priced every tick while the signal stays valid
      → order deleted on momentum loss / direction flip / timeout
      → triggered → TP = fill ± TakeProfitPriceUnits, very tight initial SL
      → track peak momentum
           momentum expanding → give the trade room
           momentum decaying  → tighten the trailing stop
      → exit: TP, trailing stop, breakeven stop, momentum reversal, or max duration
      → cooldown → reassess
```

State machine: `IDLE → WAITING → PENDING_BUY/PENDING_SELL → BUY_ACTIVE/SELL_ACTIVE → COOLDOWN`
(plus `HALTED` for the risk layer). The state is **derived from the terminal**, not from RAM,
on every tick — so a terminal/VPS/EA restart or a timeframe change reconstructs it correctly
and never creates duplicates.

### 3.4 Peak-momentum trailing (the important part)

Per position the EA tracks `entryPrice`, `highestFavorablePrice` / `lowestFavorablePrice`,
`maxFloatingProfit`, `momentumAtEntry`, `peakMomentum`, `currentMomentum` and `momentumDecay`,
where `currentMomentum` is the score projected onto the trade direction
(`+score` for a long, `−score` for a short).

```
momentumDecay    = max(0, peakMomentum − currentMomentum)
trailingDistance = TrailingBaseDistancePoints − momentumDecay × MomentumTrailFactor
```

* **Phase 1 — entry:** `peakMomentum = currentMomentum`; the stop sits at
  `InitialStopDistancePoints`.
* **Phase 2 — expansion:** while `currentMomentum` is making new highs the distance is
  multiplied by `ExpansionRoomMultiplier`, so an accelerating trade is not strangled.
  Deep in profit (`StrongMomentumTriggerPoints`) with a strong score
  (`StrongMomentumScore`) the trade gets the maximum distance and is allowed to run to TP.
* **Phase 3 — decay:** every unit of decay removes `MomentumTrailFactor` points from the
  trailing distance, clamped to
  `[TrailingMinimumDistancePoints, TrailingMaximumDistancePoints]`.

Profit protection is layered on top and takes the **best** of all candidates:

```
maxProfit ≥ BreakEvenTriggerPoints  → stop ≥ entry + BreakEvenLockPoints
maxProfit ≥ LockProfitTriggerPoints → stop ≥ entry + maxProfit × LockProfitRatio
```

The stop **never moves backwards** (for a long `newSL ≥ oldSL`, for a short `newSL ≤ oldSL`),
is clamped to the broker's stops level, is skipped inside the freeze level, and is only sent
when it improves by at least `SLModifyThresholdPoints`.

### 3.5 Exit priority

1. Broker stop loss
2. Take profit
3. Momentum-decay trailing stop
4. Momentum reversal exit (`CloseOnMomentumReversal`) — this is what reproduces the
   ≈ −0.03 "spread-sized" loss in the video
5. Emergency spread protection (`EnableSpreadEmergencyExit`, off by default)
6. Maximum holding time (`MaxTradeDurationSeconds`) — tightens the stop to the minimum
   and, with `CloseOnMaxDuration`, closes at market
7. Risk-layer halt / manual shutdown

### 3.6 What is explicitly NOT implemented

No martingale, no lot doubling, no recovery multiplication, no grid, no averaging down,
no unlimited hedging, no random or fixed-time entries, no single-indicator entries,
no large fixed stops, no revenge trading.

In `FIXED` lot mode the next lot is always the configured lot. A loss can never increase it —
there is simply no code path that changes the volume. `RISK_PERCENT` mode sizes from the
*configured stop distance*, not from previous results, so it also cannot martingale.

---

## 4. Module map (all inside the one file)

| Class | Responsibility |
|---|---|
| `CSymbolCtx` | Digits, point, tick size/value, volume limits, stops & freeze levels, price/volume normalisation, point-input scaling |
| `CMomentumEngine` | Tick ring buffer, velocity, acceleration, micro-breakout, score, confirmation |
| `COrderManager` | `CTrade` wrapper: find / place / modify / delete / close, with full retcode, ticket, price and volume validation and logging |
| `CStatisticsManager` | History-driven statistics and the exit-reason breakdown |
| `CRiskManager` | Daily loss/profit locks, equity drawdown, consecutive losses — the safety layer |
| `CDashboardManager` | On-chart dashboard, level lines, entry arrows, object cleanup |
| `CPeakMomentumEA` | State machine, pending manager, position manager, trailing manager, orchestration |

---

## 5. Point scaling — read this before optimising

US30 is quoted with 1 or 2 digits depending on the broker, so "30 points" means a different
price distance on different servers. With `NormalizePointInputs = true` (default) every
point input is scaled so it always means the same **price** distance as it would at
`ReferencePointSize = 0.01`:

```
effective price distance = inputPoints × (ReferencePointSize / SYMBOL_POINT) × SYMBOL_POINT
                         = inputPoints × ReferencePointSize
```

So with the defaults, `PendingDistancePoints = 30` is **0.30 index units** on every broker.
The exact conversion is printed to the Experts log at startup:

```
[PM] Point input scaling factor = 1.0000 (an input of 1 point = 0.0100 price)
[PM] Effective distances | pending=0.30 initialSL=1.00 trailBase=0.45 trailMin=0.08 TP=10.00
```

Set `NormalizePointInputs = false` if you prefer raw broker points.
`TakeProfitPriceUnits` is **always** in price units (10.0 = 10.0 index points) and is never scaled.

---

## 6. Parameter reference

### 6.1 General

| Input | Default | Meaning |
|---|---|---|
| `TradeSymbol` | `""` | Empty = chart symbol. Works with US30, US30.x, "Wall Street 30", XAUUSD, other CFDs |
| `SignalTimeframe` | `PERIOD_M1` | Informational only — all signals are tick based |
| `MagicNumber` | `83001` | Identifies this EA's orders. Manual trades and other EAs are never touched |
| `EnableTrading` | `true` | Master switch. `false` = manage existing trades, open nothing new |
| `DebugMode` | `true` | Verbose `[PM]` logging |
| `TimerMilliseconds` | `200` | Housekeeping timer so timeouts/trailing keep working between ticks |

### 6.2 Momentum engine

| Input | Default | Meaning |
|---|---|---|
| `MomentumLookbackTicks` | `10` | Minimum ticks back for the reference sample |
| `MomentumLookbackMilliseconds` | `1000` | Minimum age of the reference sample |
| `MomentumThreshold` | `0.35` | `\|score\|` needed to declare a direction |
| `MomentumAccelerationThreshold` | `0.0` | Normalised acceleration gate (0 = must not be decelerating) |
| `MinimumPriceVelocity` | `15.0` | Minimum velocity in points/second |
| `MomentumSmoothing` | `0.35` | EMA factor, `(0,1]`; 1 = raw, unsmoothed |
| `VelocityWeight` / `AccelerationWeight` / `BreakoutWeight` | `0.50 / 0.25 / 0.25` | Score weights |
| `VelocityNormalization` | `60.0` | points/sec that maps to a normalised 1.0 |
| `AccelerationNormalization` | `120.0` | points/sec² that maps to a normalised 1.0 |
| `ConfirmationTicks` | `3` | Consecutive qualifying ticks before a signal counts |

### 6.3 Pending order

| Input | Default | Meaning |
|---|---|---|
| `PendingDistancePoints` | `30.0` | Offset beyond the market |
| `MinimumPendingDistancePoints` / `MaximumPendingDistancePoints` | `10 / 150` | Clamps; the broker stops level is also enforced |
| `PendingModifyThresholdPoints` | `5.0` | Minimum move before the order is re-priced (prevents request flooding) |
| `PendingTimeoutSeconds` | `20` | Maximum lifetime; `0` = no timeout |
| `CancelPendingOnMomentumLoss` | `true` | Delete when the directional score falls below the threshold |
| `CancelPendingOnDirectionFlip` | `true` | Delete when momentum flips, then re-evaluate the other side |
| `UseDistinctPendingComment` | `false` | `false` → comment `peak momentum` (matches the video, because a filled position **inherits the pending order's comment**). `true` → `peak momentum pending`, which is more readable but means the position also shows "pending" |

### 6.4 TP, stops and trailing

| Input | Default | Meaning |
|---|---|---|
| `TakeProfitPriceUnits` | `10.0` | Fixed TP in **price units** (never scaled). `0` = no TP |
| `InitialStopDistancePoints` | `100.0` | Initial protective stop (= 1.00 index unit ≈ 1.00 USD at 0.10 lots) |
| `EnableTrailing` | `true` | Peak-momentum trailing engine |
| `TrailingBaseDistancePoints` | `45.0` | Base trailing distance |
| `TrailingMinimumDistancePoints` | `8.0` | Tightest allowed |
| `TrailingMaximumDistancePoints` | `120.0` | Loosest allowed |
| `MomentumTrailFactor` | `25.0` | Points removed per 1.0 of momentum decay |
| `ExpansionRoomMultiplier` | `1.5` | Extra room while momentum is still making new peaks |
| `SLModifyThresholdPoints` | `3.0` | Minimum improvement before an SL modification is sent |
| `BreakEvenTriggerPoints` / `BreakEvenLockPoints` | `60 / 2` | Profit that protects the entry, and how much is locked |
| `LockProfitTriggerPoints` / `LockProfitRatio` | `150 / 0.50` | Profit that starts partial locking, and the fraction locked |
| `StrongMomentumTriggerPoints` / `StrongMomentumScore` | `300 / 0.60` | A strong run this deep in profit keeps the maximum trailing distance |

### 6.5 Momentum exit

| Input | Default | Meaning |
|---|---|---|
| `CloseOnMomentumReversal` | `true` | Close at market when momentum turns against the trade |
| `ReversalExitScore` | `0.45` | Opposite directional score that triggers it |
| `ReversalConfirmationTicks` | `2` | Consecutive opposite readings required |
| `MaxTradeDurationSeconds` | `60` | Maximum holding time; `0` = off |
| `CloseOnMaxDuration` | `true` | `true` = close at market, `false` = only tighten to the minimum trailing distance |
| `AllowImmediateReverse` | `false` | Close and flip an open position on a direction flip. **Off by default** — the video does not prove this behaviour |

### 6.6 Execution filters and lots

| Input | Default | Meaning |
|---|---|---|
| `MaxSpreadPoints` | `60.0` | No new pending orders above this spread |
| `SpreadMultiplier` | `3.0` | Emergency threshold = `MaxSpreadPoints × SpreadMultiplier` |
| `EnableSpreadEmergencyExit` | `false` | Close an open position on a spread explosion (off: closing into a spike is usually worse) |
| `MaxSlippagePoints` | `20` | Deviation for market operations |
| `CooldownSeconds` | `1.0` | Pause after a close |
| `LotMode` | `FIXED` | `FIXED` (reproduces the video) or `RISK_PERCENT` |
| `FixedLot` | `0.10` | Fixed volume |
| `RiskPercent` | `0.25` | Risk per trade in `RISK_PERCENT` mode, sized from `InitialStopDistancePoints` and the symbol tick value |

### 6.7 Risk safety layer (NOT part of the inferred strategy)

| Input | Default | Meaning |
|---|---|---|
| `MaxOpenPositions` / `MaxPendingOrders` | `1 / 1` | Hard structural limits |
| `EnableDailyLossLimit` / `DailyLossLimitPercent` | `true / 2.0` | Mandatory daily loss lock, % of the day's starting equity |
| `MaxDailyLossMoney` | `0.0` | Additional absolute daily loss cap (0 = off) |
| `EnableDailyProfitTarget` / `DailyProfitTargetMoney` | `false / 0.0` | Stop opening new trades once reached. Open trades are **not** force-closed |
| `MaxConsecutiveLosses` | `0` | Stop after N losses in a row (0 = off) |
| `MaxEquityDrawdownPercent` | `5.0` | Stop when equity falls this far below the day's start (0 = off) |
| `CloseAllOnHalt` | `false` | Also close the open trade when a limit trips |

When a limit trips: pending orders are cancelled, new entries are disabled, and the existing
position is still managed normally (or closed if `CloseAllOnHalt`). The lock resets at the
start of the next trading day.

### 6.8 Dashboard, visuals, statistics

`ShowDashboard`, `ShowState`, `ShowMomentumScore`, `ShowVelocity`, `ShowAcceleration`,
`ShowPendingPrice`, `ShowTrailingDistance`, `ShowTradeMarkers`, `MaxTradeMarkers`,
`DashboardX`, `DashboardY`, `DashboardColor`,
`EnableStatistics`, `PrintStatsOnDeinit`, `StatsPrintIntervalSeconds`.

The dashboard shows state, score, velocity, acceleration, micro-breakout, spread, pending
order, entry, TP, SL, peak momentum, current momentum, momentum decay, trailing distance,
floating P/L and the day's P/L. Blue up arrows mark long entries, red down arrows short
entries; dotted blue/red lines mark the pending order, green the TP, orange-red the trailing
stop. All objects use a magic-number-specific prefix and are removed on deinit. Chart objects
are skipped entirely in non-visual tester runs.

---

## 7. Recommended starting configuration

The defaults in the file **are** the recommended starting point for US30.x M1:

```
TradeSymbol                  = ""            (chart symbol)
LotMode                      = FIXED
FixedLot                     = 0.10
TakeProfitPriceUnits         = 10.0
PendingDistancePoints        = 30            (= 0.30 index units)
PendingModifyThresholdPoints = 5
PendingTimeoutSeconds        = 20
MomentumLookbackTicks        = 10
MomentumLookbackMilliseconds = 1000
MomentumThreshold            = 0.35
ConfirmationTicks            = 3
MinimumPriceVelocity         = 15
InitialStopDistancePoints    = 100           (= 1.00 index unit)
TrailingBaseDistancePoints   = 45
TrailingMinimumDistancePoints= 8
MomentumTrailFactor          = 25
BreakEvenTriggerPoints       = 60
LockProfitTriggerPoints      = 150
MaxTradeDurationSeconds      = 60
CooldownSeconds              = 1
MaxSpreadPoints              = 60
EnableDailyLossLimit         = true
DailyLossLimitPercent        = 2.0
MagicNumber                  = 83001
DebugMode                    = true
ShowDashboard                = true
```

These are **starting values chosen to reproduce the observable behaviour**, not the original
author's values. Treat them as the centre of an optimisation range, not as a proven setting.

---

## 8. Backtest instructions

1. MT5 → **View → Strategy Tester** (Ctrl+R).
2. Expert: `PeakMomentumEA`, Symbol: `US30.x`, Timeframe: `M1`.
3. **Modelling: "Every tick based on real ticks"** — this is mandatory.
   The momentum engine reads `time_msc` from individual ticks. With "1 minute OHLC"
   or generated ticks the lookback window degenerates and the results are meaningless.
4. Set a realistic **spread** (use "Current" or your broker's typical US30 spread) and,
   if your broker charges one, a commission in the symbol settings.
5. Deposit: use something realistic for 0.10 lots on an index CFD. **Do not conclude from
   the video that 0.10 lots is safe on a small account** — the account in the video is a
   large demo.
6. Run. On completion the EA prints the full statistics block to the Journal:

```
===================== PEAK MOMENTUM STATISTICS =====================
Total Trades / BUY / SELL / Winning / Losing / Win Rate
Average Win / Average Loss / Largest Win / Largest Loss
Net Profit / Profit Factor / Expectancy per trade / Average Profit per trade
Max Drawdown (closed) / Recovery Factor / Max Consecutive Losses
Average Trade Duration
-------------------- EXIT REASONS (this session) -------------------
Take Profit hits / Trailing stop exits / Break-even exits / Initial stop exits
Momentum reversal exits / Max duration exits / Emergency exits / External exits
====================================================================
```

For a first look set `DebugMode = false` (per-tick logging is heavy in a tester run) and
`StatsPrintIntervalSeconds = 3600` for periodic snapshots.

---

## 9. Optimisation instructions

Optimise in this order, one group at a time — optimising everything at once on a
tick-level scalper is a guaranteed overfit.

**Step 1 — signal quality** (does it enter at the right moments?)

| Parameter | Suggested range | Step |
|---|---|---|
| `MomentumThreshold` | 0.20 – 0.70 | 0.05 |
| `MomentumLookbackTicks` | 5 – 30 | 5 |
| `MomentumLookbackMilliseconds` | 250 – 3000 | 250 |
| `ConfirmationTicks` | 1 – 6 | 1 |
| `MinimumPriceVelocity` | 5 – 50 | 5 |

**Step 2 — entry mechanics**

| Parameter | Suggested range | Step |
|---|---|---|
| `PendingDistancePoints` | 10 – 100 | 10 |
| `PendingModifyThresholdPoints` | 2 – 20 | 2 |
| `PendingTimeoutSeconds` | 5 – 60 | 5 |

**Step 3 — exit mechanics** (this is where most of the edge or damage lives)

| Parameter | Suggested range | Step |
|---|---|---|
| `TrailingBaseDistancePoints` | 20 – 120 | 10 |
| `TrailingMinimumDistancePoints` | 4 – 40 | 4 |
| `MomentumTrailFactor` | 0 – 60 | 5 |
| `BreakEvenTriggerPoints` | 20 – 200 | 20 |
| `InitialStopDistancePoints` | 40 – 300 | 20 |
| `TakeProfitPriceUnits` | 5 – 20 | 1 |

**Step 4 — timing:** `MaxTradeDurationSeconds` 15 – 180, `CooldownSeconds` 0 – 10.

Notes:

* The built-in `OnTester()` custom criterion is
  `netProfit × min(profitFactor, 10) / (1 + maxDrawdown)`, and returns `0` for fewer than
  10 trades or a non-positive expectancy. Select **"Custom max"** in the tester to use it,
  so the optimiser cannot win by producing three lucky trades.
* Optimise on one period, then **forward-test on an untouched period**. A scalper that only
  works on its optimisation window is curve fit.
* Re-check the winner with a **higher spread** than you optimised on. Tick-scalping results
  are extremely spread-sensitive; if a setting dies at +1 point of spread, it is not tradeable.

---

## 10. Statistical validation — do not trust win rate

A 90 % win rate with rare catastrophic losses is a losing strategy that looks great in a
screenshot. The report therefore includes:

```
Expectancy     = winRate × averageWin − lossRate × averageLoss
Profit Factor  = grossProfit / grossLoss
Recovery Factor= netProfit / maxDrawdown
Max Drawdown, Max Consecutive Losses, Average Trade Duration
```

Judge a configuration on **expectancy, profit factor, drawdown and largest loss together**.
Also check the exit-reason breakdown: if nearly all profit comes from `Take Profit hits`
while `Initial stop exits` are rare but huge, the risk/reward is inverted no matter how good
the win rate looks.

---

## 11. Verification checklist

These are the behaviours to confirm on a demo account or in a visual-mode tester. Each maps
to the code path that implements it.

| # | Test | Where it is enforced |
|---|---|---|
| 1 | No new trades when the spread is above the limit | `SpreadOk()` in `PlacePending()`; logs `Entry blocked: spread ...` |
| 2 | Only one pending order at a time | `MaxPendingOrders`, plus surplus deletion in `RebuildState()` |
| 3 | No duplicate pending orders | A new pending is only placed when `m_pendingTicket == 0` **and** no position exists |
| 4 | BUY STOP follows the market | `ManagePending()` → `desired = Ask + distance`, modified past `PendingModifyThresholdPoints`; logs `BUY STOP modified to ...` |
| 5 | SELL STOP follows the market | Same path, `Bid − distance` |
| 6 | Pending cancelled when momentum disappears | `CancelPendingOnMomentumLoss`; logs `momentum faded` |
| 7 | Direction change handled | `CancelPendingOnDirectionFlip` deletes, then the next tick evaluates the opposite side |
| 8 | BUY TP = entry + `TakeProfitPriceUnits` | `OnPositionOpened()` recomputes TP from the **actual fill price** and modifies if it differs |
| 9 | SELL TP = entry − `TakeProfitPriceUnits` | Same path |
| 10 | Trailing stop never moves backwards | `doIt` requires `candidate ≥ oldSL + step` (long) / `candidate ≤ oldSL − step` (short); the live SL is re-read from the position every tick |
| 11 | Lot never increases after a loss | No code path modifies volume; `LotSize()` depends only on inputs and the configured stop |
| 12 | Restart creates no duplicates | `RebuildState()` derives everything from `PositionsTotal()`/`OrdersTotal()`; existing positions and pendings are adopted, and a pre-existing better stop is never loosened |
| 13 | Manual and foreign trades ignored | Every scan filters on `MagicNumber` **and** symbol |
| 14 | Broker stops/freeze levels respected | `SYMBOL_TRADE_STOPS_LEVEL` clamps pending, TP and SL prices; `SYMBOL_TRADE_FREEZE_LEVEL` blocks modification/deletion too close to market |

Log lines to look for:

```
[PM] Momentum BUY detected | Score: 0.612 | Velocity: 31.20 | Acceleration: 8.40 | Breakout: 0.85
[PM] BUY STOP placed at 50108.54 (#123456, tp=50118.54, sl=50107.54, lots=0.10)
[PM] BUY STOP modified to 50108.21
[PM] BUY STOP triggered
[PM] Entry: 50108.21 (lots 0.10, ticket #123457)
[PM] TP: 50118.21 | initial SL: 50107.21
[PM] Peak momentum: 0.940
[PM] Momentum decay detected (peak 0.940 -> current 0.610)
[PM] Trailing SL moved to 50110.75 (distance 28.5 pts, decay 0.330)
[PM] Position closed #123457 | reason TRAILING_STOP | P/L 2.54 | peak momentum 0.940 | decay 0.330
```

---

## 12. Known uncertainties versus the reference video

Everything below is honestly unknown and is therefore a parameter, not a hidden assumption.

1. **The momentum formula itself.** Velocity + acceleration + micro-breakout with
   configurable weights is *a* defensible way to produce the observed behaviour. It is
   certainly not provably the original.
2. **The real pending-order distance.** The video shows the order moving, not its exact
   offset. `PendingDistancePoints = 30` is a plausible starting value.
3. **The re-pricing rule.** The trigger could be time-based, tick-based or threshold-based.
   A price-difference threshold was chosen because it is the most broker-friendly.
4. **The exit rule.** The video shows exits well before TP with the S/L equal to the exit
   price, which proves a *stop* was hit, not *why* it was where it was. The
   momentum-decay formula is an inference.
5. **The −0.03 loss.** Reproduced here with a momentum-reversal market exit. It could
   equally have been a stop placed one spread away. Both readings are configurable
   (`CloseOnMomentumReversal`, `InitialStopDistancePoints`).
6. **TP ≈ 10.0.** Strongly supported (50106.07 → 50116.07, 50132.03 → 50122.03,
   one +10.00 USD close), but whether it is truly fixed or symbol/volatility-scaled
   cannot be known from a handful of trades.
7. **The comment string.** `peak momentum` is visible. Whether the original also tagged
   its pendings differently is unknown — hence `UseDistinctPendingComment`.
8. **Whether the original reversed positions.** Never observed, so `AllowImmediateReverse`
   defaults to `false`.
9. **Session/news/time filters.** None are visible in the video, so none are implemented.
   If the original had them, this reconstruction will trade more often than it did.
10. **Contract size.** The observed P/L (3.28 units → 3.28 USD at 0.10 lots) implies about
    10 USD per index unit per lot. Your broker may differ; the EA reads the real tick value
    and never assumes it.

---

## 13. Risk warnings

* **This EA has not been proven profitable.** It reproduces observable *mechanics*. A video
  showing winning trades is a selected sample, not evidence of an edge.
* The default risk/reward is **asymmetric**: TP is 10.0 units while the initial stop is 1.0
  unit, and most exits are tight trailing stops. That naturally produces a high win rate with
  occasional larger losses — exactly the pattern that looks wonderful until it does not.
  Judge it by expectancy, not by win rate.
* **Tick scalping is spread- and latency-sensitive.** Results depend heavily on your broker's
  spread, commission, execution speed and slippage. Backtest results will overstate live
  performance. A VPS near the broker's server matters here more than for slower strategies.
* **Do not run this on a small account.** The account in the video is a large demo. 0.10 lots
  on US30 is roughly 1 USD per index unit of movement.
* The risk layer (daily loss lock, equity drawdown lock, consecutive-loss lock) is **an
  addition by this reconstruction**, not part of the inferred original strategy. It is
  deliberately kept separate in the code and in this document.
* Test on a demo account for a meaningful period before even considering real money.
  Past behaviour — observed or backtested — does not predict future results.

---

## 14. Build note

`PeakMomentumEA.mq5` was written and reviewed against the MQL5 language and Standard Library
API but **has not been compiled in MetaEditor in this environment** (no MetaTrader/MetaEditor
toolchain is available on Linux here). Compile it with F7 before use. If your build reports
anything, it will be trivial and local — the file has no external dependencies beyond
`<Trade\Trade.mqh>`.
