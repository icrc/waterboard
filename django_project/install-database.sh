# Warning not working with Git bash
# use power shell version
cd "$(dirname "$0")"
docker-compose exec waterboard-web sh /code/install-database.sh

