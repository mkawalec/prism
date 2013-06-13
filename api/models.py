from sqlalchemy import (Column, Integer, BigInteger, 
        String, DateTime, Boolean, Sequence, ForeignKey, 
        Table, desc, Numeric)
from sqlalchemy.orm import relationship, backref
from .database import Base
from .helpers import gen_filename
from . import app

from datetime import datetime
from hashlib import sha256


class Boilerplate(object):
    string_id = Column(String(12), unique=True, index=True)
    timestamp = Column(DateTime())
    edition_timestamp = Column(DateTime())
    disabled = Column(Boolean)

    def __init__(self):
        self.string_id = gen_filename()
        self.timestamp = datetime.now()
        self.edition_timestamp = self.timestamp
        self.disabled = False

        # TODO: Add checking for exisence of that string_id

    def __setattr__(self, name, value):
        self.__dict__['edition_timestamp'] = datetime.now()
        Base.__setattr__(self, name, value)
        self.__dict__[name] = value

    def edited(self):
        self.edition_timestamp = datetime.now()

class Signature(Boilerplate, Base):
    __tablename__ = 'signatures'
    id = Column(Integer, Sequence('signatures_id_seq'),
            primary_key=True, index=True)

    name = Column(String(200))
    email = Column(String(300), unique=True)
    comment = Column(String(160))

    confirmed = Column(Boolean)

    def __init__(self, name, email, comment=None):
        self.name = name
        self.email = email
        self.comment = comment

        self.confirmed = False

    def __repr__(self):
        return '<Signature %s>' % (self.name)


class ConfCode(Boilerplate, Base):
    __tablename__ = 'confirmation_codes'
    id = Column(Integer, Sequence('confirmation_codes_id_seq'),
            primary_key=True, index=True)

    signature_id = Column(Integer, ForeignKey('signatures.id'))
    signature = relationship("Signature", 
            backref=backref('codes', order_by=id))

    def __repr__(self):
        return '<ConfirmationCode %s>' % (self.string_id)
