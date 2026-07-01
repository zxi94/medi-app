const express = require("express");
const authMiddleware = require("../middleware/authMiddleware");
const { requireRole } = require("../middleware/roleMiddleware");
const { ROLES } = require("../constants/roles");
const {
  getMyXrays,
  getMyStats,
  getDoctorStats,
  getDoctorPatients,
  getPatientHistory,
  getDoctorHistory
} = require("../controllers/historyController");

const router = express.Router();

router.get("/my-xrays", authMiddleware, getMyXrays);
router.get("/my-stats", authMiddleware, getMyStats);
router.get("/doctor-stats", authMiddleware, requireRole(ROLES.DOCTOR), getDoctorStats);
router.get("/doctor-patients", authMiddleware, requireRole(ROLES.DOCTOR), getDoctorPatients);
router.get("/patient/:id", authMiddleware, getPatientHistory);
router.get("/doctor", authMiddleware, requireRole(ROLES.DOCTOR), getDoctorHistory);

module.exports = router;
