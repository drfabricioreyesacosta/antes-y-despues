#!/usr/bin/env bash
# Flujo PASO 1 — Confirmación de cita
# Crea/actualiza (upsert) el contacto como LEAD con cita pendiente y le envía
# un SMS de confirmación pidiéndole que responda SÍ + su fecha de nacimiento.
#
# Uso:
#   flows/confirmar-cita.sh
#   FIRST_NAME="Andre" LAST_NAME="Salcedo" PHONE="+526531660671" flows/confirmar-cita.sh
#
# Requiere .env con GHL_PIT y GHL_LOCATION_ID (ver .env.example).
# Necesita salida de red hacia services.leadconnectorhq.com.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -f "$DIR/.env" ] && { set -a; . "$DIR/.env"; set +a; }
: "${GHL_PIT:?Falta GHL_PIT (define en .env)}"
: "${GHL_LOCATION_ID:?Falta GHL_LOCATION_ID (define en .env)}"

BASE="https://services.leadconnectorhq.com"
AUTH="Authorization: Bearer $GHL_PIT"
VER="Version: 2021-07-28"

# --- Datos del contacto (editables por variables de entorno) ---
FIRST_NAME="${FIRST_NAME:-Andre}"
LAST_NAME="${LAST_NAME:-Salcedo}"
PHONE="${PHONE:-+526531660671}"
EMAIL="${EMAIL:-andre.salcedo@placeholder.invalid}"   # placeholder .invalid: no entrega a nadie real
MSG="${MSG:-Hola Andre, le confirmamos su cita para mañana miércoles 22 de julio a las 5:00 PM. Por favor responda SÍ para confirmar su asistencia. Además, ¿nos podría compartir su fecha de nacimiento para completar su expediente? ¡Gracias!}"

echo "==> 1) Upsert de contacto (LEAD + cita-pendiente-confirmacion)..."
RESP=$(curl -sS -X POST "$BASE/contacts/upsert" \
  -H "$AUTH" -H "$VER" -H "Content-Type: application/json" \
  -d "{\"locationId\":\"$GHL_LOCATION_ID\",\"firstName\":\"$FIRST_NAME\",\"lastName\":\"$LAST_NAME\",\"phone\":\"$PHONE\",\"email\":\"$EMAIL\",\"tags\":[\"lead\",\"cita-pendiente-confirmacion\"]}")

if command -v jq >/dev/null 2>&1; then
  CONTACT_ID=$(printf '%s' "$RESP" | jq -r '.contact.id // .id // empty')
else
  CONTACT_ID=$(printf '%s' "$RESP" | grep -o '"id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
fi
[ -n "${CONTACT_ID:-}" ] || { echo "ERROR: no se obtuvo contactId."; echo "Respuesta: $RESP"; exit 1; }
echo "    contactId = $CONTACT_ID"

echo "==> 2) Enviando SMS de confirmación..."
curl -sS -X POST "$BASE/conversations/messages" \
  -H "$AUTH" -H "$VER" -H "Content-Type: application/json" \
  -d "{\"type\":\"SMS\",\"contactId\":\"$CONTACT_ID\",\"message\":\"$MSG\"}"
echo

echo ""
echo "==> LISTO. '$FIRST_NAME $LAST_NAME' quedó como LEAD con cita pendiente."
echo "    Cuando responda SÍ y dé su fecha de nacimiento, corre el PASO 2:"
echo "      flows/confirmar-paciente.sh $CONTACT_ID AAAA-MM-DD"
