class WhatsAppServiceError extends Error {
  constructor(message, details = null) {
    super(message);
    this.name = "WhatsAppServiceError";
    this.details = details;
  }
}

function normalizePhoneNumber(phoneNumber) {
  const digits = String(phoneNumber || "").replace(/\D/g, "");
  if (!digits) return "";
  if (digits.startsWith("00")) return digits.slice(2);
  // Egyptian local format: starts with 0 and is 11 digits → prepend country code 20
  if (digits.startsWith("0") && digits.length === 11) return `20${digits.slice(1)}`;
  return digits;
}

function getEvolutionConfig() {
  return {
    apiUrl: (process.env.EVO_API_URL || "").replace(/\/+$/, ""),
    apiKey: process.env.EVO_API_KEY || "",
    instanceName: process.env.EVO_INSTANCE_NAME || ""
  };
}

/**
 * Sends a WhatsApp text message via Evolution API v2.
 * Evolution API v2 expects: { number, options, textMessage: { text } }
 * NOT the older format: { number, options, text }
 */
async function sendTextMessage(phoneNumber, message) {
  const { apiUrl, apiKey, instanceName } = getEvolutionConfig();
  const number = normalizePhoneNumber(phoneNumber);
  const text = String(message || "").trim();

  if (!apiUrl || !apiKey || !instanceName) {
    throw new WhatsAppServiceError(
      "Evolution API configuration is incomplete. Check EVO_API_URL, EVO_API_KEY, and EVO_INSTANCE_NAME in .env"
    );
  }

  if (!number) {
    throw new WhatsAppServiceError("Recipient phone number is required");
  }

  if (!text) {
    throw new WhatsAppServiceError("Message text is required");
  }

  const requestUrl = `${apiUrl}/message/sendText/${instanceName}`;

  // Evolution API v1 & v2 hybrid payload format
  // Some instances require "textMessage: { text }", while others require "text" at the root.
  const payload = {
    number,
    options: {
      delay: 1200,
      presence: "composing",
      linkPreview: false
    },
    textMessage: {
      text
    },
    text: text
  };

  const controller = new AbortController();
  const timeout = setTimeout(
    () => controller.abort(),
    Number(process.env.EVO_API_TIMEOUT_MS || 10000)
  );

  try {
    // eslint-disable-next-line no-console
    console.log(`[WhatsApp] Sending message to ${number} via ${requestUrl}`);

    const response = await fetch(requestUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        apikey: apiKey
      },
      body: JSON.stringify(payload),
      signal: controller.signal
    });

    const responseText = await response.text();
    let responseBody = null;
    if (responseText) {
      try {
        responseBody = JSON.parse(responseText);
      } catch (_err) {
        responseBody = responseText;
      }
    }

    if (!response.ok) {
      // eslint-disable-next-line no-console
      console.error(`❌ [Evolution API] Status ${response.status} — Failed sending to ${number}`);
      // eslint-disable-next-line no-console
      console.error("📝 [Evolution API] Request payload:", JSON.stringify(payload, null, 2));
      // eslint-disable-next-line no-console
      console.error("🚨 [Evolution API] Remote error response:", JSON.stringify(responseBody, null, 2));
      throw new WhatsAppServiceError(
        `Evolution API failed with status ${response.status}`,
        responseBody
      );
    }

    // eslint-disable-next-line no-console
    console.log(`✅ [WhatsApp] Message delivered to ${number}`);
    return responseBody;
  } catch (error) {
    if (error.name === "WhatsAppServiceError") throw error;
    if (error.name === "AbortError") {
      throw new WhatsAppServiceError("Evolution API request timed out");
    }
    // eslint-disable-next-line no-console
    console.error("🚨 [Evolution API] Network connection error:", error.message);
    throw new WhatsAppServiceError("Evolution API request failed", error.message || null);
  } finally {
    clearTimeout(timeout);
  }
}

module.exports = {
  sendTextMessage,
  normalizePhoneNumber,
  WhatsAppServiceError
};
