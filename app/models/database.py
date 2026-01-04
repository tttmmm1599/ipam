"""
데이터베이스 연결 및 세션 관리
"""
from sqlalchemy import create_engine, text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from sqlalchemy.exc import OperationalError
import os
import sys
import time
import logging

# 로깅 설정
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# PostgreSQL 사용 (환경변수로 설정 가능)
# 기본값: postgresql+psycopg2://ipam:ipam@localhost/ipam
SQLALCHEMY_DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+psycopg2://ipam:ipam@localhost/ipam"
)

# SQLite 사용 시 (개발/테스트용)
# BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
# DB_PATH = os.path.join(BASE_DIR, "ipam.db")
# SQLALCHEMY_DATABASE_URL = f"sqlite:///{DB_PATH}"

# MySQL 사용 시
# SQLALCHEMY_DATABASE_URL = os.getenv(
#     "DATABASE_URL",
#     "mysql+pymysql://user:password@localhost/ipam"
# )

def create_engine_with_retry(database_url, max_retries=5, retry_delay=2):
    """연결 재시도가 포함된 엔진 생성"""
    is_sqlite = "sqlite" in database_url
    
    for attempt in range(max_retries):
        try:
            # 연결 풀 설정
            pool_kwargs = {
                "pool_pre_ping": True,  # 연결 안정성
                "pool_size": 5,
                "max_overflow": 10,
                "pool_timeout": 30,  # 연결 풀 타임아웃 (초)
                "pool_recycle": 3600,  # 연결 재사용 시간 (초)
            }
            
            # SQLite는 다른 설정 사용
            if is_sqlite:
                connect_args = {"check_same_thread": False}
                pool_kwargs.pop("pool_size")
                pool_kwargs.pop("max_overflow")
            else:
                connect_args = {}
            
            engine = create_engine(
                database_url,
                connect_args=connect_args,
                **pool_kwargs
            )
            
            # 연결 테스트
            with engine.connect() as conn:
                conn.execute(text("SELECT 1"))
            
            logger.info(f"데이터베이스 연결 성공: {database_url.split('@')[-1] if '@' in database_url else database_url}")
            return engine
            
        except OperationalError as e:
            if attempt < max_retries - 1:
                logger.warning(f"데이터베이스 연결 실패 (시도 {attempt + 1}/{max_retries}): {str(e)}")
                logger.info(f"{retry_delay}초 후 재시도...")
                time.sleep(retry_delay)
            else:
                logger.error(f"데이터베이스 연결 최종 실패: {str(e)}")
                logger.error(f"연결 URL: {database_url.split('@')[-1] if '@' in database_url else database_url}")
                logger.error("다음 사항을 확인하세요:")
                logger.error("1. PostgreSQL 서비스가 실행 중인지: systemctl status postgresql")
                logger.error("2. 데이터베이스/사용자가 존재하는지")
                logger.error("3. pg_hba.conf 인증 설정이 올바른지")
                logger.error("4. 방화벽이 포트를 막고 있지 않은지")
                raise
        except Exception as e:
            logger.error(f"예상치 못한 데이터베이스 연결 오류: {str(e)}")
            raise

# 엔진 생성
try:
    engine = create_engine_with_retry(SQLALCHEMY_DATABASE_URL)
except Exception as e:
    logger.critical(f"데이터베이스 엔진 생성 실패: {str(e)}")
    sys.exit(1)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

def get_db():
    """데이터베이스 세션 의존성"""
    db = SessionLocal()
    try:
        yield db
    except Exception as e:
        logger.error(f"데이터베이스 세션 오류: {str(e)}")
        db.rollback()
        raise
    finally:
        db.close()


