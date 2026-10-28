# Workflow & Tool Execution Rules

## 1. Automatic Skill Discovery & Usage
- Whenever a task matches any available skill in `.agents/skills/` (such as `brainstorming`), you **MUST** automatically read and strictly follow the respective `SKILL.md` before proceeding with the implementation or design.
- Check workspace skills (`.agents/skills/*`) dynamically and load required workflows proactively without waiting for explicit prompt triggers.

## 2. Command Execution with `rtk` Prefix
- Semua eksekusi perintah shell / terminal via `run_command` harus selalu menggunakan prefix `rtk` (misal: `rtk <command> ...`), kecuali jika user secara eksplisit meminta bypass dengan `rtk bypass <cmd>`.
- Format eksekusi standar:
  - `rtk git ...`
  - `rtk flutter ...`
  - `rtk dart ...`
  - `rtk codegraph ...`

## 3. CodeGraph Synchronization Before Search
- Sebelum melakukan pencarian kode, navigasi dependensi, atau query graph menggunakan CodeGraph, **WAJIB** menjalankan sinkronisasi terlebih dahulu:
  ```bash
  rtk codegraph sync
  ```
  *(atau `rtk codegraph index` / `rtk codegraph update` sesuai perintah CLI codegraph yang aktif)*
- Pastikan status sinkronisasi CodeGraph up-to-date terhadap perubahan file terbaru sebelum menjalankan `rtk codegraph search` atau inspect graph kode.
