const https = require('https');

const MAPBOX_TOKEN = 'pk.eyJ1IjoiZWxpcmFuYmgiLCJhIjoiY21rMmRyMzdqMGlpcDNmcXkycjZ2ZGhjMiJ9.nXK-AUEMPib6HTYBbnEPlQ';

exports.handler = async function (event) {
  const q = (event.queryStringParameters && event.queryStringParameters.q) || '';
  if (!q) {
    return { statusCode: 400, body: JSON.stringify([]) };
  }

  const encoded = encodeURIComponent(q.trim());
  const url =
    'https://api.mapbox.com/geocoding/v5/mapbox.places/' + encoded + '.json' +
    '?access_token=' + MAPBOX_TOKEN +
    '&country=il' +
    '&language=he' +
    '&limit=5' +
    '&types=address';

  return new Promise((resolve) => {
    https
      .get(url, { headers: { 'User-Agent': 'gps-drivers-netlify/1.0' } }, (res) => {
        let data = '';
        res.on('data', (chunk) => (data += chunk));
        res.on('end', () => {
          try {
            const json = JSON.parse(data);
            const features = json.features || [];
            // Transform Mapbox format to match what Flutter expects
            const results = features.map((f) => ({
              display_name: f.place_name,
              lon: String(f.geometry.coordinates[0]),
              lat: String(f.geometry.coordinates[1]),
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
      })
      .on('error', (e) => {
        resolve({ statusCode: 500, body: JSON.stringify({ error: e.message }) });
      });
  });
};
