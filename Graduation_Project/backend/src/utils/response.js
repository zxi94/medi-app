function sendSuccess(res, { statusCode = 200, message = "", data = {}, legacy = {} } = {}) {
  return res.status(statusCode).json({
    success: true,
    message,
    data,
    ...legacy
  });
}

function sendError(
  res,
  { statusCode = 500, message = "Internal server error", code = "INTERNAL_ERROR", details = null, legacy = {} } = {}
) {
  return res.status(statusCode).json({
    success: false,
    message,
    error: { code, details },
    ...legacy
  });
}

module.exports = { sendSuccess, sendError };

