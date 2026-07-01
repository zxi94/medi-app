const { sendError } = require("../utils/response");

function errorMiddleware(err, _req, res, _next) {
  const statusCode = err.statusCode || 500;
  let message = err.message || "Internal server error";
  let code = err.code || "INTERNAL_ERROR";
  let details = err.details || null;

  // JWT errors (jsonwebtoken)
  if (err.name === "JsonWebTokenError" || err.name === "TokenExpiredError") {
    return sendError(res, {
      statusCode: 401,
      message: "Invalid token",
      code: "UNAUTHORIZED"
    });
  }

  // Sequelize/Postgres errors
  if (err.original && typeof err.original.code === "string") {
    const pgCode = err.original.code;
    if (pgCode === "23505") {
      // unique_violation
      return sendError(res, {
        statusCode: 409,
        message: message || "Conflict",
        code: "CONFLICT"
      });
    }
    if (pgCode === "23503") {
      // foreign_key_violation
      return sendError(res, {
        statusCode: 400,
        message: message || "Bad request",
        code: "BAD_REQUEST",
        details
      });
    }
  }

  // multer fileFilter errors and other validation-ish errors
  if (message === "Unsupported file type") {
    return sendError(res, {
      statusCode: 400,
      message,
      code: "VALIDATION_ERROR",
      details
    });
  }

  if (code === "VALIDATION_ERROR" || statusCode === 400) {
    return sendError(res, {
      statusCode: 400,
      message,
      code: "VALIDATION_ERROR",
      details
    });
  }

  if (statusCode === 401) {
    return sendError(res, {
      statusCode: 401,
      message,
      code: "UNAUTHORIZED",
      details
    });
  }

  if (statusCode === 403) {
    return sendError(res, {
      statusCode: 403,
      message,
      code: "FORBIDDEN",
      details
    });
  }

  return sendError(res, {
    statusCode,
    message,
    code,
    details
  });
}

module.exports = errorMiddleware;
