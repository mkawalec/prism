# coding=utf-8
from flask import (Flask, request, redirect, url_for, abort,
        render_template, flash, jsonify, g, session, send_file)

from datetime import timedelta, datetime

from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import joinedload
from sqlalchemy.orm.exc import NoResultFound

from flask.ext.classy import FlaskView
import redis
   
app = Flask(__name__)
app.config.from_object('api.configs.default')

from .models import Signature, ConfCode
from .database import db_session

redis_pool = redis.ConnectionPool(host='localhost', port=6379, db=0)

@app.before_request
def before_request():
    g.redis = redis.Redis(connection_pool=redis_pool)

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
        offset = request.args.get('offset')
        if not offset or offset < 0:
            offset = 0

        rv = redis.get('signatures'+offset)
        if not rv:
            signatures = db_session.query(Signature).\
                    filter(Signature.confirmed == True).\
                    offset(offset).limit(300).all()
            amount = db_session.query(Signature).\
                    filter(Signature.confirmed == True).\
                    count()
            rv = dict(signatures=signatures, amount=amount)

            redis.setex('signatures'+offset, rv, 60)
        return jsonify(strigify_class(rv))

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

SignaturesView.register(app)
