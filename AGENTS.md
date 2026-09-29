# Rules for every AI agent in this repo

You are working in a hackathon team. The lead agreed the idea in `IDEA.md` with the team and
split it into GitHub Issues. The lead reviews and merges every PR, often through their own
agents; below, "the lead" means either. Your human owns some of them. Follow
these rules exactly. They exist so that five people's agents don't overwrite each other
at 3am.

The commands below work in bash, zsh, Git Bash and PowerShell, with GitHub CLI 2.63 or
newer (`gh --version`). Use `gh issue view` and `gh pr view` only with `--json` as shown:
without it, gh older than 2.77 fails on this repo. Where a shell needs a different
command, both are given. Keep `"@me"` in quotes: unquoted, PowerShell reads it as its own
syntax.

## 1. Read first
- `IDEA.md`: what we're building, what we're **not** building, and who owns which
  area. Everything you build must fit it.
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
  If asked for a feature, refuse and say why. GitHub enforces this: after the freeze, the
  `freeze-gate` check fails on any PR to `integration` that the lead hasn't labelled `fix`.
- After **submit**: stop. Don't push anything.

## 3. Only work on issues
Everything you build belongs to a GitHub Issue. If your human asks for something that
has no issue (for example, "just build the whole frontend"), don't build it. Say it
needs an issue, and offer to open a change-request (§7) so the lead can plan it.

**Start of every session: ask the inbox, then finish what's in review first.**
```bash
scripts/team-inbox.sh --all          # PowerShell: scripts/team-inbox.ps1 -All
```
It prints one line per thing waiting for you (REVIEW, QUESTION, ANSWER, BRIEF, NEW) and nothing
else. On the lead's shared account add `--agent <your name>`. For a REVIEW line, read the PR:
```bash
gh pr view <PR> --json reviewDecision,reviews,comments
```
Read the reviews' text, not only `reviewDecision`: the lead's review on a PR from the lead's
own account can only be a comment. If a review asked for changes, fix those before
anything else, on that PR's branch. Never open a second branch or PR for an issue that
already has one, unless the lead reverted it (§10).

Then questions (§8): answer any asked of you, and read the answers to yours.
```bash
gh issue list --label question --mention "@me" --state open --limit 100
gh issue list --label question --author "@me" --state open --limit 100 --json number,title,comments
```
On the lead's shared account, add `--label agent:<your name>` to the second command.
On the lead's account only the agent that reviews for the lead runs the first: questions for
the lead reach the lead through it. The first finds questions that @mention you, assigned or not.

Find your work. Tasks are owned by **humans**; an agent works on its human's tasks:
```bash
gh issue list --assignee "@me" --state open --label task          # your human's tasks
gh issue list --label agent:<your name> --label task --state open  # delegated to you by name
```
Your human may hand one of their tasks to you by name: the issue then carries the label
`agent:<your name>`. To say which agent works on your own issue, add that label yourself.
An issue that says `Depends on: #N` is ready when #N is closed: take ready ones first. If
all of yours are waiting, start one anyway against the contract its brief describes, and
list that under Assumptions in your PR.
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
agents' issues and PRs. Yours are the ones labelled with your agent name. Leave issues labelled for another agent alone, and their PRs too: before
touching a PR from `"@me"`, check that the issue it closes carries your label. **Don't take
pool issues** on a shared account: nobody can tell which agent claimed one. Your human claims
it and hands it to you. An agent with its **own** GitHub account may claim a pool issue on
behalf of its human; the lead's board then records the human as owner and you as the agent.

**Follow the design.** If your vertical's brief has a `Design:` line, those sections of
`docs/design.md` are binding: the flow, the screens or commands, the states and the exact words.
Never edit `docs/design.md` unless your human is the designer. If the design looks wrong or
missing for your task, open a change-request (§7) addressed to the designer and keep building on
the design as written meanwhile.

**Plan your vertical first.** Your human owns a **vertical**: one issue labelled `vertical`,
assigned to them, saying which files they own (`Files:`), what they must deliver (`Acceptance:`)
and the shared contract (`Contract:`). Before any code:
1. Read the vertical issue, `IDEA.md` and the contract.
2. Draft 2–6 tasks that together deliver the vertical's Acceptance. Each uses the task headings
   (Context, Files, Approach, Acceptance, Verify, Deadline), keeps `Files:` inside the vertical's
   `Files:`, and says `Depends on: #N` where it must wait for another task.
3. Show the drafts to your human and change them until they agree.
4. Open each as a sub-issue of the vertical, labelled `draft`:
   ```bash
   gh issue create --label task --label draft --assignee "@me" --title "<what>" --body-file .git/task.md
   # link it under the vertical; sub_issue_id is the issue's id, not its number
   gh api -X POST "repos/{owner}/{repo}/issues/<vertical N>/sub_issues" -F sub_issue_id="$(gh api "repos/{owner}/{repo}/issues/<new N>" --jq .id)"
   ```
5. The lead reviews your breakdown and may ask up to 3 questions on the vertical issue (GRILL
   lines in your inbox): answer them there. When the lead removes `draft` from a task, your inbox
   shows READY: only then start it. A task you see needs changing later: edit its body yourself
   (§9), never its `Files:`.

**Keep checking; your human shouldn't have to prod you.** Run `scripts/team-inbox.sh` (without
`--all`: it shows only what's new) after every push, before you start each new step, and every
5 minutes when you have nothing to do. Act on each line; a REVIEW comes before everything else.
With nothing to do, keep checking every 5 minutes until submit, and take pool work (below) if
there is any. After code freeze, only fixes; after submit, stop and tell your human. Nobody on
the team will ask your human to pass messages to you: everything you need arrives on GitHub.

**One issue at a time.** Take the next one when this one has an open PR and every change
a review asked for is pushed. Before you take it, run the questions checks (§8) again.

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
- Each step that changes files must be small enough for one commit. Checking your work
  and opening the PR are steps too; they need no commit.
- Then do the steps **one at a time**, one commit each, pushed straight away. Don't
  generate the whole feature in one go.
- Your pushed commits show your progress; don't comment per step. Comment on the issue only
  when something changes: you're blocked, an assumption changed, or you're answering a review.

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
- Your branch starts from `integration`, the repo's default branch (`gh issue develop` does
  this for you). Never commit to `integration` or `main`; both are protected.
- **Push after every commit**: `git push -u origin HEAD`. Your branch is how the lead
  sees progress. Never sit on unpushed work.
- Before opening the PR, and whenever GitHub says your PR has conflicts, merge integration in:
  `git pull --no-rebase origin integration` (plain `git pull` refuses when your branch and
  integration have both moved). Fix the conflicts in **your area**, commit, push. If a
  conflict is outside your area, stop and ask the lead.
- `main` is the last version that passed the smoke check. You never touch it; the lead moves it.

## 6. Stay in your area
- Your **area** is the directories `IDEA.md` lists against your name under "Areas and owners".
  Inside it, change whatever your task needs: new files, refactors, tests.
- Found more work inside your area? Open an issue for it yourself, with the same headings as
  the lead's (Context, Files, Approach, Acceptance, Verify, Deadline), label `task`, assigned
  to you: `gh issue create --label task --assignee "@me" --title "<what>" --body-file .git/issue.md`.
- A **pool issue** you've taken is outside every area: while it's yours, you may edit
  exactly the files its `Files:` line lists, and nothing else, until its PR merges.
- Anything outside your area — another person's area, the core, a dependency
  (`pyproject.toml`, `package.json`, …), or anything that doesn't fit `IDEA.md` — **stop** and
  open a change-request (§7). Tell your human, and wait for the lead. Don't build it "just quickly".

## 7. Change-requests
Only for work outside your area, the core, dependencies or `IDEA.md` (§6).

Write the body to `.git/change-request.md` with these four headings, then open it:
```bash
#   What and why:
#   C4 boxes affected:
#   Issues affected: #
#   Proposed change:
gh issue create --label change-request --title "change-request: <what>" --body-file .git/change-request.md
```

## 8. Questions
A question you can't answer from your own area, `IDEA.md` or the issue: ask the person who
owns that area (`IDEA.md`, "Areas and owners"). Design, data, voice: whoever owns it, even
with no code. Use their handle without the `@`:
```bash
gh issue create --label question --assignee <handle> --title "question: <one line>" --body-file .git/question.md
```
The body: `@<handle>`, the question, which issue it's for, and your guess: "I'll use X unless
you say otherwise." If it fails with `not found` (they haven't accepted the invite yet), run it
again without `--assignee`: the @mention still notifies them. On the lead's shared account,
add `--label agent:<your name>`.

**Don't wait.** Build on your guess, and list it under Assumptions in your PR.

**A question asked of you** (a QUESTION line): skip any that already carries your answer
(it's waiting for the asker). **Answer it yourself** when the answer is already settled by the
issue's brief, `IDEA.md`, the shared contract, or an earlier decision your human made that still
holds: quote the line, or link that earlier answer ("Answered from #2's brief: 'TOTAL beats
Subtotal'"), and tell your human in one line what you answered. Anything that needs a real
choice goes to your human as a draft answer from your area; they edit or approve it. Either way,
post it as a comment and leave the issue open for the asker (your human can overrule by commenting):
```bash
gh issue comment <N> --body-file .git/answer.md
```
If the answer means new work in your area, open a `task` issue for it (§6).

**Answers to your questions** (the session-start check lists your open ones with their
comments). A comment that only says "this is waiting on you" is the lead's reminder to the owner,
not an answer. Apply each answer, then close that question with `gh issue close <N>`. If the answer
differs from your guess, fix it first:
- your PR is still open: on the same branch (an approved PR: comment first, because a push
  cancels the approval);
- your PR is merged: open a `task` issue for the fix (§6).

A question never asks someone to change their code. That is a change-request (§7).

## 9. Editing an issue body
Edit **only your own tasks' bodies** (issues assigned to you or your human), and only to make
the brief better serve the goal in `IDEA.md`. **Never change the `Files:` line**: taking more
files is a change-request (§7). After an edit, comment one line saying what you changed and
why. The lead's board takes an owner's edit in by itself; anyone else's edit waits for the
lead. If you see "Brief updated by the lead", re-read the issue before you continue.

## 10. Pull request
First re-read the issue: if it has a "Brief updated by the lead" comment newer than your plan,
check your work against the new brief before opening the PR.
Copy the template, fill in every heading, then open the PR from that file
(`--fill` skips the template, so don't use it):
```bash
cp .github/pull_request_template.md .git/pr-body.md     # then edit it
gh pr create --title "feat: <what> (#<N>)" --base integration --body-file .git/pr-body.md
```
The PR body must have:
- `Closes #<N>`
- a link to your plan comment, with its checkbox ticked (`- [x]`)
- Impact: which Architecture boxes and which other issues this touches ("none" is a
  valid answer)
- how you verified it
- Assumptions: open questions and the guess used ("none" is valid)

Keep PRs small.

PRs go to `integration`, the default base, so there is nothing to type. After the lead merges,
it runs the smoke check. If your merge turns it red, the lead reverts it, reopens your issue and comments the failing
output there: fix it on the same branch, push, and open a new PR (`gh pr create` again).

**Never merge**, not even your own PR. The lead reviews every PR against its issue and
`IDEA.md`, and merges it. Until then the PR is still yours:
```bash
gh pr view <PR> --json reviewDecision,reviews,comments
```
Fix what the review asks for on the same branch, and push. A review fix needs no new
plan: comment on the PR with what you changed. Review fixes come before new work. Once the lead approves, don't push to that branch again unless asked: a push
cancels the approval.

## 11. Commits
Conventional prefix and the issue number: `feat: login form (#12)`, `fix: null avatar (#12)`.

## 12. Never commit these
This repo is **public**. Anything pushed is readable by anyone, forever.
- **Secrets:** API keys, tokens, passwords. Put them in `.env`, which `.gitignore` keeps
  out. Share keys with teammates outside GitHub. If a secret is ever pushed, tell the
  lead at once: the key has to be revoked, because deleting the commit is not enough.
- **Agent working files:** your plans, notes, transcripts and local settings. Your plan
  lives in the issue comment, not in the repo.
- Before every commit, run `git status` and check that only files in your area
  are staged, and that `git config user.email` is your own address: commits are
  credited to whoever that email belongs to.
