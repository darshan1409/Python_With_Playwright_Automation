import os
import yaml
import argparse

_CONFIG_CACHE = None  # simple cache so file only parsed once
_CONFIG_PATH = "config.yaml"


def _load_yaml():
    with open(_CONFIG_PATH, "r", encoding="utf-8") as fh:
        return yaml.safe_load(fh)


def _parse_args():
    """Parse only known args (safe when pytest injects many)."""
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--env", type=str, help="Environment: DEV|QA|PROD")
    parser.add_argument("--base_url")
    parser.add_argument("--useremail")
    parser.add_argument("--password")
    parser.add_argument("--headless")  # true/false
    parser.add_argument("--browser")
    parser.add_argument("--trace")
    # DB overrides
    parser.add_argument("--db_host")
    parser.add_argument("--db_port")
    parser.add_argument("--db_name")
    parser.add_argument("--db_user")
    parser.add_argument("--db_password")
    parser.add_argument("--db_trust_cert")  # true/false
    args, _ = parser.parse_known_args()
    return args


def _get_base_config():
    global _CONFIG_CACHE
    if _CONFIG_CACHE is None:
        _CONFIG_CACHE = _load_yaml()
    return _CONFIG_CACHE


def get_env():
    data = _get_base_config()
    args = _parse_args()
    return (args.env or os.getenv("ENV") or data.get("DEFAULT_ENV") or "QA").upper()


def _value_from_sources(env: str, key: str, arg_name: str, section: str = "UI"):
    args = _parse_args()
    # 1 CLI, 2 ENV var, 3 YAML (UI section)
    cli_val = getattr(args, arg_name, None)
    if cli_val is not None:
        return cli_val
    env_val = os.getenv(key.upper())
    if env_val is not None:
        return env_val
    data = _get_base_config()
    return data["ENVIRONMENTS"][env][section][key]


def load_config(env: str | None = None):
    env = env.upper() if env else get_env()
    data = _get_base_config()
    if env not in data["ENVIRONMENTS"]:
        raise ValueError(f"Invalid environment: {env}")

    # Gather UI values
    base_url = _value_from_sources(env, "BASE_URL", "base_url")
    useremail = _value_from_sources(env, "USEREMAIL", "useremail")
    password = _value_from_sources(env, "PASSWORD", "password")
    headless_raw = _value_from_sources(env, "HEADLESS", "headless")
    browser = _value_from_sources(env, "BROWSER", "browser").lower()
    trace = _value_from_sources(env, "TRACE", "trace") if "TRACE" in data["ENVIRONMENTS"][env]["UI"] else None

    # Gather DB values
    db_host = _value_from_sources(env, "HOST", "db_host", section="DB")
    db_port_raw = _value_from_sources(env, "PORT", "db_port", section="DB")
    db_name = _value_from_sources(env, "DATABASE", "db_name", section="DB")
    db_user = _value_from_sources(env, "USER", "db_user", section="DB")
    db_password = _value_from_sources(env, "PASSWORD", "db_password", section="DB")
    trust_cert_raw = _value_from_sources(env, "TRUST_CERT", "db_trust_cert", section="DB")

    # Coerce headless (YAML bool or string override)
    if isinstance(headless_raw, bool):
        headless = headless_raw
    else:
        headless = str(headless_raw).lower() in {"true", "1", "yes", "on"}

    # Coerce DB types
    try:
        db_port = int(db_port_raw)
    except (TypeError, ValueError):
        db_port = 1433
    if isinstance(trust_cert_raw, bool):
        trust_cert = trust_cert_raw
    else:
        trust_cert = str(trust_cert_raw).lower() in {"true", "1", "yes", "on"}

    return {
        "ENV": env,
        # UI
        "BASE_URL": base_url,
        "USEREMAIL": useremail,
        "PASSWORD": password,
        "HEADLESS": headless,
        "BROWSER": browser,
        "TRACE": trace,
        # DB
        "DB_HOST": db_host,
        "DB_PORT": db_port,
        "DB_NAME": db_name,
        "DB_USER": db_user,
        "DB_PASSWORD": db_password,
        "DB_TRUST_CERT": trust_cert,
    }


if __name__ == "__main__":  # quick manual test
    print(load_config())
