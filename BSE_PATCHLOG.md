## BSEv1_9_ALTR.py — Project Patch Log

This project vendors `BSEv1_9_ALTR.py` as the core market engine.  
Per project policy, changes to this file are **kept minimal** and are only made when:
- the engine behavior is incorrect for the intended experiment (bug fix), or
- the engine output format prevents reliable post-processing (reproducibility fix).

All changes below are localized, backwards-compatible at the *pipeline* level (parsers accept legacy outputs),
and documented in-line in the engine as `PROJECT PATCH` comments.

### 2026-01-30

#### 1) Respect `vrbs` in `Exchange.process_order`
- **Location**: `Exchange.process_order(...)`
- **Change**: `verbose = True` → `verbose = bool(vrbs)` when calling `self.add_order(...)`.
- **Reason**: With `verbose=True`, the engine prints per-order commentary even when batch scripts set
  `process_verbose=False`. This makes sweeps noisy and slow, and can create misleading logs.

#### 1b) Respect `sess_vrbs` for population printing
- **Location**: `market_session(...)` local `populate_verbose` flag
- **Change**: `populate_verbose = True` → `populate_verbose = bool(sess_vrbs)`
- **Reason**: Printing every trader during initialization is useful interactively but is harmful in batch runs.

#### 1c) Critical matching-engine correctness fix (prevents “negative profit” crashes)
- **Location**: `Exchange.process_order(...)`
- **Change**:
  - Use the incoming order price (`oprice`) for the crossing check:
    - Bid crosses iff `oprice >= best_ask`
    - Ask crosses iff `oprice <= best_bid`
  - Remove the **incoming** order specifically via `book_del(order)` rather than deleting whichever order
    happens to be the current best bid/ask.
- **Reason**: The previous logic could trigger a trade because some *other* trader's best bid/ask crossed,
  but then attribute the transaction to the incoming order and price it at the counterparty level. This can
  violate customer limit constraints and lead to `FAIL: negative profit` in `Trader.bookkeep`, crashing Phase 3 runs.

#### 1d) Robust cancellation of live quotes on customer-order replacement
- **Location**: `market_session(...)` kill/cancel loop (processing `kills` from `customer_orders`)
- **Change**:
  - In `customer_orders(...)`, treat `lastquote != None` as sufficient to request cancellation (do not depend only on `n_quotes`).
  - In `market_session(...)`, cancel using the *actual* live order objects currently stored in `exchange.bids.orders` / `exchange.asks.orders`.
- **Reason**: If `lastquote` is stale or does not match the currently-live quote, the old quote can remain on the book
  and later trade against a new customer order with a different (lower) limit, causing `FAIL: negative profit`.

#### 2) Structured CSV headers for opinion/quote logs
- **Location**: `market_session(...)` when opening `*_opinions.csv` and `*_quotes.csv`.
- **Change**: Write one header line at file open:
  - `opinions.csv`: `time,kind,tid,ttype,opinion,mean,std`
  - `quotes.csv`: `time,tid,ttype,role,otype,quote,limit,opinion`
- **Reason**: Earlier key/value token logging (e.g. `t=,123, id=,B00, ...`) is fragile to parse using CSV readers,
  leading to missing metrics (e.g., polarization dispersion, quote-to-limit gap). Stable headers make the pipeline robust.

#### 3) Write structured CSV rows for opinion/quote logs
- **Location**: `market_session(...)` write sites for `opinion_log.write(...)` and `quotes_log.write(...)`.
- **Change**: Emit rows matching the headers above:
  - opinion aggregate rows have `kind=agg` and fill `mean/std`
  - opinion trader rows have `kind=trader` and fill `tid/ttype/opinion`
  - quote rows fill `tid/ttype/role/otype/quote/limit/opinion`
- **Reason**: Enables reliable post-processing and avoids “hallucinated” figure descriptions caused by missing data.

#### 3b) Opinion log size controls + final snapshot
- **Location**: `market_session(...)` opinion logging block and session teardown
- **Change**:
  - Always write aggregate rows (`kind=agg`) each integer time tick.
  - Write per-trader rows (`kind=trader`) **only if** `dump_opinions_detail=True` and only every `opinions_detail_every` seconds.
  - Always write one **final** per-trader snapshot at session end (time = `endtime`).
- **Reason**: Per-trader logging every second produces multi-million-line files and makes Phase 2/3 sweeps impractical.
  The final snapshot is sufficient for polarization/dispersion metrics, while aggregate rows support consensus speed metrics.

#### 3c) Ensure opinion logging is truly “once per integer time”
- **Location**: `market_session(...)` opinion logging block
- **Change**: After writing the aggregate (and optional detail snapshot), add `frames_done.add(int(time))`.
- **Reason**: The logging condition is `int(time) not in frames_done`. Without updating `frames_done`, the engine would
  log repeatedly for every sub-second timestep within the same integer second, producing very large files.

#### 1e) Disable noisy PRZI/PRDE initialization prints (Phase 4 UX fix)
- **Location**: `TraderPRZI.__init__(...)`
- **Change**: `vrbs = True` → `vrbs = False` (suppresses `print(self.strat_str())` during initialization)
- **Reason**: When creating many PRDE traders, the engine prints long strategy blocks for each trader, which can make
  Phase 4 appear “stuck” even though it is running normally. This change improves batch usability without affecting results.

#### 4) Circuit breaker (meltdown) trigger logic fix
- **Location**: `market_session(...)` circuit breaker block (rolling-window freeze)
- **Change**: Compute:
  - `ref_price`: earliest trade price with `trade.time >= (time - window)`
  - `last_price`: latest trade price on the tape
  and compare these, rather than breaking early in a way that often caused `ref_price == last_price`.
- **Reason**: The previous implementation frequently failed to trigger even under large price moves,
  undermining Phase 3 “policy” experiments.

