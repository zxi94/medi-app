const API_URL = 'http://localhost:5001';

async function testChat() {
  console.log("1. Logging in...");
  const loginRes = await fetch(`${API_URL}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: 'dr.f583e799@test.com', password: 'Password123!' })
  });
  
  if (!loginRes.ok) {
    console.error("Login failed!", await loginRes.text());
    return;
  }
  const loginData = await loginRes.json();
  const token = loginData.data.token;
  console.log("✅ Login successful. Token acquired.");

  console.log("\n2. Sending Chat Request (Measuring Time)...");
  const startTime = Date.now();
  
  try {
    const chatRes = await fetch(`${API_URL}/api/chat/ai`, {
      method: 'POST',
      headers: { 
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
      },
      body: JSON.stringify({
        question: "Is pneumonia dangerous?",
        finding: "Consolidation",
        language: "en"
      })
    });
    
    const endTime = Date.now();
    const data = await chatRes.json();
    
    console.log(`\n⏱️ Time taken: ${((endTime - startTime) / 1000).toFixed(2)} seconds`);
    
    if (chatRes.ok) {
      console.log("✅ Chat Response Success!");
      console.log("Answer:", data.data.answer);
    } else {
      console.log("❌ Chat Error Status:", chatRes.status);
      console.log("Error Data:", data);
    }
  } catch (err) {
    console.error("Fetch Error:", err);
  }
}

testChat();
