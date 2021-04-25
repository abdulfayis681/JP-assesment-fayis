#! /bin/bash

docker rmi localhost/details:v1
docker rmi localhost/frontend:v1
docker rmi localhost/pinger:v1
docker rmi localhost/pinger:v2

docker build ./details -t localhost/details:v1
docker build ./frontend -t localhost/frontend:v1
docker build ./pinger/v1 -t localhost/pinger:v1
docker build ./pinger/v2 -t localhost/pinger:v2