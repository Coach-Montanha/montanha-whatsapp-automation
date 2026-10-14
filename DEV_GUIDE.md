# MANUAL TÉCNICO DO DESENVOLVEDOR — MONTANHA WHATSAPP AUTOMATION
> **Classificação:** Documento Interno e Confidencial de Engenharia de Software  
> **Localização:** Raiz do repositório (`/DEV_GUIDE.md`). **NUNCA** mova este arquivo para a pasta `public/` ou `dist/` para evitar exposição pública via HTTP.  
> **Data de Atualização:** 22/09/2026  
> **Versão do Documento:** 1.0.0

---

## 1. Visão Geral & Escopo do Projeto

### 1.1. O que é o Montanha WhatsApp Automation?
O **Montanha WhatsApp Automation** é o módulo SaaS multi-tenant do **Ecossistema Montanha** dedicado ao CRM conversacional, automação de funis, régua de cobrança automática, disparo de mensagens inteligentes e atendimento integrado via WhatsApp (com suporte a instâncias dedicadas para cada tenant).

### 1.2. Links e Referências de Produção
- **URL Canônica em Produção:** `https://montanha-whatsapp-automation.vercel.app`
- **Repositório GitHub:** `https://github.com/Coach-Montanha/montanha-whatsapp-automation`
- **Time Vercel:** `Ecossistema Montanha` (Plano Hobby)
- **Tecnologia Base:** Aplicação Web Estática / PWA / Capacitor (Node.js Build Script `scripts/build.mjs`) + Tailwind CSS + Lucide + Supabase

---

## 2. Arquitetura do Sistema & Stack Tecnológica

### 2.1. Frontend & Empacotamento Estático
- **Estrutura:** SPA estática de alta velocidade com HTML5 nativo e componentes estilizados via Tailwind CSS.
- **Ícones & UI:** Biblioteca Lucide Icons carregada via CDN e estilos otimizados com variáveis CSS customizadas.
- **Build Script (`scripts/build.mjs`):** Script em Node.js ES Modules que limpa a pasta `dist/`, copia o conteúdo de `public/` (ícones, scripts de autenticação, `robots.txt`, `sitemap.xml`) e mescla com os arquivos raiz (`index.html`, `manifest.json`, `service-worker.js`, `capacitor.config.json`).
- **Deploy na Vercel:** Gerenciado pelo arquivo `vercel.json` com `outputDirectory: "dist"`, `cleanUrls: true` e cabeçalhos de segurança (*nosniff*, *DENY frame*).

### 2.2. Integração com APIs de WhatsApp & Supabase
- **Autenticação do Ecossistema:** Gerenciada por `public/ecosystem-auth-service.js`.
- **Modo Suporte Técnico:** Banner persistente de impersonação embutido no topo do `index.html` com alternância dinâmica de tenant.

---

## 3. Estrutura de Pastas e Componentes Críticos

```
Montanha WhatsApp Automation/
├── dist/                    # Pasta gerada pelo build.mjs (enviada para a Vercel)
│   ├── index.html           # Página principal compilada
│   ├── robots.txt           # Rastreamento SEO
│   ├── sitemap.xml          # Sitemap público
│   └── ...
├── public/                  # Arquivos estáticos fonte
│   ├── ecosystem-auth-service.js # Serviço de autenticação cross-app
│   ├── robots.txt           # Fonte do robots.txt
│   ├── sitemap.xml          # Fonte do sitemap.xml
│   └── icons/               # Ícones de aplicação
├── scripts/
│   ├── build.mjs            # Script de compilação da aplicação para dist/
│   └── dev.mjs              # Servidor local de desenvolvimento
├── capacitor.config.json    # Configuração de empacotamento mobile Android/iOS
├── DEV_GUIDE.md             # ESTE MANUAL TÉCNICO INTERNO (Atualizado)
├── index.html               # Código-fonte principal da aplicação
├── manifest.json            # Manifesto PWA
├── package.json             # Scripts de execução
├── service-worker.js        # Service worker para cache PWA
├── supabase_schema.sql      # Esquema local do CRM WhatsApp (profiles, contacts, templates, schedules)
├── database/                # Esquema SQL unificado no repositório canônico: montanha-master-admin/database/ecosystem_schema.sql
└── vercel.json              # Configuração de roteamento e segurança na Vercel
```

---

## 4. Regras Críticas de Build e Deploy

### ⚠️ REGRA 1: Bloqueio de Autor Git na Vercel (Cadeado 🔒 / Deploy Blocked)
- **O Problema:** A Vercel no plano Hobby rejeita qualquer deploy cujo autor do commit Git não corresponda ao usuário `coach-montanha` no GitHub. Commits com e-mails genéricos (ex: `coachmontanha@gmail.com`) causam bloqueio imediato do deploy.
- **A Solução Obrigatória:** O Git DEVE estar configurado com:
  ```bash
  git config --global user.name "Coach-Montanha"
  git config --global user.email "Coach-Montanha@users.noreply.github.com"
  ```
  Ao commitar:
  ```bash
  git commit --author="Coach-Montanha <Coach-Montanha@users.noreply.github.com>" -m "feat/fix: mensagem"
  ```

### ⚠️ REGRA 2: Compilação de Arquivos em `dist/` antes do Deploy
- Como a Vercel lê a pasta `dist/` como o diretório de publicação (`outputDirectory: "dist"`), ao alterar o `index.html` ou arquivos em `public/`, execute sempre `node scripts/build.mjs` para que a pasta `dist/` seja sincronizada antes de commitar.

---

## 5. Guia Passo a Passo de Execução Local e Testes

```bash
# 1. Iniciar servidor local de desenvolvimento
node scripts/dev.mjs

# 2. Executar a compilação estática
node scripts/build.mjs
# ou
bun run build
```

---

## 6. Troubleshooting e Resolução Rápida de Falhas

| Sintoma | Causa Mais Provável | Como Resolver |
| :--- | :--- | :--- |
| **Alterações no HTML não aparecem na Vercel** | O `dist/` não foi atualizado antes do commit. | Execute `node scripts/build.mjs`, verifique `git status` e envie as alterações em `dist/`. |
| **QR Code do WhatsApp não conecta** | Timeout na instância do gateway ou sessão expirada. | Reinicie a instância no painel de instâncias ou gere um novo pairing code. |
| **Deploy na Vercel bloqueado com cadeado** | Autor de commit não vinculado à conta. | Reenvie o commit com o autor `Coach-Montanha <Coach-Montanha@users.noreply.github.com>`. |
