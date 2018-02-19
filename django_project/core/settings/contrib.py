# -*- coding: utf-8 -*-
from __future__ import absolute_import, division, print_function, unicode_literals

from .base import *  # NOQA

# Extra installed apps
INSTALLED_APPS += (
    'raven.contrib.django.raven_compat',  # enable Raven plugin
    'pipeline',
    'celery',
    'django_forms_bootstrap',
    'leaflet'
)

# enable cached storage
STATICFILES_STORAGE = 'pipeline.storage.PipelineCachedStorage'

# TODO cleanup after new dashboard is done
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
                'js/bootstrap-3.3.7.js',
                'js/bootstrap-multiselect.js',
                'js/moment.js',
                'js/bootstrap-datetimepicker.js',
                'js/csrf-ajax.js',
                'js/libs/leaflet/leaflet.js',
                'js/libs/leaflet/Leaflet.Editable.js',
                'js/libs/leaflet/leaflet-bing-layer.min.js',
                'js/wb.base.js',
                'js/wb.utils.js',
                'js/wb.api.js',
                'js/wb.utils.d3.js'
            ),
            'output_filename': 'js/contrib.js',
        },
        'dashboards': {
            'source_filenames': (
                'js/wb.map.js',
                'js/wb.chart.js',
                'js/wb.chart.donut.js',
                'js/wb.chart.pie.js',
                'js/wb.chart.line.js',
                'js/wb.chart.bar.js',
                'js/wb.chart.horizontalbar.js',
                'js/wb.feature-detail.js',
                'js/wb.dashboard.charts.js',
                'js/wb.dashboard.configs.js',
            ),
            'output_filename': 'js/dashboards.js'
        },
        'featuredetail': {
            'source_filenames': (
                'js/libs/DataTables/DataTables-1.10.16/js/jquery.dataTables.js',
                'js/libs/DataTables/DataTables-1.10.16/js/dataTables.bootstrap.js',
                'js/wb.feature-detail.js',
                'js/wb.modal.js',
                'js/wb.table-report.js'
            ),
            'output_filename': 'js/feature_details.js'
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
                'css/font-awesome-4.7.0/css/font-awesome.min.css',
                'js/libs/leaflet/leaflet.css',
                'css/wb.base.css',
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
        'dashboards': {
            'source_filenames': (
                'css/wb.chart.css',
                'dashboards/css/wb.dashboards.css',
            ),
            'output_filename': 'css/wb.dashboards.css'
        },
        'features': {
            'source_filenames': (
                'css/wb.modal.css',
                'js/libs/DataTables/DataTables-1.10.16/css/dataTables.bootstrap.css',
                'css/table-data-report.css',
                'features/css/wb.features.css',
            ),
            'output_filename': 'css/wb.features.css'
        }
    }
}
