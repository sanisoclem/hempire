FROM benz0li/ghc-musl:9.10 AS builder
WORKDIR /build
COPY . .
RUN cabal update && \
    cabal build --enable-executable-static exe:ledger-worker && \
    cp $(cabal list-bin exe:ledger-worker) /ledger-worker

FROM scratch
COPY --from=builder /ledger-worker /ledger-worker
ENTRYPOINT ["/ledger-worker"]
