const { sendSuccess, sendError } = require("../utils/response");
const aiService = require("../services/aiService");

/**
 * POST /api/system/update-ai-endpoint
 *
 * Called by Colab when it starts up and gets an ngrok URL.
 * Body: { url: "https://xxxx.ngrok-free.app", token: "<shared secret>" }
 */
async function updateAiEndpoint(req, res, next) {
  try {
    const { url, token } = req.body;

    // Validate shared secret
    const expectedToken = process.env.AI_SYSTEM_SECRET;
    if (!expectedToken) {
      return sendError(res, {
        statusCode: 500,
        message: "AI_SYSTEM_SECRET not configured on server.",
        code: "CONFIG_ERROR"
      });
    }

    if (!token || token !== expectedToken) {
      return sendError(res, {
        statusCode: 401,
        message: "Invalid or missing system token.",
        code: "AUTH_ERROR"
      });
    }

    if (!url || typeof url !== "string" || !url.startsWith("http")) {
      return sendError(res, {
        statusCode: 400,
        message: "A valid URL is required (must start with http).",
        code: "VALIDATION_ERROR"
      });
    }

    // Update the AI service URL
    aiService.setAiUrl(url);

    // eslint-disable-next-line no-console
    console.log(`[System] AI endpoint updated to: ${url}`);

    return sendSuccess(res, {
      statusCode: 200,
      message: "AI endpoint updated successfully.",
      data: { url }
    });
  } catch (error) {
    return next(error);
  }
}

/**
 * GET /api/system/ai-status
 *
 * Returns the current AI endpoint URL and its health status.
 */
async function getAiStatus(req, res, next) {
  try {
    const url = aiService.getAiUrl();
    let healthy = false;

    if (url) {
      try {
        healthy = await aiService.checkAiHealth();
      } catch (_) {
        healthy = false;
      }
    }

    return sendSuccess(res, {
      statusCode: 200,
      message: "AI status retrieved.",
      data: {
        ai_url: url || null,
        healthy,
        configured: !!url
      }
    });
  } catch (error) {
    return next(error);
  }
}

module.exports = { updateAiEndpoint, getAiStatus };
