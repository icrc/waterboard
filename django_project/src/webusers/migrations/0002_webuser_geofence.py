# -*- coding: utf-8 -*-
# Generated by Django 1.11.9 on 2018-01-17 21:46
from __future__ import unicode_literals

import django.contrib.gis.db.models.fields
from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ('webusers', '0001_initial'),
    ]

    operations = [
        migrations.AddField(
            model_name='webuser',
            name='geofence',
            field=django.contrib.gis.db.models.fields.PolygonField(blank=True, null=True, srid=4326),
        ),
    ]