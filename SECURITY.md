# Security Policy

DevPortal inspects local process, port, and Docker state, so security reports are
taken seriously.

## Reporting A Vulnerability

Please do not open a public GitHub issue for vulnerabilities.

Use GitHub private vulnerability reporting:

https://github.com/mweisberg21/DevPortal/security/advisories/new

If private reporting is unavailable, open a minimal public issue asking for a
private contact path and avoid sharing exploit details.

## Scope

Useful reports include:

- unsafe process termination behavior
- command injection or unsafe shell escaping
- accidental network transmission of local machine data
- permission, launch-at-login, or notification behavior that differs from the UI
- release signing, packaging, or update integrity problems
