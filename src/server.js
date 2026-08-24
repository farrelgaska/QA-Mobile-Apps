const app = require('./app');
const { PORT, DATA_PROVIDER, STORAGE_PROVIDER, APP_ENV } = require('./config/env');
const logger = require('./utils/logger');

app.listen(PORT, () => {
  logger.info('application_started', {
    port: PORT,
    environment: APP_ENV,
    data_provider: DATA_PROVIDER,
    storage_provider: STORAGE_PROVIDER || (DATA_PROVIDER === 'json' ? 'local' : 'unconfigured')
  });
});
