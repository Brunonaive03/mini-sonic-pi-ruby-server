FROM ruby:3.0-slim

ARG BUNDLE_WITHOUT_ARG="development:test"

ENV APP_HOME=/app \
    BUNDLE_PATH=/usr/local/bundle \
    # Usamos o valor do ARG aqui
    BUNDLE_WITHOUT=$BUNDLE_WITHOUT_ARG
    
WORKDIR $APP_HOME

RUN apt-get update -qq && \
    apt-get install -y build-essential libssl-dev pkg-config curl

COPY Gemfile Gemfile.lock ./

RUN bundle install

COPY . .

# RUN chmod +x bin/musical_dsl

# ENTRYPOINT ["bin/musical_dsl", "examples/example.dsl.rb"]

EXPOSE 4567

CMD ["bundle", "exec", "ruby", "server.rb"]