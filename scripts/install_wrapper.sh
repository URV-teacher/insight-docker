#!/bin/bash
set -eo pipefail

mkdir -p "$DEVKITPRO/insight/bin"

cat <<'EOF' > "$DEVKITPRO/insight/bin/arm-eabi-insight.exe"
#!/usr/bin/env bash
exec insight "$@"
EOF

chmod +x "$DEVKITPRO/insight/bin/arm-eabi-insight.exe"