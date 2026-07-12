FROM ghcr.io/foundry-rs/foundry:v1.5.1

USER root
RUN apt-get update && apt-get install -y bc make curl jq
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && apt-get install -y nodejs

WORKDIR /app 
COPY . .

RUN cd devtools && npm install

RUN mkdir -p devtools/data/31337/state
RUN chown -R foundry:foundry /app

USER foundry

RUN forge soldeer install
RUN forge build

CMD ["make pipeline"]