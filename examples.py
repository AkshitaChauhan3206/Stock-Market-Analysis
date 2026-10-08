"""Example queries (read from the SQL file) and the answer checks for the guide tasks."""
import re

from paths import find_file

SQL_FILE = find_file("stock_analysis.sql")

# a block in the SQL file starts with a line like "-- Task 1: How much history do we have?"
BLOCK_START = re.compile(r"^-- ((?:A0|Task \d+|[BC]\d+[a-z]?): .+)$")


def load_examples():
    """Cut the SQL file into blocks: {title: sql text}. Empty if the file is missing."""
    if SQL_FILE is None:
        return {}
    examples = {}
    title, lines = None, []
    for line in SQL_FILE.read_text(encoding="utf-8").splitlines():
        match = BLOCK_START.match(line)
        if match or line.startswith("-- ====="):
            if title:
                examples[title] = f"-- {title}\n" + "\n".join(lines).strip() + "\n"
            title = match.group(1) if match else None
            lines = []
        elif title:
            lines.append(line)
    if title:
        examples[title] = f"-- {title}\n" + "\n".join(lines).strip() + "\n"
    return examples


def close(a, b):
    return abs(float(a) - float(b)) < 0.011


# one small function per guide task: does the result match the guide's checkpoint?
def task_1(d):
    return tuple(d.iloc[0]) == (889, "2015-01-01", "2018-07-31")


def task_2(d):
    return len(d) == 5 and close(d.iloc[0, 1], 32786.4)


def task_3(d):
    averages = dict(zip(d.iloc[:, 0].astype(str), d.iloc[:, 1]))
    return len(d) == 4 and close(averages["2016"], 2419.00)


def task_4(d):
    return len(d) == 6 and d.iloc[:, 1].nunique() == 2


def task_5(d):
    first = d.dropna(subset=["ma20"]).iloc[0]
    return len(d) == 889 and first["date"] == "2015-01-29" and close(first["ma20"], 2415.53)


def task_6(d):
    return d.shape == (889, 7)


def task_7(d):
    return d.shape == (889, 3)


def task_8(d):
    return dict(zip(d.iloc[:, 0], d.iloc[:, 1])) == {"Buy": 12, "Hold": 866, "Sell": 11}


def task_9(d):
    return d.shape == (1, 1) and d.iloc[0, 0] == "Buy"


def task_10(d):
    return len(d) == 6 and d.iloc[:, 1].sum() == 56 and d.iloc[:, 2].sum() == 57


def task_11(d):
    return len(d) == 6 and d.iloc[0, 0] == "TVS Motors" and close(d.iloc[0, 3], 86.9)


def task_12(d):
    moves = dict(zip(d.iloc[:, 0], d.iloc[:, 3]))
    return len(d) == 6 and close(moves["TCS"], -50.4) and close(moves["Infosys"], -49.9)


def task_13(d):
    changes = dict(zip(d.iloc[:, 0], d.iloc[:, 1]))
    return len(d) == 2 and close(changes["TCS"], 52.4) and close(changes["Infosys"], 38.2)


CHECKS = {
    1: (task_1, "one row: 889 days, 2015-01-01 to 2018-07-31"),
    2: (task_2, "5 rows, highest close 32,786.40"),
    3: (task_3, "4 rows, the 2016 average is 2419.00"),
    4: (task_4, "6 rows on only 2 different dates"),
    5: (task_5, "889 rows, first ma20 on 2015-01-29 is 2415.53"),
    6: (task_6, "889 rows and 7 columns"),
    7: (task_7, "889 rows and 3 columns"),
    8: (task_8, "Buy 12, Hold 866, Sell 11"),
    9: (task_9, "one value: Buy"),
    10: (task_10, "6 rows, 56 Buys and 57 Sells in total"),
    11: (task_11, "TVS Motors first at +86.9%"),
    12: (task_12, "TCS -50.4% and Infosys -49.9%"),
    13: (task_13, "TCS +52.4% and Infosys +38.2%"),
}


def check_answer(title, data):
    """Return (passed, expected text) for a guide task, or None if the task has no checkpoint."""
    match = re.match(r"Task (\d+)", title or "")
    if not match or int(match.group(1)) not in CHECKS:
        return None
    check, expected = CHECKS[int(match.group(1))]
    try:
        return bool(check(data)), expected
    except Exception:
        return False, expected
