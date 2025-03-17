#!/bin/bash

eval `ssh-agent -s`
ssh-add ~/.ssh/id_ed25519_GitHub

docker build --ssh default . -f docker/LANDIS-v8/Dockerfile -t achubaty/landis-ii-v8:latest
