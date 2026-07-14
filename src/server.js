const app = require('./app');
const { PORT } = require('./config/env');

app.listen(PORT, () => {
  console.log(`[Mock API Backend] Running on http://localhost:${PORT}`);
});
