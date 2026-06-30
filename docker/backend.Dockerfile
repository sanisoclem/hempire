# syntax=docker/dockerfile:1

FROM benz0li/ghc-musl:9.10 AS builder
ARG SERVICE
RUN apk add --no-cache postgresql-dev openssl-dev zlib-dev lz4-dev zstd-dev librdkafka-dev
WORKDIR /build
RUN --mount=type=cache,id=cabal-store,target=/root/.cabal \
    cabal update
COPY . .
RUN --mount=type=cache,id=cabal-store,target=/root/.cabal \
    --mount=type=cache,id=hempire-dist-${SERVICE},target=/build/dist-newstyle \
    cabal build exe:${SERVICE} && \
    cp $(cabal list-bin exe:${SERVICE}) /app

FROM alpine:3.21
RUN apk add --no-cache librdkafka libpq gmp
COPY --from=builder /app /app
ENTRYPOINT ["/app"]
