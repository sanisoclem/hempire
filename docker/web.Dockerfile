FROM oven/bun:1 AS builder
WORKDIR /app
COPY package.json bun.lock ./
RUN bun install --frozen-lockfile
COPY . .
RUN BFF_DATABASE_URL=postgres://placeholder \
    BFF_KAFKA_BROKERS=placeholder \
    BFF_CRM_API_URL=http://placeholder \
    BFF_ZITADEL_DOMAIN=http://placeholder \
    BFF_CLIENT_ID=placeholder \
    BFF_CLIENT_SECRET=placeholder \
    BFF_REDIRECT_URI=http://placeholder \
    BFF_SESSION_SECRET=0000000000000000000000000000000000000000000000000000000000000000 \
    BFF_USER_EXPIRY_MINUTES=60 \
    BFF_ELECTRIC_URL=http://placeholder \
    bun run build

FROM node:22-alpine
WORKDIR /app
COPY --from=builder /app/build ./build
COPY --from=builder /app/package.json ./
RUN npm install --omit=dev --ignore-scripts
EXPOSE 3000
ENV PORT=3000
ENTRYPOINT ["node", "build/index.js"]
