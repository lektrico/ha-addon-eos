#!/command/with-contenv bashio
# shellcheck shell=bash
# One-shot setup before the agent and its supervisor start:
#   1. the connect code → /data/connect_code (0600) and the agent's config.yaml
#   2. first start only: download ems-supervisor from Delta EnergyOS,
#      authenticated by the SITE's credential, and refuse to install it unless
#      its SHA-256 and ed25519 signature check out against our public key.
# The supervisor then installs and updates the agent itself (signed, staged).
set -euo pipefail

# Production release-signing public key (raw ed25519, base64). The same key
# is baked into every ems-supervisor we ship; public by design.
SIGNING_PUBKEY="JweBBTxFNlWSR+FInT/vn63zZ4K4Jz22tfadOzdBe2k="

ROOT=/data/ems-edge
BIN=/data/bin
mkdir -p "$ROOT" "$BIN"

CODE="$(bashio::config 'connect_code')"
if [ -z "$CODE" ]; then
    bashio::exit.nok "Set 'connect_code' in the add-on configuration (Delta EnergyOS → your site → Connect)."
fi
API="$(bashio::config 'api')"
CHANNEL="$(bashio::config 'channel')"

umask 077
printf '%s' "$CODE" > /data/connect_code

# base64url JSON → username / password / site_id (padding stripped on the wire).
decode_code() {
    local s="${1//-/+}"; s="${s//_//}"
    while [ $(( ${#s} % 4 )) -ne 0 ]; do s="${s}="; done
    printf '%s' "$s" | base64 -d
}
CODE_JSON="$(decode_code "$CODE")" || bashio::exit.nok "The connect code is not valid."
USERNAME="$(jq -r '.username // empty' <<<"$CODE_JSON")"
PASSWORD="$(jq -r '.password // empty' <<<"$CODE_JSON")"
SITE_ID="$(jq -r '.site_id // empty' <<<"$CODE_JSON")"
[ -n "$USERNAME" ] && [ -n "$PASSWORD" ] && [ -n "$SITE_ID" ] \
    || bashio::exit.nok "The connect code is missing its credential; issue a new one."

# Devices, the guard and everything else arrive over the config push; this
# file only says who we are and where state lives (agent_uid, the config
# cache and health.json sit next to the outbox, which is the supervisor root).
cat > "$ROOT/config.yaml" <<YAML
connect_code: "$CODE"
platform: hass_addon
poll_interval_seconds: 5
buffer:
  path: "$ROOT/ems-edge-outbox.db"
  max_rows: 1000000
devices: []
YAML

# uname rather than bashio::info.arch, which would need the hassio_api
# permission this add-on has no other use for.
case "$(uname -m)" in
    aarch64|arm64) ARCH=arm64 ;;
    x86_64|amd64) ARCH=amd64 ;;
    *) bashio::exit.nok "Unsupported architecture: $(uname -m)" ;;
esac
printf '%s' "$ARCH" > /data/arch
printf '%s' "$API" > /data/api
printf '%s' "$CHANNEL" > /data/channel

if [ -x "$BIN/ems-supervisor" ]; then
    bashio::log.info "Site ${SITE_ID}: supervisor present, starting."
    exit 0
fi

bashio::log.info "Site ${SITE_ID}: fetching the supervisor (${CHANNEL}, ${ARCH})…"
META="$(curl -fsS -u "${USERNAME}:${PASSWORD}" \
    "${API}/agent/releases/${CHANNEL}/latest?runtime=gosup&platform=hass_addon&arch=${ARCH}")" \
    || bashio::exit.nok "Could not reach Delta EnergyOS, or the connect code was refused. Re-issue the code if it was rotated."
URL="$(jq -r .download_url <<<"$META")"
SHA="$(jq -r .sha256 <<<"$META")"
SIG="$(jq -r .signature <<<"$META")"
VERSION="$(jq -r .version <<<"$META")"
case "$URL" in /*) URL="${API}${URL}" ;; esac

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
curl -fsS -L -o "$TMP/ems-supervisor" "$URL" || bashio::exit.nok "Supervisor download failed."

GOT="$(sha256sum "$TMP/ems-supervisor" | cut -d' ' -f1)"
[ "$GOT" = "$SHA" ] || bashio::exit.nok "Supervisor checksum mismatch — refusing to install."

# ed25519 over the hex digest string, exactly as the supervisor verifies the
# agent. Raw 32-byte key → SPKI DER (fixed 12-byte prefix) → PEM for openssl.
{ printf '\x30\x2a\x30\x05\x06\x03\x2b\x65\x70\x03\x21\x00'; printf '%s' "$SIGNING_PUBKEY" | base64 -d; } > "$TMP/pub.der"
openssl pkey -pubin -inform DER -in "$TMP/pub.der" -out "$TMP/pub.pem"
printf '%s' "$SHA" > "$TMP/msg"
printf '%s' "$SIG" | base64 -d > "$TMP/sig"
openssl pkeyutl -verify -pubin -inkey "$TMP/pub.pem" -rawin -in "$TMP/msg" -sigfile "$TMP/sig" >/dev/null \
    || bashio::exit.nok "Supervisor signature invalid — refusing to install."

install -m 0755 "$TMP/ems-supervisor" "$BIN/ems-supervisor"
bashio::log.info "Supervisor ${VERSION} verified and installed."
