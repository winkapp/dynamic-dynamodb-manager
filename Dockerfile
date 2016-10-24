FROM ruby:2.2.5-slim
MAINTAINER Jonathan Hosmer <jonathan@wink.com>

COPY bin /dynamic-dynamodb-manager/bin
COPY lib /dynamic-dynamodb-manager/lib
COPY dynamic-dynamodb-manager.gemspec Gemfile wink_tables_*.json /dynamic-dynamodb-manager/

WORKDIR /dynamic-dynamodb-manager

RUN gem build dynamic-dynamodb-manager.gemspec && gem install dynamic-dynamodb-manager-0.0.1.gem

ENTRYPOINT ["/bin/bash"]

CMD ["ruby", "/dynamic-dynamodb-manager/bin/dynamic-dynamodb-manager-cli", "--rotate", "--no-deletion", "--redis"]
