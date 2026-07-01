const express = require("express");
const authMiddleware = require("../middleware/authMiddleware");
const { validateBody, otpSendSchema, otpVerifySchema } = require("../middleware/validate");
const {
  sendOTP,
  verifyOTP,
  getPendingConnection,
  verifyPendingConnection,
  addPatientConnection
} = require("../controllers/otpController");

const router = express.Router();

// Phone verification OTP flow (used during registration)
router.post("/send", authMiddleware, validateBody(otpSendSchema), sendOTP);
router.post("/verify-phone", validateBody(otpVerifySchema), verifyOTP);

// Doctor-patient connection OTP flow
router.post("/add-patient", authMiddleware, addPatientConnection);  // Doctor sends OTP to patient
router.get("/pending", authMiddleware, getPendingConnection);        // Patient polls for pending handshake
router.post("/verify", authMiddleware, verifyPendingConnection);     // Patient submits OTP to confirm

module.exports = router;
