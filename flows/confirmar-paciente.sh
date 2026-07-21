#!/usr/bin/env bash
# Flujo PASO 2 — Captura como paciente (tras respuesta de confirmación)
# Marca al contacto como PACIENTE con cita confirmada y guarda su fecha de
# nacimiento. Ejecutar SOLO cuando el contacto ya respondió confirmando.
#
# Uso:
#   flows/confirmar-paciente.sh <contactId> <fecha-nacimiento AAAA-MM-DD>
#
# Requiere .env con GHL_PIT (ver .env.example).
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -f "$DIR/.env" ] && { set -a; . "$DIR/.env"; set +a; }
: "${GHL_PIT:?Falta GHL_PIT (define en .env)}"

CONTACT_ID="${1:?Uso: confirmar-paciente.sh <contactId> <fecha-nacimiento AAAA-MM-DD>}"
DOB="${2:?Falta la fecha de nacimiento (AAAA-MM-DD)}"

BASE="https://services.leadconnectorhq.com"
AUTH="Authorization: Bearer $GHL_PIT"
VER="Version: 2021-07-28"

echo "==> 1) Guardando fecha de nacimiento..."
curl -sS -X PUT "$BASE/contacts/$CONTACT_ID" \
  -H "$AUTH" -H "$VER" -H "Content-Type: application/json" \
  -d "{\"dateOfBirth\":\"$DOB\"}"
echo

echo "==> 2) Etiquetando como PACIENTE + cita-confirmada..."
curl -sS -X POST "$BASE/contacts/$CONTACT_ID/tags" \
  -H "$AUTH" -H "$VER" -H "Content-Type: application/json" \
  -d "{\"tags\":[\"paciente\",\"cita-confirmada\"]}"
echo

echo "==> 3) Quitando etiquetas de estado previo (lead / pendiente)..."
curl -sS -X DELETE "$BASE/contacts/$CONTACT_ID/tags" \
  -H "$AUTH" -H "$VER" -H "Content-Type: application/json" \
  -d "{\"tags\":[\"cita-pendiente-confirmacion\",\"lead\"]}"
echo

echo ""
echo "==> LISTO. El contacto $CONTACT_ID quedó como PACIENTE con cita confirmada."
