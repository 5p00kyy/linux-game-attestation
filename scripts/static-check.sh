#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"

cargo fmt --all --check
cargo clippy --workspace --all-targets -- -D warnings

shopt -s globstar nullglob
shell_scripts=(lab/**/*.sh scripts/**/*.sh)
python_files=(lab/**/*.py prototypes/**/*.py)

for script in "${shell_scripts[@]}"; do
    bash -n "$script"
done

for file in "${python_files[@]}"; do
    PYTHONDONTWRITEBYTECODE=1 python - "$file" <<'PY'
import ast
from pathlib import Path
import sys

path = Path(sys.argv[1])
ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
PY
done

if command -v shellcheck >/dev/null; then
    shellcheck "${shell_scripts[@]}"
else
    printf 'shellcheck not installed; completed bash syntax checks only\n' >&2
fi

printf 'static checks passed\n'
