"""
Provisiona o Metabase do zero: cria o admin, conecta o Snowflake e importa o
dashboard/cards a partir dos JSONs versionados em metabase_export/.

Uso:
    python setup_metabase.py

Roda automaticamente como serviço `metabase-setup` no `docker compose up` (ver
docker-compose.yml). Também pode ser executado manualmente contra qualquer
instância do Metabase, desde que METABASE_URL e as demais variáveis de
ambiente estejam definidas (lidas do .env na raiz do projeto).

Idempotente sem duplicar: reaproveita o admin (login) e a conexão Snowflake se já
existirem. O dashboard/cards, porém, são sempre ressincronizados com o conteúdo atual de
cards.json/dashboard.json — se já existirem, a versão antiga é arquivada e recriada, para
que edições nesses JSONs se reflitam no Metabase a cada execução.
"""
from __future__ import annotations

import os
import re
import sys
import time
from pathlib import Path

import requests
from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parents[1] / ".env")

EXPORT_DIR = Path(__file__).resolve().parent / "metabase_export"
BASE_URL = os.environ.get("METABASE_URL", "http://localhost:3000/api")

ADMIN_EMAIL = os.environ.get("METABASE_ADMIN_EMAIL", "admin@example.com")
ADMIN_PASSWORD = os.environ.get("METABASE_ADMIN_PASSWORD", "Admin123456!")
ADMIN_FIRSTNAME = os.environ.get("METABASE_ADMIN_FIRSTNAME", "Admin")
ADMIN_LASTNAME = os.environ.get("METABASE_ADMIN_LASTNAME", "User")
SITE_NAME = os.environ.get("METABASE_SITE_NAME", "Olist")

REQUIRED_SNOWFLAKE_ENV = [
    "SNOWFLAKE_ACCOUNT", "SNOWFLAKE_USER", "SNOWFLAKE_PASSWORD",
    "SNOWFLAKE_ROLE", "SNOWFLAKE_WAREHOUSE", "SNOWFLAKE_DATABASE",
]

def _render(value):
    """Substitui placeholders ${VAR} por variáveis de ambiente, recursivamente."""
    if isinstance(value, dict):
        return {k: _render(v) for k, v in value.items()}
    if isinstance(value, str):
        def repl(match: re.Match) -> str:
            var = match.group(1)
            env_value = os.environ.get(var)
            if env_value is None:
                raise SystemExit(f"Variável de ambiente ausente para o placeholder ${{{var}}}")
            return env_value
        return re.sub(r"\$\{(\w+)\}", repl, value)
    return value


def wait_for_metabase(timeout_s: int = 180) -> None:
    print(f"Aguardando Metabase ficar disponível em {BASE_URL}...")
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        try:
            resp = requests.get(f"{BASE_URL}/health", timeout=5)
            if resp.status_code == 200:
                print("  Metabase disponível.")
                return
        except requests.exceptions.RequestException:
            pass
        time.sleep(3)
    raise SystemExit(f"Metabase não respondeu em {timeout_s}s.")


def get_setup_token() -> str | None:
    resp = requests.get(f"{BASE_URL}/session/properties", timeout=10)
    resp.raise_for_status()
    return resp.json().get("setup-token")


def build_database_payload() -> dict:
    import json
    with open(EXPORT_DIR / "database_connection.json", encoding="utf-8") as f:
        db_conf = json.load(f)
    missing = [v for v in REQUIRED_SNOWFLAKE_ENV if not os.environ.get(v)]
    if missing:
        raise SystemExit(f"Faltam variáveis de ambiente: {', '.join(missing)} (ver .env.example)")
    payload = _render(db_conf)
    payload["details"]["password"] = os.environ["SNOWFLAKE_PASSWORD"]
    return payload


def try_initial_setup(setup_token: str) -> str | None:
    """Tenta criar o usuário admin. Retorna o session token em caso de sucesso, ou None
    se o Metabase informar que já existe um usuário (setup já foi concluído antes, ex.:
    manualmente pela UI) — nesse caso o chamador deve cair para login(). O
    /api/session/properties pode continuar devolvendo um setup-token não-nulo mesmo
    depois do setup já ter sido concluído, então esse fallback é necessário mesmo quando
    get_setup_token() indica token presente.

    A conexão Snowflake NÃO é criada aqui: o campo "database" do /api/setup não a criou de
    fato nos testes contra o Metabase v0.50 (fica só o "Sample Database" H2 padrão) — quem
    garante a conexão é sempre ensure_database(), chamado depois em main() para os dois
    fluxos (setup novo ou login em instância existente).
    """
    print("Criando usuário admin no Metabase...")
    resp = requests.post(f"{BASE_URL}/setup", json={
        "token": setup_token,
        "user": {
            "first_name": ADMIN_FIRSTNAME,
            "last_name": ADMIN_LASTNAME,
            "email": ADMIN_EMAIL,
            "password": ADMIN_PASSWORD,
        },
        "prefs": {"site_name": SITE_NAME, "allow_tracking": False},
    }, timeout=60)
    if resp.status_code == 403 and "currently exists" in resp.text:
        print("  Setup já havia sido concluído antes, autenticando em vez de recriar...")
        return None
    if resp.status_code != 200:
        raise SystemExit(f"ERRO no setup inicial: {resp.status_code} {resp.text[:300]}")
    print(f"  Admin '{ADMIN_EMAIL}' criado.")
    return resp.json()["id"]


def login() -> str:
    print(f"Metabase já configurado, autenticando como '{ADMIN_EMAIL}'...")
    resp = requests.post(f"{BASE_URL}/session", json={
        "username": ADMIN_EMAIL,
        "password": ADMIN_PASSWORD,
    }, timeout=30)
    if resp.status_code != 200:
        raise SystemExit(
            f"Erro de autenticação: {resp.status_code}. "
            "Verifique METABASE_ADMIN_EMAIL/METABASE_ADMIN_PASSWORD no .env."
        )
    return resp.json()["id"]


def get_personal_collection_id(headers: dict) -> int:
    resp = requests.get(f"{BASE_URL}/user/current", headers=headers, timeout=10)
    resp.raise_for_status()
    return resp.json()["personal_collection_id"]


def ensure_database(headers: dict) -> int:
    with open(EXPORT_DIR / "database_connection.json", encoding="utf-8") as f:
        import json
        db_name = json.load(f)["name"]

    dbs = requests.get(f"{BASE_URL}/database", headers=headers, timeout=30).json()
    for db in dbs.get("data", []):
        if db.get("name") == db_name and db.get("engine") == "snowflake":
            print(f"Conexão Snowflake '{db_name}' já existe (id={db['id']}), reaproveitando.")
            return db["id"]

    print(f"Criando conexão Snowflake '{db_name}'...")
    payload = build_database_payload()
    resp = requests.post(f"{BASE_URL}/database", headers=headers, json=payload, timeout=60)
    if resp.status_code not in (200, 202):
        raise SystemExit(f"ERRO ao criar conexão Snowflake: {resp.status_code} {resp.text[:300]}")
    db_id = resp.json()["id"]
    print(f"  Conexão criada (id={db_id}). Aguardando sincronização inicial do schema...")
    time.sleep(10)
    return db_id


def import_dashboard(headers: dict, snowflake_db_id: int, collection_id: int) -> None:
    import json
    with open(EXPORT_DIR / "cards.json", encoding="utf-8") as f:
        cards_data = json.load(f)
    with open(EXPORT_DIR / "dashboard.json", encoding="utf-8") as f:
        dash_data = json.load(f)

    existing = requests.get(f"{BASE_URL}/dashboard", headers=headers, timeout=30).json()
    for dash in existing:
        if dash.get("name") == dash_data["name"]:
            print(f"Dashboard '{dash_data['name']}' já existe (id={dash['id']}), arquivando para recriar "
                  "a partir dos JSONs atuais (garante que edições em cards.json/dashboard.json sejam aplicadas)...")
            full_dash = requests.get(f"{BASE_URL}/dashboard/{dash['id']}", headers=headers, timeout=30).json()
            for dc in full_dash.get("dashcards", []):
                card_id = dc.get("card_id")
                if card_id:
                    requests.put(f"{BASE_URL}/card/{card_id}", headers=headers,
                                 json={"archived": True}, timeout=30)
            requests.put(f"{BASE_URL}/dashboard/{dash['id']}", headers=headers,
                         json={"archived": True}, timeout=30)
            break

    print(f"Importando {len(cards_data)} cards e dashboard '{dash_data['name']}'...")

    old_to_new_card_id = {}
    for card in cards_data:
        card["dataset_query"]["database"] = snowflake_db_id
        payload = {
            "name": card["name"],
            "display": card["display"],
            "dataset_query": card["dataset_query"],
            "visualization_settings": card.get("visualization_settings", {}),
            "description": card.get("description"),
            "collection_id": collection_id,
        }
        resp = requests.post(f"{BASE_URL}/card", headers=headers, json=payload, timeout=30)
        if resp.status_code in (200, 202):
            new_id = resp.json()["id"]
            old_to_new_card_id[card["id"]] = new_id
            print(f"  Card criado: '{card['name']}' (old={card['id']} -> new={new_id})")
        else:
            print(f"  ERRO ao criar '{card['name']}': {resp.status_code} {resp.text[:200]}")

    dash_resp = requests.post(f"{BASE_URL}/dashboard", headers=headers, json={
        "name": dash_data["name"],
        "description": dash_data.get("description"),
        "parameters": dash_data.get("parameters", []),
        "collection_id": collection_id,
    }, timeout=30)
    if dash_resp.status_code not in (200, 202):
        raise SystemExit(f"ERRO ao criar dashboard: {dash_resp.status_code} {dash_resp.text[:300]}")
    new_dash_id = dash_resp.json()["id"]
    print(f"  Dashboard criado (id={new_dash_id})")

    dashcards = []
    for i, dc in enumerate(dash_data["dashcards"]):
        new_card_id = old_to_new_card_id.get(dc["card_id"])
        if new_card_id is None:
            print(f"  AVISO: card_id {dc['card_id']} não foi reimportado, pulando...")
            continue
        param_mappings = []
        for pm in dc.get("parameter_mappings", []):
            pm_copy = dict(pm)
            pm_copy["card_id"] = new_card_id
            param_mappings.append(pm_copy)
        dashcards.append({
            "id": -(i + 1),
            "card_id": new_card_id,
            "row": dc["row"],
            "col": dc["col"],
            "size_x": dc["size_x"],
            "size_y": dc["size_y"],
            "parameter_mappings": param_mappings,
            "visualization_settings": dc.get("visualization_settings", {}),
        })

    put_resp = requests.put(f"{BASE_URL}/dashboard/{new_dash_id}", headers=headers, json={
        "dashcards": dashcards,
        "parameters": dash_data.get("parameters", []),
    }, timeout=30)
    if put_resp.status_code == 200:
        print(f"Dashboard importado com sucesso! Acesse: {BASE_URL.replace('/api', '')}/dashboard/{new_dash_id}")
    else:
        raise SystemExit(f"ERRO ao atualizar dashboard: {put_resp.status_code} {put_resp.text[:300]}")


def main() -> None:
    wait_for_metabase()

    setup_token = get_setup_token()
    session_token = try_initial_setup(setup_token) if setup_token else None
    if session_token is None:
        session_token = login()

    headers = {"X-Metabase-Session": session_token, "Content-Type": "application/json"}
    collection_id = get_personal_collection_id(headers)
    snowflake_db_id = ensure_database(headers)
    import_dashboard(headers, snowflake_db_id, collection_id)
    print("\nConcluído!")


if __name__ == "__main__":
    main()
