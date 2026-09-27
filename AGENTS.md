# Rules for every AI agent in this repo

You are working in a hackathon team. The lead and their planning agent, Zeus, agreed the
idea in `IDEA.md` and split it into GitHub Issues. Your human owns some of them. Follow these rules exactly. They exist so that
five people's agents don't overwrite each other at 3am.

## 1. Read first
- `IDEA.md`: what we're building, what we're **not** building, and who owns which
  section. Everything you build must fit it.
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
If your human is the lead, you share their GitHub account, so `@me` also lists the other
agents' issues. Yours are the ones labelled with your name:
```bash
gh issue list --label agent:<your name> --state open
```
Leave issues labelled for another agent alone.

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
- Then do the steps **one at a time**, one commit each, pushed straight away. Don't
  generate the whole feature in one go.
- When a step is done, say so in a comment.

## 5. Branch
```bash
gh issue develop <N> --checkout
```
- Never commit to `main`; it's protected anyway.
- **Push after every commit**: `git push -u origin HEAD`. Your branch is how the lead
  sees progress. Never sit on unpushed work.
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
- The same goes for anything that doesn't fit `IDEA.md`.
- Tell your human, and wait for the lead. Don't build it "just quickly".

## 7. Issue bodies are read-only
The lead's planning board owns each issue's text. **Never edit an issue body.** Comment
instead. If you see "Brief updated by the lead", re-read the issue before you continue.

## 8. Pull request
Copy the template, fill in every heading, then open the PR from that file
(`--fill` skips the template, so don't use it):
```bash
cp .github/pull_request_template.md /tmp/pr-body.md   # edit it
gh pr create --title "feat: <what> (#<N>)" --body-file /tmp/pr-body.md
```
The PR body must have:
- `Closes #<N>`
- a link to your plan comment
- Impact: which Architecture boxes and which other issues this touches ("none" is a valid answer)
- how you verified it

Keep PRs small.

**Never merge**, not even your own PR. Zeus reviews every PR against its issue and
`IDEA.md`, and merges it. Until then the PR is still yours:
```bash
gh pr view <PR> --comments
```
Fix what the review asks for on the same branch, and push. Review fixes come before
new work.

## 9. Commits
Conventional prefix and the issue number: `feat: login form (#12)`, `fix: null avatar (#12)`.
