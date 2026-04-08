# GemeniFlow

> AI-augmented bug bounty hunting workflow — Gemini CLI + Burp MCP on Kali Linux.  
> Built by [@OmaRrAlaa101](https://github.com/OmaRrAlaa101)

---

## What is GemeniFlow?

GemeniFlow is an offensive security workflow that connects your local Kali tools to Gemini AI via the Model Context Protocol (MCP) — turning the Gemini CLI into an active bug bounty co-pilot.

It has two AI agents working together:

| Agent | Where | Role |
|---|---|---|
| **Tactical Operator** | Terminal (`gemini` CLI) | Runs `@kali` tools (nmap, httpx, nuclei...) and reads `@burp` live traffic |
| **Skill Builder Gem** | Browser (`gemini.google.com`) | Maps target tech stack to known bypass techniques from real H1/Bugcrowd/Intigriti disclosures |

**The core loop:**

```
@kali fingerprints the stack
        ↓
Skill Builder maps stack → Tactical Payload Map
        ↓
@burp finds matching endpoints in live traffic
        ↓
CLI executes only targeted payloads
```

No generic scanning. No SQLi on NoSQL databases. No XSS on pure APIs.

---

## Architecture

```
┌──────────────────────────────────────────────────────┐
│                    KALI TERMINAL                     │
│                                                      │
│   gemini CLI ──── @kali ──── nmap, httpx,            │
│        │                     subfinder, nuclei,      │
│        │                     katana, gau             │
│        │                                             │
│        └────────── @burp ──── Burp Suite Pro         │
│                               (live proxy traffic)   │
└──────────────────────────────────────────────────────┘
              ▲
              │  paste Tactical Payload Map
              │
┌──────────────────────────────────────────────────────┐
│                    YOUR BROWSER                      │
│                                                      │
│   Skill Builder Gem  (gemini.google.com → Gems)      │
│   Stack → known bypasses from public disclosures     │
└──────────────────────────────────────────────────────┘
```

---

## Quick Start

```bash
# 1. Install Gemini CLI
npm install -g @google/gemini-cli
gemini auth login

# 2. Install the Kali MCP server
pip install mcp-server-kali --break-system-packages

# 3. Configure MCP servers
cp templates/settings.json ~/.gemini/settings.json
# Edit: set the correct path for your burp-mcp-proxy

# 4. Create your first target
mkdir -p ~/hunts/target.com
cp templates/GEMINI.md ~/hunts/target.com/GEMINI.md
# Edit: fill in scope from the program page

# 5. Run recon
chmod +x scripts/recon.sh
cd ~/hunts/target.com
../../scripts/recon.sh target.com

# 6. Start hunting
cd ~/hunts/target.com   # MUST be in the target folder
gemini
```

---

## Repository Structure

```
gemeniflow/
├── README.md                         ← you are here
├── LICENSE                           ← MIT
├── .gitignore                        ← excludes all target data
├── docs/
│   └── methodology.md                ← full step-by-step operator playbook
├── scripts/
│   └── recon.sh                      ← automated recon pipeline
├── templates/
│   ├── GEMINI.md                     ← per-target scope file template
│   └── settings.json                 ← Gemini CLI MCP config template
└── skill-builder/
    └── system-instructions.md        ← Skill Builder Gem setup + example output
```

---

## The 5-Phase Workflow

| Phase | What happens |
|---|---|
| **0 — Setup** | Install CLI, @kali, @burp, wire settings.json, create GEMINI.md, set up Skill Builder Gem |
| **1 — Recon** | `recon.sh` runs locally (zero AI tokens) — subfinder, amass, httpx, katana, gau |
| **2 — Fingerprint** | `@kali httpx --tech-detect` → update GEMINI.md → Skill Builder Gem → Tactical Payload Map |
| **3 — Hunt** | Browse target → `/plan` → `@burp` history pull every 15-20 min → deep-dive flagged items |
| **4 — Exploit** | IDOR, JWT, GraphQL, SQLi, XXE, race conditions, WAF bypass — all prompt-ready |
| **5 — Report** | `/chat save` → generate HackerOne or Bugcrowd report in 10 minutes |

Full details: [`docs/methodology.md`](docs/methodology.md)

---

## Requirements

| Tool | Install |
|---|---|
| Kali Linux 2026.1 | — |
| Node.js v22.x | `nvm install 22` |
| Gemini CLI | `npm install -g @google/gemini-cli` |
| mcp-server-kali | `pip install mcp-server-kali --break-system-packages` |
| Burp Suite Professional | BApp Store → search "MCP Server" → Install |
| subfinder, httpx, katana, gau, nuclei | See `docs/methodology.md` → Prerequisites |

---

## Key Files

### `templates/GEMINI.md`
Scope guard + role definition. Placed in your target folder, auto-read by the CLI on every session start. Controls what the AI is allowed to touch.

### `templates/settings.json`
Wires `@kali` and `@burp` to Gemini CLI using **stdio transport** (not HTTP). Using `"url": "http://..."` causes HTTP 404 errors — this template has the correct pattern.

### `scripts/recon.sh`
Full recon pipeline with a tool-check guard. Fails early if any required tool is missing. Outputs structured files the CLI can consume directly.

### `skill-builder/system-instructions.md`
Complete setup guide for the Skill Builder Gem — the browser AI that returns stack-specific bypass techniques from real public disclosures.

---

## Important Notes

**`gemini.google.com` (web UI) cannot reach your localhost.**  
This is a browser security boundary — not a missing package.  
Everything in GemeniFlow runs in your terminal via the `gemini` command.

**Always `cd` into your target folder before running `gemini`.**  
The CLI reads `GEMINI.md` from the current working directory. Wrong folder = no scope context.

**Never use `--approval-mode yolo` on live programs.**  
One out-of-scope request = program ban.

---

## Troubleshooting

See [`docs/methodology.md`](docs/methodology.md) → Troubleshooting section.

Covers: MCP 404 errors, `mcp-server-kali` not found, `@burp` returning empty, GEMINI.md not loading, Node.js version errors.

---

## License

MIT — see [LICENSE](LICENSE)

---

## Contributing

PRs welcome. If you find a better MCP server, a new Skill Builder technique, or a workflow improvement — open an issue or submit a pull request.

---

*Use responsibly. Only test on programs you are authorized to test.*  
*Built by [@OmaRrAlaa101](https://github.com/OmaRrAlaa101)*
