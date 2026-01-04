"""
웹 페이지 라우터
"""
from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse
from jinja2 import Environment, FileSystemLoader
import os

# main.py와 동일한 경로 계산 방식 사용
BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TEMPLATES_DIR = os.path.join(BASE_DIR, "templates")

jinja_env = Environment(loader=FileSystemLoader(TEMPLATES_DIR))

def render_template(template_name: str, **kwargs):
    """템플릿 렌더링 헬퍼 함수"""
    template = jinja_env.get_template(template_name)
    return template.render(**kwargs)

router = APIRouter()

@router.get("/dashboard", response_class=HTMLResponse)
async def dashboard(request: Request):
    """대시보드 페이지"""
    try:
        content = render_template("index.html", request=request)
        return HTMLResponse(content=content)
    except Exception as e:
        return HTMLResponse(
            content=f"<h1>대시보드 오류</h1><p>템플릿을 로드할 수 없습니다: {str(e)}</p>",
            status_code=500
        )

