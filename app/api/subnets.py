"""
서브넷 관리 API 엔드포인트
"""
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import List, Optional
from pydantic import BaseModel, Field
from datetime import datetime

from app.models.database import get_db
from app.models.models import Subnet, IPAddress
import ipaddress

router = APIRouter()

# Pydantic 모델
class SubnetCreate(BaseModel):
    name: str = Field(..., description="서브넷 이름")
    network: str = Field(..., description="CIDR 형식 네트워크 (예: 192.168.1.0/24)")
    description: Optional[str] = None
    vlan_id: Optional[int] = None
    location: Optional[str] = None
    is_active: bool = True

class SubnetUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    vlan_id: Optional[int] = None
    location: Optional[str] = None
    is_active: Optional[bool] = None

class SubnetResponse(BaseModel):
    id: int
    name: str
    network: str
    description: Optional[str]
    vlan_id: Optional[int]
    location: Optional[str]
    is_active: bool
    created_at: datetime
    updated_at: Optional[datetime]
    network_info: Optional[dict] = None

    class Config:
        from_attributes = True

@router.get("/subnets", response_model=List[SubnetResponse])
async def get_subnets(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    is_active: Optional[bool] = None,
    db: Session = Depends(get_db)
):
    """서브넷 목록 조회"""
    query = db.query(Subnet)
    
    if is_active is not None:
        query = query.filter(Subnet.is_active == is_active)
    
    subnets = query.order_by(Subnet.created_at.desc()).offset(skip).limit(limit).all()
    
    result = []
    for subnet in subnets:
        subnet_dict = {
            "id": subnet.id,
            "name": subnet.name,
            "network": subnet.network,
            "description": subnet.description,
            "vlan_id": subnet.vlan_id,
            "location": subnet.location,
            "is_active": subnet.is_active,
            "created_at": subnet.created_at,
            "updated_at": subnet.updated_at,
            "network_info": subnet.get_network_info()
        }
        result.append(subnet_dict)
    
    return result

@router.get("/subnets/{subnet_id}", response_model=SubnetResponse)
async def get_subnet(subnet_id: int, db: Session = Depends(get_db)):
    """특정 서브넷 조회"""
    subnet = db.query(Subnet).filter(Subnet.id == subnet_id).first()
    if not subnet:
        raise HTTPException(status_code=404, detail="서브넷을 찾을 수 없습니다")
    
    subnet_dict = {
        "id": subnet.id,
        "name": subnet.name,
        "network": subnet.network,
        "description": subnet.description,
        "vlan_id": subnet.vlan_id,
        "location": subnet.location,
        "is_active": subnet.is_active,
        "created_at": subnet.created_at,
        "updated_at": subnet.updated_at,
        "network_info": subnet.get_network_info()
    }
    return subnet_dict

@router.post("/subnets", response_model=SubnetResponse, status_code=201)
async def create_subnet(subnet: SubnetCreate, db: Session = Depends(get_db)):
    """새 서브넷 생성"""
    # CIDR 형식 검증
    try:
        ipaddress.ip_network(subnet.network, strict=False)
    except ValueError:
        raise HTTPException(status_code=400, detail="유효하지 않은 네트워크 형식입니다")
    
    # 중복 확인
    existing = db.query(Subnet).filter(Subnet.network == subnet.network).first()
    if existing:
        raise HTTPException(status_code=400, detail="이미 존재하는 네트워크입니다")
    
    db_subnet = Subnet(**subnet.dict())
    db.add(db_subnet)
    db.commit()
    db.refresh(db_subnet)
    
    subnet_dict = {
        "id": db_subnet.id,
        "name": db_subnet.name,
        "network": db_subnet.network,
        "description": db_subnet.description,
        "vlan_id": db_subnet.vlan_id,
        "location": db_subnet.location,
        "is_active": db_subnet.is_active,
        "created_at": db_subnet.created_at,
        "updated_at": db_subnet.updated_at,
        "network_info": db_subnet.get_network_info()
    }
    return subnet_dict

@router.put("/subnets/{subnet_id}", response_model=SubnetResponse)
async def update_subnet(
    subnet_id: int,
    subnet_update: SubnetUpdate,
    db: Session = Depends(get_db)
):
    """서브넷 정보 수정"""
    db_subnet = db.query(Subnet).filter(Subnet.id == subnet_id).first()
    if not db_subnet:
        raise HTTPException(status_code=404, detail="서브넷을 찾을 수 없습니다")
    
    update_data = subnet_update.dict(exclude_unset=True)
    for field, value in update_data.items():
        setattr(db_subnet, field, value)
    
    db.commit()
    db.refresh(db_subnet)
    
    subnet_dict = {
        "id": db_subnet.id,
        "name": db_subnet.name,
        "network": db_subnet.network,
        "description": db_subnet.description,
        "vlan_id": db_subnet.vlan_id,
        "location": db_subnet.location,
        "is_active": db_subnet.is_active,
        "created_at": db_subnet.created_at,
        "updated_at": db_subnet.updated_at,
        "network_info": db_subnet.get_network_info()
    }
    return subnet_dict

@router.delete("/subnets/{subnet_id}", status_code=204)
async def delete_subnet(subnet_id: int, db: Session = Depends(get_db)):
    """서브넷 삭제"""
    db_subnet = db.query(Subnet).filter(Subnet.id == subnet_id).first()
    if not db_subnet:
        raise HTTPException(status_code=404, detail="서브넷을 찾을 수 없습니다")
    
    db.delete(db_subnet)
    db.commit()
    return None

@router.get("/subnets/{subnet_id}/stats")
async def get_subnet_stats(subnet_id: int, db: Session = Depends(get_db)):
    """서브넷 통계 정보"""
    subnet = db.query(Subnet).filter(Subnet.id == subnet_id).first()
    if not subnet:
        raise HTTPException(status_code=404, detail="서브넷을 찾을 수 없습니다")
    
    network_info = subnet.get_network_info()
    if not network_info:
        raise HTTPException(status_code=400, detail="네트워크 정보를 가져올 수 없습니다")
    
    # IP 할당 통계
    total_ips = db.query(IPAddress).filter(IPAddress.subnet_id == subnet_id).count()
    allocated_ips = db.query(IPAddress).filter(
        IPAddress.subnet_id == subnet_id,
        IPAddress.is_allocated == True
    ).count()
    
    return {
        "subnet_id": subnet_id,
        "network": subnet.network,
        "network_info": network_info,
        "total_ips": total_ips,
        "allocated_ips": allocated_ips,
        "available_ips": network_info["usable_hosts"] - allocated_ips,
        "utilization_percent": round((allocated_ips / network_info["usable_hosts"] * 100), 2) if network_info["usable_hosts"] > 0 else 0
    }


