FROM ruby:3.2-buster
WORKDIR /app

RUN apt-get update && \
  apt-get install --no-install-recommends -y git curl libpq-dev && \
  apt-get clean && rm -rf /var/lib/apt/lists/*

ADD ./Gemfile /app/
ADD ./Gemfile.lock /app/

RUN bundle install

ADD ./ /app
