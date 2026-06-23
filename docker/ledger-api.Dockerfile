FROM benz0li/ghc-musl:9.10 AS builder
WORKDIR /build
COPY . .
RUN cabal update && \
    cabal build --enable-executable-static exe:ledger-api && \
    cp $(cabal list-bin exe:ledger-api) /ledger-api

FROM scratch
COPY --from=builder /ledger-api /ledger-api
EXPOSE 8081
ENTRYPOINT ["/ledger-api"]
