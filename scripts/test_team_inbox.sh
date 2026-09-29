#!/usr/bin/env bash
set -u

script=$(cd "$(dirname "$0")" && pwd)/team-inbox.sh
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/repo" "$tmp/data"
git -C "$tmp/repo" init -q
git -C "$tmp/repo" remote add origin https://github.com/o/hk.git
export GH_FIXTURES="$tmp/data" PATH="$tmp/bin:$PATH"

cat >"$tmp/bin/gh" <<'PY'
#!/usr/bin/env python3
import json, os, pathlib, sys

a = sys.argv[1:]
d = pathlib.Path(os.environ['GH_FIXTURES'])
if (d / 'fail').exists() and (d / 'fail').read_text().strip() in ('', ' '.join(a[:2])):
    print('GitHub unavailable', file=sys.stderr)
    sys.exit(1)
if '--jq' not in a:
    print('missing --jq', file=sys.stderr)
    sys.exit(2)

def read(name):
    p = d / name
    return json.loads(p.read_text()) if p.exists() else []

def first(body):
    return (body or '').splitlines()[0] if body else ''

def row(*items):
    print('\t'.join(str(x if x is not None else '') for x in items))

if a[:2] == ['api', 'user']:
    print('me')
elif a[:2] == ['pr', 'list']:
    for p in read('prs.json'):
        row(p['number'], p.get('updatedAt', ''), ','.join(p.get('labels', [])))
elif a[:2] == ['pr', 'view']:
    p = read(f'pr-{a[2]}.json')
    if 'reviews' in a[a.index('--jq') + 1]:
        for x in p.get('reviews', []):
            row(x.get('submittedAt', ''), x.get('author', ''), x.get('state', ''), first(x.get('body')))
    else:
        for x in p.get('comments', []):
            row(x.get('createdAt', ''), x.get('author', ''), first(x.get('body')))
elif a[:2] == ['issue', 'list']:
    for i in read('issues.json'):
        if '--label' in a and a[a.index('--label') + 1] not in i.get('labels', []):
            continue
        if '--assignee' in a and 'me' not in i.get('assignees', []):
            continue
        if '--author' in a and i.get('author') != 'me':
            continue
        if '--mention' in a and '@me' not in i.get('body', ''):
            continue
        row(i['number'], i.get('title', ''), i.get('createdAt', ''),
            i.get('updatedAt', ''), ','.join(i.get('labels', [])), i.get('author', ''))
elif a[0] == 'api' and a[1].endswith('/sub_issues'):
    for r in read(f"sub-{a[1].split('/')[-2]}.json"):
        row(*r)
elif a[0] == 'api' and a[1].endswith('/timeline'):
    for r in read(f"timeline-{a[1].split('/')[-2]}.json"):
        print(r)
elif a[:2] == ['issue', 'view']:
    for x in (read(f'issue-{a[2]}.json') or {}).get('comments', []):
        row(x.get('createdAt', ''), x.get('author', ''), first(x.get('body')))
else:
    print('unexpected gh call: ' + ' '.join(a), file=sys.stderr)
    sys.exit(2)
PY
chmod +x "$tmp/bin/gh"

reset_case() {
    printf '[]' >"$tmp/data/prs.json"
    printf '[]' >"$tmp/data/issues.json"
    rm -f "$tmp/data"/pr-*.json "$tmp/data"/issue-*.json "$tmp/data"/sub-*.json "$tmp/data"/timeline-*.json "$tmp/data/fail" "$tmp/repo/.git/team-inbox.last"
    printf '| code freeze | x | 2099-01-01T00:00Z |\n' >"$tmp/repo/HACKATHON.md"
}
run_inbox() {
    (cd "$tmp/repo" && bash "$script" "$@") >"$tmp/out" 2>"$tmp/err"
    status=$?
}
check() {
    local name=$1 expected=$2 expected_status=${3:-0}
    if [[ $status != "$expected_status" || $(cat "$tmp/out") != "$expected" || ($expected_status == 0 && -s "$tmp/err") ]]; then
        printf 'FAIL %s (status %s)\nstdout: %s\nstderr: %s\n' "$name" "$status" "$(cat "$tmp/out")" "$(cat "$tmp/err")"
        failed=$((failed + 1))
    else
        printf 'ok %s\n' "$name"
    fi
}
failed=0

reset_case
run_inbox
check quiet ''

reset_case
cat >"$tmp/data/prs.json" <<'JSON'
[{"number":14,"updatedAt":"2026-09-29T12:05:00Z","labels":[]}]
JSON
cat >"$tmp/data/pr-14.json" <<'JSON'
{"reviews":[{"submittedAt":"2026-09-29T12:03:00Z","author":"lead","state":"CHANGES_REQUESTED","body":"Fix the line\nMore"}]}
JSON
run_inbox
check changes_requested 'REVIEW  #14 changes requested by lead: "Fix the line"'

cat >"$tmp/data/pr-14.json" <<'JSON'
{"reviews":[{"submittedAt":"2026-09-29T12:03:00Z","author":"lead","state":"COMMENTED","body":"Check edge case"}],"comments":[{"createdAt":"2026-09-29T12:04:00Z","author":"lead","body":"Looks close\nThanks"}]}
JSON
run_inbox --all
check review_and_comment $'REVIEW  #14 new review by lead: "Check edge case"\nREVIEW  #14 new comment by lead: "Looks close"'

reset_case
cat >"$tmp/data/issues.json" <<'JSON'
[{"number":21,"title":"Need color?","createdAt":"2026-09-29T12:01:00Z","updatedAt":"2026-09-29T12:01:00Z","labels":["question"],"assignees":["me"],"author":"alice"}]
JSON
run_inbox
check unanswered 'QUESTION #21 for you from alice: "Need color?"'

cat >"$tmp/data/issue-21.json" <<'JSON'
{"comments":[{"createdAt":"2026-09-29T12:02:00Z","author":"me","body":"Blue"},{"createdAt":"2026-09-29T12:04:00Z","author":"alice","body":"Are you sure?"}]}
JSON
run_inbox --all
check own_answer_and_followup ''

reset_case
cat >"$tmp/data/issues.json" <<'JSON'
[{"number":12,"title":"My question","createdAt":"2026-09-29T12:00:00Z","updatedAt":"2026-09-29T12:05:00Z","labels":["question"],"assignees":[],"author":"me"}]
JSON
cat >"$tmp/data/issue-12.json" <<'JSON'
{"comments":[{"createdAt":"2026-09-29T12:05:00Z","author":"lead","body":"Use blue\nplease"}]}
JSON
run_inbox
check answered 'ANSWER  #12 answered by lead: "Use blue"'

cat >"$tmp/data/issue-12.json" <<'JSON'
{"comments":[{"createdAt":"2026-09-29T12:05:00Z","author":"lead","body":"@alice this is waiting on you"}]}
JSON
run_inbox --all
check mentioned_waiting_comment ''
cat >"$tmp/data/issue-12.json" <<'JSON'
{"comments":[{"createdAt":"2026-09-29T12:05:00Z","author":"lead","body":"this is waiting on you"}]}
JSON
run_inbox --all
check bare_waiting_comment ''

reset_case
cat >"$tmp/data/issues.json" <<'JSON'
[{"number":17,"title":"Task","createdAt":"2026-09-29T11:00:00Z","updatedAt":"2026-09-29T12:05:00Z","labels":["task"],"assignees":["me"],"author":"lead"}]
JSON
cat >"$tmp/data/issue-17.json" <<'JSON'
{"comments":[{"createdAt":"2026-09-29T11:59:00Z","author":"lead","body":"Brief updated by the lead: old"},{"createdAt":"2026-09-29T12:05:00Z","author":"lead","body":"Brief updated by the lead: new"}]}
JSON
printf '2026-09-29T12:00:00Z\n' >"$tmp/repo/.git/team-inbox.last"
run_inbox
check brief_since 'BRIEF   #17 Brief updated by the lead — re-read it'

reset_case
cat >"$tmp/data/issues.json" <<'JSON'
[{"number":23,"title":"New task","createdAt":"2026-09-29T12:04:00Z","updatedAt":"2026-09-29T12:04:00Z","labels":["task"],"assignees":["me"],"author":"lead"}]
JSON
run_inbox
check first_run_open 'NEW     #23 assigned to you: "New task"'
printf '2026-09-29T12:05:00Z\n' >"$tmp/repo/.git/team-inbox.last"
run_inbox
check created_before_since ''
run_inbox --all
check all_ignores_since 'NEW     #23 assigned to you: "New task"'

reset_case
cat >"$tmp/data/issues.json" <<'JSON'
[{"number":23,"title":"Zeus task","createdAt":"2026-09-29T12:04:00Z","updatedAt":"2026-09-29T12:04:00Z","labels":["task","agent:zeus"],"assignees":["me"],"author":"lead"},{"number":24,"title":"Other task","createdAt":"2026-09-29T12:04:00Z","updatedAt":"2026-09-29T12:04:00Z","labels":["task","agent:apollo"],"assignees":["me"],"author":"lead"}]
JSON
run_inbox --agent Zeus
check agent_issues 'NEW     #23 assigned to you: "Zeus task"'

reset_case
cat >"$tmp/data/prs.json" <<'JSON'
[{"number":14,"updatedAt":"2026-09-29T12:05:00Z","labels":["agent:apollo"]}]
JSON
cat >"$tmp/data/pr-14.json" <<'JSON'
{"reviews":[{"submittedAt":"2026-09-29T12:03:00Z","author":"lead","state":"CHANGES_REQUESTED","body":"Fix"}]}
JSON
run_inbox --agent zeus
check agent_prs ''

cat >"$tmp/data/prs.json" <<'JSON'
[{"number":14,"updatedAt":"2026-09-29T12:05:00Z","labels":["agent:zeus"]}]
JSON
cat >"$tmp/data/pr-14.json" <<'JSON'
{"reviews":[{"submittedAt":"2026-09-29T12:03:00Z","author":"me","state":"CHANGES_REQUESTED","body":"Lead comment"}]}
JSON
run_inbox --agent Zeus
check shared_account_review 'REVIEW  #14 changes requested by me: "Lead comment"'

reset_case
if date -u -d '+42 minutes' '+%Y-%m-%dT%H:%MZ' >"$tmp/deadline" 2>/dev/null; then :; else date -u -v+42M '+%Y-%m-%dT%H:%MZ' >"$tmp/deadline"; fi
printf '| code freeze | x | %s |\n' "$(cat "$tmp/deadline")" >"$tmp/repo/HACKATHON.md"
run_inbox
if [[ $status == 0 && $(cat "$tmp/out") == '⏰ code freeze in '* && ! -s "$tmp/err" ]]; then printf 'ok deadline\n'; else printf 'FAIL deadline\n'; failed=$((failed + 1)); fi

cat >"$tmp/bin/date" <<'PY'
#!/usr/bin/env python3
import datetime, subprocess, sys
a = sys.argv[1:]
if '-d' in a:
    sys.exit(1)
if '-j' in a:
    value = a[a.index('-f') + 2]
    stamp = datetime.datetime.strptime(value, '%Y-%m-%dT%H:%MZ').replace(tzinfo=datetime.timezone.utc)
    print(int(stamp.timestamp()))
else:
    sys.exit(subprocess.call(['/usr/bin/date', *a]))
PY
chmod +x "$tmp/bin/date"
rm -f "$tmp/repo/.git/team-inbox.last"
run_inbox
if [[ $status == 0 && $(cat "$tmp/out") == '⏰ code freeze in '* && ! -s "$tmp/err" ]]; then printf 'ok bsd_date\n'; else printf 'FAIL bsd_date\n'; failed=$((failed + 1)); fi
rm "$tmp/bin/date"

reset_case
touch "$tmp/data/fail"
run_inbox
if [[ $status == 1 && ! -s "$tmp/out" && $(cat "$tmp/err") == 'inbox: GitHub unavailable' && ! -e "$tmp/repo/.git/team-inbox.last" ]]; then printf 'ok gh_failure\n'; else printf 'FAIL gh_failure\n'; failed=$((failed + 1)); fi

reset_case
cat >"$tmp/data/issues.json" <<'JSON'
[{"number":17,"title":"Task","createdAt":"2026-09-29T12:00:00Z","updatedAt":"2026-09-29T12:00:00Z","labels":["task"],"assignees":["me"],"author":"lead"}]
JSON
printf 'issue view\n' >"$tmp/data/fail"
run_inbox
if [[ $status == 1 && ! -s "$tmp/out" && $(cat "$tmp/err") == 'inbox: GitHub unavailable' && ! -e "$tmp/repo/.git/team-inbox.last" ]]; then printf 'ok late_gh_failure\n'; else printf 'FAIL late_gh_failure\n'; failed=$((failed + 1)); fi

reset_case
cat >"$tmp/data/issues.json" <<'JSON'
[{"number":30,"title":"Parse: read messy receipts","createdAt":"2026-09-29T11:00:00Z","updatedAt":"2026-09-29T12:06:00Z","labels":["vertical"],"assignees":["me"],"author":"lead"}]
JSON
cat >"$tmp/data/issue-30.json" <<'JSON'
{"comments":[{"createdAt":"2026-09-29T11:59:00Z","author":"lead","body":"old question"},{"createdAt":"2026-09-29T12:06:00Z","author":"me","body":"my answer"},{"createdAt":"2026-09-29T12:07:00Z","author":"lead","body":"Does #31 cover VAT lines?\nThanks"}]}
JSON
printf '2026-09-29T12:00:00Z\n' >"$tmp/repo/.git/team-inbox.last"
run_inbox
check grill_since 'GRILL   #30 question from lead: "Does #31 cover VAT lines?"'

reset_case
cat >"$tmp/data/issues.json" <<'JSON'
[{"number":31,"title":"Parse totals","createdAt":"2026-09-29T11:50:00Z","updatedAt":"2026-09-29T12:08:00Z","labels":["task"],"assignees":["me"],"author":"me"},{"number":32,"title":"Still draft","createdAt":"2026-09-29T11:50:00Z","updatedAt":"2026-09-29T12:08:00Z","labels":["task","draft"],"assignees":["me"],"author":"me"}]
JSON
printf '["2026-09-29T12:08:00Z"]' >"$tmp/data/timeline-31.json"
printf '[]' >"$tmp/data/timeline-32.json"
printf '2026-09-29T12:00:00Z\n' >"$tmp/repo/.git/team-inbox.last"
run_inbox
check ready_after_draft_removed 'READY   #31 draft removed: build it'
printf '2026-09-29T12:09:00Z\n' >"$tmp/repo/.git/team-inbox.last"
run_inbox
check ready_only_once ''

reset_case
cat >"$tmp/data/issues.json" <<'JSON'
[{"number":30,"title":"Parse vertical","createdAt":"2026-09-29T11:00:00Z","updatedAt":"2026-09-29T12:06:00Z","labels":["vertical"],"assignees":["alice"],"author":"lead"}]
JSON
cat >"$tmp/data/sub-30.json" <<'JSON'
[[33,"Parse dates","2026-09-29T12:05:00Z","task,draft","alice"],[34,"Approved one","2026-09-29T12:05:00Z","task","alice"],[35,"Old draft","2026-09-29T11:30:00Z","task,draft","alice"]]
JSON
printf '2026-09-29T12:00:00Z\n' >"$tmp/repo/.git/team-inbox.last"
run_inbox --lead
check lead_drafts 'DRAFT   #33 in #30 by alice: "Parse dates"'
run_inbox
check no_drafts_without_lead ''

if ((failed)); then printf '%d failed\n' "$failed"; exit 1; fi
printf 'all team-inbox tests passed\n'
