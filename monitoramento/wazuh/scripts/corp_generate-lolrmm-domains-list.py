#!/usr/bin/env python3
# corp_generate-lolrmm-domains-list.py
# Baseado no projeto https://lolrmm.io/
# Arquivo baixado e analizado pelos script: https://lolrmm.io/api/rmm_domains.csv

import csv
import os
import sys
import urllib.request

CSV_URL = "https://lolrmm.io/api/rmm_domains.csv"
OUTPUT_FILE = "/var/ossec/etc/lists/rmm_domains"

GENERIC_DOMAINS = {
    "github.com",
    "raw.githubusercontent.com",
    "gitlab.com",
    "bitbucket.org",
    "amazonaws.com",
    "azure.com",
    "visualstudio.com",
    "microsoft.com",
    "google.com",
    "apache.org",
}


def download_csv(url):
    try:
        with urllib.request.urlopen(url, timeout=30) as response:
            return response.read().decode("utf-8", errors="ignore")
    except Exception as e:
        print(f"[ERRO] Falha ao baixar CSV: {e}")
        sys.exit(1)


def normalize_uri(uri):
    uri = uri.strip().lower()

    # Remove path
    if "/" in uri:
        uri = uri.split("/", 1)[0]

    # Remove wildcards
    uri = uri.replace("*", "")

    # Remove prefixos inválidos
    uri = uri.lstrip("-.")

    return uri


def is_generic_domain(domain):
    for generic in GENERIC_DOMAINS:
        if domain == generic or domain.endswith("." + generic):
            return True
    return False


def generate_list(csv_content):
    entries = set()

    reader = csv.DictReader(csv_content.splitlines())
    for row in reader:
        uri = row.get("URI", "").strip()
        tool = row.get("RMM_Tool", "").strip()

        if not uri or not tool:
            continue

        domain = normalize_uri(uri)
        if not domain:
            continue

        # Remove domínios genéricos
        if is_generic_domain(domain):
            continue

        entries.add(f'{domain}:"{tool}"')

    return sorted(entries)


def write_output(entries, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)

    try:
        with open(path, "w") as f:
            for entry in entries:
                f.write(entry + "\n")
    except Exception as e:
        print(f"[ERRO] Falha ao escrever arquivo: {e}")
        sys.exit(1)


def main():
    print("[INFO] Baixando LOLRMM rmm_domains.csv...")
    csv_content = download_csv(CSV_URL)

    print("[INFO] Normalizando domínios e removendo genéricos...")
    entries = generate_list(csv_content)

    if not entries:
        print("[ERRO] Nenhuma entrada gerada.")
        sys.exit(1)

    print(f"[INFO] Gravando {len(entries)} entradas em {OUTPUT_FILE}")
    write_output(entries, OUTPUT_FILE)

    print("[OK] Lista de domínios RMM gerada com sucesso.")


if __name__ == "__main__":
    main()
