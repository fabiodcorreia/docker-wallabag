#!/bin/bash

docker build . -t wallabag
docker run --rm --entrypoint '/bin/sh' -v ${PWD}:/tmp wallabag -c '\
  apk info -v | sort > /tmp/package_versions.txt && \
  chmod 777 /tmp/package_versions.txt'
