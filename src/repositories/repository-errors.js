const notFound = message => {
  const error = new Error(message);
  error.statusCode = 404;
  return error;
};

const conflict = message => {
  const error = new Error(message);
  error.statusCode = 409;
  return error;
};

const finalConclusionViolation = message => {
  const error = new Error(message);
  error.statusCode = 422;
  return error;
};

const translatePostgresError = (error, entity, id) => {
  if (error?.code === '23505') return conflict(`${entity} with ID ${id} already exists`);
  if (error?.code === '23514' &&
      /with status (?:NEEDS_FOLLOW_UP|APPROVED) requires an explicit final conclusion/.test(
        error.message || ''
      )) {
    return finalConclusionViolation(error.message);
  }
  return error;
};

module.exports = {
  notFound,
  conflict,
  finalConclusionViolation,
  translatePostgresError
};
