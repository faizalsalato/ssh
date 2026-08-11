// ===================================================================
// server.js - API Completa VPN/SSH (12 protocolos)
// ===================================================================

const express = require('express');
const { execFile } = require('child_process');
const rateLimit = require('express-rate-limit');
const app = express();
app.use(express.json());

const API_KEY = process.env.API_KEY;
if (!API_KEY) { console.error('ERRO: defina API_KEY'); process.exit(1); }

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
        if (err) return res.status(500).json({ erro: 'Falha: ' + (stderr||err.message) });
        const p = stdout.trim().split('|');
        if (p[0] === 'ERRO') return res.status(400).json({ erro: p[1] });
        if (p[0] !== 'SUCESSO') return res.status(502).json({ erro: stdout.trim() });
        res.json(map(p));
    });
}

// ── SSH ──
app.post('/ssh', (req, res) => {
    const { login, pass, dias: d } = req.body||{};
    if (!ok(login)||!ok(pass)) return res.status(400).json({ erro: 'login/pass invalidos' });
    const dd = dias(d); if (!dd) return res.status(400).json({ erro: 'dias (1-365)' });
    run('sakaru', [login,pass,String(dd)], res, p => ({ status:p[0], conta:p[1], senha:p[2], expiracao:p[3], ip:p[4], dominio:p[5] }));
});

app.delete('/ssh/:login', (req, res) => {
    const { login } = req.params;
    if (!ok(login)) return res.status(400).json({ erro: 'login invalido' });
    execFile('userdel', ['-rf', login], (err, stdout, stderr) => {
        if (err && !(stderr||'').includes('does not exist')) return res.status(500).json({ erro: 'Falha ao deletar' });
        res.json({ status: 'SUCESSO', conta: login, mensagem: 'Deletado' });
    });
});

app.post('/ssh/:login/renew', (req, res) => {
    const { login } = req.params;
    const d = dias((req.body||{}).dias);
    if (!ok(login)||!d) return res.status(400).json({ erro: 'login/dias invalidos' });
    const exp = new Date(Date.now()+d*86400000).toISOString().slice(0,10);
    execFile('chage', ['-E', exp, login], (err) => {
        if (err) return res.status(500).json({ erro: 'Falha' });
        res.json({ status: 'SUCESSO', conta: login, nova_expiracao: exp });
    });
});

app.get('/ssh', (req, res) => {
    execFile('awk', ['-F:', '$3>=1000{print $1}', '/etc/passwd'], (err, out) => {
        res.json(out.trim().split('\n').filter(Boolean).map(u => ({ usuario: u })));
    });
});

app.get('/ssh/:login', (req, res) => {
    const { login } = req.params;
    if (!ok(login)) return res.status(400).json({ erro: 'login invalido' });
    execFile('id', [login], (err) => {
        if (err) return res.json({ usuario: login, existe: false });
        execFile('chage', ['-l', login], (e2, out) => {
            const m = out.match(/Account expires.*: (.*)/);
            res.json({ usuario: login, existe: true, expiracao: m?m[1].trim():'never' });
        });
    });
});

// ── Vmess ──
app.post('/vmess', (req, res) => {
    const { login, dias: d } = req.body||{};
    if (!ok(login)) return res.status(400).json({ erro: 'login invalido' });
    const dd = dias(d); if (!dd) return res.status(400).json({ erro: 'dias (1-365)' });
    run('sakaru2', [login,String(dd)], res, p => ({ status:p[0], usuario:p[1], uuid:p[2], expiracao:p[3], ip:p[4], dominio:p[5], link_tls:p[6], link_notls:p[7] }));
});

app.delete('/vmess/:login', (req, res) => {
    const { login } = req.params;
    execFile('sed', ['-i', '/### '+login+'/d', '/etc/xray/config.json'], () => {
        execFile('systemctl', ['restart', 'xray'], () => {});
        res.json({ status: 'SUCESSO', usuario: login, mensagem: 'Deletado' });
    });
});

app.post('/vmess/:login/renew', (req, res) => {
    const { login } = req.params;
    const d = dias((req.body||{}).dias);
    if (!ok(login)||!d) return res.status(400).json({ erro: 'login/dias invalidos' });
    const exp = new Date(Date.now()+d*86400000).toISOString().slice(0,10);
    execFile('sed', ['-i', 's/### '+login+' .*/### '+login+' '+exp+'/', '/etc/xray/config.json'], (err) => {
        execFile('systemctl', ['restart', 'xray'], () => {});
        res.json({ status: 'SUCESSO', usuario: login, nova_expiracao: exp });
    });
});

app.get('/vmess', (req, res) => {
    execFile('grep', ['-E', '^### ', '/etc/xray/config.json'], (err, out) => {
        const users = (out||'').trim().split('\n').filter(Boolean).map(l => {
            const p = l.replace('### ','').split(' ');
            return { usuario: p[0], expiracao: p[1]||'?' };
        });
        res.json(users);
    });
});

app.get('/vmess/:login', (req, res) => {
    execFile('grep', ['-w', req.params.login, '/etc/xray/config.json'], (err, out) => {
        res.json({ usuario: req.params.login, existe: !!out.trim() });
    });
});

// ── Vless ──
const vlessRoutes = (app) => {
    app.post('/vless', (req, res) => {
        const { login, dias: d } = req.body||{};
        if (!ok(login)) return res.status(400).json({ erro: 'login invalido' });
        const dd = dias(d); if (!dd) return res.status(400).json({ erro: 'dias (1-365)' });
        run('sakaru3', [login,String(dd)], res, p => ({ status:p[0], usuario:p[1], uuid:p[2], expiracao:p[3], ip:p[4], dominio:p[5], link_tls:p[6], link_notls:p[7] }));
    });
    app.delete('/vless/:login', (req, res) => {
        execFile('sed', ['-i', '/#### '+req.params.login+'/d', '/etc/xray/config.json'], () => {
            execFile('systemctl', ['restart', 'xray'], () => {});
            res.json({ status: 'SUCESSO', usuario: req.params.login, mensagem: 'Deletado' });
        });
    });
    app.post('/vless/:login/renew', (req, res) => {
        const d = dias((req.body||{}).dias);
        if (!ok(req.params.login)||!d) return res.status(400).json({ erro: 'login/dias invalidos' });
        const exp = new Date(Date.now()+d*86400000).toISOString().slice(0,10);
        execFile('sed', ['-i', 's/#### '+req.params.login+' .*/#### '+req.params.login+' '+exp+'/', '/etc/xray/config.json'], (err) => {
            execFile('systemctl', ['restart', 'xray'], () => {});
            res.json({ status: 'SUCESSO', usuario: req.params.login, nova_expiracao: exp });
        });
    });
    app.get('/vless', (req, res) => {
        execFile('grep', ['-E', '^#### ', '/etc/xray/config.json'], (err, out) => {
            const users = (out||'').trim().split('\n').filter(Boolean).map(l => {
                const p = l.replace('#### ','').split(' ');
                return { usuario: p[0], expiracao: p[1]||'?' };
            });
            res.json(users);
        });
    });
};
vlessRoutes(app);

// ── Outros protocolos (Trojan, TrGo, SS, SSR, WG, L2TP, PPTP, SSTP, gRPC) ──
['trojan','trgo','ss','ssr','wg','l2tp','pptp','sstp','grpc'].forEach(proto => {
    app.post('/'+proto, (req, res) => {
        const { login, pass, dias: d } = req.body||{};
        if (!ok(login)) return res.status(400).json({ erro: 'login invalido' });
        const dd = dias(d); if (!dd) return res.status(400).json({ erro: 'dias (1-365)' });
        const args = pass&&ok(pass) ? [login,pass,String(dd)] : [login,String(dd)];
        run('add'+proto, args, res, p => ({ status:p[0], usuario:login }));
    });
    app.delete('/'+proto+'/:login', (req, res) => {
        execFile('del'+proto, [req.params.login], { timeout: 10000 }, () => {
            res.json({ status: 'SUCESSO', usuario: req.params.login, mensagem: proto+' deletado' });
        });
    });
    app.post('/'+proto+'/:login/renew', (req, res) => {
        const d = dias((req.body||{}).dias);
        if (!ok(req.params.login)||!d) return res.status(400).json({ erro: 'login/dias invalidos' });
        execFile('renew'+proto, [req.params.login,String(d)], { timeout: 10000 }, () => {
            res.json({ status: 'SUCESSO', usuario: req.params.login, dias: d });
        });
    });
    app.get('/'+proto, (req, res) => {
        execFile('cek'+proto, [], { timeout: 10000 }, (err, out) => {
            res.json({ protocolo: proto, dados: (out||'').trim() });
        });
    });
});

// ── Health / Docs ──
app.get('/health', (req, res) => res.json({ status:'ok', ts:new Date().toISOString() }));
app.get('/', (req, res) => res.json({
    api: 'VPN API v2.0',
    protocolos: ['ssh','vmess','vless','trojan','trgo','ss','ssr','wg','l2tp','pptp','sstp','grpc'],
    operacoes: ['POST/:proto','DELETE/:proto/:login','POST/:proto/:login/renew','GET/:proto','GET/:proto/:login'],
    auth: 'Header: x-api-key'
}));

const PORT = process.env.API_PORT || 3000;
app.listen(PORT, '0.0.0.0', () => console.log('[API] Porta '+PORT+' | 12 protocolos | OK'));
