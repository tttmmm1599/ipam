"""
데이터베이스 초기화 스크립트
"""
from app.models.database import engine, Base
from app.models.models import Subnet, IPAddress

def init_db():
    """데이터베이스 테이블 생성"""
    print("데이터베이스 테이블을 생성하는 중...")
    Base.metadata.create_all(bind=engine)
    print("데이터베이스 초기화가 완료되었습니다!")

if __name__ == "__main__":
    init_db()


