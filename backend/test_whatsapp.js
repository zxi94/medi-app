const { sendTextMessage } = require('./src/services/whatsappService');
require('dotenv').config();

async function run() {
  console.log("Testing WhatsApp Service via Evolution API...");
  try {
    // We test with a dummy number. If the API is working, it should reach out to 
    // WhatsApp and return either success or a "number not on WhatsApp" error.
    const res = await sendTextMessage('+201000000000', 'Test OTP: 123456');
    console.log("✅ Response:", res);
  } catch (err) {
    console.error("❌ Caught error:", err.message);
    if (err.details) {
      console.error("   Details:", JSON.stringify(err.details, null, 2));
    }
  }
}

run();
