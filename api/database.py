from sqlalchemy import create_engine
from sqlalchemy.orm import scoped_session, sessionmaker
from sqlalchemy.ext.declarative import declarative_base

from api import app


engine = create_engine('postgresql+psycopg2://postgres@localhost/' + app.config['DB'],
    max_overflow=20,
    isolation_level='READ UNCOMMITTED')
db_session = scoped_session(sessionmaker(autocommit=False,
                                         autoflush=False,
                                         bind=engine))

Base = declarative_base()
Base.query = db_session.query_property()

def rebind():
    engine = create_engine('postgresql+psycopg2://postgres@localhost/' 
            + app.config['DB'])
    db_session = scoped_session(sessionmaker(autocommit=False,
                                     autoflush=False,
                                     bind=engine))

def init_db():
    # import all modules here that might define models so that
    # they will be registered properly on the metadata.  Otherwise
    # you will have to import them first before calling init_db()
    import api.models

    Base.metadata.create_all(engine)

    # then, load the Alembic configuration and generate the
    # version table, "stamping" it with the most recent rev:
    from alembic.config import Config
    from alembic import command
    alembic_cfg = Config("alembic.ini")
    command.stamp(alembic_cfg, "head") 
