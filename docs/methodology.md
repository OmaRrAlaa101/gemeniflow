# GemeniFlow — github.com/OmaRrAlaa101/gemeniflow
## Complete Operator Playbook | Kali Linux 2026.1

> **Critical note before starting:** `gemini.google.com` (the web UI) cannot reach your localhost. This is a browser security boundary — not a missing package or config. Everything in this guide runs in your **terminal** via the `gemini` command. The Skill Builder Gem runs in the browser but only for research output — execution always happens in the CLI.

---

## Table of Contents

1. Prerequisites & Tool Installation
2. Phase 0 — One-Time Setup (6 Steps)
3. Phase 1 — Recon (Zero AI Tokens)
4. Phase 2 — Fingerprint + Skill Builder Loop
5. Phase 3 — Live Hunt (Burp Co-Pilot)
6. Phase 4 — Exploitation & Payload Refinement
7. Phase 5 — Report Generation
8. Pro Habits
9. Troubleshooting
10. Quick Reference

---

## Prerequisites & Tool Installation

### What you need installed before anything else

Run this block first. It checks what is missing.

```bash
# Check which tools are already installed
for tool in subfinder assetfinder amass httpx katana gau nuclei nmap whatweb curl jq; do
  if command -v $tool &>/dev/null; then
    echo "✓ $tool"
  else
    echo "✗ MISSING: $tool"
  fi
done
```

### Install missing tools

```bash
# Update first
sudo apt update

# Core recon tools
sudo apt install -y nmap curl jq whatweb

# Go-based tools (install via apt on Kali 2026)
sudo apt install -y golang-go

# Subfinder
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest

# Assetfinder
go install github.com/tomnomnom/assetfinder@latest

# Amass
sudo apt install -y amass

# httpx
go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest

# Katana (crawler)
go install github.com/projectdiscovery/katana/cmd/katana@latest

# gau (historical URLs)
go install github.com/lc/gau/v2/cmd/gau@latest

# Nuclei
go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest

# Add Go binaries to PATH (do this once)
echo 'export PATH=$PATH:$HOME/go/bin' >> ~/.zshrc
source ~/.zshrc

# Verify all Go tools are in PATH
which subfinder httpx katana nuclei
```

### Install Node.js via NVM (required for Gemini CLI)

```bash
# Install NVM
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

# Reload shell
source ~/.zshrc

# Install Node.js v22 LTS
nvm install 22
nvm use 22
nvm alias default 22

# Verify
node --version   # Should print v22.x.x
npm --version    # Should print 10.x.x
```

### Directory structure you will use

Create this once. Every hunt lives here.

```bash
mkdir -p ~/hunts
```

When you start a new target:

~/hunts/
├── recon.sh                    ← shared script, created in Phase 0
└── target.com/
    ├── GEMINI.md               ← scope file, auto-read by CLI
    └── targets/
        └── target.com/
            ├── raw/
            │   └── subs.txt        ← all subdomains (raw, with dupes)
            ├── processed/
            │   ├── unique_subs.txt ← deduplicated subdomains
            │   ├── live.txt        ← live hosts with tech stack
            │   ├── endpoints.txt   ← all crawled endpoints
            │   └── endpoints_unique.txt ← final deduplicated endpoint list
            ├── all_ports/          ← NEW: Results from Phase 1.5 (naabu/nmap)
            │   ├── full_scan.txt   ← raw list of all 65k open ports
            │   └── services.txt    ← httpx/whatweb results for non-std ports
            ├── artifacts/          ← NEW: Results from Phase 2.5 (ffuf)
            │   ├── leaks.txt       ← found .env, swagger, or config files
            │   └── ai_generated.md ← analysis of detected AI/dev artifacts
            ├── monitoring/         ← NEW: Results from Phase 6 (Continuous)
            │   ├── baseline.txt    ← snapshot of last known state
            │   └── delta.txt       ← newly appeared assets found today
            └── notes/
                └── findings.md     ← your manual notes during hunt

---

## Phase 0 — One-Time Setup

> Do this once. Never again unless you wipe your system.

---

### Step 1 — Install Gemini CLI

Do NOT use the Kali apt package. Use npm — it is the official release and always more current.

```bash
npm install -g @google/gemini-cli

# Verify
gemini --version
```

Authenticate with your Google account:

```bash
gemini auth login
# This opens a browser window → sign in → authorize → return to terminal
```

**How to verify it worked:**

Start the CLI and check the first line of output:

```bash
gemini
```

You should see this line in the startup output:

```
ℹ  Authenticated via "oauth-personal".
```

If you see `Error: not authenticated` → re-run `gemini auth login`.

---

### Step 2 — Install the Kali MCP Server

This is what becomes `@kali` inside the CLI. It exposes your local tools (nmap, httpx, subfinder, nuclei, etc.) to Gemini.

> **The apt package does not exist.** `sudo apt install gemini-desktop-bridge` will fail. Use pip only.

**Option A — pip (recommended):**

```bash
pip install mcp-server-kali --break-system-packages

# Verify the binary is in PATH
which mcp-server-kali
```

Expected output: `/usr/local/bin/mcp-server-kali` or `/home/kali/.local/bin/mcp-server-kali`

**If `which` returns nothing:**

```bash
# pip installed it to ~/.local/bin which is not in PATH
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# Try again
which mcp-server-kali
```

**Option B — build from source (if pip fails):**

```bash
git clone https://github.com/rusty-sec/mcp-kali
cd mcp-kali
pip install . --break-system-packages
which mcp-server-kali
```

---

### Step 3 — Install the Burp MCP Extension

This is what becomes `@burp` inside the CLI. It gives Gemini read access to your live proxy traffic.

**Inside Burp Suite Professional:**

1. Go to **Extensions** → **BApp Store**
2. Search: `MCP Server`
3. Click **Install**
4. After install, a new **MCP** tab appears in Burp
5. Go to that tab → click **Start Server**
6. Confirm it shows: `Server running on :9876`

**Get your Burp Collaborator URL (needed for blind SSRF/XXE payloads):**

1. In Burp → **Collaborator** tab (top menu bar)
2. Click **Copy to clipboard**
3. You will get a URL like: `xyz123abc.oastify.com`
4. Save this — you will paste it into GEMINI.md

**Configure your browser to proxy through Burp:**

For Firefox (recommended):

1. Settings → Network Settings → Manual proxy configuration
2. HTTP Proxy: `127.0.0.1` Port: `8080`
3. Check "Also use this proxy for HTTPS"
4. Install Burp's CA certificate: visit `http://burp` → Download CA Certificate → install in Firefox

For Chromium:

```bash
chromium --proxy-server="http://127.0.0.1:8080" &
```

---

### Step 4 — Create `~/.gemini/settings.json`

This file wires your MCP servers to the CLI. **This is the root cause of your HTTP 404 errors** — the wrong transport type.

**Why you were getting 404s:**

Your previous config had `"url": "http://127.0.0.1:5000"` which forces HTTP transport. The CLI tried to POST to that URL and got a 404 because nothing was serving at that endpoint. The correct pattern for local tools is **stdio transport**: `command` + `args`.

```bash
mkdir -p ~/.gemini
nano ~/.gemini/settings.json
```

Paste this exactly:

{
  "mcpServers": {
    "kali": {
      "command": "/usr/bin/mcp-server",
      "args": [
        "--server",
        "http://127.0.0.1:5000"
      ]
    },
    "burp": {
      "command": "/usr/bin/java",
      "args": [
        "-jar",
        "/home/kali/mcp-proxy.jar",
        "--sse-url",
        "http://127.0.0.1:9876"
      ]
    }
  },
  "security": {
    "auth": {
      "selectedType": "oauth-personal"
    }
  }
}


> If the Burp extension handles MCP natively without a separate proxy (check your extension's documentation), you can remove the `burp` block entirely and the extension will handle it directly.

**Find the burp-mcp-proxy path if you don't know it:**

```bash
find / -name "burp-mcp*" -o -name "mcp-proxy*" 2>/dev/null | grep -v proc
```

**Verify the config works:**

```bash
gemini
```

Inside the CLI:

```
/mcp
```

You should see output like this (both servers listed with their tools):

```
MCP Servers:
  kali (connected)
    Tools: run_command, nmap_scan, httpx_probe, subfinder_enum, ...
  burp (connected)  
    Tools: list_proxy_http_history, send_http_request, get_request_details, ...
```

If you still see 404 errors, jump to the Troubleshooting section.

---

### Step 5 — Create the Scope File (GEMINI.md)

Create a new folder for each target. Put `GEMINI.md` inside it. **Always `cd` into that folder before running `gemini`** — the CLI reads `GEMINI.md` from the current working directory automatically on startup.

```bash
mkdir -p ~/hunts/target.com
cd ~/hunts/target.com
nano GEMINI.md
```

Paste this template and fill in the blanks:

```markdown
# Role: Tactical Operator
## MCP Tools: @burp (Eyes), @kali (Hands)

## Target
- Domain: target.com
- Program: HackerOne  ← change to Bugcrowd / YesWeHack / Intigriti
- Program URL: https://hackerone.com/target
- Max reward: $X for critical

## In Scope
- *.target.com
- api.target.com
- app.target.com
← list every in-scope asset from the program page

## Out of Scope
- admin.corp.target.com
- *.staging.target.com
← list every OOS asset

## Tech Stack
← fill this in after Phase 2 fingerprinting
- Backend: [unknown]
- Frontend: [unknown]
- Database: [unknown]
- CDN / WAF: [unknown]
- Auth mechanism: [unknown]
- Cloud provider: [unknown]

## Priority Vulnerability Classes
- IDOR / BOLA
- Authentication bypass
- Business logic flaws
- SSRF
- GraphQL injection / introspection
- JWT manipulation

## Burp Collaborator URL
- [paste your collaborator URL here, e.g. xyz123.oastify.com]

## Rules — NEVER BREAK THESE
- Never touch out-of-scope assets under any circumstance
- Never run denial-of-service style payloads
- Never use --approval-mode yolo on live programs
- Fingerprint first. Exploit second. Report third.
- Pull Burp history every 15-20 minutes during active browsing
- Save session before ending: /chat save session_name
```

---

### Step 6 — Set Up the Skill Builder Gem

The Skill Builder is a **custom Gemini Gem** — a persistent AI persona that lives in your browser at `gemini.google.com`. It is your research brain. You describe the target's tech stack → it returns known bypass techniques from real public disclosures on HackerOne, Bugcrowd, YesWeHack, and Intigriti.

**How to create it (one-time):**

1. Go to `gemini.google.com`
2. In the left sidebar → click **Gems**
3. Click **New Gem**
4. Name it: `Skill Builder`
5. In the **Instructions** field, paste the entire block below
6. Click **Save**

**Skill Builder System Instructions — paste verbatim:**

```
Role: You are the Skill Builder Research Agent.
Specialty: Stack-Specific Vulnerability Mapping.

Knowledge Mandate:
Analyze public disclosures from HackerOne, Bugcrowd, YesWeHack, and Intigriti
to find the intersection of specific technologies and high-impact bugs.

Instructions:

1. When I provide a Tech Stack, retrieve the top 3-5 stack-specific bypasses
   or misconfigurations reported on those platforms in 2024-2026.

2. Structure your output as a "Tactical Payload Map" for each finding:

   Technology: [e.g., Redis 7.x]
   Vulnerability Class: [e.g., SSRF-to-RCE]
   Platform Secret: The specific trick — encoding, header flip, non-standard
     port, parameter name — that bypassed WAF or firewall on H1/Bugcrowd.
     This is the delta. Not the definition. The trick.
   Minimum PoC: Exact payload or curl command to prove impact.
   CLI Command: A ready-to-run @burp or @kali instruction.
   CVSS Estimate: Score + vector string.
   Platform: Which platform reported this, and in what year.

3. After the Tactical Payload Map, add a section called "What NOT to test":
   List vulnerability classes that are generic and unlikely to yield bounties
   on this specific stack (e.g., SQLi on a NoSQL database, XSS on a pure API).

Constraints:
- No generic definitions. Only the delta.
- If a stack combination has no known public disclosures, say so explicitly.
  Do not fabricate techniques.
- Always cite the disclosure year and platform.
- If the WAF is Cloudflare, always include the current bypass technique
  for that WAF in 2024-2026 specifically.
```

**What good Skill Builder output looks like:**

When you send it a stack, it should return something like this:

```
Tactical Payload Map — Next.js 13 / Node.js / Cloudflare

1. Technology: Next.js 13 (App Router)
   Vulnerability Class: Path Traversal via i18n routing
   Platform Secret: Researchers on Intigriti (2025) found that
     /[locale]/../../../etc/passwd bypasses Next.js route guards when
     internationalization is enabled and the locale param is not sanitized.
   Minimum PoC: GET /en/../../../etc/passwd HTTP/1.1
   CLI Command: @kali run: curl -v "https://target.com/en/../../../etc/passwd"
   CVSS Estimate: 7.5 (AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:N/A:N)
   Platform: Intigriti, 2025

What NOT to test:
- Classic SQL injection (Prisma ORM parameterizes queries by default)
- Stored XSS via API-only endpoints (no HTML rendering in the API)
```

**How to use the Skill Builder per target (the loop):**

```
You (browser, Skill Builder Gem):
  "Target stack: [paste httpx -tech-detect output here].
   Give me the Tactical Payload Map."

Skill Builder returns: Tactical Payload Map

You (terminal, Gemini CLI):
  "I have the Tactical Payload Map from my research.
   Here it is: [paste the entire map]
   Search @burp history for endpoints where this technology is active.
   Apply these payloads."
```

---

## Phase 1 — Recon

> Zero AI tokens. Run everything locally first.

---

### Step 1 — Create recon.sh

Create this file once in your `~/hunts/` folder. Reuse for every target.

```bash
nano ~/hunts/recon.sh
```

Paste this entire script:

```bash
#!/bin/bash
# GemeniFlow Recon Script — run from ~/hunts/target.com/
# Usage: ./recon.sh target.com

set -e

DOMAIN=$1

if [ -z "$DOMAIN" ]; then
  echo "Usage: $0 target.com"
  exit 1
fi

# Check required tools
MISSING=0
for tool in subfinder assetfinder amass httpx katana gau; do
  if ! command -v $tool &>/dev/null; then
    echo "✗ MISSING: $tool — install it before running recon"
    MISSING=1
  fi
done
[ $MISSING -eq 1 ] && exit 1

mkdir -p ./targets/$DOMAIN/{raw,processed,notes}

echo ""
echo "[*] ═══════════════════════════════════"
echo "[*]  Target: $DOMAIN"
echo "[*] ═══════════════════════════════════"
echo ""

echo "[*] Subfinder..."
subfinder -d $DOMAIN -silent > ./targets/$DOMAIN/raw/subs.txt

echo "[*] Assetfinder..."
assetfinder --subs-only $DOMAIN >> ./targets/$DOMAIN/raw/subs.txt

echo "[*] Amass (passive, 5 min timeout)..."
timeout 300 amass enum -passive -d $DOMAIN >> ./targets/$DOMAIN/raw/subs.txt || true

echo "[*] Deduplicating..."
sort -u ./targets/$DOMAIN/raw/subs.txt \
  -o ./targets/$DOMAIN/processed/unique_subs.txt

echo "[*] Live host check (httpx)..."
cat ./targets/$DOMAIN/processed/unique_subs.txt \
  | httpx -silent \
          -mc 200,301,302,403,401 \
          -title \
          -tech-detect \
          -status-code \
          -follow-redirects \
  > ./targets/$DOMAIN/processed/live.txt

echo "[*] Endpoint crawl (katana, depth 3)..."
cat ./targets/$DOMAIN/processed/live.txt \
  | awk '{print $1}' \
  | katana -silent -d 3 -jc \
  > ./targets/$DOMAIN/processed/endpoints.txt

echo "[*] Historical URLs (gau)..."
cat ./targets/$DOMAIN/processed/unique_subs.txt \
  | gau --blacklist png,jpg,gif,svg,woff,woff2,ttf,css,ico \
  >> ./targets/$DOMAIN/processed/endpoints.txt

sort -u ./targets/$DOMAIN/processed/endpoints.txt \
  -o ./targets/$DOMAIN/processed/endpoints_unique.txt

echo ""
echo "[+] ═══════════════════════════════════"
echo "[+]  Done — $DOMAIN"
echo "[+] ═══════════════════════════════════"
echo "[+]  Raw subdomains:    $(wc -l < ./targets/$DOMAIN/raw/subs.txt)"
echo "[+]  Unique subdomains: $(wc -l < ./targets/$DOMAIN/processed/unique_subs.txt)"
echo "[+]  Live hosts:        $(wc -l < ./targets/$DOMAIN/processed/live.txt)"
echo "[+]  Unique endpoints:  $(wc -l < ./targets/$DOMAIN/processed/endpoints_unique.txt)"
echo "[+] ═══════════════════════════════════"
echo ""
echo "[*] Output files:"
echo "    ./targets/$DOMAIN/processed/live.txt"
echo "    ./targets/$DOMAIN/processed/endpoints_unique.txt"
```

Make it executable:

```bash
chmod +x ~/hunts/recon.sh
```

### Step 2 — Run recon for your target

```bash
# Always run from inside your target folder
cd ~/hunts/target.com

# Run recon
~/hunts/recon.sh target.com
```

### Step 3 — Feed output to Gemini for prioritization

This is the only AI call in Phase 1. Open Gemini CLI while still in the target folder:

```bash
cd ~/hunts/target.com
gemini
```

Inside the CLI:

```
"I am hunting on target.com. This is a HackerOne program.

Here are my live subdomains with detected tech stack:
$(cat ./targets/target.com/processed/live.txt)

Here are the first 100 discovered endpoints:
$(head -100 ./targets/target.com/processed/endpoints_unique.txt)

Tasks:
1. Rank the top 5 subdomains by vulnerability likelihood — explain your reasoning
   based on naming patterns (dev, staging, admin, api, internal) and detected tech.
2. For each of the top 5, name the single Nuclei template category most likely to find a bug.
3. Identify any endpoints with integer IDs, UUIDs, or object references that could be IDOR surfaces.
4. Flag any /api/ or /v1/ or /v2/ routes that might lack authentication based on naming.
5. Flag any tech stack combinations known for specific misconfigurations (e.g. Laravel debug
   mode, GraphQL introspection enabled, Elasticsearch exposed, Spring Actuator, etc).
6. Which subdomain should I start with? Give me one clear recommendation."
```

**What Gemini returns:** A prioritized attack queue. Pin this to your notes:

```bash
# Save Gemini's output to notes
nano ~/hunts/target.com/targets/target.com/notes/findings.md
```

### Step 4 — Run Nuclei on Gemini's top picks only

```bash
# Run only on the subdomains Gemini flagged as highest priority
nuclei -u https://dev-api.target.com \
  -t exposures/ \
  -t misconfigurations/ \
  -t cves/ \
  -severity medium,high,critical \
  -silent \
  -o ./targets/target.com/notes/nuclei_results.txt

cat ./targets/target.com/notes/nuclei_results.txt
```

---

 ### Phase 1.5 — Full Port Scan (The Competitive Edge)
    1. **Scan All Ports:** Run `naabu` against every live host found in Phase 1.
       ```bash
       cat ./processed/live.txt | awk '{print $1}' | sed 's/https\?:\/\///' | naabu -p - -silent -o ./all_ports/full_scan.txt
       ```
    2. **Service Discovery:** Feed open ports back into `httpx` to find non-standard web services (e.g., 8080, 8443, 9000).
    3. **AI Task:** Ask Gemini to identify "high-value" services (Redis, Docker API, Jenkins) and provide default credential lists for each.


## Phase 2 — Fingerprint + Skill Builder Loop

> Identify the exact stack → map it to known bypass techniques → execute only targeted payloads.

---

### Step 1 — Deep fingerprint with @kali

Make sure you are in your target folder, then start the CLI:

```bash
cd ~/hunts/target.com
gemini
```

Inside the CLI, run both of these:

```
@kali run: httpx -u https://target.com -tech-detect -title -status-code -follow-redirects -include-response-header

Report everything you find: backend framework, frontend stack, CDN name, WAF name, server header value, X-Powered-By header, Content-Security-Policy header, any version strings visible in headers or body.
```

Then:

```
@kali run: whatweb -a 3 https://target.com

Report all detected plugins, CMS, frameworks, JavaScript libraries, server software, and version numbers.
```

**What the output tells you — example:**

```
https://target.com [200] [Next.js] [React] [Cloudflare] [Node.js]
  Server: cloudflare
  X-Powered-By: Next.js
  Via: 1.1 vegur
  Content-Type: application/json; charset=utf-8
```

From this you know: Next.js frontend, Node.js backend, Cloudflare WAF.

### Step 2 — Update GEMINI.md with the stack

```bash
nano ~/hunts/target.com/GEMINI.md
```

Fill in the Tech Stack section. Example:

```markdown
## Tech Stack
- Backend: Node.js 18 / Express 4.x
- Frontend: Next.js 13 (App Router)
- Database: PostgreSQL via Prisma ORM
- CDN / WAF: Cloudflare
- Auth: JWT (RS256) + OAuth2 (Google SSO)
- Cloud: AWS (S3 bucket URLs visible in image requests)
- GraphQL: Yes — endpoint at /graphql (detected via Katana)
```

### Step 3 — Consult the Skill Builder Gem (browser)

Open the Skill Builder Gem at `gemini.google.com → Gems → Skill Builder`.

Send this prompt:

```
Skill Builder: target.com runs this stack:
  Backend: Node.js 18 / Express 4.x
  Frontend: Next.js 13 (App Router)
  Database: PostgreSQL via Prisma ORM
  WAF: Cloudflare
  Auth: JWT RS256 + OAuth2 (Google)
  Cloud: AWS S3

Give me the full Tactical Payload Map.
Top 3-5 bugs reported against this exact stack on HackerOne, Bugcrowd,
YesWeHack, or Intigriti in 2024-2026.
Include the specific bypass technique and a ready-to-run CLI command.
```

### Step 4 — Bring the Tactical Payload Map into your CLI session

Switch back to your terminal. Paste the Skill Builder's output directly:

```
"I have the Tactical Payload Map from my research session.

Here it is:
[paste the entire Skill Builder output here]

Now:
1. Search @burp history for any endpoints where the flagged technology is active.
2. For each Tactical Payload in the map, identify the best matching endpoint in Burp history.
3. Apply the first payload. Report the response code, response body snippet, and any differences from a baseline request."
```

---

 ### Phase 2.5 — AI-App Artifacts & 4xx Logic
    1. **Artifact Fuzzing:** Use `ffuf` to look for `.env`, `swagger.json`, `schema.graphql`, and `README.md`.
    2. **Investigate 403/401s:** Never ignore "Forbidden" errors. Use Gemini to generate bypass headers (e.g., `X-Custom-IP-Authorization`).
    3. **Blank 200s:** If a page returns a `200 OK` but the body is empty or < 50 bytes, flag it for manual inspection—it often indicates a misconfigured proxy.

---

## Phase 3 — Live Hunt with Burp as Co-Pilot

> You browse manually. Gemini reads your traffic in real-time and finds patterns you would miss.

---

### Session start checklist — do this before every hunt session

```
□ Terminal 1: cd ~/hunts/target.com && gemini
□ Burp Suite: running, MCP tab shows "Server running on :9876"
□ Browser: proxy configured to 127.0.0.1:8080
□ GEMINI.md: updated with latest stack and notes
□ Previous session notes: reviewed (./targets/domain/notes/findings.md)
□ Collaborator tab: open and ready in Burp
```

**Verify @kali and @burp are connected at session start:**

Run this inside the CLI immediately after opening:

```
/mcp
```

You should see both servers listed with their tools. If either shows as disconnected, check the Troubleshooting section.

**Test that @kali can actually run tools:**

```
@kali run: echo "kali MCP is working"
```

Expected response: the CLI calls the kali tool and returns `kali MCP is working`.

**Test that @burp can read history:**

```
@burp list_proxy_http_history
```

Expected: a list of recent Burp requests. If you get an error, Burp's MCP server may not be running.

### Step 1 — Use /plan before touching any complex feature

Before testing auth flows, file uploads, payment logic, or anything stateful — always plan first:

```
/plan "Map the authentication flow of https://api.target.com.

Focus areas:
1. JWT handling — what algorithm (alg field)? What is the expiry? Any validation gaps?
2. Session token rotation — does the session ID change after login?
3. Response differences — authenticated vs unauthenticated on /user/ endpoints
4. IDOR surfaces — profile, settings, billing, notifications, file access
5. OAuth flow — is the state parameter validated? Any redirect_uri bypass possible?

Output: a numbered checklist I can follow top-to-bottom. Mark each item as I complete it."
```

### Step 2 — Browse your target systematically

Cover these areas in order. Do not skip:

- Login flow (sign up, log in, password reset, logout)
- Profile / account settings (name, email, avatar, password change)
- Any feature involving other users (messaging, sharing, comments, mentions)
- File upload (avatar, attachments, imports, exports)
- Billing / subscription / coupon / promo codes
- Admin or higher-privilege features (even if you cannot access them — note the endpoints)
- API endpoints (watch Burp for /api/, /v1/, /v2/, /graphql)

### Step 3 — Pull Burp history every 15-20 minutes

Run this regularly throughout your session:

```
@burp list_proxy_http_history --filter "target.com"

"Analyze the last 30 HTTP requests. Flag:
1. Any integer ID, UUID, or object reference in URL paths or request bodies (IDOR candidates)
2. POST requests missing CSRF tokens or SameSite cookie flags
3. JWT tokens — check the alg field in the header: is it 'none' or 'HS256'?
4. Any endpoint returning data that a lower-privilege user should not see
5. File upload endpoints — what Content-Type or MIME types are accepted?
6. GraphQL queries — is introspection enabled? Any __schema or __type queries succeeding?
7. Any response containing other users' data, IDs, or email addresses

Include the Burp history item number for every suspicious finding."
```

### Step 4 — Deep-dive on flagged requests

When Gemini flags a specific item:

```
"Look at Burp history item #318.
It is a POST to /api/v2/user/settings with a JSON body.

1. Is the user_id in the body server-validated or just trusted from the client?
2. Can I replace it with another user's ID and get a 200 OK?
3. Generate 5 IDOR test payloads targeting other user IDs near my own (mine is 10482).
4. What happens if I remove the Authorization header entirely — does the server still respond?
5. What is the exact curl command to reproduce request #318 with my session cookie?

Use @burp to send the modified requests and report the response code and body for each."
```

---

## Phase 4 — Exploitation & Payload Refinement

> You have a confirmed signal. These prompts turn a lead into a documented, reproducible exploit.

---

> **Template Factory:** Once a vulnerability is confirmed manually, ask Gemini: "Based on this HTTP request/response, write a Nuclei v3 template to automate this check across my other 50 programs".


### IDOR / BOLA Exploitation

```
"IDOR confirmed: POST /api/v1/profile/update accepts user_id in the JSON body.
My user ID is 10482. The server returns 200 OK for any user_id I send.

1. Generate curl commands to test user IDs 10480 through 10490 sequentially.
   For each, compare the response body to my own — what fields differ?
2. Which specific response fields prove another user's PII is exposed?
   (email, phone, billing address, payment method, private notes)
3. Is this BOLA (accessing another object) or BFLA (calling a function you should not)?
4. What is the minimum proof-of-concept needed for a valid HackerOne P2 submission?
5. Write the exact curl command I will include in the report."
```

### JWT Manipulation

```
"I found a JWT in Burp history item #204.

The token header is: [paste base64 header here]
The token payload is: [paste base64 payload here]

1. Decode both parts — what algorithm is being used (alg field)?
2. If alg is HS256: is there a known weak secret I can try? Generate a hashcat command
   to crack it using rockyou.txt.
3. If alg is RS256: can I change it to HS256 and sign with the public key?
   Generate the attack payload.
4. Can I set alg to 'none' and remove the signature entirely?
   What does the resulting token look like?
5. Use @kali to test each variant against the /api/v1/me endpoint.
   Report which, if any, returns a valid 200 response."
```

### GraphQL Introspection & Injection

```
"I found a GraphQL endpoint at https://target.com/graphql in Burp history.

1. Use @burp to send an introspection query:
   { __schema { types { name fields { name } } } }
   Is introspection enabled? Report all types and their fields.

2. If introspection is enabled, identify:
   - Any mutations that modify user data (profile update, password change, role assignment)
   - Any queries that take an ID parameter (IDOR candidates)
   - Any fields that should require admin privileges

3. Test for GraphQL IDOR: send a query for another user's object ID
   (try user IDs near my own: 10480-10490).

4. Test for batch query abuse: send 100 identical login mutations in one request.
   Does the server rate-limit batch operations?"
```

### SQL Injection

```
"Burp history item #156 is a POST to /api/search with a JSON body:
{'query': 'test', 'category': 'products'}

1. Which parameters are most likely to be passed to a SQL query unsanitized?
2. Generate 5 SQL injection test payloads for each parameter, starting with error-based.
3. If the app uses PostgreSQL (detected from stack): what is the specific payload to
   extract the database version and current user?
4. Use @burp to send each payload and report: error messages, response time differences
   (for time-based blind), and any data returned.
5. If WAF blocks the payloads, generate URL-encoded and JSON-escaped variants."
```

### XXE / File Upload

```
"Burp history item #452 is an XML file upload to /api/import.
The Content-Type is application/xml.

1. Generate 3 XXE payloads to read /etc/passwd — ordered from most basic to most evasive.
2. If output is not reflected in the response (blind XXE):
   @kali: trigger an OOB DNS callback to my Collaborator at [your-collab-url].
   What does the triggering payload look like?
3. If an internal DTD is required to bypass filtering, generate an entity chain.
4. What response difference (timing, error message, status code) confirms the XXE is parsing
   even if output is not reflected?
5. Generate the minimum PoC for a bounty report — what is the simplest payload that proves impact?"
```

### Race Condition

```
"POST /api/redeem-coupon accepts a coupon code and deducts from account balance.
The endpoint appears to do: check coupon → deduct balance → mark coupon used.
I suspect a TOCTOU race condition.

1. @kali: generate a Turbo Intruder Python script to send 20 simultaneous requests
   to this endpoint with my valid coupon code. Include the full script I can paste.
2. What exact response difference (status code, balance value, error text) proves the race won?
3. How many parallel requests is the right number? Too many = server error, too few = miss.
4. What is the business impact for the report?
   (financial loss, unlimited credits, inventory manipulation, etc.)"
```

### WAF Bypass (Cloudflare / Akamai)

```
"My XSS payload is being blocked by Cloudflare on /search?q=
(see Burp history item #502 for the exact HTML injection context).

Think step-by-step:
1. Pull item #502 — what is the exact HTML context I am injecting into?
   (inside attribute? inside script tag? inside HTML comment? reflected in JSON?)
2. Based on the HTML context, what is the most appropriate payload structure?
3. Generate 5 progressively more evasive payloads:
   - Payload 1: basic (likely blocked — for baseline)
   - Payload 2: HTML entity encoded
   - Payload 3: Unicode encoded
   - Payload 4: alternative event handler (not onclick or onerror)
   - Payload 5: template literal or less common JS construct
4. Which should I test first to minimize detectable noise to their WAF/SOC?
5. If all 5 are blocked: what specific Cloudflare bypass technique was reported
   on HackerOne or Intigriti for XSS in 2024-2025?"
```

---

## Phase 5 — Report Generation

> 10 minutes to write, not 1 hour.

---

### Step 1 — Save your session first

Always do this before generating a report:

```
/chat save idor_target_profileupdate_2026
```

To resume the next day:

```
/chat resume idor_target_profileupdate_2026
```

Then ask:

```
"Summarize what we found yesterday on api.target.com and where we left off."
```

### Step 2 — Generate the report

**HackerOne format:**

```
"Act as a Senior Bug Bounty Reporter.

Vulnerability: IDOR on POST /api/v1/profile/update
Severity: P2 (High)
Impact: Any authenticated user can view and modify another user's private profile data,
including email address, phone number, and billing address.

HTTP Request (copy-paste from Burp):
[paste full HTTP request here]

HTTP Response proving another user's data is returned:
[paste full HTTP response here]

Write a complete HackerOne report with these sections:
1. Summary (2 sentences max — business impact first, technical detail second)
2. Steps to Reproduce (numbered list, exact curl commands, reproducible by anyone)
3. Impact (who is affected, what data is exposed, regulatory concern: GDPR / PCI-DSS if applicable)
4. Remediation (specific fix — not 'validate input' — explain the exact server-side check needed)
5. CVSS 3.1 score with the full vector string

Format: clean Markdown, no preamble, no fluff."
```

**Bugcrowd / Intigriti format:**

```
"Act as a Senior Bug Bounty Reporter writing for Bugcrowd.

Use the same vulnerability details above but restructure for Bugcrowd's format:
1. Title (max 100 characters, format: [Component] Vulnerability Type leads to Impact)
2. Description (technical explanation of root cause)
3. Steps to Reproduce
4. Expected vs Actual Result
5. Business Impact
6. Affected Assets (list the exact URL or endpoint)
7. Suggested Fix

Bugcrowd priority rating: P2 (Severity 2)."
```
 ### Phase 6 — Continuous Monitoring (Daily Delta)
    1. **Baseline:** Create a "yesterday" snapshot of your subdomains and IPs.
    2. **Daily Delta:** Run a cron job to find new assets using `subfinder` and `Shodan`.
    3. **Rapid Response:** If a new asset appears, immediately trigger **Phase 1.5** (Full Port Scan). New deploys are often unhardened for the first 24 hours.

---

## Pro Habits

| Habit | Command | Why |
|---|---|---|
| Save every session | `/chat save target_session_1` | Resume next day with full context |
| Resume a session | `/chat resume target_session_1` | Ask: "What did we find yesterday?" |
| Check MCP at session start | `/mcp` | Confirm @kali and @burp are connected before hunting |
| Never yolo on live programs | Avoid `--approval-mode yolo` | One OOS request = program ban |
| Scope file per target folder | `cd ~/hunts/target.com && gemini` | GEMINI.md is auto-read from CWD |
| Pull Burp history often | Every 15-20 min during browse | You miss patterns manually — Gemini does not |
| Check Collaborator logs | After every blind payload | OOB interaction = proof for blind SSRF/XXE |
| Store notes as you go | `./targets/$DOMAIN/notes/findings.md` | Yesterday's dead endpoint = today's bug after a code push |
| Ask Skill Builder before WAF bypass | Before manual attempts | Public bypasses already documented — start there |
| Update GEMINI.md as you learn | After fingerprinting | Gemini uses the stack info to give better targeted prompts |

---

## Troubleshooting

---

### 404 errors on MCP startup

**Symptom:**
```
MCP server 'kali': HTTP returned 404, trying SSE transport...
MCP server 'kali': SSE fallback also failed.
```

**Root cause:** Your `settings.json` uses `"url"` key (HTTP transport). The CLI tries to POST to that URL and gets a 404.

**Fix:** Use `"command"` + `"args"` (stdio transport) instead. See Phase 0, Step 4.

---

### `mcp-server-kali`: command not found

**Symptom:** `/mcp` in CLI shows kali server as disconnected or errored.

**Fix:**
```bash
which mcp-server-kali  # returns nothing

echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

which mcp-server-kali  # should now return a path
```

---

### Gemini CLI says "authenticated" but @kali tools fail

**Symptom:** CLI starts fine, `/mcp` lists kali, but `@kali run: nmap ...` returns an error.

**Fix:** The MCP server runs a subprocess. The subprocess may not have the tool in its PATH.

```bash
# Check if nmap is available to the subprocess environment
mcp-server-kali --test  # if this flag exists

# Or check the tool directly
which nmap
which httpx

# If tools are in /home/kali/go/bin but not /usr/local/bin, add to settings.json env:
{
  "mcpServers": {
    "kali": {
      "command": "mcp-server-kali",
      "args": [],
      "env": {
        "PATH": "/home/kali/go/bin:/usr/local/bin:/usr/bin:/bin"
      }
    }
  }
}
```

---

### @burp returns no history / empty list

**Symptom:** `@burp list_proxy_http_history` returns nothing.

**Checklist:**
```
□ Is Burp Suite open?
□ Is the MCP extension installed? (Extensions tab)
□ Did you click "Start Server" in the MCP tab?
□ Does the MCP tab show "Server running on :9876"?
□ Have you browsed any pages through the Burp proxy? (history is empty if you haven't)
□ Is your browser actually proxying through 127.0.0.1:8080?
  Test: visit http://burp — if you see Burp's page, proxy is working
```

---

### GEMINI.md is not being read

**Symptom:** Gemini does not seem to know the target scope or tech stack you wrote in GEMINI.md.

**Root cause:** You started `gemini` from the wrong folder.

**Fix:**
```bash
# Always cd into the target folder BEFORE running gemini
cd ~/hunts/target.com  # GEMINI.md must be HERE
gemini

# Verify it was read:
"What is my current target domain and what is in scope?"
# Gemini should answer with what you wrote in GEMINI.md
```

---

### Node.js version errors on CLI start

```bash
# Check current version
node --version

# If not v22.x
nvm use 22

# Make permanent
nvm alias default 22
echo 'nvm use default --silent' >> ~/.zshrc
```

---

## Quick Reference — Files You Must Create

| File | Location | Created when | Purpose |
|---|---|---|---|
| `settings.json` | `~/.gemini/settings.json` | Once | Wires @kali and @burp to CLI |
| `recon.sh` | `~/hunts/recon.sh` | Once | Full recon pipeline |
| `GEMINI.md` | `~/hunts/TARGET/GEMINI.md` | Per target | Scope guard, role, stack |
| `findings.md` | `~/hunts/TARGET/targets/TARGET/notes/` | Per target | Your manual notes |
| Skill Builder Gem | `gemini.google.com → Gems` | Once | Stack-to-vuln research brain |

---

## Quick Reference — CLI Commands

| Command | What it does |
|---|---|
| `gemini` | Start the CLI (from your target folder) |
| `/mcp` | List all connected MCP servers and their tools |
| `/plan "..."` | Ask Gemini to create an attack plan before you start |
| `/chat save NAME` | Save the current session to resume later |
| `/chat resume NAME` | Resume a saved session |
| `/auth` | Change authentication method |
| `@kali run: COMMAND` | Run a shell command on your Kali machine |
| `@burp list_proxy_http_history` | Pull recent Burp proxy traffic |
| `@burp get_request_details #N` | Get full details of Burp history item N |
| `Ctrl+C` | Exit the CLI |

---

*GemeniFlow — Gemini CLI Bug Bounty Methodology*
*Kali Linux 2026.1  ·  Gemini CLI  ·  github.com/OmaRrAlaa101/gemeniflow*
