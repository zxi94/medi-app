/**
 * envValidation.js
 * Validates that all required environment variables are present at startup.
 * Call this once at the top of server.js (after dotenv.config()).
 */

const REQUIRED_ENV_VARS = [
  'EVO_API_URL',
  'EVO_API_KEY',
  'EVO_INSTANCE_NAME',
  'JWT_SECRET',
  'DB_NAME',
  'DB_USER',
  'DB_HOST'
];

function validateEnv() {
  const missing = REQUIRED_ENV_VARS.filter((key) => !process.env[key]);

  if (missing.length > 0) {
    // eslint-disable-next-line no-console
    console.error(
      `[FATAL STARTUP ERROR] Missing critical environment variables in .env: ${missing.join(', ')}`
    );
    // Do NOT call process.exit so the server still runs during development
    // but log prominently so developers know immediately
    console.warn(
      '⚠️  Server started with missing env vars. WhatsApp/Auth features may not work correctly.'
    );
    return;
  }

  // eslint-disable-next-line no-console
  console.log('✅ [Environment] All required environment variables validated successfully.');
}

module.exports = validateEnv;
