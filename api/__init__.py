# coding=utf-8
from flask import (Flask, request, redirect, url_for, abort,
        jsonify, g)

from datetime import timedelta, datetime

from sqlalchemy import desc
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import joinedload
from sqlalchemy.orm.exc import NoResultFound

from flask.ext.classy import FlaskView
   
app = Flask(__name__)
app.config.from_object('api.configs.default')

from .models import Signature, ConfCode
from .database import db_session
from .helpers import stringify_class, class_spec

@app.route('/')
def home():
    return '42'

@app.route('/confirm/<code_id>', methods=['POST'])
def confirm(code_id):
    try:
        code = db_session.query(ConfCode).\
                option(joinedload(ConfCode.signature)).\
                filter(ConfCode.string_id == code_id).\
                one()
    except NoResultFound:
        abort(404)

    code.disabled = True
    code.signature.confirmed = True

    try:
        db_session.commit()
        return jsonify(staus='succ')
    except IntegrityError:
        db_session.rollback()
        abort(500)

class SignaturesView(FlaskView):

    def index(self):
        key_prefix = 'signatures-'
        after = request.args.get('after')
        after = after if after else 'empty'

        rv = g.redis.get(key_prefix+after)
        if not rv:
            signatures = db_session.query(Signature).\
                    filter(Signature.confirmed == True)

            if after:
                stmt = db_session.query(Signature.id).\
                    filter(Signature.string_id == after).\
                    subquery()

                signatures = signatures.\
                        filter(Signature.id > stmt.c.id)
            signatures = signatures.\
                order_by(desc(Signature.timestamp)).\
                limit(300).all()
            amount = int(db_session.query(Signature).\
                    filter(Signature.confirmed == True).\
                    count())

            rv = dict(signatures=signatures, amount=amount)
            g.redis.setex(key_prefix+after, rv, 60)
        return jsonify(stringify_class(rv))

    def get(self, id):
        try:
            signature = db_session.query(Signature).\
                    filter(Signature.confirmed == True).\
                    filter(Signature.string_id == id).\
                    one()
        except NoResultFound:
            abort(404)
        return jsonify(stringify_class(rv))

    def post(self):
        f = request.form
        if 'name' not in f or 'email' not in f:
            abort(409)

        sig = Signature(f['name'], f['email'], f['comment'])
        db_session.add(sig)
        db_session.flush()

        sig.codes.append(Code())
        db_session.commit()

    def spec(self):
        sig = Signature('test', 'test', 'test')
        return jsonify(class_spec(sig))

SignaturesView.register(app)
