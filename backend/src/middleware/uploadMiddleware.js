const multer = require("multer");
const path = require("path");
const fs = require("fs");

const uploadDir = path.resolve(process.cwd(), process.env.UPLOAD_DIR || "uploads");
fs.mkdirSync(uploadDir, { recursive: true });

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, uploadDir),
  filename: (_req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    cb(null, `${Date.now()}-${Math.round(Math.random() * 1e9)}${ext}`);
  }
});

const fileFilter = (_req, file, cb) => {
  const allowed = [".png", ".jpg", ".jpeg", ".dcm"];
  const ext = path.extname(file.originalname).toLowerCase();
  if (!allowed.includes(ext)) return cb(new Error("Unsupported file type"));
  return cb(null, true);
};

const maxBytes = Number(process.env.MAX_FILE_SIZE_MB || 10) * 1024 * 1024;
const upload = multer({ storage, fileFilter, limits: { fileSize: maxBytes } });

module.exports = upload;
