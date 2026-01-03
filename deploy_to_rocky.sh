#!/bin/bash

# IPAM 웹 애플리케이션 배포 스크립트
# Rocky Linux 서버에 배포하기 위한 전체 스크립트

set -e

IPAM_DIR="/opt/ipam"
SERVICE_USER="ipam"
SERVICE_NAME="ipam"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "IPAM 웹 애플리케이션 배포를 시작합니다"
echo "=========================================="
echo ""

# 현재 사용자가 root인지 확인
if [ "$EUID" -ne 0 ]; then 
    echo "이 스크립트는 root 권한이 필요합니다."
    echo "사용법: sudo ./deploy_to_rocky.sh"
    exit 1
fi

# 1. 필요한 패키지 설치
echo "[1/9] 시스템 패키지 설치 중..."
dnf update -y
dnf install -y python3 python3-pip python3-devel gcc postgresql-devel mysql-devel sqlite-devel

# 2. 서비스 사용자 생성
echo "[2/9] 서비스 사용자 생성 중..."
if ! id "$SERVICE_USER" &>/dev/null; then
    useradd -r -s /bin/false -d "$IPAM_DIR" "$SERVICE_USER"
    echo "사용자 $SERVICE_USER 생성 완료"
else
    echo "사용자 $SERVICE_USER 이미 존재합니다"
fi

# 3. 디렉토리 구조 생성
echo "[3/9] 디렉토리 구조 생성 중..."
mkdir -p "$IPAM_DIR"/{app/{api,web,templates,static,models},venv,logs}

# 4. 애플리케이션 파일 복사
echo "[4/9] 애플리케이션 파일 복사 중..."
if [ ! -d "$SCRIPT_DIR/app" ]; then
    echo "오류: app 디렉토리를 찾을 수 없습니다."
    echo "스크립트는 프로젝트 루트 디렉토리에서 실행해야 합니다."
    exit 1
fi

# app 디렉토리 전체 복사 (모든 파일 및 하위 디렉토리 포함)
echo "  - app 디렉토리 복사 중..."
cp -r "$SCRIPT_DIR/app"/. "$IPAM_DIR/app/"

# requirements.txt 복사
echo "  - requirements.txt 복사 중..."
cp "$SCRIPT_DIR/requirements.txt" "$IPAM_DIR/"

# 파일 권한 설정
echo "  - 파일 권한 설정 중..."
chown -R "$SERVICE_USER:$SERVICE_USER" "$IPAM_DIR"

# 5. Python 가상환경 생성
echo "[5/9] Python 가상환경 생성 중..."
sudo -u "$SERVICE_USER" python3 -m venv "$IPAM_DIR/venv"
sudo -u "$SERVICE_USER" "$IPAM_DIR/venv/bin/pip" install --upgrade pip

# 6. Python 패키지 설치
echo "[6/9] Python 패키지 설치 중..."
sudo -u "$SERVICE_USER" "$IPAM_DIR/venv/bin/pip" install -r "$IPAM_DIR/requirements.txt"

# 7. 데이터베이스 초기화
echo "[7/9] 데이터베이스 초기화 중..."
sudo -u "$SERVICE_USER" "$IPAM_DIR/venv/bin/python" "$IPAM_DIR/app/init_db.py"

# 8. systemd 서비스 파일 생성
echo "[8/9] systemd 서비스 파일 생성 중..."
cat > /etc/systemd/system/${SERVICE_NAME}.service <<EOF
[Unit]
Description=IPAM Web Application
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$IPAM_DIR
Environment="PATH=$IPAM_DIR/venv/bin"
ExecStart=$IPAM_DIR/venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# 9. 서비스 시작 및 활성화
echo "[9/9] 서비스 시작 및 활성화 중..."
systemctl daemon-reload
systemctl enable ${SERVICE_NAME}

# 기존 서비스가 실행 중이면 재시작
if systemctl is-active --quiet ${SERVICE_NAME}; then
    echo "기존 서비스를 재시작합니다..."
    systemctl restart ${SERVICE_NAME}
else
    echo "서비스를 시작합니다..."
    systemctl start ${SERVICE_NAME}
fi

# 방화벽 설정 (선택사항)
if command -v firewall-cmd &> /dev/null; then
    echo ""
    echo "방화벽 포트 8000을 열까요? (y/n)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        firewall-cmd --permanent --add-port=8000/tcp
        firewall-cmd --reload
        echo "방화벽 포트 8000이 열렸습니다."
    fi
fi

# 서비스 상태 확인
sleep 2
if systemctl is-active --quiet ${SERVICE_NAME}; then
    echo ""
    echo "=========================================="
    echo "✅ 배포가 성공적으로 완료되었습니다!"
    echo "=========================================="
    echo ""
    echo "서비스 상태: $(systemctl is-active ${SERVICE_NAME})"
    echo ""
    echo "유용한 명령어:"
    echo "  서비스 상태 확인: systemctl status $SERVICE_NAME"
    echo "  서비스 로그 확인: journalctl -u $SERVICE_NAME -f"
    echo "  서비스 재시작: systemctl restart $SERVICE_NAME"
    echo "  서비스 중지: systemctl stop $SERVICE_NAME"
    echo ""
    SERVER_IP=$(hostname -I | awk '{print $1}')
    echo "웹 접속 주소:"
    echo "  http://$SERVER_IP:8000"
    echo "  http://localhost:8000"
    echo ""
    echo "API 엔드포인트:"
    echo "  http://$SERVER_IP:8000/api/subnets"
    echo "  http://$SERVER_IP:8000/docs (API 문서)"
    echo ""
else
    echo ""
    echo "=========================================="
    echo "⚠️  서비스 시작에 문제가 발생했습니다"
    echo "=========================================="
    echo "로그를 확인하세요: journalctl -u $SERVICE_NAME -n 50"
    exit 1
fi

