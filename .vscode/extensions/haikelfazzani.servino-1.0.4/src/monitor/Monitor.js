const fs = require('fs');
const chokidar = require('chokidar');
const WebSocket = require('faye-websocket');

const Monitor = require('./MonitorEvent'),
  createServer = require('../server/createServer');

let clients = [];
let watcher;
let server;

const validFileExtensions = ['.json', '.js', '.ts', '.html', '.htm', '.xhtml', '.css', '.scss', '.less'];

Monitor.on('start-process', config => {
  server = createServer(config)
    .on('error', e => {
      if (e.code === 'EADDRINUSE') {
        setTimeout(() => server.listen(0, config.host), 200);
      }
      else {
        Monitor.emit('kill-process');
      }
    })
    .on('upgrade', (request, socket, body) => {
      Monitor.emit('upgrade-process', { request, socket, body })
    });
});

Monitor.on('start-watching-files', config => {
  watcher = chokidar.watch(config.wdir, { ignored: config.ignore, persistent: true, ignoreInitial: true })
    .on('change', (filePath) => {
      setTimeout(() => {

        const content = fs.readFileSync(filePath, 'utf8'); // file content
        const relativeFilePath = filePath.replace(__dirname, ''); // file path
        const fileExtension = relativeFilePath.match(/\.[0-9a-z]+$/i)[0];

        if (validFileExtensions.includes(fileExtension)) {
          Monitor.emit('restart-process', { content, fileExtension, ...config });
        }
      }, config.wait);
    })
    .on('error', error => {
      Monitor.emit('kill-process', 0, error);
    });
});

Monitor.on('restart-process', msg => {
  clients.forEach(ws => ws && ws.send(JSON.stringify(msg)));
});

Monitor.on('upgrade-process', ({ request, socket, body }) => {
  let ws = new WebSocket(request, socket, body);

  clients.push(ws);

  ws.onclose = () => {
    clients = clients.filter(i => i !== ws)
  }
});

Monitor.on('kill-process', (signal, error) => {
  clients.forEach(ws => {
    if (ws) {
      ws.send(JSON.stringify({ message: 'close-socket' }));
      ws.close();
    }
  });
  if (watcher) {
    watcher.close();
    server.close();
  }
});

module.exports = Monitor;