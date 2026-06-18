const jwt = require("jsonwebtoken");
const bcrypt = require("bcrypt");
const { authenticateUser, registerUser } = require("../services/authService");
const { sendTextMessage } = require("../services/whatsappService");
const { sendError, sendSuccess } = require("../utils/response");
const { User, Doctor, Patient } = require("../models");
const { sequelize } = require("../models");

function signToken(userId, role) {
  return jwt.sign({ sub: userId, role }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRES_IN || "1d"
  });
}

async function signup(req, res, next) {
  try {
    const created = await registerUser(req.body);
    const token = signToken(created.id, created.role);
    const user = {
      id: created.id,
      email: created.email,
      name: created.name,
      phone: created.phone,
      role: created.role
    };

    if (created.phone) {
      sendTextMessage(
        created.phone,
        `Welcome to MediScan AI, ${created.name}. Your ${created.role} account was created successfully.`
      ).catch((error) => {
        // eslint-disable-next-line no-console
        console.warn("[WhatsApp] Signup notification failed:", error.message);
      });
    }

    // ── Auto-link any pending doctor invitations for this phone ──
    if (created.role === "PATIENT" && created.phone) {
      try {
        const { normalizePhoneNumber } = require("../services/whatsappService");
        const normalized = normalizePhoneNumber(created.phone);
        const phoneVariants = [normalized, `+${normalized}`, created.phone].filter(Boolean);

        const [invites] = await sequelize.query(
          `SELECT * FROM "PendingInvitations"
           WHERE phone = ANY(:phones) AND used = false AND otp_expires_at > NOW()
           ORDER BY created_at DESC`,
          { replacements: { phones: [...new Set(phoneVariants)] } }
        );

        for (const invite of invites) {
          // Check if Contact already exists
          const [existing] = await sequelize.query(
            `SELECT id FROM "Contacts" WHERE doctor_id = :doctorId AND patient_id = :patientId`,
            { replacements: { doctorId: invite.doctor_id, patientId: created.id } }
          );
          if (!existing.length) {
            await sequelize.query(
              `INSERT INTO "Contacts" (doctor_id, patient_id, status, otp_code, otp_expires_at, otp_used)
               VALUES (:doctorId, :patientId, 'PENDING_VERIFICATION', :code, :expiresAt, false)`,
              {
                replacements: {
                  doctorId: invite.doctor_id,
                  patientId: created.id,
                  code: invite.otp_code,
                  expiresAt: invite.otp_expires_at
                }
              }
            );
          }
          // Mark invite as used
          await sequelize.query(
            `UPDATE "PendingInvitations" SET used = true WHERE id = :id`,
            { replacements: { id: invite.id } }
          );
        }
      } catch (linkErr) {
        // eslint-disable-next-line no-console
        console.warn("[Signup] PendingInvitation auto-link failed (non-fatal):", linkErr.message);
      }
    }

    return sendSuccess(res, {
      statusCode: 201,
      message: "Signup successful",
      data: { token, role: created.role, user },
      legacy: { token, role: created.role, user }
    });
  } catch (error) {
    return next(error);
  }
}


async function login(req, res, next) {
  try {
    const user = await authenticateUser(req.body);
    if (!user) {
      return sendError(res, { statusCode: 401, message: "Invalid credentials", code: "UNAUTHORIZED" });
    }

    if (user.role === "DOCTOR" && user.approval_status !== "APPROVED") {
      return res.status(403).json({ success: false, message: "Account Pending Approval" });
    }

    const token = signToken(user.id, user.role);
    const payload = { id: user.id, email: user.email, name: user.name, phone: user.phone };
    return sendSuccess(res, {
      statusCode: 200,
      message: "Login successful",
      data: { token, role: user.role, user: payload },
      legacy: { token, role: user.role, user: payload }
    });
  } catch (error) {
    return next(error);
  }
}

async function getMe(req, res, next) {
  try {
    const user = await User.findByPk(req.user.sub || req.user.id, {
      include: [
        { model: Doctor, as: "doctor" },
        { model: Patient, as: "patient" }
      ]
    });
    if (!user) {
      return sendError(res, { statusCode: 404, message: "User not found" });
    }

    const token = signToken(user.id, user.role);
    const payload = serializeAuthUser(user);

    return sendSuccess(res, {
      statusCode: 200,
      message: "Profile retrieved successfully",
      data: { token, role: user.role, user: payload },
      legacy: { token, role: user.role, user: payload }
    });
  } catch (error) {
    return next(error);
  }
}

function serializeAuthUser(user) {
  const profile = user.role === "DOCTOR" ? user.doctor : user.patient;
  return {
    id: user.id,
    profile_id: profile?.id || user.id,
    email: user.email,
    name: profile ? profile.name : "Admin",
    phone: user.phone,
    role: user.role,
    gender: user.patient?.gender || null,
    dob: user.patient?.dob || null,
    medical_history: user.patient?.medical_history || null,
    specialization: user.doctor?.specialization || null,
    medical_certificate: user.doctor?.medical_certificate || null,
    is_verified: user.is_verified,
    verification_status: user.verification_status
  };
}

async function updateMe(req, res, next) {
  try {
    // eslint-disable-next-line no-console
    console.log("[Profile Update] body:", req.body);

    const userId = req.user?.sub || req.user?.id;
    if (!userId) {
      return sendError(res, { statusCode: 401, message: "Missing authenticated user.", code: "UNAUTHORIZED" });
    }

    const user = await User.findByPk(userId, {
      include: [
        { model: Doctor, as: "doctor" },
        { model: Patient, as: "patient" }
      ]
    });

    if (!user) {
      return sendError(res, { statusCode: 404, message: "User not found.", code: "NOT_FOUND" });
    }

    const {
      email,
      phone,
      password,
      name,
      gender,
      dob,
      medical_history,
      specialization,
      medical_certificate
    } = req.body || {};

    const userUpdates = {};
    if (email !== undefined) userUpdates.email = email;
    if (phone !== undefined) userUpdates.phone = phone;
    if (password) userUpdates.password = await bcrypt.hash(password, 12);

    if (Object.keys(userUpdates).length) {
      await user.update(userUpdates);
    }

    if (user.role === "PATIENT" && user.patient) {
      const patientUpdates = {};
      if (name !== undefined) patientUpdates.name = name;
      if (gender !== undefined) patientUpdates.gender = String(gender).toLowerCase();
      if (dob !== undefined) patientUpdates.dob = dob;
      if (medical_history !== undefined) patientUpdates.medical_history = medical_history;
      if (Object.keys(patientUpdates).length) {
        await user.patient.update(patientUpdates);
      }
    }

    if (user.role === "DOCTOR" && user.doctor) {
      const doctorUpdates = {};
      if (name !== undefined) doctorUpdates.name = name;
      if (specialization !== undefined) doctorUpdates.specialization = specialization;
      if (medical_certificate !== undefined) doctorUpdates.medical_certificate = medical_certificate;
      if (Object.keys(doctorUpdates).length) {
        await user.doctor.update(doctorUpdates);
      }
    }

    const updated = await User.findByPk(userId, {
      include: [
        { model: Doctor, as: "doctor" },
        { model: Patient, as: "patient" }
      ]
    });
    const updatedUser = serializeAuthUser(updated);

    return sendSuccess(res, {
      statusCode: 200,
      message: "Profile updated successfully.",
      data: { updatedUser, user: updatedUser, role: updated.role }
    });
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error("[Profile Update] error:", error.message, error.stack);
    return next(error);
  }
}

module.exports = { signup, login, getMe, updateMe };
