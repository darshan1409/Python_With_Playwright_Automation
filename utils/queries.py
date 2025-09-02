"""Load SQL queries from a central JSON file.

Usage:
    from utils.queries import get_query
    sql = get_query("COUNT_USERS")
"""
import json
from pathlib import Path

_QUERIES_PATH = Path(__file__).resolve().parent.parent / "queries.json"
_cache = None


def _load():
    global _cache
    if _cache is None:
        with _QUERIES_PATH.open("r", encoding="utf-8") as fh:
            _cache = json.load(fh)
    return _cache


def get_query(name: str) -> str:
    data = _load()
    if name not in data:
        raise KeyError(f"Query '{name}' not found in queries.json")
    return data[name].strip()
