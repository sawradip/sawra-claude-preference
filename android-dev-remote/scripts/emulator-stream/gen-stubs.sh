#!/usr/bin/env bash
# Regenerates the gRPC stubs from the emulator's own proto. Usage: gen-stubs.sh <python-with-grpcio-tools>
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
python="${1:-python3}"
cd "${ANDROID_HOME:-$HOME/Android/Sdk}/emulator/lib"
"$python" -m grpc_tools.protoc -I. --python_out="$here" --grpc_python_out="$here" emulator_controller.proto
