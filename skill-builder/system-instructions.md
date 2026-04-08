# Skill Builder — Gemini Gem Setup

The Skill Builder is a custom Gemini Gem that maps your target's tech stack to known
bypass techniques from real public disclosures on HackerOne, Bugcrowd, YesWeHack,
and Intigriti. It is your research brain.

---

## How to Create the Gem (One Time)

1. Go to `gemini.google.com`
2. Left sidebar → click **Gems**
3. Click **New Gem**
4. Name it exactly: `Skill Builder`
5. Paste the full system instructions below into the **Instructions** field
6. Click **Save**

---

## System Instructions — Paste This Verbatim

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
     port, or parameter name — that bypassed WAF/firewall on H1/Bugcrowd.
     This is the delta. Not the definition. The trick.
   Minimum PoC: Exact payload or curl command to prove impact.
   CLI Command: A ready-to-run @burp or @kali instruction.
   CVSS Estimate: Score + vector string (CVSS 3.1).
   Platform: Which platform reported this, and in what year.

3. After the Tactical Payload Map, add a section called "What NOT to test":
   List vulnerability classes that are generic and unlikely to yield bounties
   on this specific stack.
   Examples: SQLi on a NoSQL database, XSS on a pure API with no HTML rendering.

Constraints:
- No generic definitions. Only the delta — the unique technique.
- If a stack combination has no known public disclosures, say so explicitly.
  Do NOT fabricate techniques.
- Always cite the disclosure year and platform.
- If the WAF is Cloudflare: always include the current bypass technique
  reported on H1/Intigriti specifically for that WAF in 2024-2026.
```

---

## How to Use It Per Target

### Step 1 — After fingerprinting, open the Skill Builder Gem in your browser

Send this prompt (fill in your actual stack from Phase 2):

```
Skill Builder: target.com runs this stack:
  Backend: Node.js 18 / Express 4.x
  Frontend: Next.js 13 (App Router)
  Database: PostgreSQL via Prisma ORM
  WAF: Cloudflare
  Auth: JWT RS256 + OAuth2 (Google)
  Cloud: AWS S3
  GraphQL: endpoint at /graphql

Give me the full Tactical Payload Map.
Top 3-5 bugs reported against this combination on
HackerOne, Bugcrowd, YesWeHack, or Intigriti in 2024-2026.
Include specific bypass technique and a ready-to-run CLI command.
```

### Step 2 — Copy the Tactical Payload Map output

### Step 3 — Switch to your terminal (Gemini CLI) and paste it as context

```
"I have the Tactical Payload Map from my Skill Builder research session.

Here it is:
[paste the entire map]

Now:
1. Search @burp history for endpoints where the flagged technology is active.
2. For each Tactical Payload in the map, identify the best matching endpoint.
3. Apply the first payload. Report response code and body differences."
```

---

## Example Output — What Good Skill Builder Output Looks Like

```
Tactical Payload Map — Next.js 13 / Node.js / Cloudflare

1. Technology: Next.js 13 (App Router)
   Vulnerability Class: Path Traversal via i18n routing
   Platform Secret: Intigriti (2025) — /[locale]/../../../etc/passwd bypasses
     Next.js route guards when i18n is enabled and locale param is unsanitized.
   Minimum PoC: GET /en/../../../etc/passwd HTTP/1.1
   CLI Command: @kali run: curl -v "https://target.com/en/../../../etc/passwd"
   CVSS: 7.5 (AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:N/A:N)
   Platform: Intigriti, 2025

2. Technology: JWT (RS256)
   Vulnerability Class: Algorithm Confusion Attack
   Platform Secret: HackerOne (2024) — changing alg from RS256 to HS256
     and signing with the server's public key (obtained from /jwks.json)
     bypassed token validation on 3 separate Node.js programs.
   Minimum PoC: Modified JWT signed with public key as HMAC secret.
   CLI Command: @kali run: python3 jwt_confusion.py --url https://target.com/api/me
   CVSS: 9.1 (AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:N)
   Platform: HackerOne, 2024

What NOT to test:
- Classic SQL injection (Prisma ORM parameterizes queries by default)
- Stored XSS via API-only endpoints (no HTML rendering in the API layer)
- CSRF on API endpoints using JSON bodies (not form submissions)
```

---

## Why This Matters

Without the Skill Builder you test everything generically.  
With the Skill Builder you test only what has proven to work against this exact stack — based on what other researchers already got paid for.

**Efficiency gain:** Stop testing SQLi on NoSQL. Stop testing XSS on pure APIs.  
**Platform intelligence:** You leverage collective hacker knowledge from 4 major platforms.  
**Zero wasted tokens:** Heavy research happens in the Gem. CLI tokens go to execution only.
