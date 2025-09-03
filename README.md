## Python + Playwright + SQL Server Test Automation Framework

Lightweight Pytest-based UI & DB automation scaffold using Playwright (sync API) and `pyodbc` for SQL Server. Designed to be simple, explicit, and easy to extend.

---
## ✨ Key Features
- Single `config.yaml` for DEV / QA / PROD (UI + DB credentials)
- Runtime overrides via CLI args or environment variables
- Playwright fixtures (browser + page) with automatic navigation to `BASE_URL`
- DB connection fixture (SQL Server / ODBC Driver 17) + tiny helper functions (`utils/db_utils.py`)
- Centralized SQL in `queries.json` with cached loader (`utils/queries.py`)
- Screenshot capture on UI test failure (`artifacts/screenshots/`)
- UI, DB, and integration test examples

---
## 🗂 Directory Structure
```
config.yaml                 # Multi-environment config (UI + DB)
conftest.py                 # Pytest fixtures & screenshot hook
queries.json                # Named SQL snippets
pages/                      # Page Object classes (Base + concrete pages)
  base_page.py              # Common helpers (navigation, waits, basic actions)
  home_page.py              # Sample Home page object
locators/                   # Selector groupings (data-test attributes preferred)
  home_locators.py          # Home page selectors
utils/
  config.py                 # Config loader (CLI/env/YAML precedence)
  db_utils.py               # DB helper functions (execute/query/scalar/...)
  queries.py                # Cached JSON query loader
  common_utils.py           # Reusable composite waits & helpers
tests/
  test_open_homepage.py     # UI smoke test
  test_db_basic.py          # DB tests (count/sample)
  test_ui_db_integration.py # UI ↔ DB consistency example
  test_login_flow.py        # Example using shared login fixture
artifacts/screenshots/      # Created at runtime on failures
pytest.ini                  # Pytest opts + marker registration
README.md                   # This file
```

---
## 🧱 Page Object Model (POM)
This scaffold supports (optional) Page Objects for clearer, reusable UI flows. It stays intentionally slim so you can evolve complexity only when needed.

### Structure
- `pages/` holds Python classes representing screens or logical areas.
- `locators/` holds selector groupings to keep raw selectors separate from interaction logic.

### Principles
- Keep methods task-focused (e.g., `login_as(user)`), returning `self` or another page object for chaining.
- Avoid duplicating low-level Playwright calls across tests; elevate them into page methods when reused ≥2 times.
- Prefer stable selectors: custom `data-test` / `data-testid` attributes over brittle CSS hierarchies.

### Base Page Helpers
`BasePage` implements minimal helpers (`goto`, `fill`, `click`, `text_of`, `expect_visible`, `wait_network_idle`). Extend only when duplication appears.

### Example Usage
```python
from pages.home_page import HomePage

def test_home_user_display(page):
  home = HomePage(page)
  name = home.displayed_user_full_name()
  # Skip or assert as needed depending on environment readiness
  assert name is not None, "Expected a user name on the home page"
```

### Adding a New Page
1. Create locators in `locators/<feature>_locators.py`.
2. Create `pages/<feature>_page.py` inheriting `BasePage`.
3. Expose clear action methods (e.g., `submit_form`, `filter_results`).
4. Use in tests by passing the `page` fixture to the constructor.

---
## 🔐 Login Fixture
A reusable login flow is provided in `utils/login_fixture.py` exposing:
- `login_to_application(page, config)`: function to perform login.
- `login` pytest fixture: yields an authenticated `page`.

### Example Test
```python
import pytest

@pytest.mark.ui
def test_dashboard_shows_user(login):  # 'login' is an already authenticated page
  page = login
  assert page.url  # add real assertions, e.g., user menu visible
```

---
## 🚀 Prerequisites
1. **Python**: 3.10+ (3.11 recommended)
2. **Drivers / System** (SQL Server):
   - Install Microsoft ODBC Driver 17 (or newer) for SQL Server (Windows):
     https://learn.microsoft.com/sql/connect/odbc/windows/release-notes-odbc-sql-server
3. **Node dependencies for browsers (managed by Playwright)** will be installed via `playwright install`.

---
## 📦 Installation
In the project root:

PowerShell:
```
python -m venv .venv
./.venv/Scripts/Activate.ps1
pip install --upgrade pip
pip install pytest playwright pyodbc pyyaml
python -m playwright install  # installs browsers
```

Optional (record video / traces if you enable those later):
```
python -m playwright install-deps
```

---
## ⚙️ Configuration (`config.yaml`)
Example (excerpt):
```yaml
DEFAULT_ENV: QA
ENVIRONMENTS:
  QA:
    UI:
      BASE_URL: "https://demoqa.com/"
      HEADLESS: false
      BROWSER: "firefox"
    DB:
      HOST: "qa-db.example.com"
      PORT: 1433
      DATABASE: "QaAppDB"
      USER: "qa_db_user"
      PASSWORD: "QA_DB_PASSWORD_PLACEHOLDER"
```

### Precedence (highest → lowest)
1. CLI argument (`--base_url`, `--env`, `--db_host`, etc.)
2. Environment variable (`BASE_URL`, `ENV`, `DB_HOST`, ...)
3. YAML value in chosen environment block

### Selecting Environment
Any of these:
```
pytest --env QA
ENV=QA pytest
```

### Overriding Values Inline
```
pytest --env QA --base_url https://internal.qa/ --browser chromium --headless true
```

Environment variable example (PowerShell):
```
$env:BASE_URL='https://internal.qa/'; pytest
```

---
## 🧪 Running Tests
All tests (quiet mode from `pytest.ini`):
```
pytest
```

Only UI tests:
```
pytest -m ui
```

Only DB tests:
```
pytest -m db
```

Integration (UI+DB) tests:
```
pytest -m integration
```

Fail-fast + verbose:
```
pytest -x -vv
```

Specify environment + overrides:
```
pytest -m ui --env DEV --browser webkit --headless true
```

---
## 🖥 Playwright Behavior
- The `page` fixture automatically navigates to `BASE_URL`.
- Access config inside a test without extra fixture arg: `page.config["BASE_URL"]`.
- Browser type & headless mode come from config overrides.

---
## 🗃 Database Utilities
Located in `utils/db_utils.py` (all require an active `db_connection` fixture):

| Function | Purpose | Return |
|----------|---------|--------|
| `execute(conn, sql, params=None)` | DML (INSERT/UPDATE/DELETE) | affected row count |
| `query(conn, sql, params=None)` | SELECT rows | list[tuple] |
| `scalar(conn, sql, params=None)` | First column/row | value or None |
| `query_dicts(conn, sql, params=None)` | SELECT rows w/ column names | list[dict] |
| `bulk_insert(conn, table, columns, rows)` | Multi-row insert | inserted count |

### Example
```python
from utils import db_utils as dbu
from utils.queries import get_query

def test_user_count(db_connection):
    count = dbu.scalar(db_connection, get_query("COUNT_USERS"))
    assert count >= 0
```

---
## 📄 Managing SQL (`queries.json`)
Add or modify named queries:
```json
{
  "COUNT_USERS": "SELECT COUNT(*) FROM Users;",
  "USER_BY_ID": "SELECT Id, FirstName, LastName FROM Users WHERE Id = ?;"
}
```
Use in tests:
```python
from utils.queries import get_query
sql = get_query("USER_BY_ID")
rows = dbu.query(db_connection, sql, [123])
```

---
## 🖼 Screenshots
On UI test failure a PNG is saved to `artifacts/screenshots/` with timestamp + test name. Commit the folder (empty) or let it be created at runtime.

---
## 🧩 Adding New Tests
1. Create a file under `tests/` (`test_*.py`).
2. Mark tests as needed: `@pytest.mark.ui`, `@pytest.mark.db`, `@pytest.mark.integration`.
3. Use fixtures: `page`, `db_connection`, or `config`.

Example UI form test skeleton:
```python
import pytest

@pytest.mark.ui
def test_login_form(page):
    page.fill("#username", "user1")
    page.fill("#password", "secret")
    page.click("button[type=submit]")
    page.wait_for_load_state("networkidle")
    assert page.locator("text=Welcome").first.is_visible()
```

---
## 🔐 Secrets Handling
Avoid committing real passwords. Store secure secrets in CI secret stores or provide via environment variables / pipeline variables. YAML can keep placeholders.

---
## 🛠 Troubleshooting
| Issue | Cause | Fix |
|-------|-------|-----|
| Unknown pytest marker warnings | Marker not declared | Ensure `pytest.ini` lists the marker |
| `pyodbc` ImportError | Driver / package missing | `pip install pyodbc` + install ODBC Driver 17 |
| Timeout navigating to base URL | Wrong `BASE_URL` / network | Override `--base_url` or verify connectivity |
| Empty screenshots folder | No UI test failures | Force a failure to verify hook |
| Cannot connect to DB | Firewall / host / creds | Test with a manual script; validate port 1433 open |

---
## ➕ Extending
- Add page object helpers (optional) under `pages/` and call them from tests.
- Introduce a custom marker for long-running suites (e.g., `slow`).
- Add retry logic via Playwright Trace or Pytest `--reruns` (plugin) if needed.

---
## ✅ Quality Tips
- Keep tests independent; rely on existing seed data or create/cleanup test data within the test.
- Prefer querying only necessary columns for performance.
- Use explicit waits (`locator.wait_for()`) instead of sleeps.

---
## 🧪 Marker Matrix
| Marker | Meaning |
|--------|---------|
| `ui` | Browser-based tests |
| `db` | Direct DB validations |
| `integration` | Combined UI ↔ DB flow |

Run combined selection: `pytest -m "ui and db"` (intersection) or `pytest -m "ui or db"`.

---
## 📤 CI Hints
- Cache Playwright browsers between runs (`playwright install --with-deps` in a setup stage).
- Export screenshots & any future traces as build artifacts.
- Pass secrets via environment variables and not committed YAML.

---
## 🤝 License / Usage
Internal scaffold; adapt freely for your project needs.

---
## 🧾 Change Log (Initial)
- v0.1: Base scaffold, config loader, fixtures, DB utils, sample tests.

---
## 🙋 Support
Raise improvements you want (page objects, parallel shards, reporting) and extend from this baseline.
