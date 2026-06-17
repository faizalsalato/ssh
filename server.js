const express = require('express');
const { exec } = require('child_process');
const rateLimit = require('express-rate-limit');
const app = express();

app.use(express.json());

// Proteção contra abuso (Max 5 contas a cada 15 min por IP)
const limiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 5,
    message: { erro: "Limite de tentativas excedido" }
});

const API_KEY = "Sakaruteel2003@";

app.post('/ssh', limiter, (req, res) => {
    // Validação de API Key
    if (req.headers['x-api-key'] !== API_KEY) {
        return res.status(401).json({ erro: "Acesso negado" });
    }

    const { login, pass, dias } = req.body;

    // Executa o script bash
exec(`lxc exec ubuntu20 -- sakaru ${login} ${pass} 3`, (err, stdout, stderr) => {
    if (err) return res.status(500).json({ erro: "Falha" });

    // O Node.js pega a linha curta e transforma em JSON
    const [status, user, senha, expira, ip, dominio] = stdout.trim().split('|');
    
    res.json({
        status,
        conta: user,
        senha: senha,
        expiracao: expira,
        link_config: `http://${dominio}:89/ssh-${user}.txt`
    });
});
});



app.post('/criar-vmess', (req, res) => {

	    if (req.headers['x-api-key'] !== API_KEY) {
        return res.status(401).json({ erro: "Acesso negado" });
		
    }
	    const { login, dias } = req.body;

    // Executa o script addvmess dentro do LXC
    exec(`lxc exec ubuntu20 -- sakaru2 ${login} 3`, (err, stdout, stderr) => {
        if (err) {
            return res.status(500).json({ erro: "Falha ao criar Vmess", detalhes: stderr });
        }

        // Divide a resposta separada por "|"
        const [status, usuario, uuid, expira, ip, dominio, linkTls, linkNoTls] = stdout.trim().split('|');

        if (status !== "SUCESSO") {
            return res.status(400).json({ erro: stdout.trim() });
        }

        // Retorna o JSON limpo para o seu painel
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



app.post('/criar-vless', (req, res) => {
		    if (req.headers['x-api-key'] !== API_KEY) {
        return res.status(401).json({ erro: "Acesso negado" });
		
    }
    const { login, dias } = req.body;

    exec(`lxc exec ubuntu20 -- sakaru3 ${login} 3`, (err, stdout, stderr) => {
        if (err) return res.status(500).json({ erro: "Falha ao criar Vless" });

        const [status, usuario, uuid, expira, ip, dominio, linkTls, linkNoTls] = stdout.trim().split('|');

        if (status !== "SUCESSO") {
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
