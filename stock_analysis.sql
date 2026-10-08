-- =====================================================================
-- NSE STOCK ANALYSIS: Bajaj Auto, Eicher Motors, Hero Motocorp,
-- TVS Motors, TCS, Infosys | 2015-01-01 to 2018-07-31
--
-- Part A  guide tasks 1-13
-- Part B  my own analysis
-- Part C  moving averages for all six stocks
--
-- Run top to bottom. Every table is created after DROP TABLE IF EXISTS,
-- so the file can be re-run. Lines tagged "MySQL:" need a change for MySQL.
-- =====================================================================


-- =====================================================================
-- PART A: GUIDE TASKS
-- =====================================================================

-- A0: Stack the six stocks into one table
DROP TABLE IF EXISTS prices;
CREATE TABLE prices AS
SELECT 'Bajaj Auto' AS stock, date, open_price, high_price, low_price, close_price,
       no_of_shares, no_of_trades, total_turnover, deliverable_qty, pct_deli_qty FROM bajaj_auto
UNION ALL
SELECT 'Eicher Motors', date, open_price, high_price, low_price, close_price,
       no_of_shares, no_of_trades, total_turnover, deliverable_qty, pct_deli_qty FROM eicher_motors
UNION ALL
SELECT 'Hero Motocorp', date, open_price, high_price, low_price, close_price,
       no_of_shares, no_of_trades, total_turnover, deliverable_qty, pct_deli_qty FROM hero_motocorp
UNION ALL
SELECT 'Infosys', date, open_price, high_price, low_price, close_price,
       no_of_shares, no_of_trades, total_turnover, deliverable_qty, pct_deli_qty FROM infosys
UNION ALL
SELECT 'TCS', date, open_price, high_price, low_price, close_price,
       no_of_shares, no_of_trades, total_turnover, deliverable_qty, pct_deli_qty FROM tcs
UNION ALL
SELECT 'TVS Motors', date, open_price, high_price, low_price, close_price,
       no_of_shares, no_of_trades, total_turnover, deliverable_qty, pct_deli_qty FROM tvs_motors;

SELECT COUNT(*) AS rows_in_prices FROM prices;

-- Task 1: How much history do we have?
SELECT COUNT(*)  AS trading_days,
       MIN(date) AS first_day,
       MAX(date) AS last_day
FROM bajaj_auto;

-- Task 2: Eicher's five best closes
SELECT date, close_price
FROM eicher_motors
ORDER BY close_price DESC
LIMIT 5;

-- Task 3: TCS average close per year (raw prices)
SELECT strftime('%Y', date) AS year,   -- MySQL: YEAR(date)
       ROUND(AVG(close_price), 2) AS avg_close
FROM tcs
GROUP BY strftime('%Y', date)   -- MySQL: YEAR(date)
ORDER BY year;

-- Task 4: Find the holes (NULL deliverable_qty)
SELECT 'bajaj_auto' AS stock, date FROM bajaj_auto WHERE deliverable_qty IS NULL
UNION ALL
SELECT 'eicher_motors', date FROM eicher_motors WHERE deliverable_qty IS NULL
UNION ALL
SELECT 'hero_motocorp', date FROM hero_motocorp WHERE deliverable_qty IS NULL
UNION ALL
SELECT 'infosys', date FROM infosys WHERE deliverable_qty IS NULL
UNION ALL
SELECT 'tcs', date FROM tcs WHERE deliverable_qty IS NULL
UNION ALL
SELECT 'tvs_motors', date FROM tvs_motors WHERE deliverable_qty IS NULL;

-- Task 5: 20-day and 50-day moving averages for Bajaj
DROP TABLE IF EXISTS bajaj1;
CREATE TABLE bajaj1 AS
SELECT
  date,
  close_price,
  CASE WHEN ROW_NUMBER() OVER (ORDER BY date) >= 20
       THEN ROUND(AVG(close_price) OVER (ORDER BY date ROWS BETWEEN 19 PRECEDING AND CURRENT ROW), 2)
  END AS ma20,
  CASE WHEN ROW_NUMBER() OVER (ORDER BY date) >= 50
       THEN ROUND(AVG(close_price) OVER (ORDER BY date ROWS BETWEEN 49 PRECEDING AND CURRENT ROW), 2)
  END AS ma50
FROM bajaj_auto;

-- Task 6: Master table, one closing-price column per stock
DROP TABLE IF EXISTS master_table;
CREATE TABLE master_table AS
SELECT b.date,
       b.close_price AS bajaj,
       t.close_price AS tcs,
       v.close_price AS tvs,
       i.close_price AS infosys,
       e.close_price AS eicher,
       h.close_price AS hero
FROM bajaj_auto b
JOIN tcs t            ON t.date = b.date
JOIN tvs_motors v     ON v.date = b.date
JOIN infosys i        ON i.date = b.date
JOIN eicher_motors e  ON e.date = b.date
JOIN hero_motocorp h  ON h.date = b.date;

-- Task 7: Buy / Sell / Hold signals for Bajaj
DROP TABLE IF EXISTS bajaj2;
CREATE TABLE bajaj2 AS
WITH t AS (
  SELECT date, close_price, ma20, ma50,
         LAG(ma20) OVER (ORDER BY date) AS prev_ma20,
         LAG(ma50) OVER (ORDER BY date) AS prev_ma50
  FROM bajaj1
)
SELECT date, close_price,
  CASE
    WHEN ma20 IS NULL OR ma50 IS NULL OR prev_ma20 IS NULL OR prev_ma50 IS NULL THEN 'Hold'
    WHEN ma20 > ma50 AND prev_ma20 <= prev_ma50 THEN 'Buy'
    WHEN ma20 < ma50 AND prev_ma20 >= prev_ma50 THEN 'Sell'
    ELSE 'Hold'
  END AS `signal`
FROM t;

-- Task 8: How many days carry each signal?
SELECT `signal`, COUNT(*) AS days
FROM bajaj2
GROUP BY `signal`
ORDER BY `signal`;

-- Task 9: Signal on one date
SELECT `signal` FROM bajaj2 WHERE date = '2018-06-21';

-- Task 10: Signals for all six stocks
DROP TABLE IF EXISTS raw_signals;
CREATE TABLE raw_signals AS
WITH ma AS (
  SELECT stock, date, close_price,
    CASE WHEN ROW_NUMBER() OVER (PARTITION BY stock ORDER BY date) >= 20
         THEN AVG(close_price) OVER (PARTITION BY stock ORDER BY date ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) END AS ma20,
    CASE WHEN ROW_NUMBER() OVER (PARTITION BY stock ORDER BY date) >= 50
         THEN AVG(close_price) OVER (PARTITION BY stock ORDER BY date ROWS BETWEEN 49 PRECEDING AND CURRENT ROW) END AS ma50
  FROM prices
),
lagged AS (
  SELECT *, LAG(ma20) OVER (PARTITION BY stock ORDER BY date) AS prev_ma20,
            LAG(ma50) OVER (PARTITION BY stock ORDER BY date) AS prev_ma50
  FROM ma
)
SELECT stock, date, close_price, ma20, ma50,
  CASE
    WHEN ma20 IS NULL OR ma50 IS NULL OR prev_ma20 IS NULL OR prev_ma50 IS NULL THEN 'Hold'
    WHEN ma20 > ma50 AND prev_ma20 <= prev_ma50 THEN 'Buy'
    WHEN ma20 < ma50 AND prev_ma20 >= prev_ma50 THEN 'Sell'
    ELSE 'Hold'
  END AS `signal`
FROM lagged;

WITH latest AS (
  SELECT stock, date, `signal`,
         ROW_NUMBER() OVER (PARTITION BY stock ORDER BY date DESC) AS rn
  FROM raw_signals WHERE `signal` <> 'Hold'
)
SELECT s.stock,
       SUM(s.`signal` = 'Buy')  AS buys,
       SUM(s.`signal` = 'Sell') AS sells,
       l.date   AS last_signal_date,
       l.`signal` AS last_signal
FROM raw_signals s
JOIN latest l ON l.stock = s.stock AND l.rn = 1
GROUP BY s.stock, l.date, l.`signal`
ORDER BY s.stock;

-- Task 11: First vs last close (raw prices)
WITH ends AS (SELECT stock, MIN(date) AS d0, MAX(date) AS d1 FROM prices GROUP BY stock)
SELECT e.stock,
       a.close_price AS first_close,
       b.close_price AS last_close,
       ROUND(100.0 * (b.close_price - a.close_price) / a.close_price, 1) AS pct_change
FROM ends e
JOIN prices a ON a.stock = e.stock AND a.date = e.d0
JOIN prices b ON b.stock = e.stock AND b.date = e.d1
ORDER BY pct_change DESC;

-- Task 12: Each stock's worst day
WITH m AS (
  SELECT stock, date, close_price,
         100.0 * (close_price / LAG(close_price) OVER (PARTITION BY stock ORDER BY date) - 1) AS pct_move
  FROM prices
),
r AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY stock ORDER BY pct_move) AS rn
  FROM m WHERE pct_move IS NOT NULL
)
SELECT stock, date, close_price, ROUND(pct_move, 1) AS pct_move
FROM r WHERE rn = 1
ORDER BY pct_move;

-- Task 13: Adjust TCS and Infosys for the bonus issues
WITH adjusted AS (
  SELECT 'TCS' AS stock, date,
         CASE WHEN date < '2018-05-31' THEN close_price / 2 ELSE close_price END AS adj_close
  FROM tcs
  UNION ALL
  SELECT 'Infosys', date,
         CASE WHEN date < '2015-06-15' THEN close_price / 2 ELSE close_price END
  FROM infosys
)
SELECT stock,
       ROUND(100.0 * (MAX(CASE WHEN date = '2018-07-31' THEN adj_close END) /
                      MAX(CASE WHEN date = '2015-01-01' THEN adj_close END) - 1), 1) AS adjusted_pct_change
FROM adjusted
GROUP BY stock
ORDER BY stock;

-- =====================================================================
-- PART B: MY ANALYSIS
-- Question: is a 20/50-day golden-cross rule worth trusting, and is the
-- data good enough to say so?
-- =====================================================================

-- B1a: Audit each table
DROP TABLE IF EXISTS audit_summary;
CREATE TABLE audit_summary AS
SELECT stock,
       COUNT(*)                                   AS rows_n,
       COUNT(DISTINCT date)                       AS distinct_dates,
       MIN(date)                                  AS first_day,
       MAX(date)                                  AS last_day,
       SUM(deliverable_qty IS NULL)               AS null_deliverable,
       SUM(no_of_shares = 0)                      AS zero_volume_days,
       SUM(close_price > high_price OR close_price < low_price) AS close_outside_range
FROM prices
GROUP BY stock
ORDER BY stock;

SELECT * FROM audit_summary;

-- B1b: Do all six stocks share the same dates?
SELECT COUNT(*) AS dates_common_to_all_six FROM master_table;

-- B1c: Price-cliff detector (a daily move beyond 20% is suspicious)
DROP TABLE IF EXISTS cliff_flags;
CREATE TABLE cliff_flags AS
WITH m AS (
  SELECT stock, date, close_price,
         LAG(close_price) OVER (PARTITION BY stock ORDER BY date) AS prev_close
  FROM prices
)
SELECT stock, date, prev_close, close_price,
       ROUND(100.0 * (close_price / prev_close - 1), 1) AS pct_move,
       ROUND(prev_close / close_price, 2)               AS implied_ratio
FROM m
WHERE prev_close IS NOT NULL AND ABS(close_price / prev_close - 1) > 0.20
ORDER BY stock, date;

SELECT * FROM cliff_flags;

-- B1d: Trading on a weekend
SELECT date, strftime('%w', date) AS weekday_no   -- MySQL: (DAYOFWEEK(date) - 1)
FROM bajaj_auto
WHERE strftime('%w', date) IN ('0', '6');   -- MySQL: (DAYOFWEEK(date) - 1) IN (0, 6)

-- B2a: Corporate actions found by the detector (price before the date is divided by factor)
DROP TABLE IF EXISTS corporate_actions;
CREATE TABLE corporate_actions (
  stock       VARCHAR(20),
  event_date  DATE,
  event_type  VARCHAR(30),
  factor      DECIMAL(6,2)
);

INSERT INTO corporate_actions VALUES
  ('TCS',     '2018-05-31', '1:1 bonus issue', 2.0),
  ('Infosys', '2015-06-15', '1:1 bonus issue', 2.0);

-- B2b: Adjusted prices and volume
DROP TABLE IF EXISTS adj_prices;
CREATE TABLE adj_prices AS
SELECT p.stock, p.date, p.close_price, p.no_of_shares, p.no_of_trades,
       p.total_turnover, p.deliverable_qty, p.pct_deli_qty,
       CASE WHEN c.factor IS NOT NULL AND p.date < c.event_date
            THEN p.close_price / c.factor ELSE p.close_price END AS adj_close,
       CASE WHEN c.factor IS NOT NULL AND p.date < c.event_date
            THEN p.no_of_shares * c.factor ELSE p.no_of_shares END AS adj_volume,
       ROW_NUMBER() OVER (PARTITION BY p.stock ORDER BY p.date)  AS t
FROM prices p
LEFT JOIN corporate_actions c ON c.stock = p.stock;

-- B2c: Sector of each stock
DROP TABLE IF EXISTS stock_info;
CREATE TABLE stock_info (stock VARCHAR(20), sector VARCHAR(10));

INSERT INTO stock_info VALUES
  ('Bajaj Auto','Auto'), ('Eicher Motors','Auto'), ('Hero Motocorp','Auto'),
  ('TVS Motors','Auto'), ('TCS','IT'), ('Infosys','IT');

-- B2d: Daily returns on adjusted prices
DROP TABLE IF EXISTS daily_returns;
CREATE TABLE daily_returns AS
SELECT stock, date, t, adj_close,
       adj_close / LAG(adj_close) OVER (PARTITION BY stock ORDER BY date) - 1 AS ret
FROM adj_prices;

-- B2e: One column per stock (adjusted prices)
DROP TABLE IF EXISTS master_adjusted;
CREATE TABLE master_adjusted AS
SELECT date,
  MAX(CASE WHEN stock = 'Bajaj Auto'    THEN adj_close END) AS bajaj,
  MAX(CASE WHEN stock = 'TCS'           THEN adj_close END) AS tcs,
  MAX(CASE WHEN stock = 'TVS Motors'    THEN adj_close END) AS tvs,
  MAX(CASE WHEN stock = 'Infosys'       THEN adj_close END) AS infosys,
  MAX(CASE WHEN stock = 'Eicher Motors' THEN adj_close END) AS eicher,
  MAX(CASE WHEN stock = 'Hero Motocorp' THEN adj_close END) AS hero
FROM adj_prices
GROUP BY date;

-- B2f: Same table rebased so every stock starts at 100
DROP TABLE IF EXISTS master_rebased;
CREATE TABLE master_rebased AS
SELECT date,
  ROUND(100.0 * bajaj   / FIRST_VALUE(bajaj)   OVER (ORDER BY date), 2) AS bajaj,
  ROUND(100.0 * tcs     / FIRST_VALUE(tcs)     OVER (ORDER BY date), 2) AS tcs,
  ROUND(100.0 * tvs     / FIRST_VALUE(tvs)     OVER (ORDER BY date), 2) AS tvs,
  ROUND(100.0 * infosys / FIRST_VALUE(infosys) OVER (ORDER BY date), 2) AS infosys,
  ROUND(100.0 * eicher  / FIRST_VALUE(eicher)  OVER (ORDER BY date), 2) AS eicher,
  ROUND(100.0 * hero    / FIRST_VALUE(hero)    OVER (ORDER BY date), 2) AS hero
FROM master_adjusted;

-- B2g: Cliffs left after the fix (expect 0)
SELECT COUNT(*) AS cliffs_left_after_adjustment
FROM daily_returns WHERE ABS(ret) > 0.20;

-- B3a: Performance, raw vs adjusted
DROP TABLE IF EXISTS performance;
CREATE TABLE performance AS
WITH ends AS (
  SELECT stock, MIN(date) AS d0, MAX(date) AS d1, COUNT(*) AS n
  FROM adj_prices GROUP BY stock
)
SELECT e.stock,
       a.close_price AS first_raw_close,
       b.close_price AS last_raw_close,
       ROUND(a.adj_close, 2) AS first_adj_close,
       ROUND(b.adj_close, 2) AS last_adj_close,
       ROUND(100.0 * (b.close_price / a.close_price - 1), 1) AS raw_pct_change,
       ROUND(100.0 * (b.adj_close   / a.adj_close   - 1), 1) AS adj_pct_change,
       ROUND(100.0 * (POWER(b.adj_close / a.adj_close, 252.0 / (e.n - 1)) - 1), 1) AS cagr_pct
FROM ends e
JOIN adj_prices a ON a.stock = e.stock AND a.date = e.d0
JOIN adj_prices b ON b.stock = e.stock AND b.date = e.d1;

SELECT * FROM performance ORDER BY adj_pct_change DESC;

-- B3c: simple benchmark: the average of the six stocks (the data has no market index)
DROP TABLE IF EXISTS benchmark;
CREATE TABLE benchmark AS
SELECT ROUND(AVG(adj_pct_change), 1) AS avg_adj_pct_change,
       ROUND(AVG(cagr_pct), 1)       AS avg_cagr_pct,
       SUM(adj_pct_change > (SELECT AVG(adj_pct_change) FROM performance)) AS stocks_above_average
FROM performance;
SELECT * FROM benchmark;

-- B3b: Return per calendar year
DROP TABLE IF EXISTS yearly_returns;
CREATE TABLE yearly_returns AS
WITH y AS (
  SELECT stock, strftime('%Y', date) AS yr, adj_close,   -- MySQL: YEAR(date)
         ROW_NUMBER() OVER (PARTITION BY stock, strftime('%Y', date) ORDER BY date DESC) AS rn_last,   -- MySQL: YEAR(date)
         ROW_NUMBER() OVER (PARTITION BY stock, strftime('%Y', date) ORDER BY date)      AS rn_first   -- MySQL: YEAR(date)
  FROM adj_prices
),
ye AS (
  SELECT stock, yr,
         MAX(CASE WHEN rn_last  = 1 THEN adj_close END) AS last_c,
         MAX(CASE WHEN rn_first = 1 THEN adj_close END) AS first_c
  FROM y GROUP BY stock, yr
)
SELECT stock, yr,
       ROUND(100.0 * (last_c / COALESCE(LAG(last_c) OVER (PARTITION BY stock ORDER BY yr), first_c) - 1), 1) AS pct_return
FROM ye;

SELECT * FROM yearly_returns ORDER BY stock, yr;

-- B4a: Volatility and best / worst day
DROP TABLE IF EXISTS volatility;
CREATE TABLE volatility AS
SELECT stock,
       COUNT(ret) AS n_returns,
       ROUND(100.0 * AVG(ret), 3) AS avg_daily_pct,
       ROUND(100.0 * SQRT((AVG(ret*ret) - AVG(ret)*AVG(ret)) * COUNT(ret) / (COUNT(ret) - 1)), 3) AS daily_sd_pct,
       ROUND(100.0 * SQRT((AVG(ret*ret) - AVG(ret)*AVG(ret)) * COUNT(ret) / (COUNT(ret) - 1)) * SQRT(252.0), 1) AS annual_vol_pct,
       ROUND(100.0 * MIN(ret), 1) AS worst_day_pct,
       ROUND(100.0 * MAX(ret), 1) AS best_day_pct,
       SUM(ret <= -0.03) AS days_below_minus3,
       SUM(ret >=  0.03) AS days_above_plus3
FROM daily_returns
WHERE ret IS NOT NULL
GROUP BY stock;

SELECT * FROM volatility ORDER BY annual_vol_pct;

-- B4b: Drawdown from the running peak
DROP TABLE IF EXISTS drawdowns;
CREATE TABLE drawdowns AS
SELECT stock, date, adj_close,
       MAX(adj_close) OVER (PARTITION BY stock ORDER BY date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS run_peak
FROM adj_prices;

-- B4c: Maximum drawdown per stock
DROP TABLE IF EXISTS max_drawdown;
CREATE TABLE max_drawdown AS
WITH d AS (
  SELECT stock, date, adj_close, run_peak,
         adj_close / run_peak - 1 AS dd,
         ROW_NUMBER() OVER (PARTITION BY stock ORDER BY adj_close / run_peak) AS rn
  FROM drawdowns
)
SELECT stock,
       ROUND(100.0 * dd, 1) AS max_dd_pct,
       date                 AS trough_date,
       (SELECT MIN(x.date) FROM drawdowns x
         WHERE x.stock = d.stock AND x.adj_close = d.run_peak) AS peak_date
FROM d WHERE rn = 1;

SELECT * FROM max_drawdown ORDER BY max_dd_pct;

-- B4d: Correlation of daily returns
DROP TABLE IF EXISTS correlations;
CREATE TABLE correlations AS
WITH r AS (SELECT stock, date, ret FROM daily_returns WHERE ret IS NOT NULL)
SELECT a.stock AS stock_a, b.stock AS stock_b, COUNT(*) AS n_days,
       ROUND((AVG(a.ret*b.ret) - AVG(a.ret)*AVG(b.ret)) /
             SQRT((AVG(a.ret*a.ret) - AVG(a.ret)*AVG(a.ret)) *
                  (AVG(b.ret*b.ret) - AVG(b.ret)*AVG(b.ret))), 3) AS corr
FROM r a
JOIN r b ON a.date = b.date AND a.stock < b.stock
GROUP BY a.stock, b.stock;

SELECT * FROM correlations ORDER BY corr DESC;

-- B4e: Same-sector vs cross-sector correlation
SELECT CASE WHEN sa.sector <> sb.sector THEN 'across sectors (Auto vs IT)'
            WHEN sa.sector = 'IT' THEN 'same sector: IT'
            ELSE 'same sector: Auto' END AS pair_type,
       COUNT(*) AS pairs,
       ROUND(AVG(c.corr), 3) AS avg_corr
FROM correlations c
JOIN stock_info sa ON sa.stock = c.stock_a
JOIN stock_info sb ON sb.stock = c.stock_b
GROUP BY pair_type
ORDER BY avg_corr DESC;

-- B4f: Average daily move of the six stocks
DROP TABLE IF EXISTS market_returns;
CREATE TABLE market_returns AS
SELECT date, AVG(ret) AS mkt_ret, COUNT(ret) AS n_stocks
FROM daily_returns
WHERE ret IS NOT NULL
GROUP BY date;

SELECT date, ROUND(100.0 * mkt_ret, 2) AS avg_move_pct
FROM market_returns ORDER BY mkt_ret LIMIT 5;

-- B5a: Signals on adjusted prices
DROP TABLE IF EXISTS signals_adj;
CREATE TABLE signals_adj AS
WITH ma AS (
  SELECT stock, date, adj_close, t,
    CASE WHEN t >= 20 THEN AVG(adj_close) OVER (PARTITION BY stock ORDER BY date ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) END AS ma20,
    CASE WHEN t >= 50 THEN AVG(adj_close) OVER (PARTITION BY stock ORDER BY date ROWS BETWEEN 49 PRECEDING AND CURRENT ROW) END AS ma50
  FROM adj_prices
),
lagged AS (
  SELECT *, LAG(ma20) OVER (PARTITION BY stock ORDER BY date) AS prev_ma20,
            LAG(ma50) OVER (PARTITION BY stock ORDER BY date) AS prev_ma50
  FROM ma
)
SELECT stock, date, t, adj_close, ma20, ma50,
  CASE
    WHEN ma20 IS NULL OR ma50 IS NULL OR prev_ma20 IS NULL OR prev_ma50 IS NULL THEN 'Hold'
    WHEN ma20 > ma50 AND prev_ma20 <= prev_ma50 THEN 'Buy'
    WHEN ma20 < ma50 AND prev_ma20 >= prev_ma50 THEN 'Sell'
    ELSE 'Hold'
  END AS `signal`
FROM lagged;

-- B5b: Signal counts, raw vs adjusted
DROP TABLE IF EXISTS signal_counts;
CREATE TABLE signal_counts AS
SELECT r.stock,
       SUM(r.`signal` = 'Buy')  AS raw_buys,
       SUM(r.`signal` = 'Sell') AS raw_sells,
       SUM(a.`signal` = 'Buy')  AS adj_buys,
       SUM(a.`signal` = 'Sell') AS adj_sells,
       SUM(r.`signal` <> a.`signal`) AS days_that_differ
FROM raw_signals r
JOIN signals_adj a ON a.stock = r.stock AND a.date = r.date
GROUP BY r.stock
ORDER BY r.stock;

SELECT * FROM signal_counts;

-- B5c: Days where the price cliff changed the signal
DROP TABLE IF EXISTS signal_diff;
CREATE TABLE signal_diff AS
SELECT r.stock, r.date, r.`signal` AS raw_signal, a.`signal` AS adjusted_signal
FROM raw_signals r
JOIN signals_adj a ON a.stock = r.stock AND a.date = r.date
WHERE r.`signal` <> a.`signal`
ORDER BY r.stock, r.date;

SELECT * FROM signal_diff;

-- B5d: Latest signal per stock
DROP TABLE IF EXISTS latest_signal;
CREATE TABLE latest_signal AS
WITH s AS (
  SELECT stock, date, adj_close, `signal`,
         ROW_NUMBER() OVER (PARTITION BY stock ORDER BY date DESC) AS rn
  FROM signals_adj WHERE `signal` <> 'Hold'
),
z AS (
  SELECT stock, adj_close AS last_close
  FROM (SELECT stock, adj_close, ROW_NUMBER() OVER (PARTITION BY stock ORDER BY date DESC) AS rn FROM signals_adj) q
  WHERE rn = 1
)
SELECT s.stock, s.date AS last_signal_date, s.`signal` AS last_signal,
       ROUND(100.0 * (z.last_close / s.adj_close - 1), 1) AS move_since_signal_pct
FROM s JOIN z ON z.stock = s.stock
WHERE s.rn = 1;

SELECT * FROM latest_signal ORDER BY stock;

-- B6a: What happens after each signal?
DROP TABLE IF EXISTS signal_edge;
CREATE TABLE signal_edge AS
WITH f AS (
  SELECT stock, date, `signal`,
         adj_close / LAG(adj_close, 20)  OVER (PARTITION BY stock ORDER BY date) - 1 AS prev20,
         LEAD(adj_close, 20) OVER (PARTITION BY stock ORDER BY date) / adj_close - 1 AS f20,
         LEAD(adj_close, 60) OVER (PARTITION BY stock ORDER BY date) / adj_close - 1 AS f60
  FROM signals_adj
)
SELECT `signal`,
       COUNT(*)   AS n_days,
       COUNT(f20) AS n_with_20d,
       ROUND(100.0 * AVG(prev20), 2) AS avg_prev_20d_pct,
       ROUND(100.0 * AVG(f20), 2)    AS avg_fwd_20d_pct,
       ROUND(100.0 * SQRT((AVG(f20*f20) - AVG(f20)*AVG(f20)) * COUNT(f20) / (COUNT(f20) - 1)) / SQRT(COUNT(f20)), 2) AS std_error_20d_pct,
       ROUND(100.0 * AVG(CASE WHEN f20 IS NULL THEN NULL WHEN f20 > 0 THEN 1.0 ELSE 0.0 END), 1) AS win_rate_20d_pct,
       ROUND(100.0 * AVG(f60), 2)    AS avg_fwd_60d_pct,
       ROUND(100.0 * AVG(CASE WHEN f60 IS NULL THEN NULL WHEN f60 > 0 THEN 1.0 ELSE 0.0 END), 1) AS win_rate_60d_pct
FROM f
GROUP BY `signal`
ORDER BY `signal`;

SELECT * FROM signal_edge;

-- B6b: Trades (buy on Buy, sell on the next Sell)
DROP TABLE IF EXISTS trades;
CREATE TABLE trades AS
WITH ev AS (
  SELECT stock, date, t, adj_close, `signal`,
         LEAD(date)      OVER (PARTITION BY stock ORDER BY date) AS next_date,
         LEAD(adj_close) OVER (PARTITION BY stock ORDER BY date) AS next_close,
         LEAD(t)         OVER (PARTITION BY stock ORDER BY date) AS next_t
  FROM signals_adj
  WHERE `signal` <> 'Hold'
),
last_row AS (
  SELECT stock, date AS d, adj_close AS c, t AS tt
  FROM (SELECT stock, date, adj_close, t,
               ROW_NUMBER() OVER (PARTITION BY stock ORDER BY date DESC) AS rn
        FROM signals_adj) z
  WHERE rn = 1
)
SELECT e.stock,
       e.date AS entry_date,
       ROUND(e.adj_close, 2) AS entry_price,
       COALESCE(e.next_date, l.d) AS exit_date,
       ROUND(COALESCE(e.next_close, l.c), 2) AS exit_price,
       COALESCE(e.next_t, l.tt) - e.t AS hold_days,
       e.t                        AS entry_t,
       COALESCE(e.next_t, l.tt)   AS exit_t,
       CASE WHEN e.next_date IS NULL THEN 1 ELSE 0 END AS still_open,
       COALESCE(e.next_close, l.c) / e.adj_close - 1 AS trade_ret
FROM ev e
JOIN last_row l ON l.stock = e.stock
WHERE e.`signal` = 'Buy';

SELECT stock, COUNT(*) AS trades FROM trades GROUP BY stock ORDER BY stock;

-- B6c: strategy vs buy-and-hold (cost: 0.1% per side, change it in the settings table)
-- same-window hold = hold from day 51, the first day a signal is possible (a stricter test)
DROP TABLE IF EXISTS settings;
CREATE TABLE settings AS SELECT 0.001 AS cost_per_side;

DROP TABLE IF EXISTS strategy_results;
CREATE TABLE strategy_results AS
WITH cost AS (SELECT cost_per_side AS c FROM settings),
s AS (
  SELECT t.stock,
         COUNT(*) AS n_trades,
         SUM(CASE WHEN t.trade_ret > 0 THEN 1 ELSE 0 END) AS winners,
         AVG(t.trade_ret) AS avg_ret,
         AVG(t.hold_days) AS avg_hold,
         SUM(t.hold_days) AS days_in_market,
         EXP(SUM(LN(1 + t.trade_ret)))                                  AS gross_growth,
         EXP(SUM(LN((1 + t.trade_ret) * (1 - cost.c) * (1 - cost.c)))) AS net_growth
  FROM trades t
  CROSS JOIN cost
  GROUP BY t.stock
),
hold_same AS (
  SELECT a.stock, 100.0 * (b.adj_close / a.adj_close - 1) AS pct
  FROM adj_prices a
  JOIN adj_prices b ON b.stock = a.stock AND b.date = (SELECT MAX(date) FROM adj_prices)
  WHERE a.t = 51
)
SELECT s.stock,
       s.n_trades,
       ROUND(100.0 * s.winners / s.n_trades, 1) AS win_rate_pct,
       ROUND(100.0 * s.avg_ret, 2)              AS avg_trade_pct,
       ROUND(s.avg_hold, 0)                     AS avg_hold_days,
       ROUND(100.0 * s.days_in_market / (SELECT COUNT(*) - 1 FROM adj_prices a WHERE a.stock = s.stock), 0) AS time_in_market_pct,
       ROUND(100.0 * (s.gross_growth - 1), 1)   AS strategy_gross_pct,
       ROUND(100.0 * (s.net_growth   - 1), 1)   AS strategy_net_pct,
       p.adj_pct_change                         AS buy_hold_pct,
       ROUND(100.0 * (s.net_growth - 1) - p.adj_pct_change, 1) AS net_minus_buy_hold,
       ROUND(h.pct, 1)                          AS hold_same_window_pct,
       ROUND(100.0 * (s.net_growth - 1) - h.pct, 1) AS net_minus_same_window
FROM s
JOIN performance p ON p.stock = s.stock
JOIN hold_same h   ON h.stock = s.stock;
SELECT * FROM strategy_results ORDER BY stock;

-- B6d: Do short trades lose? (whipsaws)
DROP TABLE IF EXISTS whipsaw_summary;
CREATE TABLE whipsaw_summary AS
SELECT CASE WHEN hold_days <= 30 THEN '1) up to 30 days'
            WHEN hold_days <= 90 THEN '2) 31-90 days'
            ELSE '3) over 90 days' END AS holding_period,
       COUNT(*) AS n_trades,
       ROUND(100.0 * AVG(trade_ret), 2) AS avg_return_pct,
       ROUND(100.0 * AVG(CASE WHEN trade_ret > 0 THEN 1.0 ELSE 0.0 END), 1) AS win_rate_pct,
       ROUND(100.0 * MIN(trade_ret), 1) AS worst_pct,
       ROUND(100.0 * MAX(trade_ret), 1) AS best_pct
FROM trades
GROUP BY holding_period
ORDER BY holding_period;

SELECT * FROM whipsaw_summary;

-- B6e: Short trades per stock
DROP TABLE IF EXISTS whipsaw_by_stock;
CREATE TABLE whipsaw_by_stock AS
SELECT stock,
       COUNT(*) AS short_trades,
       SUM(CASE WHEN trade_ret > 0 THEN 1 ELSE 0 END) AS winners,
       ROUND(100.0 * AVG(trade_ret), 2) AS avg_return_pct,
       ROUND(100.0 * (EXP(SUM(LN(1 + trade_ret))) - 1), 1) AS compounded_pct
FROM trades
WHERE hold_days <= 30
GROUP BY stock
ORDER BY stock;

SELECT * FROM whipsaw_by_stock;

-- B6f: the rule's daily returns (0 when in cash; the cost is charged on the first and last day of each trade)
DROP TABLE IF EXISTS strategy_daily;
CREATE TABLE strategy_daily AS
SELECT r.stock, r.date, r.t, r.ret AS hold_ret,
       CASE WHEN tr.stock IS NULL THEN 0.0
            ELSE (1 + r.ret)
                 * CASE WHEN r.t = tr.entry_t + 1 THEN 1 - (SELECT cost_per_side FROM settings) ELSE 1 END
                 * CASE WHEN r.t = tr.exit_t      THEN 1 - (SELECT cost_per_side FROM settings) ELSE 1 END
                 - 1
       END AS rule_ret
FROM daily_returns r
LEFT JOIN trades tr ON tr.stock = r.stock AND r.t > tr.entry_t AND r.t <= tr.exit_t
WHERE r.ret IS NOT NULL;

-- B6g: risk of the rule vs holding the stock (same 888 days, the rule is in cash before its first Buy)
DROP TABLE IF EXISTS strategy_risk;
CREATE TABLE strategy_risk AS
WITH curve AS (
  SELECT stock, date, rule_ret,
         EXP(SUM(LN(1 + rule_ret)) OVER (PARTITION BY stock ORDER BY date)) AS equity
  FROM strategy_daily
),
peaks AS (
  SELECT stock, date, equity,
         MAX(equity) OVER (PARTITION BY stock ORDER BY date) AS run_peak
  FROM curve
),
worst AS (
  SELECT stock, MIN(equity / run_peak - 1) AS max_dd FROM peaks GROUP BY stock
),
spread AS (
  SELECT stock,
         COUNT(*) AS n,
         SQRT((AVG(rule_ret*rule_ret) - AVG(rule_ret)*AVG(rule_ret)) * COUNT(*) / (COUNT(*) - 1)) AS sd,
         EXP(SUM(LN(1 + rule_ret))) AS final_growth
  FROM strategy_daily GROUP BY stock
)
SELECT s.stock,
       ROUND(100.0 * s.sd * SQRT(252.0), 1)                            AS rule_vol_pct,
       v.annual_vol_pct                                                AS hold_vol_pct,
       ROUND(100.0 * w.max_dd, 1)                                      AS rule_max_dd_pct,
       d.max_dd_pct                                                    AS hold_max_dd_pct,
       ROUND(100.0 * (POWER(s.final_growth, 252.0 / s.n) - 1), 1)      AS rule_cagr_pct,
       p.cagr_pct                                                      AS hold_cagr_pct,
       ROUND((POWER(s.final_growth, 252.0 / s.n) - 1) / (s.sd * SQRT(252.0)), 2) AS rule_return_per_risk,
       ROUND(p.cagr_pct / v.annual_vol_pct, 2)                         AS hold_return_per_risk
FROM spread s
JOIN worst w       ON w.stock = s.stock
JOIN volatility v  ON v.stock = s.stock
JOIN max_drawdown d ON d.stock = s.stock
JOIN performance p ON p.stock = s.stock;
SELECT * FROM strategy_risk ORDER BY stock;

-- B6h: what if you can only trade at the NEXT day's close after a signal?
DROP TABLE IF EXISTS strategy_next_day;
CREATE TABLE strategy_next_day AS
WITH legs AS (
  SELECT tr.stock,
         a_in.adj_close                                   AS buy_price,
         COALESCE(a_out.adj_close, a_last.adj_close)      AS sell_price
  FROM trades tr
  JOIN adj_prices a_in    ON a_in.stock = tr.stock AND a_in.t = tr.entry_t + 1
  LEFT JOIN adj_prices a_out ON a_out.stock = tr.stock AND a_out.t = tr.exit_t + 1
  JOIN adj_prices a_last  ON a_last.stock = tr.stock AND a_last.date = (SELECT MAX(date) FROM adj_prices)
)
SELECT l.stock,
       COUNT(*) AS n_trades,
       ROUND(100.0 * (EXP(SUM(LN(l.sell_price / l.buy_price * (1 - s.cost_per_side) * (1 - s.cost_per_side)))) - 1), 1) AS next_day_net_pct,
       p.adj_pct_change AS buy_hold_pct
FROM legs l
CROSS JOIN settings s
JOIN performance p ON p.stock = l.stock
GROUP BY l.stock, p.adj_pct_change;
SELECT * FROM strategy_next_day ORDER BY stock;

-- B6i: does Buy beat a normal day in every stock? (average change over the next 20 days)
DROP TABLE IF EXISTS signal_edge_by_stock;
CREATE TABLE signal_edge_by_stock AS
WITH f AS (
  SELECT stock, `signal`,
         LEAD(adj_close, 20) OVER (PARTITION BY stock ORDER BY date) / adj_close - 1 AS f20
  FROM signals_adj
)
SELECT stock,
       SUM(CASE WHEN `signal` = 'Buy' AND f20 IS NOT NULL THEN 1 ELSE 0 END) AS buys_counted,
       ROUND(100.0 * AVG(CASE WHEN `signal` = 'Buy'  THEN f20 END), 2) AS buy_avg_20d_pct,
       ROUND(100.0 * AVG(CASE WHEN `signal` = 'Hold' THEN f20 END), 2) AS hold_avg_20d_pct,
       ROUND(100.0 * AVG(CASE WHEN `signal` = 'Sell' THEN f20 END), 2) AS sell_avg_20d_pct
FROM f
GROUP BY stock
ORDER BY stock;
SELECT * FROM signal_edge_by_stock;

-- B6j: other moving-average windows. The average of the last n days = (running total now - running total n days ago) / n
DROP TABLE IF EXISTS ma_pairs;
CREATE TABLE ma_pairs (short_n INT, long_n INT);
INSERT INTO ma_pairs VALUES (5, 20), (10, 30), (20, 50), (20, 100), (50, 100), (50, 200);

DROP TABLE IF EXISTS price_cum;
CREATE TABLE price_cum AS
SELECT stock, t, adj_close,
       SUM(adj_close) OVER (PARTITION BY stock ORDER BY t) AS cum
FROM adj_prices;

DROP TABLE IF EXISTS pair_signals;
CREATE TABLE pair_signals AS
WITH ma AS (
  SELECT p.short_n, p.long_n, c.stock, c.t, c.adj_close,
         CASE WHEN c.t >= p.short_n THEN (c.cum - COALESCE(s.cum, 0)) / p.short_n END AS ma_short,
         CASE WHEN c.t >= p.long_n  THEN (c.cum - COALESCE(l.cum, 0)) / p.long_n  END AS ma_long
  FROM ma_pairs p
  CROSS JOIN price_cum c
  LEFT JOIN price_cum s ON s.stock = c.stock AND s.t = c.t - p.short_n
  LEFT JOIN price_cum l ON l.stock = c.stock AND l.t = c.t - p.long_n
),
lagged AS (
  SELECT *,
         LAG(ma_short) OVER (PARTITION BY short_n, long_n, stock ORDER BY t) AS prev_short,
         LAG(ma_long)  OVER (PARTITION BY short_n, long_n, stock ORDER BY t) AS prev_long
  FROM ma
)
SELECT short_n, long_n, stock, t, adj_close,
  CASE
    WHEN ma_short IS NULL OR ma_long IS NULL OR prev_short IS NULL OR prev_long IS NULL THEN 'Hold'
    WHEN ma_short > ma_long AND prev_short <= prev_long THEN 'Buy'
    WHEN ma_short < ma_long AND prev_short >= prev_long THEN 'Sell'
    ELSE 'Hold'
  END AS `signal`
FROM lagged;

DROP TABLE IF EXISTS pair_trades;
CREATE TABLE pair_trades AS
WITH ev AS (
  SELECT short_n, long_n, stock, t, adj_close, `signal`,
         LEAD(adj_close) OVER (PARTITION BY short_n, long_n, stock ORDER BY t) AS next_close,
         LEAD(t)         OVER (PARTITION BY short_n, long_n, stock ORDER BY t) AS next_t
  FROM pair_signals
  WHERE `signal` <> 'Hold'
),
last_row AS (
  SELECT stock, t AS last_t, adj_close AS last_close
  FROM adj_prices
  WHERE date = (SELECT MAX(date) FROM adj_prices)
)
SELECT e.short_n, e.long_n, e.stock,
       COALESCE(e.next_t, l.last_t) - e.t AS hold_days,
       COALESCE(e.next_close, l.last_close) / e.adj_close - 1 AS trade_ret
FROM ev e
JOIN last_row l ON l.stock = e.stock
WHERE e.`signal` = 'Buy';

-- one row per window pair and stock; hold starts on the first day that pair can give a signal
DROP TABLE IF EXISTS sensitivity_by_stock;
CREATE TABLE sensitivity_by_stock AS
WITH g AS (
  SELECT short_n, long_n, stock, COUNT(*) AS n_trades, EXP(SUM(LN(1 + trade_ret))) AS gross_growth
  FROM pair_trades
  GROUP BY short_n, long_n, stock
),
hold AS (
  SELECT p.short_n, p.long_n, a.stock, b.adj_close / a.adj_close AS hold_growth
  FROM ma_pairs p
  JOIN adj_prices a ON a.t = p.long_n + 1
  JOIN adj_prices b ON b.stock = a.stock AND b.date = (SELECT MAX(date) FROM adj_prices)
)
SELECT h.short_n, h.long_n, h.stock,
       COALESCE(g.n_trades, 0)       AS n_trades,
       COALESCE(g.gross_growth, 1.0) AS gross_growth,
       h.hold_growth
FROM hold h
LEFT JOIN g ON g.short_n = h.short_n AND g.long_n = h.long_n AND g.stock = h.stock;

-- cost per side: none, 0.1%, 0.3%. Cost multiplies the growth once for every buy and sell.
DROP TABLE IF EXISTS sensitivity;
CREATE TABLE sensitivity AS
SELECT short_n, long_n,
       ROUND(AVG(n_trades), 1) AS avg_trades,
       SUM(gross_growth > hold_growth)                                           AS beats_hold_no_cost,
       SUM(gross_growth * POWER(1 - 0.001, 2 * n_trades) > hold_growth)          AS beats_hold_cost_0_1,
       SUM(gross_growth * POWER(1 - 0.003, 2 * n_trades) > hold_growth)          AS beats_hold_cost_0_3,
       ROUND(100.0 * AVG(gross_growth * POWER(1 - 0.001, 2 * n_trades) - hold_growth), 1) AS avg_gap_points_cost_0_1
FROM sensitivity_by_stock
GROUP BY short_n, long_n
ORDER BY short_n, long_n;
SELECT * FROM sensitivity;

-- B6k: checks (expect 0 and 0): the 20/50 pair and the daily curve must reproduce the main results
SELECT SUM(a.`signal` <> p.`signal`) AS signals_that_differ
FROM signals_adj a
JOIN pair_signals p ON p.short_n = 20 AND p.long_n = 50 AND p.stock = a.stock AND p.t = a.t;

SELECT ROUND(MAX(ABS(100.0 * (g.final_growth - 1) - r.strategy_net_pct)), 1) AS max_gap_vs_strategy_results
FROM (SELECT stock, EXP(SUM(LN(1 + rule_ret))) AS final_growth FROM strategy_daily GROUP BY stock) g
JOIN strategy_results r ON r.stock = g.stock;

-- B7a: Liquidity profile
DROP TABLE IF EXISTS liquidity_profile;
CREATE TABLE liquidity_profile AS
SELECT stock,
       ROUND(AVG(total_turnover) / 10000000.0, 1) AS avg_daily_turnover_crore,
       ROUND(AVG(no_of_trades), 0)                AS avg_daily_trades,
       ROUND(AVG(pct_deli_qty), 1)                AS avg_delivery_pct
FROM adj_prices
GROUP BY stock;

SELECT * FROM liquidity_profile ORDER BY avg_daily_turnover_crore DESC;

-- B7b: Volume spikes
DROP TABLE IF EXISTS volume_spikes;
CREATE TABLE volume_spikes AS
WITH v AS (
  SELECT stock, date, t, adj_close, adj_volume,
         adj_volume / AVG(adj_volume) OVER (PARTITION BY stock ORDER BY date ROWS BETWEEN 20 PRECEDING AND 1 PRECEDING) AS vol_ratio,
         adj_close / LAG(adj_close)  OVER (PARTITION BY stock ORDER BY date) - 1 AS ret_today,
         LEAD(adj_close, 5)  OVER (PARTITION BY stock ORDER BY date) / adj_close - 1 AS fwd5,
         LEAD(adj_close, 10) OVER (PARTITION BY stock ORDER BY date) / adj_close - 1 AS fwd10
  FROM adj_prices
)
SELECT stock, date, ROUND(vol_ratio, 2) AS vol_ratio, ret_today, fwd5, fwd10,
       CASE WHEN vol_ratio >= 2 AND ret_today > 0 THEN 'spike on UP day'
            WHEN vol_ratio >= 2 AND ret_today < 0 THEN 'spike on DOWN day'
            ELSE 'normal volume' END AS day_type
FROM v
WHERE t > 20 AND ret_today IS NOT NULL;

DROP TABLE IF EXISTS spike_summary;
CREATE TABLE spike_summary AS
SELECT day_type,
       COUNT(*) AS n_days,
       ROUND(100.0 * AVG(ret_today), 2) AS avg_same_day_pct,
       ROUND(100.0 * AVG(fwd5), 2)  AS avg_next_5d_pct,
       ROUND(100.0 * AVG(fwd10), 2) AS avg_next_10d_pct,
       ROUND(100.0 * AVG(CASE WHEN fwd5 IS NULL THEN NULL WHEN fwd5 > 0 THEN 1.0 ELSE 0.0 END), 1) AS next_5d_win_pct
FROM volume_spikes
GROUP BY day_type
ORDER BY day_type;

SELECT * FROM spike_summary;

-- B7c: Delivery % buckets
DROP TABLE IF EXISTS delivery_buckets;
CREATE TABLE delivery_buckets AS
WITH q AS (
  SELECT stock, date, pct_deli_qty,
         NTILE(5) OVER (PARTITION BY stock ORDER BY pct_deli_qty) AS bucket
  FROM adj_prices WHERE pct_deli_qty IS NOT NULL
)
SELECT q.bucket,
       COUNT(*) AS n_days,
       ROUND(AVG(q.pct_deli_qty), 1) AS avg_delivery_pct,
       ROUND(100.0 * AVG(ABS(r.ret)), 3) AS avg_abs_move_pct,
       ROUND(100.0 * AVG(r.ret), 3)      AS avg_signed_move_pct
FROM q
JOIN daily_returns r ON r.stock = q.stock AND r.date = q.date
WHERE r.ret IS NOT NULL
GROUP BY q.bucket
ORDER BY q.bucket;

SELECT * FROM delivery_buckets;

-- B8a: Weekday effect
DROP TABLE IF EXISTS weekday_effect;
CREATE TABLE weekday_effect AS
SELECT strftime('%w', date) AS dow,   -- MySQL: (DAYOFWEEK(date) - 1)
       CASE strftime('%w', date) WHEN '1' THEN 'Mon' WHEN '2' THEN 'Tue'   -- MySQL: (DAYOFWEEK(date) - 1) = 1 ... etc.
            WHEN '3' THEN 'Wed' WHEN '4' THEN 'Thu' WHEN '5' THEN 'Fri' END AS weekday,
       COUNT(*) AS n_days,
       ROUND(100.0 * AVG(mkt_ret), 3) AS avg_pct,
       ROUND(100.0 * AVG(CASE WHEN mkt_ret > 0 THEN 1.0 ELSE 0.0 END), 1) AS up_days_pct,
       ROUND(AVG(mkt_ret) / (SQRT((AVG(mkt_ret*mkt_ret) - AVG(mkt_ret)*AVG(mkt_ret)) * COUNT(*) / (COUNT(*) - 1)) / SQRT(COUNT(*))), 2) AS t_stat
FROM market_returns
WHERE strftime('%w', date) BETWEEN '1' AND '5'   -- MySQL: (DAYOFWEEK(date) - 1) BETWEEN 1 AND 5  (skips 2 weekend sessions)
GROUP BY strftime('%w', date)   -- MySQL: (DAYOFWEEK(date) - 1)
ORDER BY dow;

SELECT * FROM weekday_effect;

-- B8b: Month effect
DROP TABLE IF EXISTS month_effect;
CREATE TABLE month_effect AS
SELECT strftime('%m', date) AS mth,   -- MySQL: MONTH(date)
       COUNT(*) AS n_days,
       ROUND(100.0 * AVG(mkt_ret), 3) AS avg_daily_pct,
       ROUND(AVG(mkt_ret) / (SQRT((AVG(mkt_ret*mkt_ret) - AVG(mkt_ret)*AVG(mkt_ret)) * COUNT(*) / (COUNT(*) - 1)) / SQRT(COUNT(*))), 2) AS t_stat
FROM market_returns
GROUP BY strftime('%m', date)   -- MySQL: MONTH(date)
ORDER BY mth;

SELECT * FROM month_effect;

-- B9: Scorecard, one row per stock
DROP TABLE IF EXISTS scorecard;
CREATE TABLE scorecard AS
SELECT p.stock,
       p.adj_pct_change, p.cagr_pct,
       v.annual_vol_pct,
       ROUND(p.cagr_pct / v.annual_vol_pct, 2) AS return_per_risk,
       d.max_dd_pct,
       sc.adj_buys + sc.adj_sells AS signals,
       sr.win_rate_pct, sr.strategy_net_pct, sr.buy_hold_pct, sr.net_minus_buy_hold,
       sr.hold_same_window_pct, sr.net_minus_same_window,
       rk.rule_vol_pct, rk.rule_max_dd_pct,
       ls.last_signal, ls.last_signal_date,
       l.avg_delivery_pct, l.avg_daily_turnover_crore
FROM performance p
JOIN volatility v        ON v.stock  = p.stock
JOIN max_drawdown d      ON d.stock  = p.stock
JOIN signal_counts sc    ON sc.stock = p.stock
JOIN strategy_results sr ON sr.stock = p.stock
JOIN strategy_risk rk    ON rk.stock = p.stock
JOIN latest_signal ls    ON ls.stock = p.stock
JOIN liquidity_profile l ON l.stock  = p.stock;
SELECT * FROM scorecard ORDER BY return_per_risk DESC;


-- =====================================================================
-- PART C: MOVING AVERAGES FOR ALL SIX STOCKS
-- =====================================================================

-- C1: 20, 50 and 200-day averages for every stock
DROP TABLE IF EXISTS ma_all;
CREATE TABLE ma_all AS
SELECT a.stock, a.date, a.t,
       r.close_price,
       a.adj_close,
       r.ma20 AS raw_ma20,
       r.ma50 AS raw_ma50,
       a.ma20,
       a.ma50,
       CASE WHEN a.t >= 200
            THEN AVG(a.adj_close) OVER (PARTITION BY a.stock ORDER BY a.date ROWS BETWEEN 199 PRECEDING AND CURRENT ROW)
       END AS ma200,
       a.`signal`
FROM signals_adj a
JOIN raw_signals r ON r.stock = a.stock AND r.date = a.date;

SELECT stock, COUNT(*) AS rows_n, COUNT(ma20) AS with_ma20, COUNT(ma50) AS with_ma50, COUNT(ma200) AS with_ma200
FROM ma_all GROUP BY stock ORDER BY stock;

-- C2: The Task 5 table for the other five stocks
DROP TABLE IF EXISTS eicher1;
CREATE TABLE eicher1 AS
SELECT date, close_price, ROUND(raw_ma20, 2) AS ma20, ROUND(raw_ma50, 2) AS ma50
FROM ma_all WHERE stock = 'Eicher Motors' ORDER BY date;

DROP TABLE IF EXISTS hero1;
CREATE TABLE hero1 AS
SELECT date, close_price, ROUND(raw_ma20, 2) AS ma20, ROUND(raw_ma50, 2) AS ma50
FROM ma_all WHERE stock = 'Hero Motocorp' ORDER BY date;

DROP TABLE IF EXISTS infosys1;
CREATE TABLE infosys1 AS
SELECT date, close_price, ROUND(raw_ma20, 2) AS ma20, ROUND(raw_ma50, 2) AS ma50
FROM ma_all WHERE stock = 'Infosys' ORDER BY date;

DROP TABLE IF EXISTS tcs1;
CREATE TABLE tcs1 AS
SELECT date, close_price, ROUND(raw_ma20, 2) AS ma20, ROUND(raw_ma50, 2) AS ma50
FROM ma_all WHERE stock = 'TCS' ORDER BY date;

DROP TABLE IF EXISTS tvs1;
CREATE TABLE tvs1 AS
SELECT date, close_price, ROUND(raw_ma20, 2) AS ma20, ROUND(raw_ma50, 2) AS ma50
FROM ma_all WHERE stock = 'TVS Motors' ORDER BY date;

-- C3: Check, ma_all must match Bajaj's Task 5 table (expect 0)
SELECT COUNT(*) AS bajaj_rows_that_differ_from_bajaj1
FROM bajaj1 b
JOIN ma_all m ON m.stock = 'Bajaj Auto' AND m.date = b.date
WHERE COALESCE(ROUND(m.raw_ma20, 2), -1) <> COALESCE(b.ma20, -1)
   OR COALESCE(ROUND(m.raw_ma50, 2), -1) <> COALESCE(b.ma50, -1);

-- C4: Where each stock stands on the last day
DROP TABLE IF EXISTS ma_comparison;
CREATE TABLE ma_comparison AS
WITH last_row AS (
  SELECT stock, date, t, adj_close, ma20, ma50, ma200,
         ROW_NUMBER() OVER (PARTITION BY stock ORDER BY date DESC) AS rn
  FROM ma_all
),
share AS (
  SELECT stock,
         ROUND(100.0 * AVG(CASE WHEN ma50  IS NULL THEN NULL WHEN ma20 > ma50    THEN 1.0 ELSE 0.0 END), 1) AS pct_days_ma20_above_ma50,
         ROUND(100.0 * AVG(CASE WHEN ma50  IS NULL THEN NULL WHEN adj_close > ma50  THEN 1.0 ELSE 0.0 END), 1) AS pct_days_close_above_ma50,
         ROUND(100.0 * AVG(CASE WHEN ma200 IS NULL THEN NULL WHEN adj_close > ma200 THEN 1.0 ELSE 0.0 END), 1) AS pct_days_close_above_ma200
  FROM ma_all
  GROUP BY stock
),
last_cross AS (
  SELECT stock, MAX(t) AS cross_t FROM ma_all WHERE `signal` <> 'Hold' GROUP BY stock
)
SELECT l.stock,
       l.date                                   AS as_of,
       ROUND(l.adj_close, 2)                    AS close_price,
       ROUND(l.ma20, 2)                         AS ma20,
       ROUND(l.ma50, 2)                         AS ma50,
       ROUND(l.ma200, 2)                        AS ma200,
       ROUND(100.0 * (l.adj_close / l.ma20 - 1), 1) AS close_vs_ma20_pct,
       ROUND(100.0 * (l.adj_close / l.ma50 - 1), 1) AS close_vs_ma50_pct,
       ROUND(100.0 * (l.ma20 / l.ma50 - 1), 1)      AS ma20_vs_ma50_pct,
       CASE WHEN l.ma20 > l.ma50 AND l.adj_close > l.ma50 THEN 'Uptrend'
            WHEN l.ma20 < l.ma50 AND l.adj_close < l.ma50 THEN 'Downtrend'
            ELSE 'Mixed' END                    AS trend,
       l.t - c.cross_t                          AS days_since_last_cross,
       s.pct_days_ma20_above_ma50,
       s.pct_days_close_above_ma50,
       s.pct_days_close_above_ma200
FROM last_row l
JOIN share s       ON s.stock = l.stock
JOIN last_cross c  ON c.stock = l.stock
WHERE l.rn = 1;

SELECT * FROM ma_comparison ORDER BY ma20_vs_ma50_pct DESC;

-- C5: Trend breadth
DROP TABLE IF EXISTS trend_breadth;
CREATE TABLE trend_breadth AS
SELECT date,
       SUM(CASE WHEN ma20 > ma50 THEN 1 ELSE 0 END) AS stocks_in_uptrend,
       COUNT(ma50)                                  AS stocks_with_ma50
FROM ma_all
GROUP BY date;

SELECT stocks_in_uptrend, COUNT(*) AS days,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM trend_breadth WHERE stocks_with_ma50 = 6), 1) AS pct_of_days
FROM trend_breadth
WHERE stocks_with_ma50 = 6
GROUP BY stocks_in_uptrend
ORDER BY stocks_in_uptrend;
