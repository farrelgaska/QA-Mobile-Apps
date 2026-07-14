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

const translatePostgresError = (error, entity, id) => {
  if (error?.code === '23505') return conflict(`${entity} with ID ${id} already exists`);
  return error;
};

module.exports = { notFound, conflict, translatePostgresError };
