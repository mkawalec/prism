# coding=utf-8
from flask import (Flask, request, redirect, url_for, abort,
        jsonify, g)

from datetime import timedelta, datetime

from sqlalchemy import desc
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import joinedload
from sqlalchemy.orm.exc import NoResultFound

from flask.ext.classy import FlaskView, route
   
app = Flask(__name__)
app.config.from_object('api.configs.default')

from .models import Signature, ConfCode
from .database import db_session
from .helpers import stringify_class, class_spec

from crossdomain import crossdomain

import pickle

@app.route('/')
def home():
    return '42'

@app.route('/confirm/<code_id>', methods=['POST'])
@crossdomain(origin='*')
def confirm(code_id):
    try:
        code = db_session.query(ConfCode).\
                options(joinedload(ConfCode.signature)).\
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

    @crossdomain(origin='*')
    def index(self):
        key_prefix = 'signatures-'
        after = request.args.get('after')
        after = after if after else 'empty'

        limit = request.args.get('limit')
        try:
            limit = int(limit)
            if limit > 300:
                limit = 300
        except (ValueError, TypeError):
            limit = 300

        rv = g.redis.get(key_prefix+after)
        if not rv:
            signatures = db_session.query(Signature).\
                    filter(Signature.confirmed == True)

            if after != 'empty':
                stmt = db_session.query(Signature.id).\
                    filter(Signature.string_id == after).\
                    subquery()

                signatures = signatures.\
                        filter(Signature.id > stmt.c.id)
            signatures = signatures.\
                order_by(desc(Signature.timestamp)).\
                limit(limit).all()
            amount = int(db_session.query(Signature).\
                    filter(Signature.confirmed == True).\
                    count())

            rv = dict(data=signatures, amount=amount)
            g.redis.setex(key_prefix+after, pickle.dumps(rv), 60)
        else:
            rv = pickle.loads(rv)
        return jsonify(stringify_class(rv))

    @route('/<id>')
    @crossdomain(origin='*')
    def get(self, id):
        try:
            signature = db_session.query(Signature).\
                    filter(Signature.confirmed == True).\
                    filter(Signature.string_id == id).\
                    one()
        except NoResultFound:
            abort(404)
        return jsonify(stringify_class(rv))

    @crossdomain(origin='*')
    def post(self):
        f = request.form
        if 'name' not in f or 'email' not in f:
            abort(409)

        sig = Signature(f['name'], f['email'], f['comment'])
        db_session.add(sig)
        try:
            db_session.flush()
        except IntegrityError:
            db_session.rollback()
            abort(403)

        sig.codes.append(ConfCode())
        db_session.commit()

        sig.string_id
        return jsonify(data=stringify_class(sig))

    @crossdomain(origin='*')
    def spec(self):
        sig = Signature('test', 'test', 'test')
        return jsonify(data=class_spec(sig))

SignaturesView.register(app)
