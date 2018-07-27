import csv
import os
import shutil
import tempfile
import time
from io import StringIO

import fiona
from django.db import connection
from django.http import HttpResponse
from django.views import View
from xlsxlite.writer import XLSXBook

from django.contrib.gis.geos import WKBReader

from common.mixins import LoginRequiredMixin


class CSVDownload(LoginRequiredMixin, View):

    def get(self, request, *args, **kwargs):

        with connection.cursor() as cur:
            cur.execute("""
                select * from  core_utils.export_all()
            """)

            query = cur.fetchone()[0]

            filename = 'waterpoints_{}.csv'. format(time.strftime('%Y%m%d_%H%M%S', time.gmtime()))

            response = HttpResponse(content_type='text/csv')
            response['Content-Disposition'] = 'attachment; filename="{}"'.format(filename)

            cur.copy_expert(query, response)

            return response


class SHPDownload(LoginRequiredMixin, View):

    def get(self, request, *args, **kwargs):

        tempdir = tempfile.mkdtemp()

        export_time = time.strftime('%Y%m%d_%H%M%S', time.gmtime())

        with connection.cursor() as cur:
            cur.execute("""
                select * from  core_utils.export_all()
            """)

            query = cur.fetchone()[0]
            data_buffer = StringIO()
            cur.copy_expert(query, data_buffer)

        # rewind the io object
        data_buffer.seek(0)

        point_data = csv.reader(data_buffer)

        header = next(point_data)
        # skip the first field, point_geom, trim to 10chars (SHP file limitation)
        properties = [prop.upper()[:10] for prop in header[1:]]

        # define basic geometry file properties
        ogr_driver = 'ESRI Shapefile'
        crs = {'no_defs': True, 'ellps': 'WGS84', 'datum': 'WGS84', 'proj': 'longlat'}
        schema = {
            'geometry': 'Point',
            'properties': {
                prop: 'str' for prop in properties
            }
        }

        shp_filename = os.path.join(tempdir, 'waterpoints_{}.shp'.format(export_time))

        wkb_r = WKBReader()

        with fiona.open(shp_filename, 'w', driver=ogr_driver, crs=crs, schema=schema, encoding='utf-8') as new_shp:
            for fields in point_data:
                rec = dict()

                rec['geometry'] = {u'type': u'Point', u'coordinates': wkb_r.read(bytes(fields[0], 'ascii')).coords}

                rec['properties'] = {
                    properties[idx]: value for idx, value in enumerate(fields[1:], start=0)
                }

                new_shp.write(record=rec)

        # zip the directory
        zip_filename = shutil.make_archive(tempfile.mktemp(), 'zip', tempdir)

        response = HttpResponse(open(zip_filename, 'rb'), content_type='application/zip')
        response['Content-Disposition'] = 'attachment; filename="waterpoints_{}.zip"'.format(export_time)

        return response


class XLSXDownload(LoginRequiredMixin, View):

    def get(self, request, *args, **kwargs):

        with connection.cursor() as cur:
            cur.execute("""
                select * from  core_utils.export_all()
            """)
            query = cur.fetchone()[0]
            data_buffer = StringIO()
            cur.copy_expert(query, data_buffer)

            cur.execute("""
                 SELECT attributes_attribute.key, attributes_attribute.result_type FROM public.attributes_attribute
                                                """)
            key_result_type = cur.fetchall()

        data_buffer.seek(0)

        csv_reader = csv.reader(data_buffer, dialect='excel')

        book = XLSXBook()
        sheet1 = book.add_sheet('waterpoints')
        header = next(csv_reader)
        sheet1.append_row(*header)

        keys = []
        result_types = []
        for item in key_result_type:
            keys.append(item[0])
            result_types.append(item[1])

        header_type = []
        for item in header:
            if item in keys:
                Type = result_types[keys.index(item)]
                if Type == 'DropDown' or Type == 'Text':
                    header_type.append('str')
                elif Type == 'Decimal':
                    header_type.append('dec')
                elif Type == 'Integer':
                    header_type.append('int')
                else:
                    header_type.append('str')
            else:
                header_type.append('str')

        for row in csv_reader:
            for ind, cell in enumerate(row):
                if header_type[ind] == 'int' and cell != '':
                    row[ind] = int(cell)
                elif header_type[ind] == 'dec' and cell != '':
                    row[ind] = float(cell)
            sheet1.append_row(*row)

        filename = 'waterpoints_{}.xlsx'.format(time.strftime('%Y%m%d_%H%M%S', time.gmtime()))
        response = HttpResponse(content_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
        response['Content-Disposition'] = 'attachment; filename="{}"'.format(filename)
        book.finalize(to_file=response)

        return response

