import os
import pytest
from datetime import datetime

from utils.config import load_config

try:
    from playwright.sync_api import sync_playwright
except ImportError:  # Allow repository before deps installed
    sync_playwright = None  # type: ignore

# Optional DB dependency; placeholder using pyodbc
try:
    import pyodbc  # type: ignore
except ImportError:  # pragma: no cover
    pyodbc = None  # type: ignore


@pytest.fixture(scope="session")
def config():
    return load_config()


@pytest.fixture(scope="session")
def db_connection(config):
    """Create a DB connection (SQL Server via pyodbc)."""
    if pyodbc is None:
        pytest.skip("pyodbc not installed")
    conn_str = (
        f"DRIVER={{ODBC Driver 17 for SQL Server}};SERVER={config['DB_HOST']},{config['DB_PORT']};"
        f"DATABASE={config['DB_NAME']};UID={config['DB_USER']};PWD={config['DB_PASSWORD']};"
        "TrustServerCertificate=yes;"
    )
    conn = pyodbc.connect(conn_str, timeout=10)
    yield conn
    conn.close()




@pytest.fixture(scope="session")
def browser(config):
    if sync_playwright is None:
        pytest.skip("playwright not installed")
    with sync_playwright() as p:
        browser_type = config["BROWSER"]
        pw_browser = getattr(p, browser_type).launch(headless=config["HEADLESS"])
        yield pw_browser
        pw_browser.close()


@pytest.fixture()
def page(browser, config):
    context = browser.new_context(base_url=config["BASE_URL"])
    page = context.new_page()
    # Fail fast if navigation breaks; surfaces real env issues early.
    page.goto(config["BASE_URL"], wait_until="domcontentloaded")
    # Expose config so tests can use page.config when they don't want a separate fixture argument
    page.config = config  # type: ignore[attr-defined]
    yield page
    context.close()


@pytest.hookimpl(hookwrapper=True, tryfirst=True)
def pytest_runtest_makereport(item, call):
    # Execute all other hooks to obtain the report object
    outcome = yield
    rep = outcome.get_result()

    if rep.when == "call" and rep.failed:
        page_fixture = item.funcargs.get("page")
        if page_fixture:
            ts = datetime.utcnow().strftime("%Y%m%d_%H%M%S_%f")
            screenshots_dir = os.path.join("artifacts", "screenshots")
            os.makedirs(screenshots_dir, exist_ok=True)
            file_path = os.path.join(screenshots_dir, f"{item.name}_{ts}.png")
            try:
                page_fixture.screenshot(path=file_path, full_page=True)
                rep.extra = getattr(rep, 'extra', []) + [file_path]
            except Exception:  # pragma: no cover - best effort
                pass
