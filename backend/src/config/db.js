require("dotenv").config();
const { Sequelize } = require("sequelize");

const DB_NAME = process.env.DB_NAME;
const DB_USER = process.env.DB_USER;
const DB_PASSWORD = process.env.DB_PASSWORD;
const DB_HOST = process.env.DB_HOST;
const DB_PORT = Number(process.env.DB_PORT || 5432);

// eslint-disable-next-line no-console
console.log(
  `[DB] Initializing PostgreSQL connection: ${DB_USER}@${DB_HOST}:${DB_PORT}/${DB_NAME}`
);

const sequelize = new Sequelize(
  DB_NAME,
  DB_USER,
  DB_PASSWORD,
  {
    host: DB_HOST,
    port: DB_PORT,
    dialect: "postgres",
    logging: (message) => {
      // eslint-disable-next-line no-console
      console.log(`[Sequelize] ${message}`);
    }
  }
);

sequelize
  .authenticate()
  .then(() => {
    // eslint-disable-next-line no-console
    console.log("[DB] Connection established successfully.");
  })
  .catch((error) => {
    // eslint-disable-next-line no-console
    console.error("[DB] Connection failed:", error.message);
  });

module.exports = sequelize;
