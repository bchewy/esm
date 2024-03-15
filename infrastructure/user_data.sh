#!/bin/bash
# install docker on host machine, set up
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh ./get-docker.sh
sudo usermod -a -G docker ubuntu
id ubuntu
newgrp docker

# CHANGE TO UBUNTU DIRECTORY, DOWNLOAD DOCKER-COMPOSE FILE AND DUMP
cd /home/ubuntu
wget https://bchewy.s3.ap-southeast-1.amazonaws.com/docker-compose.yml
# TODO: Applicaiton Team to replace dump.dump with the latest dump on March 19.
wget -O dump.dump https://bchewy.s3.ap-southeast-1.amazonaws.com/Odoo+CRM+dump+Mar+14+2024.dump
docker compose up --build -d

# Rest till docker-compose is up; 5 mins - needs time to deploy
sleep 360

docker exec ubuntu-db-1 psql -U odoo -c 'CREATE DATABASE odoo_actual;'
docker exec ubuntu-db-1 psql -U odoo -c "CREATE ROLE odoo16 WITH LOGIN;"
cat dump.dump | docker exec -i ubuntu-db-1 pg_restore -U odoo -d odoo_actual

