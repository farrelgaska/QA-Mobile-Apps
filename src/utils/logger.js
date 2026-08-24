const createLogger = ({ sink = console, now = () => new Date() } = {}) => {
  const emit = (level, event, fields = {}) => {
    const write = sink[level] || sink.log;
    write.call(sink, JSON.stringify({
      timestamp: now().toISOString(),
      level,
      event,
      ...fields
    }));
  };

  return {
    debug: (event, fields) => emit('debug', event, fields),
    info: (event, fields) => emit('info', event, fields),
    warn: (event, fields) => emit('warn', event, fields),
    error: (event, fields) => emit('error', event, fields)
  };
};

const logger = createLogger();
logger.createLogger = createLogger;

module.exports = logger;
