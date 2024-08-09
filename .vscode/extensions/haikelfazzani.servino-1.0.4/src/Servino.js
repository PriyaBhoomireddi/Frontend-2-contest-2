const Monitor = require('./monitor/Monitor');

module.exports = function Servino(options) {
  
  let config = {
    ssl: options.ssl || null,
    host: options.host || '0.0.0.0',
    port: options.port || 8125,
    root: options.root,
    wdir: options.wdir || [options.root],
    delay: options.delay || 200,
    ignore: options.ignore || ['node_modules', '.git', '.cache'],
    inject: options.inject || true,
    open: options.open || true,
    verbose: false,
  }

  return {
    start() {
      Monitor.emit('start-process', config);
      Monitor.emit('start-watching-files', config);
    },

    stop() {
      Monitor.emit('kill-process');
    }
  }
}