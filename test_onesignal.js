const https = require('https');

const ONESIGNAL_APP_ID = '74f25810-49aa-4dd1-938c-c30229368a63';
const ONESIGNAL_REST_KEY = 'os_v2_app_otzfqecjvjg5de4mymbcsnukmonqgdbtkt5urbupftj4pnazuivy4g6blrfco6fmrqurdgvqpt7x26yg4fqvb65p7gls3m42ktckbnq';

async function testHeader(authHeader) {
  const payload = JSON.stringify({
    app_id: ONESIGNAL_APP_ID,
    headings: { tr: '🚢 İsdemir Limanı Test Bildirimi', en: 'Port Test' },
    contents: { tr: 'Yeni gemi yanaşma testi: CHEMICAL EXPLORER', en: 'Test notification' },
    included_segments: ['Total Subscriptions'],
  });

  const options = {
    hostname: 'onesignal.com',
    path: '/api/v1/notifications',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Authorization': authHeader,
    }
  };

  return new Promise((resolve) => {
    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', d => data += d);
      res.on('end', () => {
        console.log(`[${authHeader.split(' ')[0]}] Status: ${res.statusCode} -> ${data}`);
        resolve();
      });
    });
    req.on('error', e => console.error(e));
    req.write(payload);
    req.end();
  });
}

async function runTests() {
  await testHeader(`Bearer ${ONESIGNAL_REST_KEY}`);
  await testHeader(`Key ${ONESIGNAL_REST_KEY}`);
  await testHeader(`Basic ${Buffer.from(ONESIGNAL_REST_KEY + ':').toString('base64')}`);
  await testHeader(`Basic ${ONESIGNAL_REST_KEY}`);
}

runTests();
