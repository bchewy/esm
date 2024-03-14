#!/bin/bash
# install docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh ./get-docker.sh

# allow daemon access for other non-root users
sudo usermod -a -G docker ubuntu
id ubuntu
newgrp docker

# get latest docker-compose (from s3; but ideally if the repo is pub we can just pull from the repo..)
cd /home/ubuntu
wget https://bchewy.s3.ap-southeast-1.amazonaws.com/docker-compose.yml
wget -O dump.dump https://bchewy.s3.ap-southeast-1.amazonaws.com/Odoo+CRM+dump+Mar+14+2024.dump
docker compose up --build -d

# Rest till docker-compose is up; 5 mins
sleep 360

# Create postgres database, user and restore the dump
# docker exec -it ubuntu-db-1 psql -U odoo -c 'CREATE DATABASE odoo_actual;'
# docker exec -it ubuntu-db-1 psql -U odoo -c "CREATE ROLE odoo16 WITH LOGIN;"
# docker exec -i ubuntu-db-1 pg_restore -U odoo -d odoo_actual < dump.dump

docker exec ubuntu-db-1 psql -U odoo -c 'CREATE DATABASE odoo_actual;'
docker exec ubuntu-db-1 psql -U odoo -c "CREATE ROLE odoo16 WITH LOGIN;"
cat dump.dump | docker exec -i ubuntu-db-1 pg_restore -U odoo -d odoo_actual

# didnt work in 
# docker exec ubuntu-db-1 pg_restore -U odoo -d odoo_actual < dump.dump

