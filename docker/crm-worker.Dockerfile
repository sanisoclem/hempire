FROM benz0li/ghc-musl:9.10 AS builder
WORKDIR /build
COPY . .
RUN cabal update && \
    cabal build --enable-executable-static exe:crm-worker && \
    cp $(cabal list-bin exe:crm-worker) /crm-worker

FROM scratch
COPY --from=builder /crm-worker /crm-worker
ENTRYPOINT ["/crm-worker"]
