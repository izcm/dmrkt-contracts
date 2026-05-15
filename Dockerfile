FROM ghcr.io/foundry-rs/foundry:v1.5.1

USER root
RUN apt-get update && apt-get install -y make curl jq

WORKDIR /app 
COPY . .

RUN mkdir -p devtools/data/31337/state
RUN chown -R foundry:foundry /app

USER foundry

RUN forge soldeer install
RUN forge build

CMD ["make compose-entrypoint"]