#!/bin/bash

COMPOSE_FILES=(
  "./docker-compose.yml"
  "./superset/docker-compose-non-dev.yml"
)

git clone --depth=1  https://github.com/apache/superset.github
cd superset

for file in "${COMPOSE_FILES[@]}"; do
  echo "Запуск $file"
  docker-compose -f "$file" up -d
done
