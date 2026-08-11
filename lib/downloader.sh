#!/bin/bash
# ============================================================
# lib/downloader.sh - Download inteligente com retry e cache
# ============================================================
# Uso: source lib/downloader.sh
# ============================================================

# Configuração
readonly DOWNLOAD_RETRIES=3
readonly DOWNLOAD_TIMEOUT=30
readonly CACHE_DIR="/root/.vpn-cache"

# Cria diretório de cache
mkdir -p "$CACHE_DIR" 2>/dev/null

# ----------------------------------------------------------
# Função principal de download
# ----------------------------------------------------------
# Uso: download_file "URL" "caminho/destino" ["descrição"]
# Retorna: 0 = sucesso, 1 = falha
# ----------------------------------------------------------

download_file() {
    local url="$1"
    local dest="$2"
    local desc="${3:-$(basename "$dest")}"
    local attempt=0

    log_info "Baixando: $desc"

    # Verifica cache
    local cache_file="${CACHE_DIR}/$(echo "$url" | md5sum | cut -d' ' -f1)"
    if [ -f "$cache_file" ] && [ $(stat -c%s "$cache_file" 2>/dev/null || echo 0) -gt 100 ]; then
        log_debug "Usando cache: $desc"
        cp "$cache_file" "$dest" 2>/dev/null && {
            chmod +x "$dest" 2>/dev/null
            return 0
        }
    fi

    # Tenta download com wget
    while [ $attempt -lt $DOWNLOAD_RETRIES ]; do
        attempt=$((attempt + 1))

        log_debug "Tentativa $attempt/$DOWNLOAD_RETRIES: wget $url"

        if wget -q --timeout="$DOWNLOAD_TIMEOUT" --tries=2 -O "$dest" "$url" 2>/dev/null; then
            # Verifica se o arquivo não está vazio
            if [ -s "$dest" ]; then
                # Salva no cache
                cp "$dest" "$cache_file" 2>/dev/null
                chmod +x "$dest" 2>/dev/null
                log_ok "$desc baixado com sucesso ($(du -h "$dest" | cut -f1))"
                return 0
            fi
        fi

        # Fallback: tenta com curl
        log_debug "Fallback: curl $url"
        if curl -sSL --connect-timeout "$DOWNLOAD_TIMEOUT" --max-time 60 -o "$dest" "$url" 2>/dev/null; then
            if [ -s "$dest" ]; then
                cp "$dest" "$cache_file" 2>/dev/null
                chmod +x "$dest" 2>/dev/null
                log_ok "$desc baixado via curl ($(du -h "$dest" | cut -f1))"
                return 0
            fi
        fi

        log_warn "Tentativa $attempt falhou para: $desc"

        # Se não for a última tentativa, espera um pouco
        if [ $attempt -lt $DOWNLOAD_RETRIES ]; then
            sleep 2
        fi
    done

    log_fail "Falha ao baixar: $desc após $DOWNLOAD_RETRIES tentativas"
    log_error "URL: $url"
    return 1
}

# ----------------------------------------------------------
# Download com fallback automático (tenta URLs alternativas)
# ----------------------------------------------------------
# Uso: download_with_fallback "URL_PRINCIPAL" "URL_FALLBACK" "destino" ["descrição"]
# ----------------------------------------------------------

download_with_fallback() {
    local primary="$1"
    local fallback="$2"
    local dest="$3"
    local desc="${4:-$(basename "$dest")}"

    if download_file "$primary" "$dest" "$desc"; then
        return 0
    fi

    log_warn "Tentando URL alternativa para: $desc"
    if download_file "$fallback" "$dest" "$desc (fallback)"; then
        return 0
    fi

    return 1
}

# ----------------------------------------------------------
# Download e execução de script
# ----------------------------------------------------------
# Uso: download_and_run "URL" "nome_script" [args...]
# Retorna o exit code do script
# ----------------------------------------------------------

download_and_run() {
    local url="$1"
    local script_name="$2"
    shift 2
    local args="$@"

    local tmp_script="/tmp/${script_name}"

    log_info "Preparando: $script_name"

    if ! download_file "$url" "$tmp_script" "$script_name"; then
        return 1
    fi

    chmod +x "$tmp_script"

    log_info "Executando: $script_name $args"

    # Executa e captura exit code
    bash "$tmp_script" $args
    local exit_code=$?

    # Limpa
    rm -f "$tmp_script"

    if [ $exit_code -eq 0 ]; then
        log_ok "$script_name concluído"
    else
        log_fail "$script_name falhou (exit code: $exit_code)"
    fi

    return $exit_code
}

# ----------------------------------------------------------
# Atualiza cache de downloads
# ----------------------------------------------------------

update_cache() {
    log_info "Atualizando cache de downloads..."
    rm -rf "$CACHE_DIR" 2>/dev/null
    mkdir -p "$CACHE_DIR"
    log_ok "Cache limpo"
}