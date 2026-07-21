# 빌드 컨텍스트 = 레포 루트 (Cloudtype: -f frontend/Dockerfile .)
# 1단계: Flutter 웹 릴리즈 빌드 (API 주소는 빌드 시점에 박힘)
# cirruslabs 최신 배포 태그 3.44.0(Dart 3.12.0)으로 고정 — pubspec sdk 하한도 ^3.12.0
FROM ghcr.io/cirruslabs/flutter:3.44.0 AS build

WORKDIR /app
# 의존성 레이어 분리 — 코드만 바뀐 빌드에서 pub get 캐시 재사용
COPY frontend/pubspec.yaml frontend/pubspec.lock ./
RUN flutter pub get
COPY frontend/ .

ARG API_BASE_URL=https://port-0-otfit-api-m7c8oc297ff7fd19.sel4.cloudtype.app

# --pwa-strategy none: 서비스워커 미사용 → 재배포가 새로고침만으로 반영됨 (데모에 오프라인 캐시 불필요)
RUN flutter build web --release --pwa-strategy none \
    --dart-define=API_BASE_URL=${API_BASE_URL}

# 2단계: 정적 서빙 (비루트 nginx — Cloudtype 권한 제약 대응, 8080 리슨)
FROM nginxinc/nginx-unprivileged:alpine

COPY frontend/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 8080
