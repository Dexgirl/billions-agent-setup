# Billions Network — Verified Agent Identity Setup Guide

A step-by-step guide to creating and verifying your AI agent's on-chain identity using the [Billions Network](https://billions.network) Verified Agent Identity Skill on OpenClaw.

---

## Prerequisites

- [Node.js](https://nodejs.org/) `>= v20`
- [npm](https://www.npmjs.com/)
- [OpenClaw CLI](https://clawhub.ai) installed
- WSL or Linux/macOS terminal
- Git Bash (recommended for Windows users — download at https://git-scm.com/downloads/win)

---

## Step 1 — Install the Skill
```bash
npx clawhub@latest install verified-agent-identity
```

---

## Step 2 — Navigate to the Scripts Folder
```bash
cd ~/.openclaw/workspace/skills/verified-agent-identity/scripts
```

> ⚠️ **Common mistake:** Running scripts from your home directory (`~`) will throw a `MODULE_NOT_FOUND` error. Always `cd` into the scripts folder first.

---

## Step 3 — Install Dependencies
```bash
npm install
```

---

## Step 4 — Create Your Agent's Ethereum Identity

**Option A — Generate a brand new key:**
```bash
node createNewEthereumIdentity.js
```

**Option B — Use an existing private key:** **(MOST PREFERRABLE)**
```bash
node createNewEthereumIdentity.js --key <your-ethereum-private-key>
```

> 🔐 **Security tip:** Never share or reuse private keys. Generate a dedicated key for each agent.

A successful run will print your agent's DID, e.g.:
```
did:iden3:billions:main:2VmAkXrihYaL...
```

Verify it was saved correctly:
```bash
node getIdentities.js
```

---

## Step 5 — Generate & Open the Verification Link

Replace `Your Agent Name` and description with your agent's details.

### On WSL (Windows) — auto-opens in browser:
```bash
node manualLinkHumanToAgent.js --challenge '{"name": "Your Agent Name", "description": "What your agent does"}' > /tmp/agent_url.txt && echo "<meta http-equiv='refresh' content='0;url=$(cat /tmp/agent_url.txt)'>" > /tmp/agent.html && explorer.exe "$(wslpath -w /tmp/agent.html)"
```

### On Mac/Linux — auto-opens in browser:
```bash
node manualLinkHumanToAgent.js --challenge '{"name": "Your Agent Name", "description": "What your agent does"}' | xargs open
```

> ⚠️ **Do not copy-paste the URL manually.** The hash fragment is a long base64 string — even one missing character will cause an error. Use the auto-open commands above.

---

## Step 6 — Complete Human Verification

1. Sign in with Google, Apple, or your wallet
2. Complete a quick face scan
3. Your agent is now linked on-chain ✅

---

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `Cannot find module` | Running script from wrong directory | `cd ~/.openclaw/workspace/skills/verified-agent-identity/scripts` |
| `Cannot find module '@0xpolygonid/js-sdk'` | Dependencies not installed | Run `npm install` inside the `scripts/` folder |
| `Invalid request base64 encoding` | URL was copy-pasted and got corrupted | Use the auto-open browser command in Step 5 |
| `Invalid request JSON syntax` | URL truncated or mangled by shell | Use the auto-open browser command in Step 5 |
| `Proof generation failed — Reading out of bounds` | DID not yet propagated on-chain | Wait a minute and regenerate the verification link |

---

## Resources

- [Billions Network](https://billions.network)
- [ClawHub Skill Page](https://clawhub.ai/OBrezhniev/verified-agent-identity)
- [GitHub Source](https://github.com/BillionsNetwork/verified-agent-identity)
- [Git Bash for Windows](https://git-scm.com/downloads/win)
