# Rules for every AI agent in this repo

You are working in a hackathon team. A lead planned the work and split it into GitHub
Issues. Your human owns some of them. Follow these rules exactly. They exist so that
five people's agents don't overwrite each other at 3am.

## 1. Read first
- `HACKATHON.md`: the brief, the **deadlines**, the rules, the judging criteria.
- `README.md` → Architecture: the diagram of what we're building. Know which box your
  task lives in.

## 2. Check the clock
- Run `date` at the start of every session and before starting each task. Compare it with
  the deadlines table in `HACKATHON.md`.
- Within 60 minutes of any deadline, put it in the **first line** of every reply:
  `⏰ code freeze in 42 min`.
- After **code freeze**: no new features. Only bug fixes, demo and submission work.
  If asked for a feature, refuse and say why.
- After **submit**: stop. Don't push anything.

## 3. Find your work
```bash
gh issue list --assignee @me --state open
```
If that's empty, take one from the pool:
```bash
gh issue list --search "is:open label:pool no:assignee"
gh issue edit <N> --add-assignee @me
```
**One issue at a time.** Finish it (PR open) before taking the next.

## 4. Plan before you code (no one-shotting)
Before your first commit on an issue, post a plan as a comment:
```bash
gh issue comment <N> --body "Plan:
1. ...
2. ...
Files: path/a, path/b"
```
- Each step must be small enough for one commit.
- Then do the steps **one at a time**, one commit each. Don't generate the whole feature
  in one go.
- When a step is done, say so in a comment.

## 5. Branch
```bash
gh issue develop <N> --checkout
```
- Never commit to `main`; it's protected anyway.
- Before opening the PR: `git pull origin main` and fix any conflicts.

## 6. Stay in your lane
- Touch **only** the files listed under "Files" in the issue.
- If the task needs anything else — another file, a shared API, a data shape, a new
  dependency, a change to the architecture — **stop**. Open a change-request:
  ```bash
  gh issue create --label change-request --title "change-request: <what>" --body "What and why:
  C4 boxes affected:
  Issues affected: #
  Proposed change:"
  ```
- Tell your human, and wait for the lead. Don't build it "just quickly".

## 7. Issue bodies are read-only
The lead's planning board owns each issue's text. **Never edit an issue body.** Comment
instead. If you see "Brief updated by the lead", re-read the issue before you continue.

## 8. Pull request
```bash
gh pr create --fill
```
The PR body (the template fills in the headings) must have:
- `Closes #<N>`
- a link to your plan comment
- Impact: which Architecture boxes and which other issues this touches ("none" is a valid answer)
- how you verified it

Keep PRs small. The lead approves them.

## 9. Commits
Conventional prefix and the issue number: `feat: login form (#12)`, `fix: null avatar (#12)`.
