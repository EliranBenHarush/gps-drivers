const https = require('https');

// Nominatim finds house numbers better when number comes before street name.
// If query looks like "רחוב 5" or "רחוב 5, עיר", reorder to "5 רחוב, עיר".
function reorderQuery(q) {
  // Match: word(s) then space then number, optionally followed by comma + city
  const match = q.match(/^(.+?)\s+(\d+)(.*)$/);
  if (match) {
    const street = match[1].trim();
    const number = match[2];
    const rest = match[3]; // e.g. ", בת ים"
    return number + ' ' + street + rest;
  }
  return q;
}

exports.handler = async function (event) {
  const q = (event.queryStringParameters && event.queryStringParameters.q) || '';
  if (!q) {
    return { statusCode: 400, body: JSON.stringify([]) };
  }

  const reordered = reorderQuery(q);

  const url =
    'https://nominatim.openstreetmap.org/search' +
    '?q=' + encodeURIComponent(reordered) +
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
