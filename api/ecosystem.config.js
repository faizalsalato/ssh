module.exports = {
  apps: [{
    name: 'api-ssl',
    script: 'server.js',
    cwd: '/opt/api-ssl',
    env: {
      API_KEY: 'sakaruteel',
      API_PORT: '3000'
    },
    autorestart: true,
    max_restarts: 5
  }]
};
