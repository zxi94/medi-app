const { Sequelize } = require('sequelize');
const sequelize = new Sequelize('medical_imaging_db', 'postgres', '12345', {
  host: 'localhost',
  dialect: 'postgres',
  logging: false,
});

async function test() {
  try {
    await sequelize.authenticate();
    console.log('Connection has been established successfully.');
    const [results, metadata] = await sequelize.query("SELECT 1+1 AS result");
    console.log('Query result:', results);
  } catch (error) {
    console.error('Unable to connect to the database:', error);
  } finally {
    await sequelize.close();
  }
}

test();
