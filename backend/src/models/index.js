const sequelize = require("../config/db");
const UserFactory = require("./User");
const DoctorFactory = require("./Doctor");
const PatientFactory = require("./Patient");
const XrayImageFactory = require("./XrayImage");
const ResultImageFactory = require("./ResultImage");
const DiagnosisReportFactory = require("./DiagnosisReport");
const ContactFactory = require("./Contact");
const ChatThreadFactory = require("./ChatThread");
const ChatMessageFactory = require("./ChatMessage");

const User = UserFactory(sequelize);
const Doctor = DoctorFactory(sequelize);
const Patient = PatientFactory(sequelize);
const XrayImage = XrayImageFactory(sequelize);
const ResultImage = ResultImageFactory(sequelize);
const DiagnosisReport = DiagnosisReportFactory(sequelize);
const Contact = ContactFactory(sequelize);
const ChatThread = ChatThreadFactory(sequelize);
const ChatMessage = ChatMessageFactory(sequelize);

// User Profile Associations (One-to-One)
User.hasOne(Patient, { foreignKey: "user_id", as: "patient" });
Patient.belongsTo(User, { foreignKey: "user_id", as: "user" });

User.hasOne(Doctor, { foreignKey: "user_id", as: "doctor" });
Doctor.belongsTo(User, { foreignKey: "user_id", as: "user" });

// Apply default scopes to automatically include the base User model on patient/doctor queries
Patient.addScope("defaultScope", {
  include: [{ model: User, as: "user" }]
}, { override: true });

Doctor.addScope("defaultScope", {
  include: [{ model: User, as: "user" }]
}, { override: true });

Patient.hasMany(XrayImage, { foreignKey: "patient_id" });
Doctor.hasMany(XrayImage, { foreignKey: "doctor_id" });
XrayImage.belongsTo(Patient, { foreignKey: "patient_id" });
XrayImage.belongsTo(Doctor, { foreignKey: "doctor_id" });

XrayImage.hasOne(ResultImage, { foreignKey: "xray_id" });
ResultImage.belongsTo(XrayImage, { foreignKey: "xray_id" });

Patient.hasMany(DiagnosisReport, { foreignKey: "patient_id" });
Doctor.hasMany(DiagnosisReport, { foreignKey: "doctor_id" });
ResultImage.hasMany(DiagnosisReport, { foreignKey: "result_id" });
DiagnosisReport.belongsTo(Patient, { foreignKey: "patient_id" });
DiagnosisReport.belongsTo(Doctor, { foreignKey: "doctor_id" });
DiagnosisReport.belongsTo(ResultImage, { foreignKey: "result_id" });

// Chat & Contact Associations
Doctor.hasMany(Contact, { foreignKey: "doctor_id", as: "contacts" });
Contact.belongsTo(Doctor, { foreignKey: "doctor_id", as: "doctor" });

Patient.hasMany(Contact, { foreignKey: "patient_id", as: "contacts" });
Contact.belongsTo(Patient, { foreignKey: "patient_id", as: "patient" });

Patient.hasMany(ChatThread, { foreignKey: "patient_id", as: "threads" });
ChatThread.belongsTo(Patient, { foreignKey: "patient_id", as: "patient" });

Doctor.hasMany(ChatThread, { foreignKey: "doctor_id", as: "threads" });
ChatThread.belongsTo(Doctor, { foreignKey: "doctor_id", as: "doctor" });

ChatThread.hasMany(ChatMessage, { foreignKey: "thread_id", as: "messages" });
ChatMessage.belongsTo(ChatThread, { foreignKey: "thread_id", as: "thread" });

User.hasMany(ChatMessage, { foreignKey: "sender_user_id", as: "messages" });
ChatMessage.belongsTo(User, { foreignKey: "sender_user_id", as: "sender" });

module.exports = {
  sequelize,
  User,
  Doctor,
  Patient,
  XrayImage,
  ResultImage,
  DiagnosisReport,
  Contact,
  ChatThread,
  ChatMessage
};
