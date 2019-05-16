# Generated by Django 2.1.8 on 2019-04-25 21:36

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('attributes', '0010_auto_20181103_2221'),
    ]

    operations = [
        migrations.AlterField(
            model_name='attribute',
            name='max_length',
            field=models.PositiveIntegerField(blank=True, help_text='Maximum length', null=True),
        ),
        migrations.AlterField(
            model_name='attribute',
            name='max_value',
            field=models.FloatField(blank=True, help_text='Maximum value', null=True),
        ),
        migrations.AlterField(
            model_name='attribute',
            name='min_value',
            field=models.FloatField(blank=True, help_text='Minimum value', null=True),
        ),
        migrations.AlterField(
            model_name='attribute',
            name='result_type',
            field=models.CharField(choices=[('Integer', 'Integer'), ('Decimal', 'Decimal'), ('Text', 'Text'), ('Attachment', 'Attachment'), ('DropDown', 'DropDown')], max_length=16),
        ),
        migrations.AlterUniqueTogether(
            name='attributeoption',
            unique_together={('attribute', 'option')},
        ),
    ]