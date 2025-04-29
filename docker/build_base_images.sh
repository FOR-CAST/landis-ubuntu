cd ~/GitHub/FOR-CAST/rocker-versioned2

## -----------------------------------------------------------------------------
docker build . -f dockerfiles/geospatial_4.3.3-focal.Dockerfile -t achubaty/geospatial:4.3.3-focal-ubuntugis
docker build . -f dockerfiles/geospatial_4.3.3-noble.Dockerfile -t achubaty/geospatial:4.3.3-noble-ubuntugis

docker build . -f dockerfiles/geospatial_4.4.2-focal.Dockerfile -t achubaty/geospatial:4.4.2-focal-ubuntugis
docker build . -f dockerfiles/geospatial_4.4.2-noble.Dockerfile -t achubaty/geospatial:4.4.2-noble-ubuntugis

## -----------------------------------------------------------------------------
docker push achubaty/geospatial:4.3.3-focal-ubuntugis
docker push achubaty/geospatial:4.3.3-noble-ubuntugis
docker push achubaty/geospatial:4.4.2-focal-ubuntugis
docker push achubaty/geospatial:4.4.2-noble-ubuntugis

