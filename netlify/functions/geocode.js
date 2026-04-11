const https = require('https');

exports.handler = async function (event) {
  const q = (event.queryStringParameters && event.queryStringParameters.q) || '';
  if (!q) {
    return { statusCode: 400, body: JSON.stringify([]) };
  }

  const url =
    'https://nominatim.openstreetmap.org/search' +
    '?q=' + encodeURIComponent(q) +
    '&format=json' +
    '&addressdetails=1' +
    '&limit=5' +
    '&countrycodes=il' +
    '&accept-language=he';

  return new Promise((resolve) => {
    https
      .get(url, { headers: { 'User-Agent': 'gps-drivers-netlify/1.0' } }, (res) => {
        let data = '';
        res.on('data', (chunk) => (data += chunk));
        res.on('end', () => {
          resolve({
            statusCode: 200,
            headers: { 'Content-Type': 'application/json' },
            body: data,
          });
        });
      })
      .on('error', (e) => {
        resolve({ statusCode: 500, body: JSON.stringify({ error: e.message }) });
      });
  });
};
