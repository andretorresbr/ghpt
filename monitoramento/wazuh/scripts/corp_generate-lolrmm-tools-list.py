#!/usr/bin/env python3
# corp_generate-lolrmm-tools-list.py
# Baseado no projeto https://lolrmm.io/
# Arquivo baixado e analizado pelos script: https://lolrmm.io/api/rmm_tools.csv

import csv
import os
import sys
import urllib.request
import re

CSV_URL = "https://lolrmm.io/api/rmm_tools.csv"

TOOLS_FILE = "/var/ossec/etc/lists/rmm_tools"
DESC_FILE = "/var/ossec/etc/lists/rmm_tools-description"

GENERIC_EXECUTABLES = {
    "setup.exe", "installer.exe", "update.exe", "updater.exe",
    "agent.exe", "launcher.exe", "unins000.exe", "uninstall.exe",
    "access.exe", "client.exe", "client32.exe", "connect.exe",
    "mstsc.exe", "quickassist.exe", "runner.exe", "service.exe",
    "standalone.exe", "support.exe", "supporttool.exe",
    "termsrv.exe", "windowsclient.exe", "windowslauncher.exe",
}


def download_csv(url):
    try:
        with urllib.request.urlopen(url, timeout=30) as r:
            return r.read().decode("utf-8", errors="ignore")
    except Exception as e:
        print(f"[ERRO] Falha ao baixar CSV: {e}")
        sys.exit(1)


def extract_exes(text):
    exes = set()
    if not text:
        return exes

    matches = re.findall(r"[A-Za-z0-9_\-*]+\.exe", text, re.IGNORECASE)
    for m in matches:
        exe = m.replace("*", "")

        if exe.lower() in GENERIC_EXECUTABLES:
            continue

        exes.add(exe)

    return exes


def process_csv(csv_content):
    tools_lines = set()
    desc_lines = set()

    reader = csv.DictReader(csv_content.splitlines())
    for row in reader:
        name = row.get("Name", "").strip()
        if not name:
            continue

        # rmm_tools-description
        desc_lines.add(f"{name}:{name}")

        exes = set()
        exes |= extract_exes(row.get("Filename", ""))
        exes |= extract_exes(row.get("InstallationPaths", ""))

        for exe in exes:
            tools_lines.add(f'{exe}:"{name}"')

    return sorted(tools_lines), sorted(desc_lines)


def write_file(path, lines):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        for line in lines:
            f.write(line + "\n")


def main():
    print("[INFO] Baixando rmm_tools.csv...")
    csv_content = download_csv(CSV_URL)

    tools_lines, desc_lines = process_csv(csv_content)

    print(f"[INFO] Gravando {len(tools_lines)} entradas em {TOOLS_FILE}")
    write_file(TOOLS_FILE, tools_lines)

    print(f"[INFO] Gravando {len(desc_lines)} entradas em {DESC_FILE}")
    write_file(DESC_FILE, desc_lines)

    print("[OK] Geração concluída com sucesso.")


if __name__ == "__main__":
    main()
