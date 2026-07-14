const app = require('./app');
const { PORT, DATA_PROVIDER } = require('./config/env');

app.listen(PORT, () => {
  console.log(`[Mock API Backend] Running on http://localhost:${PORT}`);
  console.log(`[Mock API Backend] Data provider: ${DATA_PROVIDER}`);
});
