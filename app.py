"""Streamlit app: compare moving averages of six stocks and practise SQL in a playground."""
import pandas as pd
import streamlit as st

import charts
import database
from examples import check_answer, load_examples
from sandbox import Sandbox

st.set_page_config(page_title="NSE stock analysis", layout="wide")

if not database.DATABASE.exists():
    st.error("The database file stock_market.db was not found in this repository. "
             "Upload the 'data' folder with stock_market.db inside it to GitHub, then reboot the app.")
    st.stop()


@st.cache_data
def get_moving_averages():
    return database.load_moving_averages()


@st.cache_data
def get_table(name):
    return database.read_table(name)


# ---------------------------------------------------------------- sidebar
def sidebar_controls(all_data):
    """Choices shared by all tabs. Returns the filtered data and the choices."""
    with st.sidebar:
        st.header("Controls")
        basis = st.radio("Price basis", ["Adjusted", "Raw"],
                         help="Adjusted fixes the TCS and Infosys bonus-issue price drops.")
        stocks = st.multiselect("Stocks", database.STOCKS, default=database.STOCKS) or database.STOCKS
        windows = st.multiselect("Moving averages", [20, 50, 200], default=[20, 50])
        show_signals = st.checkbox("Show Buy / Sell markers", value=True)
        first_day, last_day = all_data["date"].min().date(), all_data["date"].max().date()
        start, end = st.slider("Date range", min_value=first_day, max_value=last_day, value=(first_day, last_day))

    series = database.choose_basis(all_data, basis)
    series = series[(series["date"] >= pd.Timestamp(start)) & (series["date"] <= pd.Timestamp(end))]
    return series, basis, stocks, windows, show_signals


# ---------------------------------------------------------------- tab 1
def tab_compare(series, basis, stocks, windows, show_signals):
    summary = get_table("ma_comparison")
    trends = dict(zip(summary["stock"], summary["trend"]))

    st.subheader("Where does each stock stand today?")
    st.caption("Uptrend: 20-day above 50-day and price above 50-day. Downtrend: both below. Otherwise Mixed.")
    st.dataframe(summary[summary["stock"].isin(stocks)].sort_values("ma20_vs_ma50_pct", ascending=False))

    st.subheader("All stocks side by side")
    st.pyplot(charts.small_charts(series, stocks, windows, show_signals, trends if basis == "Adjusted" else None))

    st.subheader("Compare on one scale")
    metric = st.radio("Metric", charts.METRICS, horizontal=True)
    window = 50
    if metric == charts.METRICS[2]:
        window = st.selectbox("Which average", [20, 50], index=1)
    st.pyplot(charts.compare_chart(series, stocks, metric, window))

    st.subheader("How many of the six stocks are in an up-regime?")
    st.pyplot(charts.breadth_chart(get_table("trend_breadth")))


# ---------------------------------------------------------------- tab 2
def tab_one_stock(series, windows, show_signals):
    stock = st.selectbox("Stock", database.STOCKS, index=database.STOCKS.index("TCS"))
    st.pyplot(charts.price_chart(series, stock, windows, show_signals))

    data = series[series["stock"] == stock].copy()
    data["date"] = data["date"].dt.strftime("%Y-%m-%d")
    left, right = st.columns(2)
    left.markdown("**Latest 15 days**")
    left.dataframe(data.tail(15)[["date", "price", "ma20", "ma50", "ma200", "signal"]].round(2))
    right.markdown("**All Buy / Sell signals**")
    right.dataframe(data[data["signal"] != "Hold"][["date", "price", "signal"]].round(2))


# ---------------------------------------------------------------- tab 3
def tab_signals():
    st.subheader("Signal counts: raw prices vs adjusted prices")
    st.dataframe(get_table("signal_counts"))
    st.markdown("**Days where the bonus-issue price drop changed the signal**")
    st.dataframe(get_table("signal_diff"))

    st.subheader("Golden-cross strategy vs buy-and-hold")
    results = get_table("strategy_results")
    st.pyplot(charts.strategy_chart(results))
    st.dataframe(results)

    st.subheader("Risk: was the rule calmer than holding?")
    st.caption("Same 888 days. The rule sits in cash before its first Buy and between a Sell and the next Buy.")
    st.dataframe(get_table("strategy_risk"))

    st.subheader("Is the result robust? Three stress tests")
    st.markdown("**1. Trade one day later** (buy and sell at the next day's close, not the signal day's close)")
    st.dataframe(get_table("strategy_next_day"))
    st.markdown("**2. Other moving-average windows and trading costs** "
                "(how many of the 6 stocks the rule beat, when holding starts on the first day the rule could trade)")
    st.dataframe(get_table("sensitivity"))
    st.markdown("**3. Does a Buy beat a normal day in each stock?** (average change over the next 20 days)")
    st.dataframe(get_table("signal_edge_by_stock"))

    st.subheader("All trades")
    trades = get_table("trades")
    stock = st.selectbox("Stock", ["All"] + database.STOCKS, key="trade_stock")
    if stock != "All":
        trades = trades[trades["stock"] == stock]
    trades = trades.assign(return_pct=(trades["trade_ret"] * 100).round(1)).drop(columns=["trade_ret"])
    st.dataframe(trades)


# ---------------------------------------------------------------- tab 4
BLANK = "(blank editor)"
examples = load_examples()


def fill_editor_with_example():
    """Runs when a new example is picked in the drop-down."""
    title = st.session_state["example"]
    if title in examples:
        st.session_state["sql_text"] = examples[title]


def show_results(packet):
    last_table = None
    for number, result in enumerate(packet["results"], start=1):
        if result["kind"] == "error":
            st.error(f"Statement {number}: {result['message']}")
        elif result["kind"] == "ok":
            st.success(f"Statement {number}: {result['message']}")
        else:
            last_table = result["data"]
            st.markdown(f"**Statement {number}:** {len(last_table)} rows")
            st.dataframe(last_table)

    if last_table is None:
        return
    st.download_button("Download last result (CSV)", last_table.to_csv(index=False).encode("utf-8"),
                       file_name="result.csv", mime="text/csv")

    verdict = check_answer(packet["example"], last_table)
    if verdict is not None:
        passed, expected = verdict
        if passed:
            st.success(f"Matches the guide checkpoint: {expected}")
        else:
            st.warning(f"Does not match the checkpoint. Expected: {expected}")


def tab_playground():
    st.subheader("SQL playground")
    st.caption("You work on a private copy of the database. Create, change or drop anything: "
               "the real data is safe, and 'Reset database' brings everything back.")

    if "sandbox" not in st.session_state:
        st.session_state["sandbox"] = Sandbox()
        st.session_state["sql_text"] = "SELECT stock, date, close_price\nFROM prices\nWHERE date = '2018-07-31';"
        st.session_state["packet"] = None
    sandbox = st.session_state["sandbox"]

    if not examples:
        st.info("The example list is empty because stock_analysis.sql was not found in the repository. "
                "Upload the 'sql' folder to GitHub to turn the examples on. You can still type your own SQL.")

    left, right = st.columns([1, 3])

    with left:
        tables = sandbox.tables()
        name = st.selectbox("Browse a table", list(tables))
        st.dataframe(pd.DataFrame(tables[name], columns=["column", "type"]))
        if st.button("Preview 5 rows"):
            st.session_state["packet"] = {"example": None, "results": sandbox.run(f'SELECT * FROM "{name}" LIMIT 5')}

    with right:
        st.selectbox("Load an example", [BLANK] + list(examples), key="example", on_change=fill_editor_with_example)
        sql = st.text_area("SQL", key="sql_text", height=280)

        run_clicked, reset_clicked, _ = st.columns([1, 1, 4])
        if run_clicked.button("Run query"):
            title = st.session_state["example"]
            same_as_example = title in examples and sql.strip() == examples[title].strip()
            st.session_state["packet"] = {"example": title if same_as_example else None,
                                          "results": sandbox.run(sql)}
        if reset_clicked.button("Reset database"):
            sandbox.reset()
            st.session_state["packet"] = None

        if st.session_state["packet"]:
            show_results(st.session_state["packet"])


# ---------------------------------------------------------------- tab 5
def tab_insights():
    st.subheader("Scorecard")
    st.dataframe(get_table("scorecard"))
    st.markdown("""
**Main findings** (the PDF report has the full details)

- TCS and Infosys fall about 50% in one day because of bonus issues, not real losses.
- Today TCS and Infosys are in an uptrend. Hero, Eicher and TVS are in a downtrend. Bajaj Auto is mixed.
- In the base case the golden-cross rule earned less than buy-and-hold on all six stocks. If trades happen one day later, TVS Motors edges ahead of holding, so the result is not completely firm.
- The rule was calmer (lower volatility on all six) but not always safer: its worst fall was smaller for only 3 of 6 stocks.
- Other windows and costs did not change the answer: only very slow averages (50/200) matched buy-and-hold, because they trade rarely.
- Short trades (30 days or less) mostly lost money.
- Volume, delivery % and weekday or month patterns gave no reliable edge.
""")


# ---------------------------------------------------------------- page
st.title("NSE stock analysis: moving averages and SQL playground")
st.caption("Bajaj Auto, Eicher Motors, Hero Motocorp, TVS Motors, TCS, Infosys | Jan 2015 to Jul 2018")

moving_averages = get_moving_averages()
series, basis, stocks, windows, show_signals = sidebar_controls(moving_averages)

tab1, tab2, tab3, tab4, tab5 = st.tabs(
    ["Compare moving averages", "One stock", "Signals and backtest", "SQL playground", "Insights"])
with tab1:
    tab_compare(series, basis, stocks, windows, show_signals)
with tab2:
    tab_one_stock(series, windows, show_signals)
with tab3:
    tab_signals()
with tab4:
    tab_playground()
with tab5:
    tab_insights()
