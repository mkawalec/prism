# -*- coding: utf-8 -*-

import random

CHARS = 'abcdefghijklmnoprstuwqxyzABCDEFGHIJKLMNOPRSTUWXYZ0123456789'

def gen_filename(chars=12):
    return ''.join(random.sample(CHARS, chars))

