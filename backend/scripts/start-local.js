// Use a dedicated app port; PORT overrides it when a deployment needs another port.
process.env.PORT = process.env.PORT || '5002';
const app = require('../server');
app.listen(Number(process.env.PORT), '0.0.0.0', () => console.log(`ReportR backend listening on ${process.env.PORT}`));
