#!/bin/bash

if [ "$1" == "test" ]; then
  echo "🛠️ Preparando ambiente de testes..."
  docker build --build-arg BUNDLE_WITHOUT_ARG="" -t musical-dsl-test .
  
  echo "🚀 Rodando RSpec..."
  docker run --rm -it musical-dsl-test bundle exec rspec
else
  echo "🛠️ Preparando servidor..."
  docker build -t musical-dsl .
  
  echo "🌐 Iniciando servidor em http://localhost:4567"
  docker run --rm -it -p 4567:4567 musical-dsl
fi