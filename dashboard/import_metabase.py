"""
Reimporta o dashboard e cards do Metabase a partir dos JSONs exportados.

Uso:
    python import_metabase.py

Pré-requisitos:
    1. Metabase rodando em http://localhost:3000
    2. Setup inicial concluído (admin criado)
    3. Banco Snowflake já conectado no Metabase

O script recria todos os cards e o dashboard com o layout e filtro global
originais, conectando-os ao primeiro banco Snowflake encontrado na instância.
"""
import requests
import json
import sys
from pathlib import Path

BASE_URL = "http://localhost:3000/api"
EXPORT_DIR = Path(__file__).resolve().parent / "metabase_export"

# --- Autenticação ---
print("Autenticando no Metabase...")
session = requests.post(f"{BASE_URL}/session", json={
    "username": "admin@example.com",
    "password": "Admin123456!"
})
if session.status_code != 200:
    print(f"Erro de autenticação: {session.status_code}")
    print("Verifique se o Metabase está rodando e as credenciais estão corretas.")
    sys.exit(1)

TOKEN = session.json()["id"]
HEADERS = {"X-Metabase-Session": TOKEN, "Content-Type": "application/json"}

# --- Descobrir o database_id do Snowflake ---
print("Procurando banco Snowflake conectado...")
dbs = requests.get(f"{BASE_URL}/database", headers=HEADERS).json()
snowflake_db_id = None
for db in dbs.get("data", []):
    if db.get("engine") == "snowflake":
        snowflake_db_id = db["id"]
        print(f"  Encontrado: '{db['name']}' (id={db['id']})")
        break

if snowflake_db_id is None:
    print("ERRO: Nenhum banco Snowflake encontrado. Conecte o Snowflake primeiro.")
    sys.exit(1)

# --- Carregar JSONs exportados ---
print("Carregando JSONs exportados...")
with open(EXPORT_DIR / "cards.json", encoding="utf-8") as f:
    cards_data = json.load(f)
with open(EXPORT_DIR / "dashboard.json", encoding="utf-8") as f:
    dash_data = json.load(f)

print(f"  {len(cards_data)} cards, dashboard: '{dash_data['name']}'")

# --- Criar os cards ---
old_to_new_card_id = {}
for card in cards_data:
    # Atualizar o database_id para o atual
    card["dataset_query"]["database"] = snowflake_db_id
    
    payload = {
        "name": card["name"],
        "display": card["display"],
        "dataset_query": card["dataset_query"],
        "visualization_settings": card.get("visualization_settings", {}),
        "description": card.get("description"),
        "collection_id": None
    }
    
    resp = requests.post(f"{BASE_URL}/card", headers=HEADERS, json=payload)
    if resp.status_code in (200, 202):
        new_id = resp.json()["id"]
        old_to_new_card_id[card["id"]] = new_id
        print(f"  Card criado: '{card['name']}' (old={card['id']} -> new={new_id})")
    else:
        print(f"  ERRO ao criar '{card['name']}': {resp.status_code} {resp.text[:200]}")

# --- Criar o dashboard ---
print(f"\nCriando dashboard '{dash_data['name']}'...")
dash_resp = requests.post(f"{BASE_URL}/dashboard", headers=HEADERS, json={
    "name": dash_data["name"],
    "description": dash_data.get("description"),
    "parameters": dash_data.get("parameters", [])
})

if dash_resp.status_code not in (200, 202):
    print(f"ERRO ao criar dashboard: {dash_resp.status_code} {dash_resp.text[:200]}")
    sys.exit(1)

new_dash_id = dash_resp.json()["id"]
print(f"  Dashboard criado (id={new_dash_id})")

# --- Montar os dashcards com IDs atualizados ---
dashcards = []
for i, dc in enumerate(dash_data["dashcards"]):
    old_card_id = dc["card_id"]
    new_card_id = old_to_new_card_id.get(old_card_id)
    if new_card_id is None:
        print(f"  AVISO: card_id {old_card_id} não foi reimportado, pulando...")
        continue
    
    # Atualizar os parameter_mappings com o novo card_id
    param_mappings = []
    for pm in dc.get("parameter_mappings", []):
        pm_copy = dict(pm)
        pm_copy["card_id"] = new_card_id
        param_mappings.append(pm_copy)
    
    dashcards.append({
        "id": -(i + 1),  # IDs negativos para novos dashcards
        "card_id": new_card_id,
        "row": dc["row"],
        "col": dc["col"],
        "size_x": dc["size_x"],
        "size_y": dc["size_y"],
        "parameter_mappings": param_mappings,
        "visualization_settings": dc.get("visualization_settings", {})
    })

# --- Atualizar o dashboard com os dashcards ---
put_resp = requests.put(f"{BASE_URL}/dashboard/{new_dash_id}", headers=HEADERS, json={
    "dashcards": dashcards,
    "parameters": dash_data.get("parameters", [])
})

if put_resp.status_code == 200:
    print(f"\nDashboard importado com sucesso!")
    print(f"Acesse: http://localhost:3000/dashboard/{new_dash_id}")
else:
    print(f"ERRO ao atualizar dashboard: {put_resp.status_code} {put_resp.text[:300]}")

print("\nConcluído!")
