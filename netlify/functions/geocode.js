const https = require('https');

exports.handler = async function (event) {
  const q = (event.queryStringParameters && event.queryStringParameters.q) || '';
  if (!q) {
    return { statusCode: 400, body: JSON.stringify([]) };
  }

  const GOOGLE_KEY = process.env.GOOGLE_PLACES_KEY;
  if (!GOOGLE_KEY) {
    return { statusCode: 500, body: JSON.stringify({ error: 'missing api key' }) };
  }

  const requestBody = JSON.stringify({
    textQuery: q.trim(),
    languageCode: 'he',
    regionCode: 'IL',
    maxResultCount: 5,
  });

  return new Promise((resolve) => {
    const options = {
      hostname: 'places.googleapis.com',
      path: '/v1/places:searchText',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': GOOGLE_KEY,
        'X-Goog-FieldMask': 'places.displayName,places.formattedAddress,places.location',
      },
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        try {
          const json = JSON.parse(data);
          const places = json.places || [];
          const results = places.map((p) => ({
            display_name: p.formattedAddress || p.displayName?.text || '',
            lon: String(p.location.longitude),
            lat: String(p.location.latitude),
          }));
          resolve({
            statusCode: 200,
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(results),
          });
        } catch (e) {
          resolve({ statusCode: 500, body: JSON.stringify({ error: 'parse error' }) });
        }
      });
    });

    req.on('error', (e) => {
      resolve({ statusCode: 500, body: JSON.stringify({ error: e.message }) });
    });

    req.write(requestBody);
    req.end();
  });
};
