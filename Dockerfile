FROM ghcr.io/foundry-rs/foundry:v1.5.1

USER root
RUN apt-get update && apt-get install -y make

WORKDIR /app 
COPY . .

RUN chown -R foundry:foundry /app

USER foundry

RUN forge build
# RUN forge test

# CMD ["bash"]
CMD ["make", "dev-bootstrap"]