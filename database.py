"""Reading data from the SQLite database (read only)."""
import sqlite3
from pathlib import Path

import pandas as pd

from paths import find_file

DATABASE = find_file("stock_market.db") or Path("stock_market.db")
STOCKS = ["Bajaj Auto", "Eicher Motors", "Hero Motocorp", "Infosys", "TCS", "TVS Motors"]


def read_query(sql):
    connection = sqlite3.connect(DATABASE)
    connection.execute("PRAGMA query_only = ON")
    data = pd.read_sql_query(sql, connection)
    connection.close()
    return data


def read_table(name):
    return read_query(f"SELECT * FROM {name}")


def load_moving_averages():
    """One row per stock per day, with raw and adjusted prices, averages and signals."""
    data = read_query("""
        SELECT m.stock, m.date, m.close_price, m.adj_close,
               m.raw_ma20, m.raw_ma50, m.ma20, m.ma50, m.ma200,
               m.`signal` AS adj_signal, r.`signal` AS raw_signal
        FROM ma_all m
        JOIN raw_signals r ON r.stock = m.stock AND r.date = m.date
        ORDER BY m.stock, m.date""")
    data["date"] = pd.to_datetime(data["date"])
    return data


def choose_basis(data, basis):
    """Give the same column names whether the user picks Raw or Adjusted prices."""
    if basis == "Raw":
        return pd.DataFrame({"stock": data.stock, "date": data.date, "price": data.close_price,
                             "ma20": data.raw_ma20, "ma50": data.raw_ma50, "ma200": float("nan"),
                             "signal": data.raw_signal})
    return pd.DataFrame({"stock": data.stock, "date": data.date, "price": data.adj_close,
                         "ma20": data.ma20, "ma50": data.ma50, "ma200": data.ma200,
                         "signal": data.adj_signal})
