import { env } from '$env/dynamic/private';

export const config = {
  database: {
    url: env.BFF_DATABASE_URL!,
  },
  kafka: {
    brokers: env.BFF_KAFKA_BROKERS!.split(',') ?? [],
  },
  crm: {
    apiUrl: env.BFF_CRM_API_URL!,
  },
  zitadel: {
    domain: env.BFF_ZITADEL_DOMAIN!,
    clientId: env.BFF_CLIENT_ID!,
    clientSecret: env.BFF_CLIENT_SECRET ?? null,
    redirectUri: env.BFF_REDIRECT_URI!,
  },
  session: {
    secret: env.BFF_SESSION_SECRET ?? '0000000000000000000000000000000000000000000000000000000000000000',
  },
  electric: {
    url: env.BFF_ELECTRIC_URL!,
  },
  user: {
    expiryMinutes: parseInt(env.BFF_USER_EXPIRY_MINUTES!, 10),
  },
} as const;
