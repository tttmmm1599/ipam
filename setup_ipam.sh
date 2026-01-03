#!/bin/bash

# IPAM 웹 애플리케이션 설치 스크립트
# Rocky Linux용

set -e

IPAM_DIR="/opt/ipam"
SERVICE_USER="ipam"
SERVICE_NAME="ipam"

echo "=========================================="
echo "IPAM 웹 애플리케이션 설치를 시작합니다"
echo "=========================================="

# 1. 필요한 패키지 설치
echo "[1/8] 시스템 패키지 설치 중..."
sudo dnf update -y
sudo dnf install -y python3 python3-pip python3-devel gcc postgresql-devel mysql-devel sqlite-devel nginx

# 2. 서비스 사용자 생성
echo "[2/8] 서비스 사용자 생성 중..."
if ! id "$SERVICE_USER" &>/dev/null; then
    sudo useradd -r -s /bin/false -d "$IPAM_DIR" "$SERVICE_USER"
    echo "사용자 $SERVICE_USER 생성 완료"
else
    echo "사용자 $SERVICE_USER 이미 존재합니다"
fi

# 3. 디렉토리 구조 생성
echo "[3/8] 디렉토리 구조 생성 중..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sudo mkdir -p "$IPAM_DIR"/{app/{api,web,templates,static,models},venv,logs}
sudo chown -R "$SERVICE_USER:$SERVICE_USER" "$IPAM_DIR"

# 애플리케이션 파일 복사
echo "애플리케이션 파일 복사 중..."
# app 디렉토리 전체 복사 (모든 파일 및 하위 디렉토리 포함)
sudo cp -r "$SCRIPT_DIR/app"/. "$IPAM_DIR/app/"
sudo cp "$SCRIPT_DIR/requirements.txt" "$IPAM_DIR/"
sudo chown -R "$SERVICE_USER:$SERVICE_USER" "$IPAM_DIR"

# 4. Python 가상환경 생성 및 활성화
echo "[4/8] Python 가상환경 생성 중..."
sudo -u "$SERVICE_USER" python3 -m venv "$IPAM_DIR/venv"
sudo -u "$SERVICE_USER" "$IPAM_DIR/venv/bin/pip" install --upgrade pip

# 5. 필요한 Python 패키지 설치
echo "[5/8] Python 패키지 설치 중..."
sudo -u "$SERVICE_USER" "$IPAM_DIR/venv/bin/pip" install -r "$IPAM_DIR/requirements.txt"

# 6. 데이터베이스 초기화
echo "[6/8] 데이터베이스 초기화 중..."
sudo -u "$SERVICE_USER" "$IPAM_DIR/venv/bin/python" "$IPAM_DIR/app/init_db.py"

# 7. systemd 서비스 파일 생성
echo "[7/8] systemd 서비스 파일 생성 중..."
sudo tee /etc/systemd/system/${SERVICE_NAME}.service > /dev/null <<EOF
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

[Install]
WantedBy=multi-user.target
EOF

# 8. 서비스 시작 및 활성화
echo "[8/8] 서비스 시작 및 활성화 중..."
sudo systemctl daemon-reload
sudo systemctl enable ${SERVICE_NAME}
sudo systemctl start ${SERVICE_NAME}

echo "=========================================="
echo "설치가 완료되었습니다!"
echo "=========================================="
echo "서비스 상태 확인: sudo systemctl status $SERVICE_NAME"
echo "서비스 로그 확인: sudo journalctl -u $SERVICE_NAME -f"
echo "웹 접속: http://$(hostname -I | awk '{print $1}'):8000"
echo "=========================================="

