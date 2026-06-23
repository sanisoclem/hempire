FROM benz0li/ghc-musl:9.10 AS builder
WORKDIR /build
COPY . .
RUN cabal update && \
    cabal build --enable-executable-static exe:crm-api && \
    cp $(cabal list-bin exe:crm-api) /crm-api

FROM scratch
COPY --from=builder /crm-api /crm-api
EXPOSE 8080
ENTRYPOINT ["/crm-api"]
