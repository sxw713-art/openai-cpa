# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Wenfxl Codex Manager** — A Python/FastAPI web app that automates OpenAI account registration, manages a local credential inventory (SQLite), and can push accounts to downstream warehouses (CPA APIs, Sub2API). License: CC BY-NC 4.0 (non-commercial only).

## Commands

**Run locally:**
```bash
pip install -r requirements.txt
python wfxl_openai_regst.py   # Web console at http://127.0.0.1:8000, default password: admin
```

**Docker (recommended):**
```bash
docker compose up -d     # Start (builds from local Dockerfile)
docker compose logs -f   # Tail logs
docker compose down      # Stop
```

**CI/CD:** GitHub Actions builds multi-arch Docker images (`linux/amd64`, `linux/arm64`) on version tags (`v*`) and pushes to Docker Hub as `wenfxl/wenfxl-codex-manager:latest`.

## Architecture

### Entry Point
`wfxl_openai_regst.py` — FastAPI app. Hosts all `/api/*` routes: auth, task control (start/stop), real-time stats, config CRUD, SSE log streaming, account inventory, Cloudflare management, LuckMail console.

### Core Modules (`utils/`)

| Module | Role |
|---|---|
| `core_engine.py` | `RegEngine` orchestrator. Runs 3 modes (see below). Multi-threaded via `ThreadPoolExecutor`. Monkey-patches `builtins.print` to stream logs via SSE. |
| `register.py` | PKCE OAuth2 flow against `auth.openai.com`. Impersonates Chrome via `curl_cffi`. Uses `CLIENT_ID = "app_EMoamEEZ73f0CkXaXp7hrann"`. |
| `config.py` | Loads `data/config.yaml`, deep-merges with `config.example.yaml`. Exposes ~80 module-level globals. Hot-reloaded on each task start. |
| `db_manager.py` | SQLite wrapper (`data/data.db`). Tables: `accounts`, `system_kv`. |
| `mail_service.py` | Routes OTP retrieval to 11+ backends based on `email_api_mode` config. |
| `proxy_manager.py` | Clash/Mihomo proxy rotation via external controller API. |
| `ai_service.py` | Calls a configurable LLM endpoint to generate realistic `firstname.lastname` values. |
| `sub2api_client.py` | Sub2API warehouse integration. |
| `tg_notifier.py` | Telegram bot notifications. |
| `auth_core` (binary) | Closed binary (`.so`/`.pyd` per platform). Generates anti-bot payload for OpenAI registration. The `utils/auth_core/__init__.py` is a Windows stub only; the Dockerfile deletes it so only compiled binaries are used. |

### Three Operating Modes (selected from config flags at task start)
1. **Normal mode** — Registers up to `target_count` accounts, saves to local SQLite.
2. **CPA mode** (`ENABLE_CPA_MODE=true`) — Uploads credentials to a CPA warehouse API, monitors inventory levels.
3. **Sub2API mode** (`ENABLE_SUB2API_MODE=true`) — Same as CPA but uses Sub2API endpoints.

### Frontend
Single-page app served from `index.html` (145 KB, embedded JS). Static assets in `static/`. Communicates with backend via REST + SSE (`/api/logs/stream`).

### Data Persistence
- `data/config.yaml` — Active config (gitignored; auto-generated from `config.example.yaml` on first run).
- `data/data.db` — SQLite credential inventory.
- Both are mounted via Docker volume `./data:/app/data`.

## Key Configuration (`config.example.yaml`)

Important config sections:
- `email_api_mode` — Mailbox backend (`cloudflare_temp_email`, `imap`, `luckmail`, `duckmail`, `GmailOauth`, etc.)
- `clash_proxy_pool` — Clash API URL/secret/group for IP rotation
- `cpa_mode` / `sub2api_mode` — Warehouse API credentials and thresholds
- `enable_multi_thread_reg` / `reg_threads` — Concurrency
- `tg_bot` — Telegram notification bot token + chat ID
- `web_password` — Web console login password

## Python Version Notes
- Docker/Linux/macOS: Python 3.11 (matches compiled `auth_core.cpython-311-*.so`)
- Windows: Python 3.12.6 (uses `auth_core.pyd`)
