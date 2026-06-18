const Joi = require("joi");
const { ROLES } = require("../constants/roles");

function validateBody(schema) {
  return (req, _res, next) => {
    const { error, value } = schema.validate(req.body, {
      abortEarly: false,
      allowUnknown: true,
      stripUnknown: true
    });

    if (error) {
      error.statusCode = 400;
      error.code = "VALIDATION_ERROR";
      error.message = error.details?.[0]?.message || "Validation error";
      return next(error);
    }

    req.body = value;
    return next();
  };
}

function validateParams(schema) {
  return (req, _res, next) => {
    const { error, value } = schema.validate(req.params, {
      abortEarly: false,
      allowUnknown: true,
      stripUnknown: true,
      convert: true
    });

    if (error) {
      error.statusCode = 400;
      error.code = "VALIDATION_ERROR";
      error.message = error.details?.[0]?.message || "Validation error";
      return next(error);
    }

    req.params = value;
    return next();
  };
}

const signupSchema = Joi.object({
  name: Joi.string().min(1).required(),
  email: Joi.string().email().required(),
  password: Joi.string().min(8).required(),
  phone: Joi.string().min(7).allow(null, "").optional(),
  role: Joi.string().uppercase().valid(ROLES.PATIENT, ROLES.DOCTOR).default(ROLES.PATIENT),
  role_type: Joi.string().uppercase().valid(ROLES.PATIENT, ROLES.DOCTOR).optional(),
  // Patient-only fields
  gender: Joi.when("role_type", {
    is: ROLES.DOCTOR,
    then: Joi.string().allow(null, "").optional(),
    otherwise: Joi.when("role", {
      is: ROLES.DOCTOR,
      then: Joi.string().allow(null, "").optional(),
      otherwise: Joi.string().min(1).required()
    })
  }),
  dob: Joi.when("role_type", {
    is: ROLES.DOCTOR,
    then: Joi.string().allow(null, "").optional(),
    otherwise: Joi.when("role", {
      is: ROLES.DOCTOR,
      then: Joi.string().allow(null, "").optional(),
      otherwise: Joi.string().min(1).required()
    })
  }),
  medical_history: Joi.string().allow(null, "").optional(),
  // Doctor-only fields
  specialization: Joi.when("role_type", {
    is: ROLES.DOCTOR,
    then: Joi.string().min(1).required(),
    otherwise: Joi.when("role", {
      is: ROLES.DOCTOR,
      then: Joi.string().min(1).required(),
      otherwise: Joi.string().allow(null, "").optional()
    })
  }),
  medical_certificate: Joi.when("role_type", {
    is: ROLES.DOCTOR,
    then: Joi.string().min(1).required(),
    otherwise: Joi.when("role", {
      is: ROLES.DOCTOR,
      then: Joi.string().min(1).required(),
      otherwise: Joi.string().allow(null, "").optional()
    })
  })
}).required();


const loginSchema = Joi.object({
  email: Joi.string().email().required(),
  password: Joi.string().min(1).required()
}).required();

const otpSendSchema = Joi.object({
  phone: Joi.string().min(7).allow(null, "").optional()
}).required();

const otpVerifySchema = Joi.object({
  phone: Joi.string().min(7).required(),
  code: Joi.string().pattern(/^\d{6}$/).required()
}).required();

const analyzeIdSchema = Joi.object({
  id: Joi.number().integer().positive().required()
}).required();

function validateXrayUpload(req, _res, next) {
  if (!req.file) {
    const err = new Error("X-ray file is required");
    err.statusCode = 400;
    err.code = "VALIDATION_ERROR";
    return next(err);
  }

  const role = String(req.user?.role || "").toUpperCase();
  const patientIdSchema = Joi.number().integer().positive();
  const schema = Joi.object({
    patient_id: patientIdSchema.optional()
  }).required();

  const { error, value } = schema.validate(req.body, {
    abortEarly: false,
    allowUnknown: true,
    stripUnknown: true,
    convert: true
  });

  if (error) {
    error.statusCode = 400;
    error.code = "VALIDATION_ERROR";
    error.message = error.details?.[0]?.message || "Validation error";
    return next(error);
  }

  req.body = value;
  return next();
}

module.exports = {
  validateBody,
  validateParams,
  validateXrayUpload,
  signupSchema,
  loginSchema,
  otpSendSchema,
  otpVerifySchema,
  analyzeIdSchema
};
