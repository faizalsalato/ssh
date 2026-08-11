#!/usr/bin/env python3

"""
Substitui automaticamente URLs e variáveis de repositório nos scripts.

Uso:
    python addurl.py

Exemplo:
    Substitui "faizalsalato/ssh" -> "seu_user/seu_repo"
    e atualiza todas as referências nos arquivos .sh, .py, .conf, etc.

Ignora:
    - .git
    - node_modules
    - arquivos binários
    - backups
"""

from pathlib import Path
import sys

BASE_DIR = Path(__file__).parent.resolve()

# ============================================================
# CONFIGURAÇÃO: edite abaixo para substituir pelas suas URLs
# ============================================================
REPLACEMENTS = {
    # Repositório antigo                 -> Repositório novo
    "faizalsalato/ssh/":                "faizalsalato/ssh/",
    "faizalsalato/ssh":                 "faizalsalato/ssh",
    "raw.githubusercontent.com/faizalsalato/ssh": "raw.githubusercontent.com/faizalsalato/ssh",
    # Emails e domínios (todos devem usar blaylook)
    "blaylooks@gmail.com":              "blaylooks@gmail.com",
    "nekopoi.care":                     "blaylook.com",
    "mantapxsl.my.id":                  "blaylook.com",
    "nevermoressh.my.id":               "blaylook.com",
    "nevermoressh.tech":                "blaylook.com",
    # Marcas
    "NevermoreSSH":                     "blaylook",
    "ROTATEEL SSH":                     "blaylook",
    "ROTATEEL":                         "blaylook",
    "Freedom Internet":                 "blaylook Internet",
}

IGNORE_DIRS = {
    ".git",
    "__pycache__",
    ".venv",
    "venv",
    "node_modules",
    "backup",
}

BINARY_EXTENSIONS = {
    ".png", ".jpg", ".jpeg", ".gif", ".webp",
    ".zip", ".rar", ".7z", ".tar", ".gz", ".xz",
    ".mp3", ".mp4", ".avi", ".mkv",
    ".pdf", ".so", ".dll", ".exe", ".bin",
    ".pyc", ".o", ".a",
}

checked = 0
modified = 0

print("=" * 60)
print("ALTERAÇÃO AUTOMÁTICA DO PROJETO")
print("=" * 60)
print()

for file in BASE_DIR.rglob("*"):
    if not file.is_file():
        continue
    if any(part in IGNORE_DIRS for part in file.parts):
        continue
    if file.suffix.lower() in BINARY_EXTENSIONS:
        continue
    if file.name.endswith(".backup") or file.name.endswith(".bkp"):
        continue
    if file.name == "addurl.py":
        continue

    checked += 1
    try:
        content = file.read_text(encoding="utf-8", errors="ignore")
        original = content
        for old, new in REPLACEMENTS.items():
            content = content.replace(old, new)
        if content != original:
            file.write_text(content, encoding="utf-8")
            modified += 1
            print(f"  [OK] {file.relative_to(BASE_DIR)}")
    except Exception as e:
        print(f"  [ERRO] {file}: {e}")

print()
print("=" * 60)
print("RESUMO")
print("=" * 60)
print(f"  Arquivos verificados : {checked}")
print(f"  Arquivos modificados : {modified}")
print("=" * 60)

if modified == 0:
    print()
    print("AVISO: Nenhum arquivo foi modificado!")
    print("Edite o dicionário REPLACEMENTS em addurl.py com")
    print("suas próprias URLs antes de executar novamente.")
    print()
    print("Exemplo:")
    print('  "faizalsalato/ssh" -> "seu_usuario/seu_repo"')

