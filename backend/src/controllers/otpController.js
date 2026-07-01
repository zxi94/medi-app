const { sendOtp, verifyOtp } = require("../services/otpService");
const { User, Contact, Doctor, Patient, ChatThread } = require("../models");
const { Op } = require("sequelize");
const { sendSuccess } = require("../utils/response");

/**
 * Safely resolve user ID from JWT payload.
 * Supports both { sub: id } and { id } JWT shapes.
 */
function getUserId(user) {
  return user?.id ?? user?.sub ?? null;
}

async function getAuthenticatedUserPhone(user) {
  const userId = getUserId(user);
  if (!userId) return null;
  const record = await User.findByPk(userId, { attributes: ["phone"] });
  return record?.phone || null;
}

async function sendOtpCode(req, res, next) {
  try {
    const phone = req.body.phone || (await getAuthenticatedUserPhone(req.user));
    const language = req.body.language || "en";
    const result = await sendOtp(phone, language);
    return sendSuccess(res, {
      statusCode: 200,
      message: "Verification code sent",
      data: result
    });
  } catch (error) {
    if (error.name === "WhatsAppServiceError") {
      return res.status(502).json({ success: false, message: "WhatsApp delivery failed — check Evolution API config" });
    }
    return next(error);
  }
}

async function verifyOtpCode(req, res, next) {
  try {
    const result = await verifyOtp(req.body.phone, req.body.code);
    return sendSuccess(res, {
      statusCode: 200,
      message: "Phone number verified",
      data: result
    });
  } catch (error) {
    return next(error);
  }
}

/**
 * GET /api/otp/pending
 * Fetches an active connection handshake waiting for the logged-in patient.
 */
async function getPendingConnection(req, res, next) {
  try {
    const patientId = getUserId(req.user);

    const pendingContact = await Contact.findOne({
      where: {
        patient_id: patientId,
        status: "PENDING_VERIFICATION",
        otp_used: false,
        otp_expires_at: {
          [Op.gt]: new Date()
        }
      },
      include: [
        {
          model: Doctor,
          as: "doctor",
          include: [{ model: User, as: "user" }]
        }
      ]
    });

    if (!pendingContact) {
      return sendSuccess(res, {
        statusCode: 200,
        message: "No pending connections",
        data: { pending: null }
      });
    }

    return sendSuccess(res, {
      statusCode: 200,
      message: "Pending connection retrieved",
      data: {
        pending: {
          doctorId: pendingContact.doctor_id,
          doctorName: pendingContact.doctor?.user?.name || pendingContact.doctor?.name || "Your doctor",
          expiresAt: pendingContact.otp_expires_at
        }
      }
    });
  } catch (error) {
    return next(error);
  }
}

/**
 * POST /api/otp/verify
 * Patient confirms the OTP from WhatsApp to complete connection and open a chat thread.
 */
async function verifyPendingConnection(req, res, next) {
  try {
    const patientId = getUserId(req.user);
    const { otp, doctorId } = req.body;

    if (!otp || !doctorId) {
      return res.status(400).json({ success: false, message: "Missing otp or doctorId" });
    }

    const contact = await Contact.findOne({
      where: {
        patient_id: patientId,
        doctor_id: doctorId
      }
    });

    if (!contact || contact.status !== "PENDING_VERIFICATION" || contact.otp_used) {
      return res.status(400).json({ success: false, message: "OTP expired or already used" });
    }

    if (new Date() > new Date(contact.otp_expires_at)) {
      return res.status(400).json({ success: false, message: "OTP expired or already used" });
    }

    if (String(contact.otp_code) !== String(otp).trim()) {
      return res.status(400).json({ success: false, message: "Invalid OTP" });
    }

    await contact.update({
      otp_used: true,
      status: "ACTIVE"
    });

    // Create or find the ChatThread
    let thread = await ChatThread.findOne({
      where: { doctor_id: doctorId, patient_id: patientId }
    });

    if (!thread) {
      thread = await ChatThread.create({
        doctor_id: doctorId,
        patient_id: patientId
      });
    }

    return sendSuccess(res, {
      statusCode: 200,
      message: "Connection verified",
      data: { chatThreadId: thread.id }
    });
  } catch (error) {
    return next(error);
  }
}

/**
 * POST /api/otp/add-patient
 * Doctor requests a connection with a patient by phone number.
 * Delegates to requestConnection logic from chatController.
 */
async function addPatientConnection(req, res, next) {
  // Re-use the requestConnection logic from chatController
  const { requestConnection } = require("./chatController");
  return requestConnection(req, res, next);
}

module.exports = {
  sendOTP: sendOtpCode,
  verifyOTP: verifyOtpCode,
  sendOtpCode,
  verifyOtpCode,
  getPendingConnection,
  verifyPendingConnection,
  addPatientConnection
};
