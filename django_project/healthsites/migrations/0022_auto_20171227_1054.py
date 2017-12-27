# -*- coding: utf-8 -*-
# Generated by Django 1.11.8 on 2017-12-27 09:54
from __future__ import unicode_literals

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('healthsites', '0021_pg_get_events'),
    ]

    operations = [
        migrations.RemoveField(
            model_name='assessmentcriteria',
            name='assessment_group',
        ),
        migrations.RemoveField(
            model_name='healthsiteassessmententrydropdown',
            name='assessment_criteria',
        ),
        migrations.RemoveField(
            model_name='healthsiteassessmententrydropdown',
            name='healthsite_assessment',
        ),
        migrations.RemoveField(
            model_name='healthsiteassessmententryinteger',
            name='assessment_criteria',
        ),
        migrations.RemoveField(
            model_name='healthsiteassessmententryinteger',
            name='healthsite_assessment',
        ),
        migrations.RemoveField(
            model_name='healthsiteassessmententryreal',
            name='assessment_criteria',
        ),
        migrations.RemoveField(
            model_name='healthsiteassessmententryreal',
            name='healthsite_assessment',
        ),
        migrations.RemoveField(
            model_name='resultoption',
            name='assessment_criteria',
        ),
        migrations.AlterField(
            model_name='healthsiteassessment',
            name='overall_assessment',
            field=models.IntegerField(),
        ),
        migrations.DeleteModel(
            name='AssessmentCriteria',
        ),
        migrations.DeleteModel(
            name='AssessmentGroup',
        ),
        migrations.DeleteModel(
            name='HealthsiteAssessmentEntryDropDown',
        ),
        migrations.DeleteModel(
            name='HealthsiteAssessmentEntryInteger',
        ),
        migrations.DeleteModel(
            name='HealthsiteAssessmentEntryReal',
        ),
        migrations.DeleteModel(
            name='ResultOption',
        ),
    ]
