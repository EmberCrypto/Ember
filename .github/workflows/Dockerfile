FROM nimlang/nim:1.0.4 AS builder
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    make \
    cmake \
    autoconf \
    automake \
    libtool \
    curl

COPY . ./
RUN nimble build -y -d:nogui

FROM ubuntu:devel
COPY --from=builder ./build/Meros .
ENTRYPOINT ["./Meros"]