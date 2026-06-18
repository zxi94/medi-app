const app = require('./src/app');
const server = app.listen(5003, () => {
  console.log('Test server on 5003');
  console.log('Server ref status:', server.hasRef ? server.hasRef() : 'unknown');
});
