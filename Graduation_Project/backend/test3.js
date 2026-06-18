const app = require('./src/app');
const { sequelize } = require('./src/models');
async function run() {
  await sequelize.authenticate();
  console.log('authenticated');
  await sequelize.sync();
  console.log('synced');
  app.listen(5003, () => console.log('listening'));
}
run();
