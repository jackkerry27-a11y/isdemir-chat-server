const https = require('https');

async function testVF() {
  const req = https.request({
    hostname: 'www.vesselfinder.com',
    path: '/ports/ISDEMIR-TR-TURKEY-3056',
    method: 'GET',
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    }
  }, (r) => {
    let body = '';
    r.on('data', d => body += d);
    r.on('end', () => {
      console.log('Status:', r.statusCode);
      console.log('Body start:\n', body.substring(0, 1000));
    });
  });
  req.end();
}
testVF();
