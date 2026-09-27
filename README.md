# <Project name>

<One paragraph: what we're building and who it's for.>

## Before you start

- **git** and the **GitHub CLI 2.63 or newer** (`gh --version`), logged in: `gh auth login`.
- **Accept the invite** to this repo from your email or github.com/notifications. Until
  you do, your issues can't be assigned to you.
- **Never commit API keys.** This repo is public: keys go in `.env` (ignored), and are
  shared with the team outside GitHub.

## Quick start for teammates

1. `gh repo clone <this repo>`
2. Open your AI tool (Claude Code, Codex, Cursor, Copilot…) in the folder.
3. Tell it: *"Read AGENTS.md, then pick up my issue."*

What we're building and who owns which part: [IDEA.md](IDEA.md). Deadlines, rules and
the team: [HACKATHON.md](HACKATHON.md).

## How this workflow works

![How it works](docs/how-it-works.png)

1. The lead plans the project on their PC and splits it into tasks.
2. Each task appears here as a GitHub Issue, assigned to you or labelled `pool`.
3. Your AI agent follows [AGENTS.md](AGENTS.md): plan first, one branch per issue, stay in
   your files, and raise a change-request for anything bigger.

## Architecture

<!-- the lead adds the C4 diagrams here -->
