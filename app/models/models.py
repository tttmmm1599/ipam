"""
데이터베이스 모델 정의
"""
from sqlalchemy import Column, Integer, String, DateTime, Boolean, Text
from sqlalchemy.sql import func
from app.models.database import Base
import ipaddress

class Subnet(Base):
    """서브넷 모델"""
    __tablename__ = "subnets"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False, index=True)
    network = Column(String(50), nullable=False, unique=True, index=True)  # CIDR 형식 (예: 192.168.1.0/24)
    description = Column(Text, nullable=True)
    vlan_id = Column(Integer, nullable=True)
    location = Column(String(255), nullable=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    def __repr__(self):
        return f"<Subnet(name='{self.name}', network='{self.network}')>"

    def get_network_info(self):
        """네트워크 정보 반환"""
        try:
            net = ipaddress.ip_network(self.network, strict=False)
            return {
                "network": str(net.network_address),
                "netmask": str(net.netmask),
                "broadcast": str(net.broadcast_address),
                "hosts": net.num_addresses,
                "usable_hosts": net.num_addresses - 2,  # 네트워크 주소와 브로드캐스트 제외
                "prefix": net.prefixlen
            }
        except ValueError:
            return None

class IPAddress(Base):
    """IP 주소 모델"""
    __tablename__ = "ip_addresses"

    id = Column(Integer, primary_key=True, index=True)
    subnet_id = Column(Integer, nullable=False, index=True)
    ip_address = Column(String(50), nullable=False, index=True)
    hostname = Column(String(255), nullable=True)
    description = Column(Text, nullable=True)
    is_allocated = Column(Boolean, default=False)
    allocated_to = Column(String(255), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    def __repr__(self):
        return f"<IPAddress(ip_address='{self.ip_address}', allocated={self.is_allocated})>"


