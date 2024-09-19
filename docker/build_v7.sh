#!/bin/bash
docker build --ssh default . -f docker/LANDIS-v7/Dockerfile -t achubaty/landis-ii-v7:latest
