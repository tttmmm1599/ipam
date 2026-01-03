"""
데이터베이스 연결 및 세션 관리
"""
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
import os

# 데이터베이스 파일 경로
BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DB_PATH = os.path.join(BASE_DIR, "ipam.db")
SQLALCHEMY_DATABASE_URL = f"sqlite:///{DB_PATH}"

# PostgreSQL 사용 시 (환경변수로 설정 가능)
# SQLALCHEMY_DATABASE_URL = os.getenv(
#     "DATABASE_URL",
#     "postgresql://user:password@localhost/ipam"
# )

# MySQL 사용 시
# SQLALCHEMY_DATABASE_URL = os.getenv(
#     "DATABASE_URL",
#     "mysql+pymysql://user:password@localhost/ipam"
# )

engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False} if "sqlite" in SQLALCHEMY_DATABASE_URL else {}
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

def get_db():
    """데이터베이스 세션 의존성"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


