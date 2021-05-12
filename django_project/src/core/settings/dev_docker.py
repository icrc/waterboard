# -*- coding: utf-8 -*-
from __future__ import absolute_import, division, print_function, unicode_literals

from .dev import *  # noqa

DATABASES = {
    'default': {
        'ENGINE': 'django.contrib.gis.db.backends.postgis',
        'NAME': os.environ['PGDATABASE'],
        'USER': os.environ['PGUSER'],
        'PASSWORD': os.environ['PGPASSWORD'],
        'HOST': os.environ['PGHOST'],
        # Set to empty string for default.
        'PORT': os.environ['PGPORT'],
    }
}

GEOS_LIBRARY_PATH = '/usr/lib/libgeos_c.so.1'

POSTGIS_VERSION = (2, 4, 0)
