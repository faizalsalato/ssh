#!/usr/bin/env python3
"""
Lista todos os arquivos do projeto que contêm referências a github.com
(URLs como https://github.com/..., raw.githubusercontent.com, etc.)
"""

import re
from pathlib import Path

BASE_DIR = Path(__file__).parent.resolve()

IGNORE_DIRS = {".git", "__pycache__", ".venv", "venv", "node_modules"}

BINARY_EXTENSIONS = {
    ".png", ".jpg", ".jpeg", ".gif", ".webp",
    ".zip", ".rar", ".7z", ".tar", ".gz", ".xz",
    ".mp3", ".mp4", ".avi", ".mkv",
    ".pdf", ".so", ".dll", ".exe", ".bin",
    ".pyc", ".o", ".a"
}

# Regex que pega qualquer coisa parecida com domínio github
PATTERN = re.compile(r"[^\s\"'<>]*github(?:usercontent)?\.com[^\s\"'<>]*", re.IGNORECASE)

checked = 0
found_files = 0
total_matches = 0

print("=" * 60)
print("BUSCA POR LINKS DO GITHUB")
print("=" * 60)
print()

for file in BASE_DIR.rglob("*"):
    if not file.is_file():
        continue
    if any(part in IGNORE_DIRS for part in file.parts):
        continue
    if file.suffix.lower() in BINARY_EXTENSIONS:
        continue
    if file.name.endswith(".backup"):
        continue
    if file.name == Path(__file__).name:
        continue

    checked += 1
    try:
        content = file.read_text(encoding="utf-8", errors="ignore")
    except Exception as e:
        print(f"✗ Erro ao ler {file}: {e}")
        continue

    matches = PATTERN.findall(content)
    if matches:
        found_files += 1
        total_matches += len(matches)
        print(f"📄 {file.relative_to(BASE_DIR)}")
        for i, m in enumerate(matches, 1):
            print(f"   {i}. {m}")
        print()

print("=" * 60)
print("RESUMO")
print("=" * 60)
print(f"Arquivos verificados : {checked}")
print(f"Arquivos com links   : {found_files}")
print(f"Total de ocorrências : {total_matches}")
print("=" * 60)
