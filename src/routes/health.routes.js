const express = require('express');
const router = express.Router();
const { dataProvider } = require('../repositories');
const { checkDatabaseReachable } = require('../database/postgres');

router.get('/', async (req, res) => {
  const databaseReachable = await checkDatabaseReachable();
  res.json({
    status: 'OK',
    timestamp: new Date().toISOString(),
    data_provider: dataProvider,
    database_reachable: databaseReachable
  });
});

module.exports = router;
