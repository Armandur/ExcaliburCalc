#!/usr/bin/env bash
# Korskompilerar launchern till en 64-bitars Windows-exe.
# Kräver: sudo apt install gcc-mingw-w64-x86-64
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p dist
x86_64-w64-mingw32-gcc -O2 -s -mwindows \
    -o dist/excalibur-launcher.exe src/launcher.c -luser32 -lkernel32
ls -l dist/excalibur-launcher.exe
