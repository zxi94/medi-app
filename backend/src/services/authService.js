const bcrypt = require("bcrypt");
const { User, Doctor, Patient, sequelize } = require("../models");
const { ASSIGNABLE_SELF_REGISTRATION_ROLE, ROLES } = require("../constants/roles");
const { normalizePhoneNumber } = require("./whatsappService");

async function registerUser(input) {
  const { password, role_type, ...payload } = input;
  // role_type takes precedence over role (role defaults to PATIENT from Joi schema)
  const role = String(role_type || payload.role || ASSIGNABLE_SELF_REGISTRATION_ROLE).toUpperCase();

  const phone = payload.phone ? normalizePhoneNumber(payload.phone) : null;
  const hashedPassword = await bcrypt.hash(password, 12);

  if (![ROLES.PATIENT, ROLES.DOCTOR].includes(role)) {
    const err = new Error("Invalid registration role");
    err.statusCode = 400;
    err.code = "VALIDATION_ERROR";
    throw err;
  }

  const existingUser = await User.findOne({ where: { email: payload.email } });
  if (existingUser) {
    const err = new Error("Email already in use");
    err.statusCode = 409;
    err.code = "CONFLICT";
    throw err;
  }

  const createdUser = await sequelize.transaction(async (t) => {
    // Step A: Hash the password and insert the base record into the users table
    const baseUser = await User.create(
      {
        email: payload.email,
        password: hashedPassword,
        role,
        phone,
        is_verified: false,
        verification_status: "pending"
      },
      { transaction: t }
    );

    // Step B & C: Extract user_id and insert into doctor/patient profile table
    if (role === ROLES.DOCTOR) {
      await Doctor.create(
        {
          id: baseUser.id, // mapped to user_id column
          name: payload.name,
          specialization: payload.specialization,
          medical_certificate: payload.medical_certificate,
          approval_status: "PENDING"
        },
        { transaction: t }
      );
    } else {
      await Patient.create(
        {
          id: baseUser.id, // mapped to user_id column
          name: payload.name,
          gender: payload.gender,
          dob: payload.dob,
          medical_history: payload.medical_history
        },
        { transaction: t }
      );
    }

    return baseUser;
  });

  return {
    id: createdUser.id,
    email: createdUser.email,
    name: payload.name,
    phone: createdUser.phone,
    role: createdUser.role
  };
}

async function authenticateUser({ email, password }) {
  const user = await User.findOne({
    where: { email },
    include: [
      { model: Doctor, as: "doctor" },
      { model: Patient, as: "patient" }
    ]
  });

  if (!user) {
    return null;
  }

  const passwordMatches = await bcrypt.compare(password, user.password);
  if (!passwordMatches) {
    return null;
  }

  const role = String(user.role || "").toUpperCase();
  const profile = role === ROLES.DOCTOR ? user.doctor : user.patient;
  return {
    id: user.id,
    email: user.email,
    name: profile ? profile.name : "Admin",
    phone: user.phone,
    role,
    verification_status: user.verification_status,
    approval_status: user.doctor?.approval_status || null
  };
}

module.exports = {
  registerUser,
  authenticateUser
};
