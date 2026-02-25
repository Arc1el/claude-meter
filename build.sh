#!/bin/bash
set -e

APP_NAME="ClaudeMeter"
APP_BUNDLE="${APP_NAME}.app"
INSTALL_DIR="/Applications"

echo "🔨 Claude Meter 빌드 중..."
swift build -c release 2>&1

echo ""
echo "📦 앱 번들 패키징 중..."

# 기존 번들 제거
rm -rf "${APP_BUNDLE}"

# 디렉터리 구조 생성
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# 실행 파일 복사
cp ".build/release/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/"

# Info.plist 생성 (LSUIElement=true → 독에 표시 안 됨)
cat > "${APP_BUNDLE}/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>ClaudeMeter</string>
    <key>CFBundleIdentifier</key>
    <string>com.claude.meter</string>
    <key>CFBundleName</key>
    <string>Claude Meter</string>
    <key>CFBundleDisplayName</key>
    <string>Claude Meter</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

# Ad-hoc 코드 서명 (서명 없으면 macOS가 실행 거부)
codesign --force --deep --sign - "${APP_BUNDLE}" > /dev/null 2>&1

echo ""
echo "✅ 빌드 성공! → ${APP_BUNDLE}"
echo ""

# 설치 여부 묻기
read -p "📥 /Applications 에 설치할까요? (y/N) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # 기존 설치본 제거
    if [ -d "${INSTALL_DIR}/${APP_BUNDLE}" ]; then
        echo "기존 버전 제거 중..."
        rm -rf "${INSTALL_DIR}/${APP_BUNDLE}"
        # 실행 중이면 종료
        pkill -x "${APP_NAME}" 2>/dev/null || true
        sleep 0.5
    fi

    cp -r "${APP_BUNDLE}" "${INSTALL_DIR}/"
    echo "✅ ${INSTALL_DIR}/${APP_BUNDLE} 설치 완료!"
    echo ""
    read -p "🚀 지금 실행할까요? (y/N) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        open "${INSTALL_DIR}/${APP_BUNDLE}"
        echo "▶ Claude Meter 실행됨"
    fi
else
    echo "현재 디렉터리의 ${APP_BUNDLE} 을 직접 실행할 수 있습니다:"
    echo "  open ${APP_BUNDLE}"
fi
