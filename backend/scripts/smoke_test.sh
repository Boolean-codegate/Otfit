#!/usr/bin/env bash
# Otfit 백엔드 스모크 테스트 — api_contract.md(§10) 계약 검증 포함.
#
# 사용법 (backend/ 에서, 스택 기동 + 마이그레이션 + 시드 완료 후):
#   bash scripts/smoke_test.sh [BASE_URL]
#
# 회원가입→로그인→refresh→업로드→analyze→recommendations→products→
# generations→폴링→results→select→shop→events→export→credits 순서로 호출하고,
# 각 응답의 필드/타입/상태코드가 계약과 일치하는지 assert 한다.
set -euo pipefail

BASE="${1:-http://localhost:8000}"
PASS=0

say()  { printf '\n\033[1;34m== %s ==\033[0m\n' "$*"; }
ok()   { printf '  \033[32mOK\033[0m %s\n' "$*"; PASS=$((PASS+1)); }
fail() { printf '  \033[31mFAIL\033[0m %s\n' "$*"; exit 1; }

# check <json> <설명> <python assert문...>  — d 에 파싱된 JSON이 들어간다
check() {
  local json="$1" desc="$2"; shift 2
  local code=""
  for a in "$@"; do code+="assert ($a)"$'\n'; done
  if echo "$json" | python3 -c "
import sys, json
d = json.load(sys.stdin)
$code" 2>/tmp/smoke_err; then
    ok "$desc"
  else
    echo "  response: $(echo "$json" | head -c 400)"
    cat /tmp/smoke_err | tail -3
    fail "$desc"
  fi
}

# req <expected_status> <method> <path> [curl args...] — body를 출력, 상태코드 검증
req() {
  local expect="$1" method="$2" path="$3"; shift 3
  local out status body
  out=$(curl -s -w $'\n%{http_code}' -X "$method" "$BASE$path" "$@")
  status="${out##*$'\n'}"
  body="${out%$'\n'*}"
  if [ "$status" != "$expect" ]; then
    echo "  $method $path -> HTTP $status (expected $expect)" >&2
    echo "  response: $(echo "$body" | head -c 400)" >&2
    exit 1
  fi
  echo "$body"
}

jget() { echo "$1" | python3 -c "import sys,json;print(json.load(sys.stdin)$2)"; }

command -v docker-compose >/dev/null && COMPOSE=docker-compose || COMPOSE="docker compose"

say "0. 헬스체크 + 테스트 이미지 준비"
HEALTH=$(req 200 GET /health)
check "$HEALTH" "GET /health" "d['status']=='ok'"
$COMPOSE exec -T api python -c "
from PIL import Image
Image.new('RGB', (900, 1200), (172, 151, 129)).save('/code/.smoke_test.jpg', 'JPEG')
" || fail "테스트 이미지 생성 (backend/에서 실행했는지, 스택이 떠 있는지 확인)"
IMG="$(cd "$(dirname "$0")/.." && pwd)/.smoke_test.jpg"
trap 'rm -f "$IMG"' EXIT

say "1. 회원가입 (201, user+토큰 shape)"
EMAIL="smoke_$(date +%s)@test.dev"
REG=$(req 201 POST /auth/register -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"password\":\"password1\",\"nickname\":\"스모크\"}")
check "$REG" "POST /auth/register" \
  "set(d) == {'user','access_token','refresh_token'}" \
  "set(d['user']) == {'id','email','nickname','credit_balance','is_premium','created_at'}" \
  "d['user']['email'] == '$EMAIL'" \
  "isinstance(d['user']['credit_balance'], int)"

say "2. 로그인 + refresh"
LOGIN=$(req 200 POST /auth/login -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"password\":\"password1\"}")
check "$LOGIN" "POST /auth/login" "set(d) == {'user','access_token','refresh_token'}"
TOKEN=$(jget "$LOGIN" "['access_token']")
AUTH="Authorization: Bearer $TOKEN"
REFRESH=$(req 200 POST /auth/refresh -H 'Content-Type: application/json' \
  -d "{\"refresh_token\":\"$(jget "$LOGIN" "['refresh_token']")\"}")
check "$REFRESH" "POST /auth/refresh" "set(d) == {'access_token','refresh_token'}"
ME=$(req 200 GET /me -H "$AUTH")
check "$ME" "GET /me" "d['email'] == '$EMAIL'"

say "3. 인증 에러 포맷 (계약 §0)"
ERR=$(req 401 GET /me)
check "$ERR" "no-auth error shape" \
  "set(d['error']) == {'code','message','detail'}" "d['error']['code'] == 'UNAUTHORIZED'"

say "4. 사진 업로드 (201)"
PHOTO=$(req 201 POST /photos -H "$AUTH" -F "file=@$IMG" -F "consent_image_processing=true")
check "$PHOTO" "POST /photos" \
  "set(d) == {'id','storage_url','width','height','status','uploaded_at'}" \
  "d['status'] == 'uploaded'" "d['width'] == 900 and d['height'] == 1200"
PHOTO_ID=$(jget "$PHOTO" "['id']")

say "5. analyze (계약 §3 shape)"
AN=$(req 200 POST /photos/$PHOTO_ID/analyze -H "$AUTH")
check "$AN" "POST /photos/{id}/analyze" \
  "d['photo_id'] == '$PHOTO_ID'" \
  "d['is_valid'] is True and d['reject_reason'] is None" \
  "d['person_count'] == 1" \
  "d['pose'] in ('front','three_quarter')" \
  "d['garment_regions'][0]['type'] in ('top','jacket','shirt','dress')" \
  "len(d['garment_regions'][0]['bbox']) == 4" \
  "0 <= d['occlusion_score'] <= 1" \
  "set(d['lighting']) == {'brightness','direction'}" \
  "all(set(s) == {'id','label'} for s in d['style_suggestions'])" \
  "len(d['style_suggestions']) >= 2"
STYLE_ID=$(jget "$AN" "['style_suggestions'][0]['id']")

say "6. recommendations (B_stylist 그룹 + style_id 필터)"
REC=$(req 200 POST /photos/$PHOTO_ID/recommendations -H "$AUTH" \
  -H 'Content-Type: application/json' -d '{"mode":"B_stylist"}')
check "$REC" "POST recommendations (B)" \
  "d['photo_id'] == '$PHOTO_ID' and d['mode'] == 'B_stylist'" \
  "len(d['groups']) >= 1" \
  "all(set(g) >= {'style_id','label','products'} for g in d['groups'])" \
  "all(set(p) >= {'id','title','brand','category','price','currency','stock_status','product_url','image_url','attributes'} for g in d['groups'] for p in g['products'])" \
  "all(isinstance(p['price'], int) for g in d['groups'] for p in g['products'])" \
  "all(set(p['attributes']) >= {'color','pattern','length','material'} for g in d['groups'] for p in g['products'])"
REC1=$(req 200 POST /photos/$PHOTO_ID/recommendations -H "$AUTH" \
  -H 'Content-Type: application/json' -d "{\"mode\":\"B_stylist\",\"style_id\":\"$STYLE_ID\"}")
check "$REC1" "POST recommendations (style_id 필터)" \
  "len(d['groups']) == 1 and d['groups'][0]['style_id'] == '$STYLE_ID'"
PRODUCT_ID=$(jget "$REC" "['groups'][0]['products'][0]['id']")

say "7. products (페이지네이션)"
PROD=$(req 200 "GET" "/products?category=shirt&limit=3" -H "$AUTH")
check "$PROD" "GET /products" \
  "set(d) == {'items','next_cursor'}" "len(d['items']) == 3" "d['next_cursor'] is not None"
PROD2=$(req 200 "GET" "/products?category=shirt&limit=3&cursor=$(jget "$PROD" "['next_cursor']")" -H "$AUTH")
check "$PROD2" "GET /products (cursor)" \
  "[p['id'] for p in d['items']] != $(echo "$PROD" | python3 -c "import sys,json;print([p['id'] for p in json.load(sys.stdin)['items']])")"

say "8. generations (202) + 폴링"
JOB=$(req 202 POST /generations -H "$AUTH" -H 'Content-Type: application/json' \
  -d "{\"photo_id\":\"$PHOTO_ID\",\"mode\":\"B_stylist\",\"options\":{\"styles\":[\"casual\",\"minimal\"]}}")
check "$JOB" "POST /generations" \
  "set(d) == {'job_id','status','credits_charged'}" \
  "d['status'] == 'queued'" "d['credits_charged'] == 1"
JOB_ID=$(jget "$JOB" "['job_id']")

STATUS=queued
for i in $(seq 1 15); do
  POLL=$(req 200 GET /generations/$JOB_ID -H "$AUTH")
  STATUS=$(jget "$POLL" "['status']")
  check "$POLL" "폴링 #$i (status=$STATUS)" \
    "set(d) == {'job_id','status','progress','step_label','error'}" \
    "d['status'] in ('queued','analyzing','searching','generating','quality_check','done','failed')" \
    "0 <= d['progress'] <= 1"
  [ "$STATUS" = done ] && break
  [ "$STATUS" = failed ] && { echo "$POLL"; fail "generation failed"; }
  sleep 2
done
[ "$STATUS" = done ] || fail "30초 내 done 미도달"

say "9. results (품질 통과만 + disclaimer)"
RES=$(req 200 GET /generations/$JOB_ID/results -H "$AUTH")
check "$RES" "GET results" \
  "d['job_id'] == '$JOB_ID'" "len(d['results']) >= 1" \
  "all(set(r) == {'id','product_id','result_url','style_label','quality_score','identity_preserved','is_selected','disclaimer'} for r in d['results'])" \
  "all(r['identity_preserved'] and r['quality_score'] >= 0.6 for r in d['results'])" \
  "all('스타일링 시각화' in r['disclaimer'] for r in d['results'])"
RESULT_ID=$(jget "$RES" "['results'][0]['id']")
RESULT_URL=$(jget "$RES" "['results'][0]['result_url']")
IMG_CODE=$(curl -s -o /dev/null -w '%{http_code}' "$RESULT_URL")
[ "$IMG_CODE" = 200 ] && ok "결과 이미지 다운로드 (HTTP 200)" || fail "결과 이미지 $RESULT_URL -> $IMG_CODE"

say "10. select + shop + events"
SEL=$(req 200 POST /generations/$JOB_ID/results/$RESULT_ID/select -H "$AUTH")
check "$SEL" "select" "d == {'ok': True}"
SHOP=$(req 200 GET /results/$RESULT_ID/shop -H "$AUTH")
check "$SHOP" "GET /results/{id}/shop" \
  "set(d) == {'applied_product','similar_products'}" \
  "len(d['similar_products']) >= 1" \
  "d['applied_product']['product_url'].startswith('http')"
EV=$(req 202 POST /events -H "$AUTH" -H 'Content-Type: application/json' \
  -d "{\"type\":\"product_click\",\"session_id\":\"smoke\",\"payload\":{\"product_id\":\"$PRODUCT_ID\"}}")
check "$EV" "POST /events" "d == {'ok': True}"

say "11. export (무료 유저 → 워터마크 유지)"
EXP=$(req 200 POST /results/$RESULT_ID/export -H "$AUTH" -H 'Content-Type: application/json' \
  -d '{"ratio":"4:5","hi_res":true,"remove_watermark":true}')
check "$EXP" "POST export" \
  "set(d) == {'export_url','watermark'}" "d['watermark'] is True"

say "12. credits (가입 10 - 생성 1 = 9 → 충전 +50)"
CR=$(req 200 GET /credits -H "$AUTH")
check "$CR" "GET /credits" "d == {'balance': 9}"
BUY=$(req 200 POST /credits/purchase -H "$AUTH" -H 'Content-Type: application/json' -d '{"amount":50}')
check "$BUY" "POST /credits/purchase" \
  "set(d) == {'balance','transaction_id'}" "d['balance'] == 59"

printf '\n\033[1;32m✔ 스모크 테스트 통과: %d개 검증 성공\033[0m\n' "$PASS"
