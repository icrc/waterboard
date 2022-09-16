# -*- coding: utf-8 -*-
# Generated by Django 1.11.12 on 2018-05-01 12:32
from __future__ import unicode_literals

from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('attributes', '0005_auto_20180116_2210'),
    ]

    operations = [
        migrations.AlterField(
            model_name='attribute',
            name='attribute_group',
            field=models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='attributes', to='attributes.AttributeGroup'),
        ),
    ]