# -*- coding: utf-8 -*-
from __future__ import absolute_import, division, print_function, unicode_literals

from .base import *  # NOQA

# Extra installed apps
INSTALLED_APPS += (
    'raven.contrib.django.raven_compat',  # enable Raven plugin
    'pipeline',
    'celery',
    'django_forms_bootstrap'
)

# enable cached storage
STATICFILES_STORAGE = 'pipeline.storage.PipelineCachedStorage'


PIPELINE = {
    # Don't actually try to compress with pipeline
    'CSS_COMPRESSOR': 'pipeline.compressors.NoopCompressor',
    'JS_COMPRESSOR': 'pipeline.compressors.NoopCompressor',
    # bad bad bad Javascript
    'DISABLE_WRAPPER': True,

    'JAVASCRIPT': {
        'contrib': {
            'source_filenames': (
                'js/libs/lodash.min.js',
                'js/jquery-2.2.4.js',
                'js/libs/jquery-ui.min.js',
                # 'js/bootstrap-3.3.7.js',
                # 'js/bootstrap-multiselect.js',
                'js/moment.js',
                'js/bootstrap-datetimepicker.js',
                'js/csrf-ajax.js',
                'js/libs/leaflet/leaflet.js',
                'js/libs/leaflet/Leaflet.Editable.js',
                'js/wb.utils.js'
            ),
            'output_filename': 'js/contrib.js',
        },
        'browser': {
            'source_filenames': (
                'js/browser.index.js',

            ),
            'output_filename': 'js/browser.js'
        },

        'feature': {
            'source_filenames': (
                'js/browser.index.js',
                'js/add_event.js',
            ),
            'output_filename': 'js/feature.js'
        },
        'features': {
            'source_filenames': (
                'js/wb.chart.pie.js',
            ),
            'output_filename': 'js/features.js'
        },
        'table_data_report': {
            'source_filenames': (
                'js/event_mapper.js',
                'js/libs/DataTables/DataTables-1.10.16/js/jquery.dataTables.js',
                'js/libs/DataTables/DataTables-1.10.16/js/dataTables.bootstrap.js',
                'js/wb.modal.js',
                'js/wb.table-report.js',

            ),
            'output_filename': 'js/table_data_report.js'
        }
    },
    'STYLESHEETS': {
        'contrib': {
            'source_filenames': (
                'css/bootstrap-3.3.7.css',
                'css/jquery-ui.css',
                'css/bootstrap-datetimepicker.css',
            ),
            'output_filename': 'css/contrib.css',
            'extra_context': {
                'media': 'screen, projection',
            }
        },
        'table_data_report_css': {
            'source_filenames': (
                'css/wb.modal.css',
                'js/libs/DataTables/DataTables-1.10.16/css/dataTables.bootstrap.css',
                'css/table-data-report.css',
            ),
            'output_filename': 'css/table_data_report_css.css'
        },
        'features': {
            'source_filenames': (
                'css/wb.chart.css',
            ),
            'output_filename': 'css/wb.features.css'
        },
        'event_mapper_css': {
            'source_filenames': (
                'js/libs/leaflet/leaflet.css',
                'css/jquery-ui.css',
                'css/material-wfont.min.css',
                'css/event_mapper.css',
            ),
            'output_filename': 'css/event_mapper_css.css',
        }
    }
}
