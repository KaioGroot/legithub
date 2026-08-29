# LEGITHUB — ROADMAP

Objetivo: de "menu bom" para **hub universal + farm premium + PvP pro**,
com monetização saudável e presença de comunidade.

Fases executadas em ordem; cada uma termina com release no GitHub
(`KaioGroot/legithub`) + bump de VERSION.

---

## ✔ FASE 0 — Limpeza e credibilidade — CONCLUIDA
- [x] Fix: Enter no input custom de item do Blox Fruits agora adiciona o item
- [x] Splash dinamico (usa VERSION real) — sem texto hardcoded desatualizado
- [x] Removidos placeholders `discord.gg/SEU_SERVER` (hub + launcher) → link da landing
- [x] Teleporte suave (SmoothTp) aplicado em: ilhas Blox Fruits, waypoints e TP para jogador
- [x] Dica de instalacao do companion server no painel do hub

## 🔧 FASE 1 — Hub Universal (IY-style)
- [x] Command Bar (`;` ou `/` abre; Backquote por tecla; painel de Teclas)
  - [x] 40+ comandos (speed, fly, noclip, infjump, ctp, invis, esp, fov, fullbright,
        nofog, gravity, time, hitbox/reach/aimbot, tp, tppos, wp save|go|list|del|clear,
        rj/rejoin, hop (serverhop), jobid, farm (VIP), antiafk, spectate, status, help)
  - [x] Autocomplete ao digitar + historico (setas)
- [x] Extras: help no console (F9), `site` copia link, `status` mostra plano/versao
- [ ] Dex++ explorer (arvore de instancias + editar property)
- [ ] Server tools: join [player], lista de servidores (hop ja esta pronto)
- [ ] Chat Spy + bypass
- [ ] god mode, transparente, fling

## 🎯 FASE 2 — PvP Pro
- [ ] Silent Aim REAL (hook em remotes/tool)
- [ ] Aimbot avancado (hard-lock, cycle targets, partes do corpo, predicao)
- [ ] ESP de itens/chests/NPCs universal
- [ ] Hitbox/Reach server-side automatico (sem companion manual)

## 🌾 FASE 3 — Farm em escala
- [ ] Farm generico universal (auto-click/auto-collect/auto-quest detector)
- [ ] Blade Ball, Da Hood, Jujutsu Legends, Anime Spirits / King Legacy,
      Fisch, Miner's Haven (nesta ordem)

## 🎨 FASE 4 — UI/UX + Plataforma
- [ ] Temas completos (dark/light + accents)
- [ ] Modo mobile/compacto
- [ ] Configs multi-slot nomeadas por PlaceId
- [ ] Streamer mode + FPS unlock

## 💰 FASE 5 — Negocio/Marketing
- [ ] Produtos semanal e anual na Kiwify (links reais)
- [ ] Discord com verificacao automatica de key
- [ ] Roadmap publico + prova social (Shorts/TikTok, configs compartilhaveis)
- [ ] Telemetria opt-in (Cloudflare Worker)

## 🔒 FASE 6 — Seguranca/Arquitetura
- [ ] Validacao de licenca via Cloudflare Worker (tirar API key do cliente)
- [ ] CI de sintaxe (luaparse) + teste de launch antes de todo push
- [ ] Anti-tamper leve / ofuscacao minima na entrega