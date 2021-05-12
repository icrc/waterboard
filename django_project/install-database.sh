cd "$(dirname "$0")"
DOCKER_ID=`docker-compose ps -q waterboard-web`
docker exec -i $DOCKER_ID  sh /install-database.sh
