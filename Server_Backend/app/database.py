"""
Database configuration and connection management
Async SQLAlchemy setup for PostgreSQL
"""
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase
from sqlalchemy import MetaData
import logging

from app.config import get_settings

logger = logging.getLogger(__name__)

# Database metadata and base
class Base(DeclarativeBase):
    """Base class for all database models"""
    metadata = MetaData(
        naming_convention={
            "ix": "ix_%(column_0_label)s",
            "uq": "uq_%(table_name)s_%(column_0_name)s",
            "ck": "ck_%(table_name)s_%(constraint_name)s",
            "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
            "pk": "pk_%(table_name)s"
        }
    )

# Global engine and session maker
engine = None
AsyncSessionLocal = None

def create_engine():
    """Create database engine"""
    global engine, AsyncSessionLocal

    settings = get_settings()

    engine = create_async_engine(
        settings.database_url,
        echo=settings.database_echo,
        pool_pre_ping=True,
        pool_recycle=300,
        future=True
    )

    AsyncSessionLocal = async_sessionmaker(
        engine, 
        class_=AsyncSession, 
        expire_on_commit=False
    )

    logger.info("Database engine created")
    return engine

async def init_db():
    """Initialize database tables"""
    global engine
    if engine is None:
        create_engine()

    # Import all models to ensure they're registered
    from app.models import device, sensor_data, user

    async with engine.begin() as conn:
        # Create all tables
        await conn.run_sync(Base.metadata.create_all)

    logger.info("Database tables initialized")

async def get_db() -> AsyncSession:
    """Dependency for getting database session"""
    if AsyncSessionLocal is None:
        create_engine()

    async with AsyncSessionLocal() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()
