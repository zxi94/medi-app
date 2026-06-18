const express = require("express");
const authMiddleware = require("../middleware/authMiddleware");
const {
  getContacts,
  getThreads,
  requestConnection,
  verifyConnection,
  createThread,
  getMessages,
  sendMessage,
  streamMessages,
  askAiChatbot
} = require("../controllers/chatController");

const router = express.Router();

// All chat routes require authentication
router.use(authMiddleware);

router.post("/ai", askAiChatbot);
router.get("/contacts", getContacts);
router.get("/threads", getThreads);
router.post("/initiate-handshake", requestConnection);
router.post("/connections/verify", verifyConnection);
router.post("/threads", createThread);
router.get("/threads/:threadId/messages", getMessages);
router.post("/threads/:threadId/messages", sendMessage);
router.get("/threads/:threadId/stream", streamMessages);

module.exports = router;
