const http = require('http');
http.get({ host: 'localhost', port: 3000, path: '/health' }, res => {
  let data = ''; res.on('data', d => data += d); res.on('end', () => console.log('health', res.statusCode, data));
});
