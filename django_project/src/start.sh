#!/bin/sh
echo "Wait for database"
/wait-for-it.sh "$PGHOST":"$PGPORT"
echo "Start Waterboard website"
python3 manage.py runserver 0.0.0.0:8000
