const AppError = require('../utils/AppError');

module.exports = (req, res, next) => {
  next(new AppError({
    status: 404,
    code: 'NOT_FOUND',
    message: 'Endpoint API tidak ditemukan.'
  }));
};
