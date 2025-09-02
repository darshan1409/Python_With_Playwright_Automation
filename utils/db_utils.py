"""Very simple DB helper functions (SQL Server via pyodbc).

Keep it small & readable: no classes, just functions that take a live
pyodbc connection object.

Example:
    from utils import db_utils as dbu
    rows = dbu.query(conn, "SELECT * FROM Users WHERE Id=?", [1])
    first_name = dbu.scalar(conn, "SELECT TOP 1 FirstName FROM Users")
"""

from typing import Any, Iterable, List, Sequence  # kept only for internal use

try:
    import pyodbc  # type: ignore
except ImportError:  # pragma: no cover
    pyodbc = None  # type: ignore


def execute(conn, sql, params=None):
    """Execute an INSERT / UPDATE / DELETE.

    Parameters:
        conn: Open pyodbc connection.
        sql:  SQL string with optional parameter placeholders (?).
        params: Sequence of parameter values or None.

    Returns:
        int: Number of affected rows.
    """
    with conn.cursor() as cur:
        cur.execute(sql, params or [])
        conn.commit()
        return cur.rowcount


def query(conn, sql, params=None):
    """Run a SELECT returning a list of tuples.

    Returns:
        list[tuple]: All result rows.
    """
    with conn.cursor() as cur:
        cur.execute(sql, params or [])
        return [tuple(r) for r in cur.fetchall()]


def scalar(conn, sql, params=None):
    """Return first column of the first row or None."""
    with conn.cursor() as cur:
        cur.execute(sql, params or [])
        row = cur.fetchone()
        return row[0] if row else None


def query_dicts(conn, sql, params=None):
    """Run SELECT and return list of dict rows: [{column: value}, ...]."""
    with conn.cursor() as cur:
        cur.execute(sql, params or [])
        cols = [c[0] for c in cur.description]
        return [dict(zip(cols, r)) for r in cur.fetchall()]


def bulk_insert(conn, table, columns, rows):
    """Insert multiple rows.

    Parameters:
        conn: Connection.
        table (str): Target table name.
        columns (Sequence[str]): Column names.
        rows (Iterable[Sequence[Any]]): Row value sequences.

    Returns:
        int: Number of inserted rows.
    """
    if not rows:
        return 0
    placeholders = ",".join(["?"] * len(columns))
    col_list = ",".join(columns)
    sql = f"INSERT INTO {table} ({col_list}) VALUES ({placeholders})"
    count = 0
    with conn.cursor() as cur:
        for r in rows:
            cur.execute(sql, r)
            count += 1
        conn.commit()
    return count


__all__ = [
    "execute",
    "query",
    "scalar",
    "query_dicts",
    "bulk_insert",
]
