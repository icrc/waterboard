#!/bin/bash

#psql -U $PGUSER -h $PGHOST --port $PGPORT --dbname 'postgres' <<EOF
#drop database $PGDATABASE;
#create database $PGDATABASE;
#EOF


#
#source /home/kknezevic/venv/hcid_env/bin/activate
#cd /home/kknezevic/waterboard/django_project
python3 manage.py migrate

psql -U $PGUSER -h $PGHOST --port $PGPORT --dbname $PGDATABASE <<EOF
\i /code/sql_scripts/00_import_raw_data_tigray.sql
\i /code/sql_scripts/10_features_schema.sql
\i /code/sql_scripts/20_core_utils_schema.sql
\i /code/sql_scripts/22_core_load_attribute.sql
\i /code/sql_scripts/25_core_utils_dashboard.sql
\i /code/sql_scripts/30_load_data.sql
\i /code/sql_scripts/40_simulate_history_data.sql
EOF
