/wait-for-it.sh "$PGHOST":"$PGPORT"
python3 manage.py runserver 0.0.0.0:8000
