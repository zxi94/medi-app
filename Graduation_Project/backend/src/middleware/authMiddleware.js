const jwt = require("jsonwebtoken");

function authMiddleware(req, res, next) {
  const authHeader = req.headers.authorization || "";
  const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : null;
  if (!token) {
    const err = new Error("Missing token");
    err.statusCode = 401;
    err.code = "UNAUTHORIZED";
    return next(err);
  }

  try {
    req.user = jwt.verify(token, process.env.JWT_SECRET);
    return next();
  } catch (error) {
    const err = new Error("Invalid token");
    err.statusCode = 401;
    err.code = "UNAUTHORIZED";
    err.name = error.name;
    return next(err);
  }
}

module.exports = authMiddleware;
