# 빌드 컨텍스트 = 레포 루트 (Cloudtype: -f frontend/Dockerfile .)
# 1단계: Flutter 웹 릴리즈 빌드 (API 주소·DEV 로그인은 빌드 시점에 박힘)
# cirruslabs 최신 배포 태그 3.44.0(Dart 3.12.0)으로 고정 — pubspec sdk 하한도 ^3.12.0
FROM ghcr.io/cirruslabs/flutter:3.44.0 AS build

WORKDIR /app
COPY frontend/ .

ARG API_BASE_URL=https://port-0-otfit-api-m7c8oc297ff7fd19.sel4.cloudtype.app
# 로그인 화면 도입 — 자동 로그인(DEV_LOGIN)은 기본 비활성. 필요 시 build arg로 주입.
ARG DEV_LOGIN_EMAIL=
ARG DEV_LOGIN_PASSWORD=
# 소셜 로그인 키 (미설정 시 버튼은 안내만 표시)
ARG KAKAO_JS_KEY=
ARG GOOGLE_CLIENT_ID=

RUN flutter pub get && flutter build web --release \
    --dart-define=API_BASE_URL=${API_BASE_URL} \
    --dart-define=DEV_LOGIN_EMAIL=${DEV_LOGIN_EMAIL} \
    --dart-define=DEV_LOGIN_PASSWORD=${DEV_LOGIN_PASSWORD} \
    --dart-define=KAKAO_JS_KEY=${KAKAO_JS_KEY} \
    --dart-define=GOOGLE_CLIENT_ID=${GOOGLE_CLIENT_ID}

# 2단계: 정적 서빙 (비루트 nginx — Cloudtype 권한 제약 대응, 8080 리슨)
FROM nginxinc/nginx-unprivileged:alpine

COPY frontend/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 8080
