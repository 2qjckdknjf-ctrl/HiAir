import { Container } from "@cloudflare/containers";

const CONTAINER_ENV_KEYS = [
  "APP_ENV",
  "DATABASE_URL",
  "DIRECT_DATABASE_URL",
  "JWT_SECRET",
  "JWT_ALGORITHM",
  "HIAIR_AUTH_PROVIDER",
  "HIAIR_AUTH_LEGACY_ENABLED",
  "HIAIR_IOS_URL_SCHEME",
  "HIAIR_ANDROID_URL_SCHEME",
  "HIAIR_AUTH_REDIRECT_URI",
  "HIAIR_AUTH_EMAIL_BRIDGE_ENABLED",
  "ALLOW_LEGACY_USER_HEADER_AUTH",
  "SUPABASE_URL",
  "SUPABASE_ANON_KEY",
  "SUPABASE_SERVICE_ROLE_KEY",
  "SUPABASE_JWT_SECRET",
  "OPENAI_API_KEY",
  "OPENAI_MODEL",
  "OPENAI_BASE_URL",
  "OPENAI_PROMPT_VERSION",
  "OPENAI_RATE_LIMIT_PER_MINUTE",
  "OPENAI_HTTP_TIMEOUT_SECONDS",
  "OPENAI_MAX_TOKENS",
  "NOTIFICATION_ADMIN_TOKEN",
  "NOTIFICATIONS_PROVIDER_MODE",
  "SUBSCRIPTION_PROVIDER",
  "SUBSCRIPTION_WEBHOOK_SECRET",
  "APPLE_STORE_VERIFIER_MODE",
  "GOOGLE_PLAY_VERIFIER_MODE",
  "APPLE_BUNDLE_ID",
  "GOOGLE_PLAY_PACKAGE_NAME",
  "DEPLOY_GIT_SHA",
  "WEATHER_API_PROVIDER",
  "WEATHER_API_KEY",
  "AQI_API_PROVIDER",
  "AQI_API_KEY",
];

function containerEnv(env) {
  const vars = { APP_ENV: env.APP_ENV || "production" };
  for (const key of CONTAINER_ENV_KEYS) {
    if (key === "APP_ENV") {
      continue;
    }
    const value = env[key];
    if (typeof value === "string" && value.length > 0) {
      vars[key] = value;
    }
  }
  return vars;
}

export class HiAirApiContainer extends Container {
  defaultPort = 8080;
  sleepAfter = "15m";
}

export default {
  async fetch(request, env) {
    const container = env.HIAIR_API.getByName("production");
    await container.startAndWaitForPorts({
      startOptions: {
        envVars: containerEnv(env),
      },
    });
    return container.fetch(request);
  },
};
