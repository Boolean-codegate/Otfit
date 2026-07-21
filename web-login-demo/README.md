# OTFIT 웹 로그인 데모

백엔드 인증(이메일 + 카카오/구글 소셜)을 브라우저에서 바로 테스트하는 정적 페이지.
Flutter 소셜 로그인 연동 시 참고 구현이기도 하다 (토큰 → POST /auth/social 흐름).

## 실행

```bash
# 백엔드 먼저: cd backend && docker compose up -d
python3 -m http.server 8090 --directory web-login-demo
# → http://localhost:8090
```

## 소셜 키 설정 (index.html 상단 CONFIG)

- `GOOGLE_CLIENT_ID`: GCP OAuth **웹 클라이언트 ID**. 넣으면 진짜 구글 로그인 버튼이 렌더됨.
  GCP 콘솔에서 "승인된 JavaScript 원본"에 `http://localhost:8090` 추가 필요.
  같은 값을 backend/.env `GOOGLE_CLIENT_ID`에도 넣을 것 (aud 검증).
- `KAKAO_JS_KEY`: 카카오 developers JavaScript 키. 카카오 developers > 플랫폼 > Web에 `http://localhost:8090` 등록.
  웹은 리다이렉트 인가 방식이라, 빠른 검증은 하단 "개발자 도구"에서
  [카카오 토큰 도구](https://developers.kakao.com/tool/rest-api/open/get/v2-user-me)로 받은
  access_token을 붙여넣는 방법 권장.

테스트 계정: `test@otfit.app` / `test1234` (시드)
