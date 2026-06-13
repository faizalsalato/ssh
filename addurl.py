#!/usr/bin/env python3

"""
Substitui automaticamente:

* faizalsalato/ssh -> faizalsalato/ssh
* Variáveis akbarvpn -> nomes reais dos serviços

Funciona em:

* Arquivos com extensão
* Arquivos sem extensão
* Scripts .sh, .py, .conf, .service, etc.

Ignora:

* .git
* arquivos binários
* backups
  """

from pathlib import Path

BASE_DIR = Path(__file__).parent.resolve()

REPLACEMENTS = {
# Repositório antigo -> novo
"faizalsalato/ssh/": "faizalsalato/ssh/",
"faizalsalato/ssh": "faizalsalato/ssh",


# Variáveis
"ssh_repo=": 'ssh_repo=',
"sstp_repo=": 'sstp_repo=',
"ssr_repo=": 'ssr_repo=',
"shadowsocks_repo=": 'shadowsocks_repo=',
"wireguard_repo=": 'wireguard_repo=',
"xray_repo=": 'xray_repo=',
"ipsec_repo=": 'ipsec_repo=',
"backup_repo=": 'backup_repo=',
"websocket_repo=": 'websocket_repo=',
"ohp_repo=": 'ohp_repo=',

# Referências às variáveis
"${ssh_repo}": "${ssh_repo}",
"${sstp_repo}": "${sstp_repo}",
"${ssr_repo}": "${ssr_repo}",
"${shadowsocks_repo}": "${shadowsocks_repo}",
"${wireguard_repo}": "${wireguard_repo}",
"${xray_repo}": "${xray_repo}",
"${ipsec_repo}": "${ipsec_repo}",
"${backup_repo}": "${backup_repo}",
"${websocket_repo}": "${websocket_repo}",
"${ohp_repo}": "${ohp_repo}",

"$ssh_repo": "$ssh_repo",
"$ssh_repon": "$sstp_repo",
"$ssh_reponn": "$ssr_repo",
"$ssh_reponnn": "$shadowsocks_repo",
"$ssh_reponnnn": "$wireguard_repo",
"$ssh_reponnnnn": "$xray_repo",
"$ssh_reponnnnnn": "$ipsec_repo",
"$ssh_reponnnnnnn": "$backup_repo",
"$ssh_reponnnnnnnn": "$websocket_repo",
"$ssh_reponnnnnnnnn": "$ohp_repo",


}

IGNORE_DIRS = {
".git",
"**pycache**",
".venv",
"venv",
"node_modules"
}

BINARY_EXTENSIONS = {
".png", ".jpg", ".jpeg", ".gif", ".webp",
".zip", ".rar", ".7z", ".tar", ".gz", ".xz",
".mp3", ".mp4", ".avi", ".mkv",
".pdf", ".so", ".dll", ".exe", ".bin",
".pyc", ".o", ".a"
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
    if file.name.endswith(".backup"):
        continue
    checked += 1
    try:
        content = file.read_text(encoding="utf-8", errors="ignore")
        original = content
        for old, new in REPLACEMENTS.items():
            content = content.replace(old, new)
        if content != original:
            backup_file = Path(str(file) + ".backup")
            backup_file.write_text(original, encoding="utf-8")
            file.write_text(content, encoding="utf-8")
            modified += 1
            print(f"✓ {file.relative_to(BASE_DIR)}")
    except Exception as e:
        print(f"✗ {file}: {e}")


print()
print("=" * 60)
print("RESUMO")
print("=" * 60)
print(f"Arquivos verificados : {checked}")
print(f"Arquivos modificados : {modified}")
print(f"Backups criados      : {modified}")
print("=" * 60)
print()
print("Concluído!")
