#!/bin/bash
#
# agguro NAS Web Monitor
# Create development directory structure
#
# Usage: bash setup.sh

set -e

BASE="$HOME/Projects/asm-linux-sparc/nas-monitor"

mkdir -p \
    "$BASE/src" \
    "$BASE/arch/sparc" \
    "$BASE/www/css" \
    "$BASE/www/js"

touch \
    "$BASE/Makefile" \
    "$BASE/src/main.c" \
    "$BASE/src/http.c" \
    "$BASE/src/hardware.c" \
    "$BASE/src/auth.c" \
    "$BASE/arch/sparc/start.S" \
    "$BASE/arch/sparc/syscall.S" \
    "$BASE/www/index.html" \
    "$BASE/www/login.html" \
    "$BASE/www/css/style.css" \
    "$BASE/www/js/app.js"

echo "Project structure created: $BASE"

if command -v tree >/dev/null 2>&1; then
    tree "$BASE"
fi
