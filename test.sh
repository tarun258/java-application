#!/bin/bash -ex

docker run \
    -v $PWD:/code \
    hello /bin/bash -c -l 'source ~/.bashrc && grade test'