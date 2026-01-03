"""
웹 페이지 라우터
"""
from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse
from jinja2 import Environment, FileSystemLoader
import os

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
    content = render_template("index.html", request=request)
    return HTMLResponse(content=content)

