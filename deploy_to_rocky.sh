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

# 필요한 파일 및 디렉토리 확인
echo "프로젝트 파일 확인 중..."
echo "  스크립트 위치: $SCRIPT_DIR"

if [ ! -d "$SCRIPT_DIR/app" ]; then
    echo "❌ 오류: app 디렉토리를 찾을 수 없습니다."
    echo "   스크립트는 프로젝트 루트 디렉토리에서 실행해야 합니다."
    echo "   현재 위치: $SCRIPT_DIR"
    exit 1
fi

if [ ! -f "$SCRIPT_DIR/requirements.txt" ]; then
    echo "⚠️  경고: requirements.txt 파일을 찾을 수 없습니다."
    echo "   현재 위치: $SCRIPT_DIR"
    echo "   파일 목록:"
    ls -la "$SCRIPT_DIR" | head -10
    echo ""
    echo "   requirements.txt가 없어도 계속 진행할 수 있지만,"
    echo "   Python 패키지 설치 단계에서 실패할 수 있습니다."
    echo ""
fi

echo "✅ 필수 파일 확인 완료"
echo ""

# 1. 필요한 패키지 설치
echo "[1/10] 시스템 패키지 설치 중..."
dnf update -y
# PostgreSQL을 기본값으로 사용하므로 postgresql-server와 postgresql-devel 설치
dnf install -y python3 python3-pip python3-devel gcc postgresql postgresql-server postgresql-devel

# 2. PostgreSQL 초기화 및 시작
echo "[2/10] PostgreSQL 설정 중..."
if [ ! -d /var/lib/pgsql/data ]; then
    postgresql-setup --initdb
    echo "PostgreSQL 데이터베이스 초기화 완료"
else
    echo "PostgreSQL 데이터베이스가 이미 초기화되어 있습니다"
fi

# PostgreSQL 서비스 시작 및 활성화
systemctl enable postgresql
systemctl start postgresql

# PostgreSQL 사용자 및 데이터베이스 생성
echo "  - PostgreSQL 사용자 및 데이터베이스 생성 중..."
# 사용자 생성 (이미 존재하면 에러 무시)
sudo -u postgres psql -c "CREATE USER ipam WITH PASSWORD 'ipam';" 2>/dev/null || echo "  사용자 ipam이 이미 존재합니다"

# 데이터베이스 생성 (이미 존재하면 에러 무시)
sudo -u postgres psql -c "CREATE DATABASE ipam OWNER ipam;" 2>/dev/null || echo "  데이터베이스 ipam이 이미 존재합니다"

# 권한 부여
sudo -u postgres psql -d ipam -c "GRANT ALL PRIVILEGES ON DATABASE ipam TO ipam;" 2>/dev/null

# PostgreSQL 인증 설정 (pg_hba.conf)
echo "  - PostgreSQL 인증 설정 중..."
PG_HBA_CONF="/var/lib/pgsql/data/pg_hba.conf"
if [ -f "$PG_HBA_CONF" ]; then
    # 기존 설정 확인
    if ! grep -q "host.*ipam.*ipam.*127.0.0.1/32.*md5" "$PG_HBA_CONF"; then
        echo "host    ipam    ipam    127.0.0.1/32    md5" | sudo -u postgres tee -a "$PG_HBA_CONF" > /dev/null
        sudo systemctl reload postgresql
        echo "  PostgreSQL 인증 설정 완료"
    else
        echo "  PostgreSQL 인증 설정이 이미 존재합니다"
    fi
else
    echo "  ⚠️  경고: pg_hba.conf 파일을 찾을 수 없습니다"
fi

echo "  PostgreSQL 설정 완료 (사용자: ipam, 비밀번호: ipam, 데이터베이스: ipam)"
echo "  ⚠️  보안을 위해 프로덕션 환경에서는 비밀번호를 변경하세요!"

# 3. 서비스 사용자 생성
echo "[3/10] 서비스 사용자 생성 중..."
if ! id "$SERVICE_USER" &>/dev/null; then
    useradd -r -s /bin/false -d "$IPAM_DIR" "$SERVICE_USER"
    echo "사용자 $SERVICE_USER 생성 완료"
else
    echo "사용자 $SERVICE_USER 이미 존재합니다"
fi

# 4. 디렉토리 구조 생성
echo "[4/10] 디렉토리 구조 생성 중..."
mkdir -p "$IPAM_DIR"/{app/{api,web,templates,static,models},venv,logs}

# 5. 애플리케이션 파일 복사
echo "[5/10] 애플리케이션 파일 복사 중..."
echo "  스크립트 실행 위치: $SCRIPT_DIR"

# app 디렉토리 확인
if [ ! -d "$SCRIPT_DIR/app" ]; then
    echo "오류: app 디렉토리를 찾을 수 없습니다."
    echo "스크립트는 프로젝트 루트 디렉토리에서 실행해야 합니다."
    exit 1
fi

# app 디렉토리 전체 복사 (모든 파일 및 하위 디렉토리 포함)
echo "  - app 디렉토리 복사 중..."
cp -r "$SCRIPT_DIR/app"/. "$IPAM_DIR/app/"

# requirements.txt 복사 (파일 존재 여부 확인)
echo "  - requirements.txt 복사 중..."
if [ -f "$SCRIPT_DIR/requirements.txt" ]; then
    cp "$SCRIPT_DIR/requirements.txt" "$IPAM_DIR/"
    echo "  requirements.txt 복사 완료"
else
    echo "  ⚠️  경고: requirements.txt 파일을 찾을 수 없습니다."
    echo "  현재 디렉토리: $SCRIPT_DIR"
    echo "  파일 목록:"
    ls -la "$SCRIPT_DIR" | head -10
    echo "  requirements.txt를 수동으로 생성하거나, Python 패키지를 수동으로 설치해야 합니다."
    if [ -t 0 ] && [ -t 1 ]; then
        # 대화형 모드
        echo "  계속 진행하시겠습니까? (y/n)"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            echo "배포를 중단합니다."
            exit 1
        fi
    else
        # 비대화형 모드 - 자동으로 계속 진행
        echo "  비대화형 모드: 자동으로 계속 진행합니다."
    fi
fi

# 파일 권한 설정
echo "  - 파일 권한 설정 중..."
chown -R "$SERVICE_USER:$SERVICE_USER" "$IPAM_DIR"

# 6. Python 가상환경 생성
echo "[6/10] Python 가상환경 생성 중..."
sudo -u "$SERVICE_USER" python3 -m venv "$IPAM_DIR/venv"
sudo -u "$SERVICE_USER" "$IPAM_DIR/venv/bin/pip" install --upgrade pip

# 7. Python 패키지 설치
echo "[7/10] Python 패키지 설치 중..."
if [ -f "$IPAM_DIR/requirements.txt" ]; then
    sudo -u "$SERVICE_USER" "$IPAM_DIR/venv/bin/pip" install -r "$IPAM_DIR/requirements.txt"
    echo "  Python 패키지 설치 완료"
else
    echo "  ⚠️  경고: requirements.txt 파일이 없어 기본 패키지를 설치합니다."
    echo "  필수 패키지 설치 중..."
    sudo -u "$SERVICE_USER" "$IPAM_DIR/venv/bin/pip" install \
        fastapi==0.104.1 \
        uvicorn[standard]==0.24.0 \
        jinja2==3.1.2 \
        python-multipart==0.0.6 \
        sqlalchemy==2.0.23 \
        pydantic==2.5.0 \
        psycopg2-binary==2.9.9 \
        ipaddress==1.0.23
    echo "  기본 패키지 설치 완료"
fi

# 8. 데이터베이스 초기화
echo "[8/10] 데이터베이스 초기화 중..."
# PYTHONPATH를 설정하여 app 모듈을 찾을 수 있도록 함
sudo -u "$SERVICE_USER" env PYTHONPATH="$IPAM_DIR" "$IPAM_DIR/venv/bin/python" -m app.init_db

# 9. systemd 서비스 파일 생성
echo "[9/10] systemd 서비스 파일 생성 중..."

# 비대화형 모드 감지 함수
is_interactive() {
    [ -t 0 ] && [ -t 1 ]
}

# 포트 충돌 검사
PORT=8000
if command -v netstat &> /dev/null; then
    if netstat -tuln 2>/dev/null | grep -q ":${PORT} "; then
        echo "  ⚠️  경고: 포트 ${PORT}이 이미 사용 중입니다."
        if is_interactive; then
            echo "  다른 포트를 사용하시겠습니까? (y/n)"
            read -r response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                read -p "  포트 번호를 입력하세요 [8000]: " input_port
                PORT=${input_port:-8000}
            else
                echo "  기존 서비스를 중지하고 계속 진행합니다..."
                systemctl stop ${SERVICE_NAME} 2>/dev/null || true
            fi
        else
            echo "  비대화형 모드: 기존 서비스를 중지하고 계속 진행합니다..."
            systemctl stop ${SERVICE_NAME} 2>/dev/null || true
        fi
    fi
fi

cat > /etc/systemd/system/${SERVICE_NAME}.service <<EOF
[Unit]
Description=IPAM Web Application
After=network.target postgresql.service
Requires=postgresql.service

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$IPAM_DIR
Environment="PATH=$IPAM_DIR/venv/bin"
Environment="PYTHONPATH=$IPAM_DIR"
ExecStart=$IPAM_DIR/venv/bin/uvicorn app.main:app --host 0.0.0.0 --port ${PORT}
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# 10. 서비스 시작 및 활성화
echo "[10/10] 서비스 시작 및 활성화 중..."
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
    if [ -t 0 ] && [ -t 1 ]; then
        # 대화형 모드
        echo "방화벽 포트 ${PORT}을 열까요? (y/n)"
        read -r response
    else
        # 비대화형 모드 - 기본값 사용
        response="n"
        echo "비대화형 모드: 방화벽 설정을 건너뜁니다."
    fi
    if [[ "$response" =~ ^[Yy]$ ]]; then
        firewall-cmd --permanent --add-port=${PORT}/tcp
        firewall-cmd --reload
        echo "방화벽 포트 ${PORT}이 열렸습니다."
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

