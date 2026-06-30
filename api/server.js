const express = require('express');
const { execFile } = require('child_process');
const rateLimit = require('express-rate-limit');

const app = express();
app.use(express.json());

// ---------------------------------------------------------------------------
// Configuração
// ---------------------------------------------------------------------------

// A API key DEVE vir de variável de ambiente. Nunca deixe chaves no código-fonte.
// Defina antes de iniciar: export API_KEY="sua_chave_aqui"
const API_KEY = process.env.API_KEY;
if (!API_KEY) {
    console.error('ERRO: defina a variável de ambiente API_KEY antes de iniciar o servidor.');
    process.exit(1);
}

// Proteção contra abuso (Max 5 contas a cada 15 min por IP)
const limiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 5,
    standardHeaders: true,
    legacyHeaders: false,
    message: { erro: 'Limite de tentativas excedido' }
});

// Aplica o rate limiter a TODAS as rotas abaixo (antes elas tinham proteção inconsistente)
app.use(limiter);

// ---------------------------------------------------------------------------
// Middlewares de segurança
// ---------------------------------------------------------------------------

// Validação de API Key, centralizada (evita repetir em cada rota e esquecer alguma)
function checkApiKey(req, res, next) {
    const key = req.headers['x-api-key'];
    if (!key || key !== API_KEY) {
        return res.status(401).json({ erro: 'Acesso negado' });
    }
    next();
}
app.use(checkApiKey);

// Whitelist simples para login/senha: letras, números, _ , - e . (3 a 32 caracteres)
// Ajuste a regex conforme as regras reais de username/senha do seu sistema.
const SAFE_PATTERN = /^[a-zA-Z0-9_.-]{3,32}$/;

function validarCampo(valor) {
    return typeof valor === 'string' && SAFE_PATTERN.test(valor);
}

// Valida e normaliza "dias": deve ser um inteiro positivo dentro de um limite razoável
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
        return res.status(400).json({ erro: 'dias inválido' });
    }

    // execFile evita que o shell interprete caracteres especiais (sem injeção de comando)
    execFile('sakaru', [login, pass, String(diasValidados)], (err, stdout, stderr) => {
        if (err) {
            console.error('Erro ao executar sakaru:', stderr || err.message);
            return res.status(500).json({ erro: 'Falha' });
        }

        const partes = stdout.trim().split('|');
        if (partes.length < 6) {
            console.error('Saída inesperada do script sakaru:', stdout);
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
        return res.status(400).json({ erro: 'dias inválido' });
    }

    execFile('sakaru2', [login, String(diasValidados)], (err, stdout, stderr) => {
        if (err) {
            console.error('Erro ao executar sakaru2:', stderr || err.message);
            return res.status(500).json({ erro: 'Falha ao criar Vmess' });
        }

        const partes = stdout.trim().split('|');
        if (partes.length < 8) {
            console.error('Saída inesperada do script sakaru2:', stdout);
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
        return res.status(400).json({ erro: 'dias inválido' });
    }

    execFile('sakaru3', [login, String(diasValidados)], (err, stdout, stderr) => {
        if (err) {
            console.error('Erro ao executar sakaru3:', stderr || err.message);
            return res.status(500).json({ erro: 'Falha ao criar Vless' });
        }

        const partes = stdout.trim().split('|');
        if (partes.length < 8) {
            console.error('Saída inesperada do script sakaru3:', stdout);
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

app.listen(3000, () => console.log('API rodando na porta 3000'));
