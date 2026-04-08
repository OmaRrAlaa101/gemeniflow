# Role: Tactical Operator
## MCP Tools: @burp (Eyes), @kali (Hands)

## Target
- Domain: TARGET.COM
- Program: PLATFORM_NAME          ← HackerOne / Bugcrowd / YesWeHack / Intigriti
- Program URL: https://hackerone.com/TARGET
- Max reward: $X for critical

## In Scope
- *.target.com
- api.target.com
- app.target.com
<!-- Copy every in-scope asset from the program page verbatim -->

## Out of Scope
- admin.corp.target.com
- *.staging.target.com
<!-- Copy every OOS asset from the program page -->

## Tech Stack
<!-- Fill this in after Phase 2 fingerprinting — leave [unknown] until confirmed -->
- Backend: [unknown]
- Frontend: [unknown]
- Database: [unknown]
- CDN / WAF: [unknown]
- Auth mechanism: [unknown]
- Cloud provider: [unknown]
- GraphQL: [yes/no — endpoint at /graphql if yes]

## Priority Vulnerability Classes
- IDOR / BOLA
- Authentication bypass
- Business logic flaws
- SSRF
- GraphQL injection / introspection
- JWT manipulation

## Burp Collaborator URL
- REPLACE_WITH_YOUR_COLLABORATOR_URL.oastify.com
<!-- Get this from Burp → Collaborator tab → Copy to clipboard -->

## Rules — NEVER BREAK THESE
- Never touch out-of-scope assets under any circumstance
- Never run denial-of-service style payloads
- Never use --approval-mode yolo on live programs
- Fingerprint first → exploit second → report third
- Pull Burp history every 15-20 minutes during active browsing
- Save session before ending: /chat save session_name
