const { z } = require('zod');

const isoDateSchema = z.string().refine(val => {
  // Simple regex or parse test for ISO-8601 date string
  const d = new Date(val);
  return !isNaN(d.getTime());
}, {
  message: "Must be a valid date string"
});

module.exports = {
  isoDateSchema
};
