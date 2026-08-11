#!/bin/bash
# Script para renomear projeto para blaylook
# ===============================================

echo "=============================================="
echo "  Renomeando projeto para blaylook"
echo "=============================================="
echo ""

# Encontrar e substituir em todos os arquivos .sh, .md, .txt
find . -type f \( -name "*.sh" -o -name "*.md" -o -name "*.txt" -o -name "*.conf" \) ! -path "*/.git/*" ! -name "*.backup" -exec sed -i.bkp \
    -e 's/blaylook/blaylook/g' \
    -e 's/blaylook/blaylook/g' \
    -e 's/blaylook/blaylook/g' \
    -e 's/blaylook/blaylook/g' \
    -e 's/Powered by blaylook/Powered by blaylook/g' \
    -e 's/Script Powered by blaylook/blaylook Script/g' \
    -e 's/Script Modificado por blaylook/Script blaylook/g' \
    -e 's/mantapxsl\.my\.id/blaylook.com/g' \
    -e 's/slinfinity69@gmail\.com/blaylooks@gmail.com/g' \
    -e 's/nekopoi\.care/blaylook.com/g' \
    {} \;

echo "✓ Nomes substituídos nos arquivos"
echo ""

# Remover arquivos de backup criados
echo "Removendo arquivos de backup temporários..."
find . -type f -name "*.bkp" -delete
echo "✓ Backups removidos"
echo ""

echo "=============================================="
echo "  Renomeação concluída!"
echo "  Projeto agora se chama: blaylook"
echo "=============================================="
