const express = require("express");
const { approveDoctor, rejectDoctor, listDoctors, suspendUser } = require("../controllers/adminController");
const authMiddleware = require("../middleware/authMiddleware");
const { requireRole } = require("../middleware/roleMiddleware");
const { ROLES } = require("../constants/roles");

const router = express.Router();

// All admin routes require authentication + ADMIN role
const adminGuard = [authMiddleware, requireRole(ROLES.ADMIN)];

// GET  /api/admin/doctors?status=PENDING|APPROVED|REJECTED
router.get("/doctors", adminGuard, listDoctors);

// PUT  /api/admin/doctors/:id/approve
router.put("/doctors/:id/approve", adminGuard, approveDoctor);

// PUT  /api/admin/doctors/:id/reject
router.put("/doctors/:id/reject", adminGuard, rejectDoctor);

// PUT  /api/admin/users/:id/suspend
router.put("/users/:id/suspend", adminGuard, suspendUser);

module.exports = router;
