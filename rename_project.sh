#!/bin/bash
# Script para renomear projeto para ROTATEEL SSH
# ===============================================

echo "=============================================="
echo "  Renomeando projeto para ROTATEEL SSH"
echo "=============================================="
echo ""

# Encontrar e substituir em todos os arquivos .sh, .md, .txt
find . -type f \( -name "*.sh" -o -name "*.md" -o -name "*.txt" -o -name "*.conf" \) ! -path "*/.git/*" ! -name "*.backup" -exec sed -i.bkp \
    -e 's/ROTATEEL SSH/ROTATEEL SSH/g' \
    -e 's/ROTATEEL/ROTATEEL/g' \
    -e 's/ROTATEEL/rotateel/g' \
    -e 's/ROTATEEL/Rotateel/g' \
    -e 's/Powered by ROTATEEL/Powered by ROTATEEL/g' \
    -e 's/Script Powered by ROTATEEL/ROTATEEL SSH Script/g' \
    -e 's/Script Modificado por ROTATEEL/Script ROTATEEL SSH/g' \
    -e 's/mantapxsl\.my\.id/rotateel.com/g' \
    -e 's/slinfinity69@gmail\.com/admin@rotateel.com/g' \
    -e 's/nekopoi\.care/rotateel.com/g' \
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
echo "  Projeto agora se chama: ROTATEEL SSH"
echo "=============================================="
