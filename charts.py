"""All charts. Figure() is used instead of pyplot because it is safe inside Streamlit."""
import math

import matplotlib.dates as mdates
from matplotlib.figure import Figure

COLORS = {"Bajaj Auto": "#1F3A5F", "Eicher Motors": "#2A9D8F", "Hero Motocorp": "#9B8AC4",
          "TVS Motors": "#E9873A", "TCS": "#D1495B", "Infosys": "#4F8FD6"}
AVERAGE_COLORS = {20: "#E9873A", 50: "#1F3A5F", 200: "#7C3AED"}
METRICS = ["Price vs its 50-day average (%)", "20-day vs 50-day gap (%)", "Moving average, rebased to 100"]


def tidy(ax):
    """Light grid, no top/right lines, readable dates."""
    ax.grid(True, color="#E5E7EB", linewidth=0.6)
    ax.set_axisbelow(True)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    locator = mdates.AutoDateLocator()
    ax.xaxis.set_major_locator(locator)
    ax.xaxis.set_major_formatter(mdates.ConciseDateFormatter(locator))
    ax.tick_params(labelsize=8)


def draw_stock(ax, data, windows, show_signals, marker_size):
    """Price line, chosen moving averages, and Buy / Sell triangles."""
    ax.plot(data["date"], data["price"], color="#9CA3AF", linewidth=1, label="Close")
    for window in windows:
        column = f"ma{window}"
        if data[column].notna().any():
            ax.plot(data["date"], data[column], color=AVERAGE_COLORS[window], linewidth=1.2,
                    label=f"{window}-day average")
    if show_signals:
        for signal, shape, color in (("Buy", "^", "#2A9D8F"), ("Sell", "v", "#D1495B")):
            points = data[data["signal"] == signal]
            if len(points):
                ax.scatter(points["date"], points["price"], marker=shape, color=color, s=marker_size,
                           zorder=5, edgecolor="white", label=signal)


def price_chart(series, stock, windows, show_signals):
    """One big chart for one stock."""
    figure = Figure(figsize=(10, 4.2))
    ax = figure.subplots()
    draw_stock(ax, series[series["stock"] == stock], windows, show_signals, marker_size=70)
    ax.set_title(f"{stock}: close and moving averages", loc="left", fontsize=10, fontweight="bold")
    ax.set_ylabel("Rs per share")
    ax.legend(frameon=False, fontsize=8, ncol=6, loc="upper left")
    tidy(ax)
    figure.tight_layout()
    return figure


def small_charts(series, stocks, windows, show_signals, trends=None):
    """A grid of small charts, one per stock."""
    columns = min(3, len(stocks))
    rows = math.ceil(len(stocks) / columns)
    figure = Figure(figsize=(4.4 * columns, 2.9 * rows))
    axes = figure.subplots(rows, columns, squeeze=False).flatten()
    for ax, stock in zip(axes, stocks):
        draw_stock(ax, series[series["stock"] == stock], windows, show_signals, marker_size=22)
        title = f"{stock}  [{trends[stock]}]" if trends and stock in trends else stock
        ax.set_title(title, loc="left", fontsize=9, fontweight="bold")
        tidy(ax)
    for ax in axes[len(stocks):]:
        ax.axis("off")
    axes[0].legend(frameon=False, fontsize=6.5, loc="upper left", ncol=2)
    figure.tight_layout()
    return figure


def compare_chart(series, stocks, metric, window=50):
    """All chosen stocks on one chart, using one of the three metrics."""
    figure = Figure(figsize=(10, 3.8))
    ax = figure.subplots()
    for stock in stocks:
        data = series[series["stock"] == stock]
        if metric == METRICS[0]:
            line = (data["price"] / data["ma50"] - 1) * 100
        elif metric == METRICS[1]:
            line = (data["ma20"] / data["ma50"] - 1) * 100
        else:
            line = data[f"ma{window}"] / data["price"].iloc[0] * 100
        ax.plot(data["date"], line, color=COLORS[stock], linewidth=1.2, label=stock)
    ax.axhline(100 if metric == METRICS[2] else 0, color="black", linewidth=0.7)
    ax.set_ylabel(metric)
    ax.legend(frameon=False, fontsize=8, ncol=6, loc="upper left")
    tidy(ax)
    figure.tight_layout()
    return figure


def breadth_chart(breadth):
    """How many of the six stocks have the 20-day average above the 50-day average."""
    data = breadth[breadth["stocks_with_ma50"] == 6].copy()
    data["date"] = data["date"].astype("datetime64[ns]")
    figure = Figure(figsize=(10, 2.6))
    ax = figure.subplots()
    ax.fill_between(data["date"], data["stocks_in_uptrend"], step="post", color="#4F8FD6", alpha=0.35)
    ax.step(data["date"], data["stocks_in_uptrend"], where="post", color="#1F3A5F", linewidth=1)
    ax.set_ylim(0, 6.3)
    ax.set_ylabel("stocks with 20d > 50d")
    tidy(ax)
    figure.tight_layout()
    return figure


def strategy_chart(results):
    """Strategy return next to buy-and-hold return for each stock."""
    results = results.sort_values("buy_hold_pct", ascending=False).reset_index(drop=True)
    figure = Figure(figsize=(10, 3.4))
    ax = figure.subplots()
    width = 0.38
    positions = list(range(len(results)))
    hold = ax.bar([p - width / 2 for p in positions], results["buy_hold_pct"], width, color="#1F3A5F", label="Buy and hold")
    rule = ax.bar([p + width / 2 for p in positions], results["strategy_net_pct"], width, color="#E9873A",
                  label="Golden-cross strategy (after costs)")
    for bars in (hold, rule):
        for bar in bars:
            height = bar.get_height()
            ax.text(bar.get_x() + bar.get_width() / 2, height + (2 if height >= 0 else -7),
                    f"{height:+.1f}%", ha="center", fontsize=7.5)
    ax.axhline(0, color="black", linewidth=0.7)
    ax.set_xticks(positions)
    ax.set_xticklabels(results["stock"], fontsize=8)
    ax.set_ylabel("Total return (%)")
    ax.legend(frameon=False, fontsize=8)
    ax.grid(True, axis="y", color="#E5E7EB", linewidth=0.6)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    figure.tight_layout()
    return figure
