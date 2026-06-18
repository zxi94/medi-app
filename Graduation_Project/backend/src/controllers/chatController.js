const { User, Doctor, Patient, Contact, ChatThread, ChatMessage, sequelize } = require("../models");
const { Op } = require("sequelize");
const { sendContactOtp, verifyContactOtp } = require("../services/otpService");
const { normalizePhoneNumber } = require("../services/whatsappService");
const { sendSuccess, sendError } = require("../utils/response");
const { chatWithAI } = require("../services/aiService");

const activeStreams = new Map();

/**
 * Safely resolve user ID from JWT payload.
 * Supports both { sub: id } and { id } JWT shapes.
 */
function getUserId(user) {
  return user?.id ?? user?.sub ?? null;
}

async function ensureThreadForContact(contact) {
  let thread = await ChatThread.findOne({
    where: { doctor_id: contact.doctor_id, patient_id: contact.patient_id }
  });

  if (!thread) {
    thread = await ChatThread.create({
      doctor_id: contact.doctor_id,
      patient_id: contact.patient_id
    });
  }

  return thread;
}

async function ensureActiveContactThreads(userId, role) {
  if (!["PATIENT", "DOCTOR"].includes(role)) return;

  const where = { status: "ACTIVE" };
  if (role === "PATIENT") {
    where.patient_id = userId;
  } else {
    where.doctor_id = userId;
  }

  const contacts = await Contact.findAll({ where });
  await Promise.all(contacts.map(ensureThreadForContact));
}

async function getContacts(req, res, next) {
  try {
    const userId = getUserId(req.user);
    const role = String(req.user.role || "").toUpperCase();

    const contacts = [];

    if (role === "PATIENT") {
      const dbContacts = await Contact.findAll({
        where: { patient_id: userId },
        include: [
          {
            model: Doctor,
            as: "doctor",
            include: [{ model: User, as: "user" }]
          }
        ]
      });

      for (const contact of dbContacts) {
        if (contact.doctor) {
          contacts.push({
            user_id: contact.doctor.id,
            profile_id: contact.doctor.id,
            role: "doctor",
            name: contact.doctor.name,
            email: contact.doctor.email,
            phone: contact.doctor.phone,
            subtitle: contact.doctor.specialization || "Doctor",
            is_verified: contact.doctor.is_verified,
            verification_status: contact.status
          });
        }
      }
    } else if (role === "DOCTOR") {
      const dbContacts = await Contact.findAll({
        where: { doctor_id: userId },
        include: [
          {
            model: Patient,
            as: "patient",
            include: [{ model: User, as: "user" }]
          }
        ]
      });

      for (const contact of dbContacts) {
        if (contact.patient) {
          contacts.push({
            user_id: contact.patient.id,
            profile_id: contact.patient.id,
            role: "patient",
            name: contact.patient.name,
            email: contact.patient.email,
            phone: contact.patient.phone,
            subtitle: `${contact.patient.gender || "Other"}, ${contact.patient.dob || "N/A"}`,
            is_verified: contact.patient.is_verified,
            verification_status: contact.status
          });
        }
      }
    }

    return sendSuccess(res, {
      statusCode: 200,
      message: contacts.length === 0
        ? "No contacts found. Start a connection to add contacts."
        : "Contacts retrieved successfully.",
      data: { contacts }
    });
  } catch (error) {
    return next(error);
  }
}

async function getThreads(req, res, next) {
  try {
    const userId = getUserId(req.user);
    const role = String(req.user.role || "").toUpperCase();

    if (!["PATIENT", "DOCTOR"].includes(role)) {
      return sendSuccess(res, {
        statusCode: 200,
        message: "Threads retrieved successfully.",
        data: { threads: [] }
      });
    }

    await ensureActiveContactThreads(userId, role);

    const threads = await ChatThread.findAll({
      where: {
        [Op.or]: [
          { patient_id: userId },
          { doctor_id: userId }
        ]
      },
      include: [
        {
          model: Patient,
          as: "patient",
          include: [{ model: User, as: "user" }]
        },
        {
          model: Doctor,
          as: "doctor",
          include: [{ model: User, as: "user" }]
        }
      ],
      order: [["updated_at", "DESC"]]
    });

    const serializedThreads = [];
    for (const thread of threads) {
      if (!thread.patient || !thread.doctor) continue;

      const latestMessage = await ChatMessage.findOne({
        where: { thread_id: thread.id },
        order: [["created_at", "DESC"]]
      });

      const contact = await Contact.findOne({
        where: { doctor_id: thread.doctor_id, patient_id: thread.patient_id, status: "ACTIVE" }
      });
      if (!contact) continue;
      const status = contact.status;

      serializedThreads.push({
        id: thread.id,
        patient: {
          user_id: thread.patient.id,
          profile_id: thread.patient.id,
          role: "patient",
          name: thread.patient.name,
          email: thread.patient.email,
          phone: thread.patient.phone,
          subtitle: `${thread.patient.gender || "Other"}, ${thread.patient.dob || ""}`,
          is_verified: thread.patient.is_verified,
          verification_status: status
        },
        doctor: {
          user_id: thread.doctor.id,
          profile_id: thread.doctor.id,
          role: "doctor",
          name: thread.doctor.name,
          email: thread.doctor.email,
          phone: thread.doctor.phone,
          subtitle: thread.doctor.specialization || "Doctor",
          is_verified: thread.doctor.is_verified,
          verification_status: status
        },
        latest_message: latestMessage
          ? {
              id: latestMessage.id,
              thread_id: latestMessage.thread_id,
              sender_user_id: latestMessage.sender_user_id,
              body: latestMessage.body,
              created_at: latestMessage.created_at
            }
          : null,
        updated_at: thread.updated_at
      });
    }

    return sendSuccess(res, {
      statusCode: 200,
      message: "Threads retrieved successfully.",
      data: { threads: serializedThreads }
    });
  } catch (error) {
    return next(error);
  }
}

async function requestConnection(req, res, next) {
  try {
    const doctorId = getUserId(req.user);
    const { phone } = req.body;

    if (String(req.user.role || "").toUpperCase() !== "DOCTOR") {
      return sendError(res, {
        statusCode: 403,
        message: "Only doctors can initiate contact connections.",
        code: "FORBIDDEN"
      });
    }

    const normalizedPhone = normalizePhoneNumber(phone);
    if (!normalizedPhone) {
      return sendError(res, {
        statusCode: 400,
        message: "Valid phone number is required.",
        code: "VALIDATION_ERROR"
      });
    }

    // Search with multiple phone formats to handle +/no-+ prefix mismatches
    const phoneVariants = [
      normalizedPhone,
      `+${normalizedPhone}`,
      phone.trim()
    ].filter(Boolean);

    const patient = await User.findOne({
      where: {
        role: "PATIENT",
        phone: { [Op.in]: [...new Set(phoneVariants)] }
      }
    });

    // Fetch the Doctor record to get the doctor's name
    const doctorProfile = await Doctor.findByPk(doctorId, {
      include: [{ model: User, as: "user" }]
    });
    const doctorName = doctorProfile ? doctorProfile.name : "Your doctor";

    const crypto = require("crypto");
    const code = String(crypto.randomInt(100000, 1000000));
    const otpExpiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

    const { sendTextMessage } = require("../services/whatsappService");

    if (!patient) {
      // ── Patient not registered yet: store invite and send WhatsApp ──
      await sequelize.query(
        `INSERT INTO "PendingInvitations" (phone, doctor_id, otp_code, otp_expires_at)
         VALUES (:phone, :doctorId, :code, :expiresAt)`,
        { replacements: { phone: normalizedPhone, doctorId, code, expiresAt: otpExpiresAt } }
      );

      const messageText = `MediScan AI: Dr. ${doctorName} wants to connect with you. Download the app and register with this phone number. Your connection code is: ${code}. Valid for 10 minutes.`;
      await sendTextMessage(normalizedPhone, messageText);

      return sendSuccess(res, {
        statusCode: 200,
        message: "Invitation sent. The patient will receive a connection code via WhatsApp."
      });
    }

    // ── Patient is registered: use the existing contact/OTP flow ──
    if (patient.id === doctorId) {
      return sendError(res, { statusCode: 400, message: "Cannot connect to yourself.", code: "BAD_REQUEST" });
    }

    let contact = await Contact.findOne({
      where: { doctor_id: doctorId, patient_id: patient.id }
    });

    if (contact && contact.status === "ACTIVE") {
      const thread = await ensureThreadForContact(contact);
      return sendSuccess(res, {
        statusCode: 200,
        message: "You are already connected to this patient.",
        data: { alreadyConnected: true, chatThreadId: thread.id }
      });
    }

    if (!contact) {
      contact = await Contact.create({
        doctor_id: doctorId,
        patient_id: patient.id,
        status: "PENDING_VERIFICATION",
        otp_code: code,
        otp_expires_at: otpExpiresAt,
        otp_used: false
      });
    } else {
      await contact.update({
        otp_code: code,
        otp_expires_at: otpExpiresAt,
        otp_used: false,
        status: "PENDING_VERIFICATION"
      });
    }

    const lang = patient.language || "en";
    let messageText;
    if (lang === "ar") {
      messageText = `MediScan AI: الدكتور ${doctorName} يريد التواصل معك. رمز التحقق: ${code}. صالح لمدة 10 دقائق.`;
    } else {
      messageText = `MediScan AI: Dr. ${doctorName} wants to connect with you. Verification code: ${code}. Valid for 10 minutes.`;
    }

    await sendTextMessage(normalizedPhone, messageText);

    return sendSuccess(res, {
      statusCode: 200,
      message: "OTP sent to patient"
    });
  } catch (error) {
    if (error.name === "WhatsAppServiceError") {
      return res.status(502).json({ success: false, message: "WhatsApp delivery failed — check Evolution API config" });
    }
    return next(error);
  }
}


async function verifyConnection(req, res, next) {
  try {
    const patientId = getUserId(req.user);
    const { code } = req.body;

    if (String(req.user.role || "").toUpperCase() !== "PATIENT") {
      return sendError(res, {
        statusCode: 403,
        message: "Only patients can verify connection authorization.",
        code: "FORBIDDEN"
      });
    }

    const patientUser = await User.findByPk(patientId);
    if (!patientUser || !patientUser.phone) {
      return sendError(res, {
        statusCode: 400,
        message: "Patient profile is missing a registered phone number.",
        code: "BAD_REQUEST"
      });
    }

    const record = await verifyContactOtp(patientUser.phone, code);

    const contact = await Contact.findOne({
      where: { doctor_id: record.doctorId, patient_id: patientId }
    });

    if (!contact) {
      return sendError(res, {
        statusCode: 404,
        message: "Pending connection request not found.",
        code: "NOT_FOUND"
      });
    }

    await contact.update({ status: "ACTIVE" });

    return sendSuccess(res, {
      statusCode: 200,
      message: "Connection verified successfully."
    });
  } catch (error) {
    if (error.statusCode) {
      return sendError(res, {
        statusCode: error.statusCode,
        message: error.message,
        code: error.code || "VERIFICATION_ERROR"
      });
    }
    return next(error);
  }
}

async function createThread(req, res, next) {
  try {
    const currentUserId = getUserId(req.user);
    const currentUserRole = String(req.user.role || "").toUpperCase();
    const { user_id } = req.body;

    let doctorId, patientId;
    if (currentUserRole === "DOCTOR") {
      doctorId = currentUserId;
      patientId = Number(user_id);
    } else if (currentUserRole === "PATIENT") {
      doctorId = Number(user_id);
      patientId = currentUserId;
    } else {
      return sendError(res, {
        statusCode: 403,
        message: "Admins cannot participate in chat threads.",
        code: "FORBIDDEN"
      });
    }

    const contact = await Contact.findOne({
      where: { doctor_id: doctorId, patient_id: patientId }
    });

    if (!contact || (contact.status !== "ACTIVE" && contact.status !== "PENDING_VERIFICATION")) {
      return sendError(res, {
        statusCode: 403,
        message: "Active connection is required to start a chat thread.",
        code: "FORBIDDEN"
      });
    }

    let thread = await ChatThread.findOne({
      where: { doctor_id: doctorId, patient_id: patientId },
      include: [
        { model: Patient, as: "patient", include: [{ model: User, as: "user" }] },
        { model: Doctor, as: "doctor", include: [{ model: User, as: "user" }] }
      ]
    });

    if (!thread) {
      thread = await ChatThread.create({ doctor_id: doctorId, patient_id: patientId });
      thread = await ChatThread.findByPk(thread.id, {
        include: [
          { model: Patient, as: "patient", include: [{ model: User, as: "user" }] },
          { model: Doctor, as: "doctor", include: [{ model: User, as: "user" }] }
        ]
      });
    }

    return sendSuccess(res, {
      statusCode: 200,
      message: "Chat thread ready.",
      data: {
        thread: {
          id: thread.id,
          patient: {
            user_id: thread.patient.id,
            profile_id: thread.patient.id,
            role: "patient",
            name: thread.patient.name,
            email: thread.patient.email,
            phone: thread.patient.phone,
            subtitle: `${thread.patient.gender || "Other"}, ${thread.patient.dob || ""}`,
            is_verified: thread.patient.is_verified,
            verification_status: contact.status
          },
          doctor: {
            user_id: thread.doctor.id,
            profile_id: thread.doctor.id,
            role: "doctor",
            name: thread.doctor.name,
            email: thread.doctor.email,
            phone: thread.doctor.phone,
            subtitle: thread.doctor.specialization || "Doctor",
            is_verified: thread.doctor.is_verified,
            verification_status: contact.status
          },
          latest_message: null,
          updated_at: thread.updated_at
        }
      }
    });
  } catch (error) {
    return next(error);
  }
}

async function getMessages(req, res, next) {
  try {
    const userId = getUserId(req.user);
    const threadId = Number(req.params.threadId);

    const thread = await ChatThread.findByPk(threadId);
    if (!thread) {
      return sendError(res, { statusCode: 404, message: "Thread not found.", code: "NOT_FOUND" });
    }

    if (thread.patient_id !== userId && thread.doctor_id !== userId) {
      return sendError(res, { statusCode: 403, message: "You are not a participant in this thread.", code: "FORBIDDEN" });
    }

    const contact = await Contact.findOne({
      where: { doctor_id: thread.doctor_id, patient_id: thread.patient_id }
    });

    if (!contact || contact.status !== "ACTIVE") {
      return sendError(res, { statusCode: 403, message: "Active connection is required to retrieve messages.", code: "FORBIDDEN" });
    }

    const messages = await ChatMessage.findAll({
      where: { thread_id: threadId },
      order: [["created_at", "ASC"]]
    });

    const serializedMessages = messages.map((m) => ({
      id: m.id,
      thread_id: m.thread_id,
      sender_user_id: m.sender_user_id,
      body: m.body,
      created_at: m.created_at
    }));

    return sendSuccess(res, {
      statusCode: 200,
      message: "Messages retrieved successfully.",
      data: { messages: serializedMessages }
    });
  } catch (error) {
    return next(error);
  }
}

async function sendMessage(req, res, next) {
  try {
    const userId = getUserId(req.user);
    const threadId = Number(req.params.threadId);
    const { body } = req.body;

    if (!body || !String(body).trim()) {
      return sendError(res, { statusCode: 400, message: "Message body cannot be empty.", code: "VALIDATION_ERROR" });
    }

    const thread = await ChatThread.findByPk(threadId);
    if (!thread) {
      return sendError(res, { statusCode: 404, message: "Thread not found.", code: "NOT_FOUND" });
    }

    if (thread.patient_id !== userId && thread.doctor_id !== userId) {
      return sendError(res, { statusCode: 403, message: "You are not a participant in this thread.", code: "FORBIDDEN" });
    }

    const contact = await Contact.findOne({
      where: { doctor_id: thread.doctor_id, patient_id: thread.patient_id }
    });

    if (!contact || contact.status !== "ACTIVE") {
      return sendError(res, { statusCode: 403, message: "Active connection is required to send messages.", code: "FORBIDDEN" });
    }

    const message = await ChatMessage.create({
      thread_id: threadId,
      sender_user_id: userId,
      body: String(body).trim()
    });

    await thread.update({ updated_at: new Date() });

    const payload = {
      id: message.id,
      thread_id: message.thread_id,
      sender_user_id: message.sender_user_id,
      body: message.body,
      created_at: message.created_at
    };

    const clients = activeStreams.get(threadId);
    if (clients) {
      for (const client of clients) {
        try {
          client.write(`event: message\n`);
          client.write(`data: ${JSON.stringify(payload)}\n\n`);
        } catch (err) {
          // eslint-disable-next-line no-console
          console.warn("[SSE] Error sending payload to client:", err.message);
        }
      }
    }

    return sendSuccess(res, {
      statusCode: 201,
      message: "Message sent successfully.",
      data: { message: payload }
    });
  } catch (error) {
    return next(error);
  }
}

async function streamMessages(req, res, next) {
  try {
    const userId = getUserId(req.user);
    const threadId = Number(req.params.threadId);

    const thread = await ChatThread.findByPk(threadId);
    if (!thread) return res.status(404).end();

    if (thread.patient_id !== userId && thread.doctor_id !== userId) {
      return res.status(403).end();
    }

    const contact = await Contact.findOne({
      where: { doctor_id: thread.doctor_id, patient_id: thread.patient_id }
    });

    if (!contact || contact.status !== "ACTIVE") return res.status(403).end();

    res.writeHead(200, {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache",
      Connection: "keep-alive"
    });
    res.write("\n");

    if (!activeStreams.has(threadId)) {
      activeStreams.set(threadId, new Set());
    }
    activeStreams.get(threadId).add(res);

    req.on("close", () => {
      const clients = activeStreams.get(threadId);
      if (clients) {
        clients.delete(res);
        if (clients.size === 0) activeStreams.delete(threadId);
      }
    });
  } catch (error) {
    return next(error);
  }
}

async function askAiChatbot(req, res, next) {
  try {
    const { question, finding, session_id, language } = req.body;
    
    if (!question) {
      return sendError(res, { statusCode: 400, message: "Question is required.", code: "VALIDATION_ERROR" });
    }

    // Valid findings the Kaggle AI model recognises
    const VALID_FINDINGS = [
      "Aortic Enlargement", "Cardiomegaly", "Consolidation",
      "Lung Opacity", "Nodule/Mass", "Pleural Effusion",
      "Pleural Thickening", "Pneumothorax", "Pulmonary Fibrosis"
    ];

    let safeFinding = finding || "Consolidation";
    if (!VALID_FINDINGS.includes(safeFinding)) {
      safeFinding = "Consolidation";
    }

    const aiResult = await chatWithAI({
      question,
      finding: safeFinding,
      session_id: session_id || null,
      language: language || "en"
    });

    return sendSuccess(res, {
      statusCode: 200,
      message: "AI response generated.",
      data: aiResult
    });
  } catch (error) {
    if (error.statusCode) {
       return sendError(res, { statusCode: error.statusCode, message: error.message, code: "AI_ERROR" });
    }
    return next(error);
  }
}

module.exports = {
  getContacts,
  getThreads,
  requestConnection,
  verifyConnection,
  createThread,
  getMessages,
  sendMessage,
  streamMessages,
  askAiChatbot
};
