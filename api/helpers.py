# -*- coding: utf-8 -*-

import random
import redis
from flask import g

from . import app


CHARS = 'abcdefghijklmnoprstuwqxyzABCDEFGHIJKLMNOPRSTUWXYZ0123456789'
redis_pool = redis.ConnectionPool(host='localhost', port=6379, db=0)

@app.before_request
def before_request():
    g.redis = redis.Redis(connection_pool=redis_pool)

def gen_filename(chars=12):
    return ''.join(random.sample(CHARS, chars))

def stringify_class(obj, one=None):
    restricted = ['id', 'disabled', 'added_quota']
    if isinstance(obj, dict):
        ret = {}
        for el in obj:
            ret[el] = stringify_class(obj[el])
    elif isinstance(obj, list):
        ret = []
        for el in obj:
            ret.append(stringify_class(el))
    elif isinstance(obj, str) or isinstance(obj, unicode) or\
            isinstance(obj, int) or isinstance(obj, long):
        ret = obj

    else:
        ret = {}
        for el in obj.__dict__:
            # We don't want to publish private ids
            if el in restricted or el[0] == '_':
                continue
            if isinstance(obj.__dict__[el], datetime):
                ret[el] = unicode(obj.__dict__[el])
            elif isinstance(obj.__dict__[el], state.InstanceState):
                continue
            elif isinstance(obj.__dict__[el], list):
                prop = []
                for element in obj.__dict__[el]:
                    prop.append(stringify_class(element))
                ret[el] = prop
            elif hasattr(obj.__dict__[el], '__dict__'):
                ret[el] = stringify_class(obj.__dict__[el])
            else:
                ret[el] = obj.__dict__[el]

    return ret

def class_spec(instance, restricted=[]):
    restricted = ['id', 'disabled']

    ret = {}
    for key in instance.__dict__:
        if key not in restricted and key[0] != '_':
            ret[key] = instance.__dict__[key].__class__.__name__

    return ret
