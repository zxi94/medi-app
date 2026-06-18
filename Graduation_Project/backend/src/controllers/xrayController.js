const fs = require('fs');
const path = require('path');
const { XrayImage, ResultImage, Patient, Doctor } = require("../models");
const { analyzeXrayWithAI, generateReport } = require("../services/aiService");
const { sendTextMessage } = require("../services/whatsappService");
const { ROLES } = require("../constants/roles");
const { sendError, sendSuccess } = require("../utils/response");

function formatDiagnosisSummary(diagnosisOutput = {}) {
  const label = diagnosisOutput.label || diagnosisOutput.prediction || "analysis completed";
  const confidence = Number(diagnosisOutput.confidence);
  const confidenceText =
    Number.isFinite(confidence) && confidence > 0
      ? ` with ${Math.round(confidence * 100)}% confidence`
      : "";

  return `${label}${confidenceText}`;
}

async function notifyPatientAnalysisComplete(xray, result) {
  let recipient = null;
  let name = "";
  
  if (xray.patient_id) {
    const patient = await Patient.findByPk(xray.patient_id);
    if (patient?.phone) {
      recipient = patient.phone;
      name = patient.name ? ` ${patient.name}` : "";
    }
  } else if (xray.doctor_id) {
    const doctor = await Doctor.findByPk(xray.doctor_id);
    if (doctor?.phone) {
      recipient = doctor.phone;
      name = doctor.name ? ` Dr. ${doctor.name}` : "";
    }
  }

  if (!recipient) return;

  const summary = formatDiagnosisSummary(result.diagnosis_output || {});
  await sendTextMessage(
    recipient,
    `Hello${name}, your MediScan AI X-ray analysis is complete. Result summary: ${summary}.`
  );
}

async function processAiAnalysis(xrayPath, xrayId, language = "en") {
  try {
    const aiResult = await analyzeXrayWithAI({ imagePath: xrayPath });
    
    // Save heatmap if available
    let savedHeatmapPath = null;
    if (aiResult.heatmaps && Object.keys(aiResult.heatmaps).length > 0) {
      const firstKey = Object.keys(aiResult.heatmaps)[0];
      const base64Data = aiResult.heatmaps[firstKey];
      const buffer = Buffer.from(base64Data, 'base64');
      savedHeatmapPath = `uploads/heatmaps/heatmap_${xrayId}_${Date.now()}.png`;
      const fullPath = path.join(__dirname, '../../', savedHeatmapPath);
      // Ensure directory exists
      await fs.promises.mkdir(path.dirname(fullPath), { recursive: true });
      await fs.promises.writeFile(fullPath, buffer);
    }

    // Generate LLM report
    let aiReportData = null;
    try {
      // Qwen expects an array of prediction strings
      const preds = aiResult.predictions || [];
      if (preds.length === 0 && aiResult.diagnosis_output?.label) {
        preds.push(aiResult.diagnosis_output.label);
      }
      aiReportData = await generateReport({ predictions: preds, language: language });
    } catch (reportErr) {
      console.error("Report generation failed:", reportErr);
    }

    const result = await ResultImage.create({
      xray_id: xrayId,
      diagnosis_output: aiResult.diagnosis_output || {},
      heatmap_path: savedHeatmapPath || aiResult.heatmap_path || null,
      bounding_boxes: aiResult.bounding_boxes || [],
      ai_report: aiReportData
    });
    
    return result;
  } catch (err) {
    console.error("Background AI analysis failed:", err);
    throw err;
  }
}

async function uploadXray(req, res, next) {
  try {
    if (!req.file) {
      return sendError(res, { statusCode: 400, message: "X-ray file is required", code: "VALIDATION_ERROR" });
    }
    const { patient_id } = req.body;
    const doctorId = req.user.role === ROLES.DOCTOR ? req.user.sub : null;
    const effectivePatientId = req.user.role === ROLES.PATIENT ? req.user.sub : (patient_id || null);

    const relativeImagePath = req.file.filename ? `uploads/${req.file.filename}` : req.file.path;
    
    // Fast synchronous check: Gatekeeper & RAD-DINO
    let aiResult;
    try {
      aiResult = await analyzeXrayWithAI({ imagePath: req.file.path });
    } catch (err) {
      return sendError(res, { statusCode: 400, message: "Please upload a suitable chest X-ray image.", code: "GATEKEEPER_REJECTED" });
    }

    // Only save to DB if Gatekeeper accepted it
    const xray = await XrayImage.create({
      patient_id: effectivePatientId,
      doctor_id: doctorId,
      image_path: relativeImagePath
    });

    // Save heatmap immediately
    let savedHeatmapPath = null;
    if (aiResult.heatmaps && Object.keys(aiResult.heatmaps).length > 0) {
      const firstKey = Object.keys(aiResult.heatmaps)[0];
      const base64Data = aiResult.heatmaps[firstKey];
      const buffer = Buffer.from(base64Data, 'base64');
      savedHeatmapPath = `uploads/heatmaps/heatmap_${xray.id}_${Date.now()}.png`;
      const fullPath = path.join(__dirname, '../../', savedHeatmapPath);
      await fs.promises.mkdir(path.dirname(fullPath), { recursive: true });
      await fs.promises.writeFile(fullPath, buffer);
    }

    // Create ResultImage with basic info but empty ai_report
    const result = await ResultImage.create({
      xray_id: xray.id,
      diagnosis_output: aiResult.diagnosis_output || {},
      heatmap_path: savedHeatmapPath || aiResult.heatmap_path || null,
      bounding_boxes: aiResult.bounding_boxes || [],
      ai_report: null
    });

    // Run LLM report generation in the background
    setImmediate(async () => {
      try {
        const preds = aiResult.predictions || [];
        if (preds.length === 0 && aiResult.diagnosis_output?.label) {
          preds.push({
            label: aiResult.diagnosis_output.label,
            probability: aiResult.diagnosis_output.confidence || 1.0,
            threshold: 0.5,
            positive: true,
            severity: "Unknown",
            info: ""
          });
        }
        const aiReportData = await generateReport({ predictions: preds, language: req.body.language || "en" });
        await result.update({ ai_report: aiReportData });
        await notifyPatientAnalysisComplete(xray, result);
      } catch (err) {
        console.error("LLM background generation failed:", err);
      }
    });

    return sendSuccess(res, {
      statusCode: 201,
      message: "Uploaded successfully. AI analysis is running in the background.",
      data: { xray },
      legacy: { xray }
    });
  } catch (error) {
    return next(error);
  }
}

async function analyzeXray(req, res, next) {
  try {
    const xray = await XrayImage.findByPk(req.params.id);
    if (!xray) {
      return sendError(res, { statusCode: 404, message: "X-ray not found", code: "NOT_FOUND" });
    }

    const result = await processAiAnalysis(xray.image_path, xray.id, req.body.language || "en");

    const resultPayload = {
      ...result.toJSON(),
      original_image_url: xray.image_path
    };

    notifyPatientAnalysisComplete(xray, result).catch((error) => {
      console.warn("[WhatsApp] Diagnosis notification failed:", error.message);
    });

    return sendSuccess(res, {
      statusCode: 200,
      message: "Analysis complete",
      data: { result: resultPayload },
      legacy: { result: resultPayload }
    });
  } catch (error) {
    return next(error);
  }
}

module.exports = { uploadXray, analyzeXray };
