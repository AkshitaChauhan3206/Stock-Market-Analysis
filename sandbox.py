"""A safe SQL playground: every user gets a private in-memory copy of the database."""
import re
import sqlite3
import time

import pandas as pd

from database import DATABASE

ALLOWED_FIRST_WORDS = {"select", "with", "create", "drop", "insert", "update", "delete",
                       "replace", "alter", "explain", "values"}


def block_dangerous_actions(action, arg1, arg2, db_name, source):
    """SQLite calls this before every action. We refuse ATTACH, DETACH and most PRAGMAs."""
    if action in (sqlite3.SQLITE_ATTACH, sqlite3.SQLITE_DETACH):
        return sqlite3.SQLITE_DENY
    if action == sqlite3.SQLITE_PRAGMA and (arg1 or "").lower() != "table_info":
        return sqlite3.SQLITE_DENY
    return sqlite3.SQLITE_OK


def remove_comments(text):
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    return re.sub(r"--[^\n]*", "", text)


def split_statements(sql):
    """Cut the text into single statements at each ';' (SQLite checks quotes for us)."""
    statements, buffer = [], ""
    for piece in sql.split(";"):
        buffer += piece + ";"
        if sqlite3.complete_statement(buffer):
            if remove_comments(buffer).replace(";", "").strip():
                statements.append(buffer.strip())
            buffer = ""
    leftover = buffer.rstrip(";").strip()
    if remove_comments(leftover).strip():
        statements.append(leftover)
    return statements


def first_word(statement):
    match = re.match(r"[A-Za-z]+", remove_comments(statement).strip())
    return match.group(0).lower() if match else ""


class Sandbox:
    def __init__(self):
        self.reset()

    def reset(self):
        """Copy the real database into memory. The real file is never changed."""
        source = sqlite3.connect(DATABASE)
        self.connection = sqlite3.connect(":memory:", check_same_thread=False)
        source.backup(self.connection)
        source.close()
        self.connection.set_authorizer(block_dangerous_actions)

    def tables(self):
        """Return {table name: [(column, type), ...]} for the schema browser."""
        names = self.connection.execute(
            "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name").fetchall()
        result = {}
        for (name,) in names:
            columns = self.connection.execute(f'PRAGMA table_info("{name}")').fetchall()
            result[name] = [(column[1], column[2]) for column in columns]
        return result

    def run(self, sql, max_seconds=15, max_rows=1000):
        """Run every statement. Returns one result dict per statement."""
        results = []
        statements = split_statements(sql)
        if not statements:
            return [{"kind": "error", "message": "The editor is empty."}]

        for statement in statements:
            word = first_word(statement)
            if word not in ALLOWED_FIRST_WORDS:
                results.append({"kind": "error", "message": f"{word.upper()} is not allowed in the playground."})
                break

            deadline = time.time() + max_seconds
            self.connection.set_progress_handler(lambda: 1 if time.time() > deadline else 0, 20000)
            start = time.time()
            try:
                cursor = self.connection.execute(statement)
                if cursor.description:
                    columns = [column[0] for column in cursor.description]
                    rows = cursor.fetchmany(max_rows + 1)
                    results.append({"kind": "table",
                                    "data": pd.DataFrame(rows[:max_rows], columns=columns),
                                    "cut": len(rows) > max_rows,
                                    "seconds": time.time() - start})
                else:
                    results.append({"kind": "ok", "message": "Done", "seconds": time.time() - start})
                self.connection.commit()
            except sqlite3.Error as error:
                message = str(error)
                if "interrupted" in message:
                    message = f"Stopped: the query ran for more than {max_seconds} seconds."
                results.append({"kind": "error", "message": message})
                self.connection.rollback()
                break
            finally:
                self.connection.set_progress_handler(None, 0)
        return results
