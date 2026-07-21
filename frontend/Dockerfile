# 빌드 컨텍스트 = 레포 루트 (Cloudtype: -f frontend/Dockerfile .)
# 1단계: Flutter 웹 릴리즈 빌드 (API 주소·DEV 로그인은 빌드 시점에 박힘)
# cirruslabs 최신 배포 태그 3.44.0(Dart 3.12.0)으로 고정 — pubspec sdk 하한도 ^3.12.0
FROM ghcr.io/cirruslabs/flutter:3.44.0 AS build

WORKDIR /app
COPY frontend/ .

ARG API_BASE_URL=https://port-0-otfit-api-m7c8oc297ff7fd19.sel4.cloudtype.app
# 로그인 UI 도입 전까지의 데모용 자동 로그인 계정
ARG DEV_LOGIN_EMAIL=test@otfit.app
ARG DEV_LOGIN_PASSWORD=test1234

RUN flutter pub get && flutter build web --release \
    --dart-define=API_BASE_URL=${API_BASE_URL} \
    --dart-define=DEV_LOGIN_EMAIL=${DEV_LOGIN_EMAIL} \
    --dart-define=DEV_LOGIN_PASSWORD=${DEV_LOGIN_PASSWORD}

# 2단계: 정적 서빙 (비루트 nginx — Cloudtype 권한 제약 대응, 8080 리슨)
FROM nginxinc/nginx-unprivileged:alpine

COPY frontend/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 8080
