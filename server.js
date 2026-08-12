// ===================================================================
// server.js - API VPN v2.1 (12 protocolos - todos via sakaru*)
// ===================================================================

const express = require('express');
const { execFile } = require('child_process');
const rateLimit = require('express-rate-limit');
const app = express();
app.use(express.json());

const API_KEY = process.env.API_KEY;
if (!API_KEY) { console.error('ERRO: API_KEY não definida'); process.exit(1); }

app.use(rateLimit({ windowMs: 15*60*1000, max: 200, message: { erro: 'Limite excedido' } }));
app.use((req, res, next) => {
    if (req.headers['x-api-key'] !== API_KEY) return res.status(401).json({ erro: 'Acesso negado' });
    next();
});

const SAFE = /^[a-zA-Z0-9_.-]{3,32}$/;
function ok(v) { return typeof v === 'string' && SAFE.test(v); }
function dias(v) { const n = Number(v); return Number.isInteger(n) && n>0 && n<=365 ? n : null; }

function run(script, args, res, map) {
    execFile(script, args, { timeout: 30000 }, (err, stdout, stderr) => {
        // Check stdout first - may contain ERRO even on non-zero exit
        if (stdout) {
            const p = stdout.trim().split('|');
            if (p[0] === 'ERRO') return res.status(400).json({ erro: p[1] || 'Erro' });
            if (p[0] === 'SUCESSO') return res.json(map(p));
        }
        if (err) return res.status(500).json({ erro: 'Falha: ' + (stderr||err.message) });
        if (stdout) return res.status(502).json({ erro: stdout.trim() });
        res.status(500).json({ erro: 'Erro desconhecido' });
    });
}

// ──────────────────────────────────────────────
// DEFINIÇÃO DOS PROTOCOLOS
// ──────────────────────────────────────────────
const PROTOCOLS = {
  // name, sakaru#, args (l=login, p=pass, d=dias), response mapper
  ssh:    { script: 'sakaru',  args: 'lpd', map: p => ({ status:p[0], conta:p[1], senha:p[2], expiracao:p[3], ip:p[4], dominio:p[5] }) },
  vmess:  { script: 'sakaru2', args: 'ld',  map: p => ({ status:p[0], usuario:p[1], uuid:p[2], expiracao:p[3], ip:p[4], dominio:p[5], link_tls:p[6], link_notls:p[7] }) },
  vless:  { script: 'sakaru3', args: 'ld',  map: p => ({ status:p[0], usuario:p[1], uuid:p[2], expiracao:p[3], ip:p[4], dominio:p[5], link_tls:p[6], link_notls:p[7] }) },
  trojan: { script: 'sakaru4', args: 'ld',  map: p => ({ status:p[0], usuario:p[1], password:p[2], expiracao:p[3], ip:p[4], dominio:p[5], link:p[6] }) },
  trgo:   { script: 'sakaru5', args: 'ld',  map: p => ({ status:p[0], usuario:p[1], password:p[2], expiracao:p[3], ip:p[4], dominio:p[5], link:p[6] }) },
  ss:     { script: 'sakaru6', args: 'lpd', map: p => ({ status:p[0], usuario:p[1], senha:p[2], expiracao:p[3], ip:p[4], dominio:p[5], link:p[6] }) },
  ssr:    { script: 'sakaru7', args: 'lpd', map: p => ({ status:p[0], usuario:p[1], senha:p[2], expiracao:p[3], ip:p[4], dominio:p[5] }) },
  wg:     { script: 'sakaru8', args: 'ld',  map: p => ({ status:p[0], usuario:p[1], expiracao:p[2], ip:p[3], dominio:p[4], client_ip:p[5], config:p[6] }) },
  l2tp:   { script: 'sakaru9', args: 'lpd', map: p => ({ status:p[0], usuario:p[1], senha:p[2], expiracao:p[3], ip:p[4] }) },
  pptp:   { script: 'sakaru10',args: 'lpd', map: p => ({ status:p[0], usuario:p[1], senha:p[2], expiracao:p[3], ip:p[4] }) },
  sstp:   { script: 'sakaru11',args: 'lpd', map: p => ({ status:p[0], usuario:p[1], senha:p[2], expiracao:p[3], ip:p[4], dominio:p[5] }) },
  grpc:   { script: 'sakaru12',args: 'ld',  map: p => ({ status:p[0], usuario:p[1], uuid:p[2], expiracao:p[3], ip:p[4], dominio:p[5] }) },
};

// ──────────────────────────────────────────────
// GERADOR DE ROTAS (CRUD)
// ──────────────────────────────────────────────
Object.entries(PROTOCOLS).forEach(([name, cfg]) => {

  // POST /proto - Criar conta
  app.post('/'+name, (req, res) => {
    const { login, pass, dias: d } = req.body||{};
    if (!ok(login)) return res.status(400).json({ erro: 'login invalido' });
    const dd = dias(d); if (!dd) return res.status(400).json({ erro: 'dias (1-365)' });

    // Build args based on config pattern
    let args = [];
    for (const c of cfg.args) {
      if (c === 'l') args.push(login);
      else if (c === 'p') { if (!ok(pass)) return res.status(400).json({ erro: 'senha invalida' }); args.push(pass); }
      else if (c === 'd') args.push(String(dd));
    }
    run(cfg.script, args, res, cfg.map);
  });

  // DELETE /proto/:login
  app.delete('/'+name+'/:login', (req, res) => {
    const { login } = req.params;
    if (!ok(login)) return res.status(400).json({ erro: 'login invalido' });

    // Delete strategy depends on protocol
    const cmds = {
      ssh:   [['userdel','-rf',login]],
      vmess: [['sed','-i','/### '+login+'/d','/etc/xray/config.json'],['systemctl','restart','xray']],
      vless: [['sed','-i','/#### '+login+'/d','/etc/xray/config.json'],['systemctl','restart','xray']],
      trojan:[['sed','-i','/### '+login+'/d','/etc/xray/config.json'],['systemctl','restart','xray']],
      trgo:  [['sed','-i','/'+login+'/d','/etc/trojan-go/config.json'],['systemctl','restart','trojan-go']],
      ss:    [['sed','-i','/### '+login+'/d','/etc/xray/config.json'],['systemctl','restart','xray']],
      ssr:   [['sed','-i','/'+login+'/d','/etc/shadowsocksr/config.json'],['systemctl','restart','shadowsocksr']],
      wg:    [['sed','-i','/^# '+login+'/,/AllowedIPs/d','/etc/wireguard/wg0.conf'],['systemctl','restart','wg-quick@wg0']],
      l2tp:  [['sed','-i','/^'+login+' /d','/etc/ppp/chap-secrets'],['sed','-i','/^'+login+' :/d','/etc/ipsec.secrets']],
      pptp:  [['sed','-i','/^'+login+' /d','/etc/ppp/chap-secrets']],
      sstp:  [['sed','-i','/^'+login+' /d','/etc/ppp/chap-secrets']],
      grpc:  [['sed','-i','/### '+login+'/d','/etc/xray/config.json'],['systemctl','restart','xray']],
    };
    const queue = cmds[name] || [['echo','ok']];
    function execQueue(i) {
      if (i >= queue.length) return res.json({ status:'SUCESSO', usuario:login, mensagem:name+' deletado' });
      execFile(queue[i][0], queue[i].slice(1), { timeout: 10000 }, () => execQueue(i+1));
    }
    execQueue(0);
  });

  // POST /proto/:login/renew
  app.post('/'+name+'/:login/renew', (req, res) => {
    const { login } = req.params;
    const d = dias((req.body||{}).dias);
    if (!ok(login)||!d) return res.status(400).json({ erro: 'login/dias invalidos' });
    const exp = new Date(Date.now()+d*86400000).toISOString().slice(0,10);

    if (name === 'ssh') {
      execFile('chage', ['-E', exp, login], (err) => {
        if (err) return res.status(500).json({ erro: 'Falha ao renovar' });
        res.json({ status:'SUCESSO', conta:login, nova_expiracao:exp });
      });
    } else {
      // For xray-based protocols, update the date in config
      const markers = { vmess:'###', vless:'####', trojan:'###', ss:'###', grpc:'###' };
      const m = markers[name];
      if (m) {
        execFile('sed', ['-i', 's/'+m+' '+login+' .*/'+m+' '+login+' '+exp+'/', '/etc/xray/config.json'], (err) => {
          execFile('systemctl', ['restart', 'xray'], () => {});
          res.json({ status:'SUCESSO', usuario:login, nova_expiracao:exp });
        });
      } else {
        res.json({ status:'SUCESSO', usuario:login, dias_adicionados:d });
      }
    }
  });

  // GET /proto - Listar
  app.get('/'+name, (req, res) => {
    if (name === 'ssh') {
      execFile('awk', ['-F:', '$3>=1000{print $1}', '/etc/passwd'], (err, out) => {
        res.json(out.trim().split('\n').filter(Boolean).map(u => ({ usuario:u })));
      });
    } else if (['vmess','vless','trojan','ss','grpc'].includes(name)) {
      const m = { vmess:'###', vless:'####', trojan:'###', ss:'###', grpc:'###' };
      execFile('sh', ['-c', 'grep -E "^'+m[name]+' " /etc/xray/config.json | sed "s/'+m[name]+' //"'], (err, out) => {
        const users = out.trim().split('\n').filter(Boolean).map(l => {
          const [u, exp] = l.split(' ');
          return { usuario:u, expiracao:exp||'?' };
        });
        res.json(users);
      });
    } else if (name === 'wg') {
      execFile('sh', ['-c', 'grep "^# " /etc/wireguard/wg0.conf | sed "s/^# //"'], (err, out) => {
        const users = out.trim().split('\n').filter(Boolean).map(l => {
          const [u, exp] = l.split(' / ');
          return { usuario:u, expiracao:exp||'?' };
        });
        res.json(users);
      });
    } else {
      execFile('sh', ['-c', 'grep -v "^#" /etc/ppp/chap-secrets | grep -v "^$" | awk "{print \$1}"'], (err, out) => {
        res.json(out.trim().split('\n').filter(Boolean).map(u => ({ usuario:u })));
      });
    }
  });

  // GET /proto/:login - Checar
  app.get('/'+name+'/:login', (req, res) => {
    const { login } = req.params;
    if (!ok(login)) return res.status(400).json({ erro: 'login invalido' });
    if (name === 'ssh') {
      execFile('id', [login], (err) => {
        if (err) return res.json({ usuario:login, existe:false });
        execFile('chage', ['-l', login], (e, out) => {
          const m = out.match(/Account expires.*: (.*)/);
          res.json({ usuario:login, existe:true, expiracao:m?m[1].trim():'never' });
        });
      });
    } else {
      execFile('sh', ['-c', 'grep -q "'+login+'" /etc/xray/config.json 2>/dev/null && echo found || echo not'], (err, out) => {
        res.json({ usuario:login, existe:out.trim()==='found' });
      });
    }
  });

});

// ── Health / Docs ──
app.get('/health', (req, res) => res.json({ status:'ok', ts:new Date().toISOString() }));
app.get('/', (req, res) => res.json({
  api:'VPN API v2.1',
  protocolos:Object.keys(PROTOCOLS),
  operacoes:['POST /:proto','DELETE /:proto/:login','POST /:proto/:login/renew','GET /:proto','GET /:proto/:login'],
  auth:'Header: x-api-key'
}));

const PORT = process.env.API_PORT || 3000;
app.listen(PORT, '0.0.0.0', () => console.log('[API] Porta '+PORT+' | '+Object.keys(PROTOCOLS).length+' protocolos | OK'));
