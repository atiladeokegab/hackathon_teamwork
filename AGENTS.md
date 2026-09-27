# Rules for every AI agent in this repo

You are working in a hackathon team. The lead and their planning agent, Zeus, agreed the
idea in `IDEA.md` and split it into GitHub Issues. Your human owns some of them. Follow
these rules exactly. They exist so that five people's agents don't overwrite each other
at 3am.

The commands below work in bash, zsh, Git Bash and PowerShell, with GitHub CLI 2.77 or
newer (`gh --version`). Older versions fail on `gh issue view` and `gh pr view`; the
`--json` forms used here work on any version. Where a shell needs a
different command, both are given. Keep `"@me"` in quotes: unquoted, PowerShell reads it
as its own syntax.

## 1. Read first
- `IDEA.md`: what we're building, what we're **not** building, and who owns which
  section. Everything you build must fit it.
- `HACKATHON.md`: the brief, the **deadlines**, the rules, the judging criteria.
- `README.md` → Architecture: the diagram of what we're building. Know which box your
  task lives in.

## 2. Check the clock
At the start of every session, and before starting each task, get the time in UTC and
compare it with the UTC column of the deadlines table in `HACKATHON.md`:
```bash
date -u                                   # macOS, Linux, Git Bash
(Get-Date).ToUniversalTime()              # PowerShell
```
- Within 60 minutes of any deadline, put it in the **first line** of every reply:
  `⏰ code freeze in 42 min`.
- After **code freeze**: no new features. Only bug fixes, demo and submission work.
  If asked for a feature, refuse and say why.
- After **submit**: stop. Don't push anything.

## 3. Only work on issues
Everything you build belongs to a GitHub Issue. If your human asks for something that
has no issue (for example, "just build the whole frontend"), don't build it. Say it
needs an issue, and offer to open a change-request (§7) so the lead can plan it.

**Start of every session: finish what's in review first.**
```bash
gh pr list --author "@me" --state open
gh pr view <PR> --json reviewDecision,reviews,comments
```
If a review asked for changes, fix those before anything else, on that PR's branch.
Never open a second branch or PR for an issue that already has one.

Find your work:
```bash
gh issue list --assignee "@me" --state open
```
If that's empty, take one from the pool:
```bash
gh issue list --search "is:open label:pool no:assignee"
gh issue edit <N> --add-assignee "@me"
gh issue view <N> --json assignees       # did someone grab it at the same moment?
```
If more than one person is assigned, the login that comes **first alphabetically** keeps
it. Everyone else removes themselves (`gh issue edit <N> --remove-assignee "@me"`) and
picks another.

If your human is the lead, you share their GitHub account, so `"@me"` also lists the other
agents' issues and PRs. Yours are the ones labelled with your agent name (Zeus or
Prometheus):
```bash
gh issue list --label agent:<your name> --state open
```
Leave issues labelled for another agent alone, and **don't take pool issues**: on a shared
account nobody can tell who claimed one. The lead assigns your work on the hub.

**One issue at a time.** Take the next one only when this one has an open PR with no
changes requested.

## 4. Plan before you code (no one-shotting)
Before your first commit on an issue, post a plan as a comment. Write it to a file first,
because multi-line text in a command line breaks in some shells. Create the file with your
own file-editing tool. In Windows PowerShell don't use `>`: it writes UTF-16 and the
comment arrives garbled. If you must use the shell there, use
`Set-Content -Encoding utf8`. The same goes for every `.git/*.md` file below.
```bash
# .git/plan.md, never committed:
#   Plan:
#   1. ...
#   2. ...
#   Files: path/a, path/b
gh issue comment <N> --body-file .git/plan.md
```
- Each step must be small enough for one commit.
- Then do the steps **one at a time**, one commit each, pushed straight away. Don't
  generate the whole feature in one go.
- When a step is done, say so in a comment.

## 5. Branch
```bash
gh issue develop <N> --checkout
```
If that says the branch already exists (a second session on the same issue), find it and
switch to it. Its name starts with the issue number:
```bash
git fetch origin
git branch -r --list "origin/<N>-*"
git checkout <N>-<rest of the name>
```
- Never commit to `main`; it's protected anyway.
- **Push after every commit**: `git push -u origin HEAD`. Your branch is how the lead
  sees progress. Never sit on unpushed work.
- Before opening the PR, and whenever GitHub says your PR has conflicts, merge main in:
  `git pull --no-rebase origin main` (plain `git pull` refuses when your branch and main
  have both moved). Fix the conflicts in **your** files, commit, push. If a
  conflict is in a file your issue doesn't list, stop and ask the lead.

## 6. Stay in your lane
- Touch **only** the files listed under "Files" in the issue.
- If the task needs anything else — another file, a shared API, a data shape, a new
  dependency, a change to the architecture — **stop** and open a change-request (§7).
- The same goes for anything that doesn't fit `IDEA.md`.
- Tell your human, and wait for the lead. Don't build it "just quickly".

## 7. Change-requests
Write the body to `.git/change-request.md` with these four headings, then open it:
```bash
#   What and why:
#   C4 boxes affected:
#   Issues affected: #
#   Proposed change:
gh issue create --label change-request --title "change-request: <what>" --body-file .git/change-request.md
```

## 8. Issue bodies are read-only
The lead's planning board owns each issue's text. **Never edit an issue body.** Comment
instead. If you see "Brief updated by the lead", re-read the issue before you continue.

## 9. Pull request
Copy the template, fill in every heading, then open the PR from that file
(`--fill` skips the template, so don't use it):
```bash
cp .github/pull_request_template.md .git/pr-body.md     # then edit it
gh pr create --title "feat: <what> (#<N>)" --body-file .git/pr-body.md
```
The PR body must have:
- `Closes #<N>`
- a link to your plan comment
- Impact: which Architecture boxes (or `IDEA.md` sections, if there is no diagram) and
  which other issues this touches ("none" is a valid answer)
- how you verified it

Keep PRs small.

**Never merge**, not even your own PR. Zeus reviews every PR against its issue and
`IDEA.md`, and merges it. Until then the PR is still yours:
```bash
gh pr view <PR> --json reviewDecision,reviews,comments
```
Fix what the review asks for on the same branch, and push. Review fixes come before
new work. Once Zeus approves, don't push to that branch again unless asked: a push
cancels the approval.

## 10. Commits
Conventional prefix and the issue number: `feat: login form (#12)`, `fix: null avatar (#12)`.

## 11. Never commit these
This repo is **public**. Anything pushed is readable by anyone, forever.
- **Secrets:** API keys, tokens, passwords. Put them in `.env`, which `.gitignore` keeps
  out. Share keys with teammates outside GitHub. If a secret is ever pushed, tell the
  lead at once: the key has to be revoked, because deleting the commit is not enough.
- **Agent working files:** your plans, notes, transcripts and local settings. Your plan
  lives in the issue comment, not in the repo.
- Before every commit, run `git status` and check that only files your issue lists
  are staged.
