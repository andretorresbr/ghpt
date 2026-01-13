#!/bin/bash
# Script de integração Wazuh - YARA (Versão JSON Support)
# Autor: Andre Torres

# Debug caso seja necessário verificar se o script está sendo chamado
# echo "$(date) - DEBUG: Script yara.sh INICIADO. Argumentos recebidos: $@" >> /tmp/active-responses.log

LOG_FILE="/var/ossec/logs/active-responses.log"
RULES_FILE="/var/ossec/yara/rules/yara-rules-core.yar"

# 1. LER O INPUT JSON DO WAZUH (STDIN)
read -r INPUT_JSON

# 2. DEBUG: Registrar o que chegou (opcional, bom para troubleshooting)
# echo "$(date) - DEBUG RECEBIDO: $INPUT_JSON" >> "${LOG_FILE}"

# 3. EXTRAIR O NOME DO ARQUIVO USANDO JQ
# O caminho vem em parameters -> alert -> syscheck -> path
FILENAME=$(echo "$INPUT_JSON" | jq -r .parameters.alert.syscheck.path)

# Se o campo syscheck.path for nulo (ex: teste manual sem syscheck), tenta pegar do argumento (backup)
if [ "$FILENAME" == "null" ] || [ -z "$FILENAME" ]; then
    FILENAME=$3
fi

# 4. EXECUÇÃO
if [ -n "$FILENAME" ] && [ -f "$FILENAME" ]; then
    # Executa o YARA
    YARA_OUTPUT=$(yara -w "$RULES_FILE" "$FILENAME")

    if [ ! -z "$YARA_OUTPUT" ]; then
        # Loga no formato que o Decoder espera
        echo "wazuh-yara: INFO - Scan result: $YARA_OUTPUT" >> "${LOG_FILE}"
    fi
else
    echo "$(date) - ERRO: Arquivo nao encontrado ou caminho vazio. Filename: $FILENAME" >> "${LOG_FILE}"
fi
