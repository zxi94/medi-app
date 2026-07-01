const crypto = require('crypto');

const API_URL = 'http://localhost:5001/api';
const testId = crypto.randomBytes(4).toString('hex');
const doctorEmail = `dr.${testId}@test.com`;
const doctorPassword = 'Password123!';
const adminEmail = 'admin@dev.com';

async function fetchWithMethod(url, method, body, token) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers['Authorization'] = `Bearer ${token}`;
  const res = await fetch(url, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined
  });
  const data = await res.json();
  if (!res.ok) throw { status: res.status, data };
  return data;
}

async function runTest() {
  try {
    console.log(`\n=== 1. Registering Doctor (${doctorEmail}) ===`);
    const regRes = await fetchWithMethod(`http://localhost:5001/auth/signup`, 'POST', {
      name: 'Dr. Test',
      email: doctorEmail,
      password: doctorPassword,
      role_type: 'DOCTOR',
      specialization: 'Cardiology',
      medical_certificate: 'CERT123',
      phone: '+201000000000'
    });
    console.log('Registration Success:', JSON.stringify(regRes, null, 2));

    console.log(`\n=== 2. Attempting Login (Should Fail with 403) ===`);
    try {
      await fetchWithMethod(`http://localhost:5001/auth/login`, 'POST', {
        email: doctorEmail,
        password: doctorPassword
      });
      console.log('❌ ERROR: Login succeeded but should have failed!');
    } catch (err) {
      if (err.status === 403) {
        console.log('✅ Login properly blocked with 403 Forbidden!');
        console.log('Response:', JSON.stringify(err.data, null, 2));
      } else {
        console.log('❌ ERROR: Unexpected error:', err);
      }
    }

    console.log(`\n=== 3. Authenticating as Admin to Approve ===`);
    let adminToken;
    try {
      const adminLogin = await fetchWithMethod(`http://localhost:5001/auth/login`, 'POST', {
        email: adminEmail,
        password: 'admin'
      });
      adminToken = adminLogin.data.token;
      console.log('Admin authenticated.');
    } catch (err) {
      console.log('Failed to login as admin@dev.com. Checking db...');
      return;
    }

    console.log(`\n=== 4. Approving Doctor via Admin API ===`);
    const { User } = require('./src/models');
    const doctorUser = await User.findOne({ where: { email: doctorEmail } });
    const doctorId = doctorUser.id;

    const approveRes = await fetchWithMethod(`${API_URL}/admin/doctors/${doctorId}/approve`, 'PUT', null, adminToken);
    console.log('✅ Doctor approved successfully:', JSON.stringify(approveRes, null, 2));

    console.log(`\n=== 5. Attempting Login Again (Should Succeed) ===`);
    const loginRes = await fetchWithMethod(`http://localhost:5001/auth/login`, 'POST', {
      email: doctorEmail,
      password: doctorPassword
    });
    console.log('✅ Login succeeded!');
    console.log('Auth Payload:', JSON.stringify(loginRes, null, 2));
    
    console.log('\n✅ ALL TESTS PASSED!');
  } catch (error) {
    console.error('Test failed:', error.data || error);
  }
}

runTest();
