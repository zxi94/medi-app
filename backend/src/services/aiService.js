/**
 * aiService.js
 *
 * Manages communication with the Colab-hosted FastAPI AI backend.
 * Supports:
 *   - Dynamic ngrok URL (set by Colab on startup)
 *   - Health-check before heavy requests
 *   - Exponential-backoff retry for transient failures
 *   - X-ray analysis (RAD-DINO + GradCAM)
 *   - Report generation (Qwen LLM)
 *   - RAG chatbot (FAISS + Qwen)
 */

const fs = require('fs');

// ─── In-memory AI URL store ────────────────────────────────────────────────
let _aiUrl = process.env.AI_SERVICE_URL || null;

function setAiUrl(url) {
  _aiUrl = url;
}

function getAiUrl() {
  return _aiUrl;
}

// ─── Error class ───────────────────────────────────────────────────────────
class AiServiceError extends Error {
  constructor({ message, code, statusCode = 502, details = null }) {
    super(message);
    this.code = code;
    this.statusCode = statusCode;
    this.details = details;
  }
}

// ─── Helpers ───────────────────────────────────────────────────────────────

function ensureAiUrl() {
  if (!_aiUrl) {
    throw new AiServiceError({
      message: "AI service URL is not configured. The Colab server may not have started yet.",
      code: "AI_NOT_CONFIGURED",
      statusCode: 503
    });
  }
  return _aiUrl;
}

/**
 * Lightweight health check — pings GET /health on the Colab server.
 * Returns true if healthy, false otherwise.
 */
async function checkAiHealth() {
  const url = ensureAiUrl();
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 5000);

  try {
    const response = await fetch(`${url}/health`, {
      method: "GET",
      headers: { "ngrok-skip-browser-warning": "true" },
      signal: controller.signal
    });
    return response.ok;
  } catch (_) {
    return false;
  } finally {
    clearTimeout(timeout);
  }
}

/**
 * Generic fetch with exponential-backoff retry.
 */
async function fetchWithRetry(fetchUrl, options, { maxRetries = 2, baseDelay = 1000 } = {}) {
  let lastError;

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      const mergedOptions = {
        ...options,
        headers: {
          "ngrok-skip-browser-warning": "true",
          ...(options.headers || {})
        }
      };
      const response = await fetch(fetchUrl, mergedOptions);

      if (!response.ok) {
        const text = await response.text().catch(() => "");
        throw new AiServiceError({
          message: `AI service responded with ${response.status}`,
          code: "AI_NON_2XX",
          statusCode: 502,
          details: { status: response.status, body: text }
        });
      }

      try {
        return await response.json();
      } catch (err) {
        throw new AiServiceError({
          message: "AI service returned invalid JSON",
          code: "AI_INVALID_RESPONSE",
          statusCode: 502,
          details: err?.message || null
        });
      }
    } catch (err) {
      lastError = err;

      // Don't retry on client errors or known structured errors
      if (err instanceof AiServiceError && err.statusCode < 500) {
        throw err;
      }

      if (attempt < maxRetries) {
        const delay = baseDelay * Math.pow(2, attempt);
        // eslint-disable-next-line no-console
        console.warn(`[AI] Retry ${attempt + 1}/${maxRetries} after ${delay}ms...`);
        await new Promise(resolve => setTimeout(resolve, delay));
      }
    }
  }

  // All retries exhausted
  if (lastError instanceof AiServiceError) throw lastError;

  throw new AiServiceError({
    message: "AI service network error after retries",
    code: "AI_NETWORK_ERROR",
    statusCode: 502,
    details: lastError?.message || null
  });
}

// ─── Domain helpers ────────────────────────────────────────────────────────

function normalizeAiResponse(aiJson) {
  return {
    diagnosis_output: aiJson?.diagnosis_output ?? aiJson?.diagnosisOutput ?? {},
    heatmap_path: aiJson?.heatmap_path ?? aiJson?.heatmapPath ?? null,
    heatmaps: aiJson?.heatmaps ?? {},
    bounding_boxes: aiJson?.bounding_boxes ?? aiJson?.boundingBoxes ?? [],
    predictions: aiJson?.predictions ?? []
  };
}

// ─── Public API ────────────────────────────────────────────────────────────

/**
 * Analyze an X-ray image using RAD-DINO + GradCAM on Colab.
 */
async function analyzeXrayWithAI({ imagePath }) {
  const baseUrl = ensureAiUrl();
  const timeoutMs = Number(process.env.AI_SERVICE_TIMEOUT_MS || 60000);
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);

  try {
    // Pre-flight health check
    const healthy = await checkAiHealth();
    if (!healthy) {
      throw new AiServiceError({
        message: "AI service is currently offline. Please ensure the Colab notebook is running.",
        code: "AI_OFFLINE",
        statusCode: 503
      });
    }

    const fileBuffer = await fs.promises.readFile(imagePath);
    const blob = new Blob([fileBuffer]);
    const formData = new FormData();
    formData.append("file", blob, "image.png");

    const aiJson = await fetchWithRetry(`${baseUrl}/predict`, {
      method: "POST",
      body: formData,
      signal: controller.signal
    });

    return normalizeAiResponse(aiJson);
  } catch (err) {
    if (err?.name === "AbortError") {
      throw new AiServiceError({
        message: "AI service timeout",
        code: "AI_TIMEOUT",
        statusCode: 504,
        details: { timeoutMs }
      });
    }
    throw err;
  } finally {
    clearTimeout(timeout);
  }
}

/**
 * Generate a structured radiology report using Qwen on Colab.
 *
 * @param {Object} params
 * @param {Array}  params.predictions - Array of detected findings from RAD-DINO
 * @param {string} params.language    - "en" or "ar"
 * @returns {Object} { findings, impression, recommendations, full_report }
 */
async function generateReport({ predictions, language = "en" }) {
  const baseUrl = ensureAiUrl();
  const timeoutMs = Number(process.env.AI_SERVICE_TIMEOUT_MS || 60000);
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const result = await fetchWithRetry(`${baseUrl}/generate_report`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ predictions, language }),
      signal: controller.signal
    });

    return result;
  } catch (err) {
    if (err?.name === "AbortError") {
      throw new AiServiceError({
        message: "Report generation timeout",
        code: "AI_TIMEOUT",
        statusCode: 504,
        details: { timeoutMs }
      });
    }
    throw err;
  } finally {
    clearTimeout(timeout);
  }
}

/**
 * Send a message to the RAG chatbot on Colab.
 *
 * @param {Object} params
 * @param {string} params.question    - User's question
 * @param {string} params.finding     - Current diagnosis finding
 * @param {string} params.session_id  - Session ID for memory
 * @param {string} params.language    - "en" or "ar"
 * @returns {Object} { answer, finding, success }
 */
async function chatWithAI({ question, finding, session_id, language = "en" }) {
  const baseUrl = ensureAiUrl();
  const timeoutMs = Number(process.env.AI_CHAT_TIMEOUT_MS || process.env.AI_SERVICE_TIMEOUT_MS || 120000);
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);

  try {
    // Chat uses fewer retries (1 vs 2) and shorter delay to reduce latency.
    // LLM inference on Kaggle through ngrok is inherently slow; retrying
    // a failed heavy request rarely helps and just adds wait time.
    const result = await fetchWithRetry(`${baseUrl}/chat`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ question, finding, session_id, language }),
      signal: controller.signal
    }, { maxRetries: 1, baseDelay: 500 });

    return result;
  } catch (err) {
    if (err?.name === "AbortError") {
      throw new AiServiceError({
        message: "Chatbot response timeout",
        code: "AI_TIMEOUT",
        statusCode: 504,
        details: { timeoutMs }
      });
    }
    throw err;
  } finally {
    clearTimeout(timeout);
  }
}

module.exports = {
  setAiUrl,
  getAiUrl,
  checkAiHealth,
  analyzeXrayWithAI,
  generateReport,
  chatWithAI
};
