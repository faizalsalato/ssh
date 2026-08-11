const express = require('express');
const { execFile } = require('child_process');
const rateLimit = require('express-rate-limit');

const app = express();
app.use(express.json());

// ---------------------------------------------------------------------------
// Configuração
// ---------------------------------------------------------------------------
const API_KEY = process.env.API_KEY;
if (!API_KEY) {
    console.error('ERRO: defina a variável de ambiente API_KEY antes de iniciar.');
    console.error('Exemplo: export API_KEY="sua_chave" && node server.js');
    process.exit(1);
}

// ---------------------------------------------------------------------------
// Rate Limiter global
// ---------------------------------------------------------------------------
const limiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 100,
    standardHeaders: true,
    legacyHeaders: false,
    message: { erro: 'Limite de tentativas excedido' }
});
app.use(limiter);

// ---------------------------------------------------------------------------
// Middleware de autenticação
// ---------------------------------------------------------------------------
function checkApiKey(req, res, next) {
    const key = req.headers['x-api-key'];
    if (!key || key !== API_KEY) {
        return res.status(401).json({ erro: 'Acesso negado' });
    }
    next();
}
app.use(checkApiKey);

// ---------------------------------------------------------------------------
// Validação de input
// ---------------------------------------------------------------------------
const SAFE_PATTERN = /^[a-zA-Z0-9_.-]{3,32}$/;

function validarCampo(valor) {
    return typeof valor === 'string' && SAFE_PATTERN.test(valor);
}

function validarDias(dias) {
    const n = Number(dias);
    if (!Number.isInteger(n) || n <= 0 || n > 365) return null;
    return n;
}

// ---------------------------------------------------------------------------
// Rotas
// ---------------------------------------------------------------------------

app.post('/ssh', (req, res) => {
    const { login, pass, dias } = req.body || {};

    if (!validarCampo(login) || !validarCampo(pass)) {
        return res.status(400).json({ erro: 'login/pass inválidos' });
    }
    const diasValidados = validarDias(dias);
    if (diasValidados === null) {
        return res.status(400).json({ erro: 'dias inválido (1-365)' });
    }

    // execFile previne injeção de comandos
    execFile('lxc', ['exec', 'ubuntu20', '--', 'sakaru', login, pass, String(diasValidados)], (err, stdout, stderr) => {
        if (err) {
            console.error('Erro sakaru:', stderr || err.message);
            return res.status(500).json({ erro: 'Falha ao criar conta SSH' });
        }

        const partes = stdout.trim().split('|');
        if (partes.length < 6) {
            console.error('Saída inesperada sakaru:', stdout);
            return res.status(502).json({ erro: 'Resposta inesperada do script' });
        }
        const [status, user, senha, expira, ip, dominio] = partes;

        if (status !== 'SUCESSO') {
            return res.status(400).json({ erro: stdout.trim() });
        }

        res.json({
            status,
            conta: user,
            senha,
            expiracao: expira,
            link_config: `http://${dominio}:89/ssh-${user}.txt`
        });
    });
});

app.post('/vmess', (req, res) => {
    const { login, dias } = req.body || {};

    if (!validarCampo(login)) {
        return res.status(400).json({ erro: 'login inválido' });
    }
    const diasValidados = validarDias(dias);
    if (diasValidados === null) {
        return res.status(400).json({ erro: 'dias inválido (1-365)' });
    }

    execFile('lxc', ['exec', 'ubuntu20', '--', 'sakaru2', login, String(diasValidados)], (err, stdout, stderr) => {
        if (err) {
            console.error('Erro sakaru2:', stderr || err.message);
            return res.status(500).json({ erro: 'Falha ao criar Vmess' });
        }

        const partes = stdout.trim().split('|');
        if (partes.length < 8) {
            console.error('Saída inesperada sakaru2:', stdout);
            return res.status(502).json({ erro: 'Resposta inesperada do script' });
        }
        const [status, usuario, uuid, expira, ip, dominio, linkTls, linkNoTls] = partes;

        if (status !== 'SUCESSO') {
            return res.status(400).json({ erro: stdout.trim() });
        }

        res.json({
            status,
            usuario,
            uuid,
            expiracao: expira,
            ip,
            dominio,
            link_tls: linkTls,
            link_notls: linkNoTls
        });
    });
});

app.post('/vless', (req, res) => {
    const { login, dias } = req.body || {};

    if (!validarCampo(login)) {
        return res.status(400).json({ erro: 'login inválido' });
    }
    const diasValidados = validarDias(dias);
    if (diasValidados === null) {
        return res.status(400).json({ erro: 'dias inválido (1-365)' });
    }

    execFile('lxc', ['exec', 'ubuntu20', '--', 'sakaru3', login, String(diasValidados)], (err, stdout, stderr) => {
        if (err) {
            console.error('Erro sakaru3:', stderr || err.message);
            return res.status(500).json({ erro: 'Falha ao criar Vless' });
        }

        const partes = stdout.trim().split('|');
        if (partes.length < 8) {
            console.error('Saída inesperada sakaru3:', stdout);
            return res.status(502).json({ erro: 'Resposta inesperada do script' });
        }
        const [status, usuario, uuid, expira, ip, dominio, linkTls, linkNoTls] = partes;

        if (status !== 'SUCESSO') {
            return res.status(400).json({ erro: stdout.trim() });
        }

        res.json({
            status,
            usuario,
            uuid,
            expiracao: expira,
            ip,
            dominio,
            link_tls: linkTls,
            link_notls: linkNoTls
        });
    });
});

// Health check
app.get('/health', (req, res) => {
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

const PORT = process.env.API_PORT || 3000;
app.listen(PORT, () => console.log(`API rodando na porta ${PORT}`));
