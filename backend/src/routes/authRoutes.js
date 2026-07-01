const express = require("express");
const { validateBody, signupSchema, loginSchema } = require("../middleware/validate");
const { signup, login, getMe, updateMe } = require("../controllers/authController");
const authMiddleware = require("../middleware/authMiddleware");

const router = express.Router();

router.post("/signup", validateBody(signupSchema), signup);
router.post("/login", validateBody(loginSchema), login);
router.get("/me", authMiddleware, getMe);
router.patch("/me", authMiddleware, updateMe);

module.exports = router;
