module.exports = (err, req, res, next) => {
  console.error('API Error:', err);
  
  const statusCode = err.statusCode || 500;
  const message = statusCode >= 500 && !err.statusCode
    ? 'Internal Server Error'
    : (err.message || 'Internal Server Error');
  
  res.status(statusCode).json({ error: message });
};
