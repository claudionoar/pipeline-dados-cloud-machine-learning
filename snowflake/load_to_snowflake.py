"""Executa os scripts SQL de snowflake/sql/ contra a conta Snowflake configurada no .env.

Uso:
    python load_to_snowflake.py --steps setup,stage,tables,grants,copy
    python load_to_snowflake.py --steps copy_predictions

Cada `.sql` é tratado como um template: placeholders no formato ${VAR} são substituídos pelas
variáveis de ambiente equivalentes antes da execução.
"""
from __future__ import annotations

import argparse
import os
import re
from pathlib import Path

import snowflake.connector
from dotenv import load_dotenv

load_dotenv()

SQL_DIR = Path(__file__).resolve().parent / "sql"

STEP_FILES = {
    "setup": "00_setup_warehouse_db.sql",
    "stage": "01_create_stage.sql",
    "tables": "02_create_raw_tables.sql",
    "copy": "03_copy_into.sql",
    "grants": "04_grants.sql",
    "copy_predictions": "05_copy_predictions.sql",
}

REQUIRED_ENV = [
    "SNOWFLAKE_ACCOUNT", "SNOWFLAKE_USER", "SNOWFLAKE_PASSWORD", "SNOWFLAKE_ROLE",
    "SNOWFLAKE_WAREHOUSE", "SNOWFLAKE_DATABASE",
]


def _render(sql_text: str) -> str:
    def repl(match: re.Match) -> str:
        var = match.group(1)
        value = os.environ.get(var)
        if value is None:
            raise SystemExit(f"Variável de ambiente ausente para o placeholder ${{{var}}}")
        return value

    return re.sub(r"\$\{(\w+)\}", repl, sql_text)


def _connect():
    missing = [v for v in REQUIRED_ENV if not os.environ.get(v)]
    if missing:
        raise SystemExit(f"Faltam variáveis de ambiente: {', '.join(missing)} (ver .env.example)")
    return snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_USER"],
        password=os.environ["SNOWFLAKE_PASSWORD"],
        role=os.environ["SNOWFLAKE_ROLE"],
        warehouse=os.environ["SNOWFLAKE_WAREHOUSE"],
    )


def _strip_comment_lines(sql_text: str) -> str:
    # Remove linhas de comentario ANTES de dividir por ";" - se so filtrarmos por statement
    # depois do split, um comentario na mesma linha/bloco do primeiro comando real faz o
    # bloco inteiro (comentario + comando) ser descartado, ja que ele COMECA com "--".
    return "\n".join(
        line for line in sql_text.splitlines() if not line.strip().startswith("--")
    )


def run_step(conn, step: str) -> None:
    filename = STEP_FILES[step]
    raw_text = (SQL_DIR / filename).read_text(encoding="utf-8")
    sql_text = _render(_strip_comment_lines(raw_text))
    statements = [s.strip() for s in sql_text.split(";") if s.strip()]
    with conn.cursor() as cur:
        for statement in statements:
            print(f"[{step}] {statement.splitlines()[0][:90]}...")
            cur.execute(statement)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--steps", default="setup,stage,tables,grants,copy",
                         help="Lista separada por vírgula entre: " + ", ".join(STEP_FILES))
    args = parser.parse_args()
    steps = [s.strip() for s in args.steps.split(",") if s.strip()]
    for step in steps:
        if step not in STEP_FILES:
            raise SystemExit(f"Step desconhecido: {step}. Opções: {', '.join(STEP_FILES)}")

    conn = _connect()
    try:
        for step in steps:
            run_step(conn, step)
    finally:
        conn.close()
    print("Concluído.")


if __name__ == "__main__":
    main()
