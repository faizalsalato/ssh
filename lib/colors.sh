#!/bin/bash
# ============================================================
# Biblioteca de cores ANSI compartilhada
# Uso: source lib/colors.sh
# ============================================================

export RED='\033[0;31m'
export GREEN='\033[0;32m'
export ORANGE='\033[0;33m'
export BLUE='\033[0;34m'
export PURPLE='\033[0;35m'
export CYAN='\033[0;36m'
export LIGHT='\033[0;37m'
export NC='\033[0m'

# Cores em negrito
export RED_BOLD='\033[1;31m'
export GREEN_BOLD='\033[1;32m'
export YELLOW_BOLD='\033[1;33m'
export BLUE_BOLD='\033[1;34m'
export PURPLE_BOLD='\033[1;35m'
export CYAN_BOLD='\033[1;36m'
export WHITE_BOLD='\033[1;37m'

# Aliases para compatibilidade com scripts antigos
# (alguns scripts usam variáveis diferentes)
export y='\033[0;1;37m'
export yy='\033[0;1;32m'
export yl='\033[0;1;33m'
export wh='\033[0m'
export m='\033[0;1;36m'
