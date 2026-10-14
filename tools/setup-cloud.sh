#!/usr/bin/env bash
set -euo pipefail
# Use the existing isolated checkout; do not create a worktree during onboarding.
cd /workspace/SecureRun
export CARGO_HOME=/workspace/.securerun-tools/cargo
export RUSTUP_HOME=/workspace/.securerun-tools/rustup
export npm_config_cache=/workspace/.securerun-tools/npm-cache
export PATH="$CARGO_HOME/bin:$PATH"
command -v cc >/dev/null
node -e 'const [major,minor]=process.versions.node.split(".").map(Number); if(major!==24 || minor<19)process.exit(1)'
if ! test -x "$CARGO_HOME/bin/rustup"; then
    test "$(uname -m)" = x86_64
    mkdir -p /workspace/.securerun-tools
    curl --fail --location --proto '=https' --tlsv1.2 https://static.rust-lang.org/rustup/archive/1.28.2/x86_64-unknown-linux-gnu/rustup-init -o /workspace/.securerun-tools/rustup-init
    python - <<'PY'
from pathlib import Path
import hashlib
path=Path('/workspace/.securerun-tools/rustup-init')
assert hashlib.sha256(path.read_bytes()).hexdigest() == '20a06e644b0d9bd2fbdbfd52d42540bdde820ea7df86e92e533c073da0cdd43c'
PY
    chmod +x /workspace/.securerun-tools/rustup-init
    /workspace/.securerun-tools/rustup-init -y --no-modify-path --profile minimal --default-toolchain 1.90.0
fi
rustup toolchain install 1.90.0 --profile minimal --component rustfmt,clippy
npm ci --ignore-scripts
npm run build
npm test
cargo test --locked -p securerun-foundation
cargo clippy --locked -p securerun-foundation --all-targets -- -D warnings
python tools/lab/validate_repository.py
