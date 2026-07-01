const app = require('./src/app');
const { sequelize } = require('./src/models');
async function run() {
  const server = app.listen(5003, () => console.log('listening'));
  await sequelize.authenticate();
  console.log('authenticated');
  await sequelize.sync();
  console.log('synced');
}
run();
