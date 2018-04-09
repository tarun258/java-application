FROM java:8-jdk

RUN apt-get update && \
    apt-get install -y zip

RUN curl -s "https://get.sdkman.io" | bash

RUN /bin/bash -l -c 'sdk install gradle 4.0.1'

WORKDIR /code