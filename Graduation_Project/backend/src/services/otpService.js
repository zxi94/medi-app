const crypto = require("crypto");
const { User, Contact } = require("../models");
const { sendTextMessage, normalizePhoneNumber } = require("./whatsappService");

const otpStore = new Map();
const OTP_TTL_MS = 24 * 60 * 60 * 1000;            // 24h for phone-verification OTPs
const CONTACT_OTP_TTL_MS = 10 * 60 * 1000;          // 10min for doctor-patient contact OTPs

function generateOtp() {
  return String(crypto.randomInt(100000, 1000000));
}

function buildOtpMessage(code, language = "en") {
  if (language === "ar") {
    return `رمز التحقق الخاص بك في MediScan AI هو: ${code}. ينتهي صلاحية هذا الرمز خلال 24 ساعة.`;
  }
  return `MediScan AI verification code: ${code}. This code expires in 24 hours.`;
}

function buildContactOtpMessage(code, doctorName, language = "en") {
  if (language === "ar") {
    return `MediScan AI: الدكتور ${doctorName} يريد التواصل معك. استخدم رمز التحقق ${code} للموافقة. صالح لمدة 10 دقائق.`;
  }
  return `MediScan AI: Dr. ${doctorName} wants to connect with you. Use verification code ${code} to authorize. Valid for 10 minutes.`;
}

async function sendOtp(phone, language = "en") {
  const normalizedPhone = normalizePhoneNumber(phone);
  if (!normalizedPhone) {
    const err = new Error("Valid phone number is required");
    err.statusCode = 400;
    err.code = "VALIDATION_ERROR";
    throw err;
  }

  const code = generateOtp();
  const createdAt = Date.now();
  otpStore.set(normalizedPhone, {
    code,
    phone: normalizedPhone,
    createdAt,
    expiresAt: createdAt + OTP_TTL_MS,
    attempts: 0
  });

  try {
    await sendTextMessage(normalizedPhone, buildOtpMessage(code, language));
  } catch (error) {
    otpStore.delete(normalizedPhone);
    throw error;
  }

  return {
    phone: normalizedPhone,
    expires_in_seconds: Math.floor(OTP_TTL_MS / 1000)
  };
}

async function verifyOtp(phone, code) {
  const normalizedPhone = normalizePhoneNumber(phone);
  const record = otpStore.get(normalizedPhone);
  const tokenAgeMs = record ? Date.now() - record.createdAt : Infinity;

  if (!record || tokenAgeMs > OTP_TTL_MS) {
    otpStore.delete(normalizedPhone);
    const err = new Error("Verification code has expired");
    err.statusCode = 400;
    err.code = "VALIDATION_ERROR";
    throw err;
  }

  record.attempts += 1;
  if (record.code !== String(code || "").trim()) {
    if (record.attempts >= 5) otpStore.delete(normalizedPhone);
    const err = new Error("Invalid verification code");
    err.statusCode = 400;
    err.code = "VALIDATION_ERROR";
    throw err;
  }

  otpStore.delete(normalizedPhone);
  await markPhoneVerified(normalizedPhone);
  return { phone: normalizedPhone, verified: true };
}

async function markPhoneVerified(phone) {
  await User.update(
    { is_verified: true, verification_status: "approved" },
    { where: { phone } }
  );
}

/**
 * Sends an OTP to a patient for a doctor-patient connection request.
 *
 * @param {string} phone - Patient's phone number
 * @param {number} doctorId - Doctor's user_id (used as key in otpStore)
 * @param {string} doctorName - Doctor's display name (passed from controller)
 * @param {string} language - Patient's preferred language ('en' | 'ar')
 */
async function sendContactOtp(phone, doctorId, doctorName = "A doctor", language = "en") {
  const normalizedPhone = normalizePhoneNumber(phone);
  if (!normalizedPhone) {
    const err = new Error("Valid phone number is required");
    err.statusCode = 400;
    err.code = "VALIDATION_ERROR";
    throw err;
  }

  const code = generateOtp();
  const createdAt = Date.now();
  const message = buildContactOtpMessage(code, doctorName, language);

  otpStore.set(normalizedPhone, {
    code,
    phone: normalizedPhone,
    doctorId,
    createdAt,
    expiresAt: createdAt + CONTACT_OTP_TTL_MS,
    attempts: 0
  });

  try {
    await sendTextMessage(normalizedPhone, message);
  } catch (error) {
    otpStore.delete(normalizedPhone);
    throw error;
  }

  return {
    phone: normalizedPhone,
    expires_in_seconds: Math.floor(CONTACT_OTP_TTL_MS / 1000)
  };
}

async function verifyContactOtp(phone, code) {
  const normalizedPhone = normalizePhoneNumber(phone);
  const record = otpStore.get(normalizedPhone);
  const tokenAgeMs = record ? Date.now() - record.createdAt : Infinity;

  if (!record || tokenAgeMs > CONTACT_OTP_TTL_MS) {
    otpStore.delete(normalizedPhone);
    const err = new Error("Verification code has expired or is invalid");
    err.statusCode = 400;
    err.code = "VALIDATION_ERROR";
    throw err;
  }

  record.attempts += 1;
  if (record.code !== String(code || "").trim()) {
    if (record.attempts >= 5) otpStore.delete(normalizedPhone);
    const err = new Error("Invalid verification code");
    err.statusCode = 400;
    err.code = "VALIDATION_ERROR";
    throw err;
  }

  otpStore.delete(normalizedPhone);
  return record;
}

module.exports = {
  sendOtp,
  verifyOtp,
  sendContactOtp,
  verifyContactOtp
};
