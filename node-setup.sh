#!/bin/bash
#
# Script to setup five node web voting application. Node is taken as a paramter.
# Check if a parameter is provided
if [ -z "$1" ]; then
  echo "No parameter provided. Please provide one of the following: db, worker, vote, result, redis"
  exit 1
fi

# List of valid words
VALID_WORDS=("db" "worker" "vote" "result" "redis")

# Check if the provided parameter is in the list of valid words
if [[ " ${VALID_WORDS[@]} " =~ " $1 " ]]; then
  #Add Docker Repo
  dnf -y config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  #
  #Install docker 
  dnf -y install docker-ce docker-ce-cli containerd.io
  #
  #Start Docker service
  systemctl start docker
  #
  #Start the container depending on parameter
  docker compose --file ./docker-compose.$1.yml up -d

else
  echo "Invalid input. Please provide one of the following: db, worker, vote, result, redis"
  exit 1
fi
