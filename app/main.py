"""
IPAM 웹 애플리케이션 메인 엔트리 포인트
"""
from fastapi import FastAPI, Request
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse
from fastapi.middleware.cors import CORSMiddleware
from jinja2 import Environment, FileSystemLoader
import os

from app.api import subnets
from app.web import routes

# FastAPI 앱 생성
app = FastAPI(
    title="IPAM - IP Address Management",
    description="IP 주소 및 서브넷 관리 시스템",
    version="1.0.0"
)

# CORS 설정
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 프로덕션에서는 특정 도메인으로 제한
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 정적 파일 및 템플릿 설정
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEMPLATES_DIR = os.path.join(BASE_DIR, "templates")
STATIC_DIR = os.path.join(BASE_DIR, "static")

app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")
jinja_env = Environment(loader=FileSystemLoader(TEMPLATES_DIR))

def render_template(template_name: str, **kwargs):
    """템플릿 렌더링 헬퍼 함수"""
    template = jinja_env.get_template(template_name)
    return template.render(**kwargs)

# API 라우터 등록
app.include_router(subnets.router, prefix="/api", tags=["subnets"])

# 웹 라우터 등록
app.include_router(routes.router, tags=["web"])

@app.get("/", response_class=HTMLResponse)
async def root(request: Request):
    """메인 페이지"""
    try:
        content = render_template("index.html", request=request)
        return HTMLResponse(content=content)
    except Exception as e:
        # 템플릿 파일이 없거나 오류 발생 시 기본 응답
        return HTMLResponse(
            content=f"<h1>IPAM 서비스</h1><p>템플릿을 로드할 수 없습니다: {str(e)}</p><p>템플릿 경로: {TEMPLATES_DIR}</p>",
            status_code=500
        )

@app.get("/health")
async def health_check():
    """헬스 체크 엔드포인트"""
    return {"status": "healthy", "service": "ipam"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

