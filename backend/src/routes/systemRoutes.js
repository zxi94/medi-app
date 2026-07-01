const express = require("express");
const { updateAiEndpoint, getAiStatus } = require("../controllers/systemController");

const router = express.Router();

// Public endpoint — Colab calls this, authenticated via shared secret in body
router.post("/update-ai-endpoint", updateAiEndpoint);

// Status check — can be used by admin dashboard or health monitors
router.get("/ai-status", getAiStatus);

module.exports = router;
