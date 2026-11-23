#!/bin/bash
# Health check for the forgot-password flow and the pieces it depends on
# (SMTP connectivity, realm/client reachability). Exits non-zero on any
# failure so this can be wired into cron/monitoring directly.
#
# Usage: ./check-forgot-password.sh [test-email] [realm] [client_id]
set -u

KC_BASE="http://localhost:8080"
REALM="${2:-toowix}"
CLIENT_ID="${3:-toowix-meet}"
TEST_EMAIL="${1:-toowix-healthcheck+$(date +%s)@toowix.test}"
TEST_USERNAME="toowix-healthcheck-$(date +%s)"
FAILED=0

log() { echo "[$(date -u +%H:%M:%S)] $1"; }
fail() { echo "[$(date -u +%H:%M:%S)] FAIL: $1"; FAILED=1; }

log "Checking Keycloak is reachable..."
if ! curl -sf -o /dev/null "$KC_BASE/realms/$REALM/.well-known/openid-configuration"; then
  fail "Realm '$REALM' is not reachable at $KC_BASE"
  exit 1
fi
log "OK"

log "Getting admin token..."
if [ -z "${KEYCLOAK_ADMIN_PASSWORD:-}" ]; then
  fail "KEYCLOAK_ADMIN_PASSWORD env var is not set -- refusing to guess a default"
  exit 1
fi
ADMIN_PASS="$KEYCLOAK_ADMIN_PASSWORD"
ADMIN_USER="${KEYCLOAK_ADMIN_USERNAME:-admin}"
TOKEN=$(curl -s -X POST "$KC_BASE/realms/master/protocol/openid-connect/token" \
  -d "client_id=admin-cli" -d "grant_type=password" -d "username=$ADMIN_USER" -d "password=$ADMIN_PASS" \
  | python3 -c "import json,sys
try:
    print(json.load(sys.stdin)['access_token'])
except Exception:
    pass" 2>/dev/null)

if [ -z "$TOKEN" ]; then
  fail "Could not obtain admin token -- admin credentials may have changed"
  exit 1
fi
log "OK"

log "Creating temporary test user ($TEST_EMAIL)..."
CREATE_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$KC_BASE/admin/realms/$REALM/users" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d "{\"username\":\"$TEST_USERNAME\",\"email\":\"$TEST_EMAIL\",\"enabled\":true,\"emailVerified\":true,\"firstName\":\"Health\",\"lastName\":\"Check\"}")
if [ "$CREATE_STATUS" != "201" ]; then
  fail "User creation returned HTTP $CREATE_STATUS"
  exit 1
fi
log "OK"

cleanup() {
  USER_ID=$(curl -s "$KC_BASE/admin/realms/$REALM/users?username=$TEST_USERNAME" -H "Authorization: Bearer $TOKEN" \
    | python3 -c "import json,sys
try:
    print(json.load(sys.stdin)[0]['id'])
except Exception:
    pass" 2>/dev/null)
  if [ -n "$USER_ID" ]; then
    curl -s -o /dev/null -X DELETE "$KC_BASE/admin/realms/$REALM/users/$USER_ID" -H "Authorization: Bearer $TOKEN"
  fi
}
trap cleanup EXIT

log "Fetching reset-credentials page (session_code/execution)..."
COOKIES=$(mktemp)
PAGE=$(curl -s -c "$COOKIES" "$KC_BASE/realms/$REALM/login-actions/reset-credentials?client_id=$CLIENT_ID")
SESSION_CODE=$(echo "$PAGE" | grep -oE 'session_code=[a-zA-Z0-9_-]+' | head -1 | cut -d= -f2)
EXECUTION=$(echo "$PAGE" | grep -oE 'execution=[a-zA-Z0-9_-]+' | head -1 | cut -d= -f2)
TAB_ID=$(echo "$PAGE" | grep -oE 'tab_id=[a-zA-Z0-9_-]+' | head -1 | cut -d= -f2)

if [ -z "$SESSION_CODE" ] || [ -z "$EXECUTION" ]; then
  fail "Could not extract session_code/execution from reset-credentials page -- login theme or flow may be broken"
  rm -f "$COOKIES"
  exit 1
fi
log "OK"

log "Submitting forgot-password form for $TEST_EMAIL..."
RESPONSE=$(curl -s -c "$COOKIES" -b "$COOKIES" -X POST \
  "$KC_BASE/realms/$REALM/login-actions/reset-credentials?session_code=$SESSION_CODE&execution=$EXECUTION&client_id=$CLIENT_ID&tab_id=$TAB_ID" \
  --data-urlencode "username=$TEST_EMAIL")
rm -f "$COOKIES"

if echo "$RESPONSE" | grep -qi "You should"; then
  log "OK -- confirmation page rendered, email was queued for sending"
else
  fail "Forgot-password submission did not return the expected confirmation message"
fi

if [ "$FAILED" -eq 0 ]; then
  log "All checks passed."
  exit 0
else
  log "One or more checks failed."
  exit 1
fi
