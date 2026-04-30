#!/usr/bin/env bash
# Idempotent installer for the pinned weaver CLI.
#
# Downloads the prebuilt weaver binary for the host platform from
# open-telemetry/weaver releases, verifies the SHA-256 checksum, and
# extracts it to ./bin/weaver inside the semconv directory. The Makefile
# invokes ./bin/weaver, so this stays self-contained — no global install,
# no PATH mutation, no Rust toolchain required.
#
# Re-runs are no-ops once the pinned version is present.
set -euo pipefail

WEAVER_VERSION="${WEAVER_VERSION:-v0.23.0}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${SCRIPT_DIR}/bin"
WEAVER_BIN="${BIN_DIR}/weaver"

# Detect platform → asset name
case "$(uname -s)-$(uname -m)" in
    Darwin-arm64)  ASSET="weaver-aarch64-apple-darwin.tar.xz" ;;
    Darwin-x86_64) ASSET="weaver-x86_64-apple-darwin.tar.xz" ;;
    Linux-x86_64)  ASSET="weaver-x86_64-unknown-linux-gnu.tar.xz" ;;
    Linux-aarch64) ASSET="weaver-aarch64-unknown-linux-gnu.tar.xz" ;;
    *)
        echo "error: unsupported platform $(uname -s)-$(uname -m)" >&2
        echo "       see https://github.com/open-telemetry/weaver/releases/${WEAVER_VERSION}" >&2
        exit 1
        ;;
esac

# Idempotency: skip if pinned version is already installed
if [[ -x "${WEAVER_BIN}" ]]; then
    INSTALLED_VERSION="$("${WEAVER_BIN}" --version 2>/dev/null | awk '{print $2}')"
    if [[ "v${INSTALLED_VERSION}" == "${WEAVER_VERSION}" ]]; then
        echo "weaver ${WEAVER_VERSION} already installed at ${WEAVER_BIN}"
        exit 0
    fi
    echo "weaver version mismatch (installed=v${INSTALLED_VERSION}, pinned=${WEAVER_VERSION}) — reinstalling"
fi

mkdir -p "${BIN_DIR}"

BASE_URL="https://github.com/open-telemetry/weaver/releases/download/${WEAVER_VERSION}"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT

echo "downloading ${ASSET} (${WEAVER_VERSION})..."
curl -fsSL -o "${TMPDIR}/${ASSET}" "${BASE_URL}/${ASSET}"
curl -fsSL -o "${TMPDIR}/${ASSET}.sha256" "${BASE_URL}/${ASSET}.sha256"

# Verify checksum (sha256 file format: "<hash> *<filename>" or "<hash>  <filename>")
EXPECTED_HASH="$(awk '{print $1}' "${TMPDIR}/${ASSET}.sha256")"
ACTUAL_HASH="$(shasum -a 256 "${TMPDIR}/${ASSET}" | awk '{print $1}')"
if [[ "${EXPECTED_HASH}" != "${ACTUAL_HASH}" ]]; then
    echo "error: checksum mismatch for ${ASSET}" >&2
    echo "       expected ${EXPECTED_HASH}" >&2
    echo "       actual   ${ACTUAL_HASH}" >&2
    exit 1
fi

tar -xJf "${TMPDIR}/${ASSET}" -C "${TMPDIR}"
EXTRACTED_DIR="$(find "${TMPDIR}" -maxdepth 1 -type d -name 'weaver-*' | head -1)"
if [[ -z "${EXTRACTED_DIR}" || ! -f "${EXTRACTED_DIR}/weaver" ]]; then
    echo "error: archive layout unexpected — could not locate weaver binary" >&2
    exit 1
fi

mv "${EXTRACTED_DIR}/weaver" "${WEAVER_BIN}"
chmod +x "${WEAVER_BIN}"

INSTALLED_VERSION="$("${WEAVER_BIN}" --version 2>/dev/null | awk '{print $2}')"
echo "installed weaver v${INSTALLED_VERSION} at ${WEAVER_BIN}"
