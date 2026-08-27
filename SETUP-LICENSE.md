# LegitHub - Sistema de Licenças

## Setup Completo (sem Cloud Functions!)

### 1. Firebase

1. Crie o projeto no Firebase Console
2. Ative o Firestore Database
3. Copie a **Web API Key** e **Project ID**
4. Atualize em `legithub-launcher.lua`:
   ```lua
   local FIREBASE_API_KEY = "SUA_API_KEY"
   local FIREBASE_PROJECT_ID = "SEU_PROJECT_ID"
   ```

### 2. Firestore Rules

Deploy as regras:
```bash
firebase deploy --only firestore:rules
```

Ou copie manualmente no Console:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /licenses/{key} {
      allow read: if true;
      allow write: if request.auth != null;
    }
  }
}
```

### 3. Criar Keys

#### Opção A: Firebase Console (mais fácil)
1. Acesse Firestore Database
2. Crie collection `licenses`
3. Adicione documento manualmente:
   - Document ID: `LH-XXXX-XXXX-XXXX`
   - Campos:
     - key: "LH-XXXX-XXXX-XXXX"
     - plan: "monthly" (weekly, monthly, annual, premium)
     - status: "active"
     - createdAt: (timestamp)
     - expiresAt: (timestamp + dias do plano)
     - hwid: ""
     - discordId: ""
     - email: ""
     - lastCheck: null

#### Opção B: Script Node.js
1. Baixe a service account key no Firebase Console
2. Salve como `service-account-key.json`
3. Rode:
```bash
npm install firebase-admin
node create-license.js LH-MINHA-KEY-123 monthly
```

### 4. Planos

| Plano | Preço | Duração |
|---|---|---|
| Free | R$ 0 | ∞ |
| Semanal | R$ 9,90 | 7 dias |
| Mensal | R$ 24,90 | 30 dias |
| Anual | R$ 149,90 | 365 dias |
| Premium | R$ 199,90 | 365 dias |

### 5. Kirvano (opcional)

Se quiser automatizar a criação de keys:
1. Crie um script que recebe webhook do Kirvano
2. Usa Firebase Admin SDK pra criar o documento
3. Retorna a key pro usuário

Ou manualmente:
1. Usuário paga no Kirvano
2. Você cria a key no Firebase Console
3. Envia a key pro usuário via Discord

## Estrutura

```
legithub/
├── firebase.json              # Config Firebase
├── firestore.rules            # Regras do Firestore
├── create-license.js          # Script pra criar keys
├── legithub-v2.lua            # Hub (com verificação VIP)
├── legithub-launcher.lua      # Launcher com tela de key
└── legithub-license.lua       # Módulo de licenciamento
```

## Como Funciona

1. Usuário roda o launcher
2. Launcher verifica key salva localmente
3. Se não tem key → mostra tela de ativação
4. Launcher lê Firestore REST API direto (sem Cloud Functions)
5. Se key é válida → carrega hub com plano correto
6. A cada 30min, revalida com Firestore

## Segurança

- **Firestore Rules**: leitura livre, escrita autenticada
- **HWID check**: key associada a um dispositivo
- **Cache local**: key salva em `legithub_license.json`
- **Revalidação**: launcher checa key periodicamente

## Vantagens

- ✅ **Sem Cloud Functions** (não precisa Blaze)
- ✅ **Sem custo** (Firestore free tier: 50k leituras/dia)
- ✅ **Simples** (só REST API + Lua)
- ✅ **Rápido** (direto no Firestore, sem middleman)
