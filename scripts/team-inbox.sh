#!/usr/bin/env bash
set -u
shopt -s nocasematch

since=1970-01-01T00:00:00Z
agent=
all=0
lead=0
while (($#)); do
    case $1 in
        --all) all=1; shift ;;
        --lead) lead=1; shift ;;
        --agent) agent=${2:?--agent needs a name}; shift 2 ;;
        *) printf 'inbox: unknown option: %s\n' "$1" >&2; exit 1 ;;
    esac
done

remote=$(git remote get-url origin 2>&1) || { printf 'inbox: %s\n' "$remote" >&2; exit 1; }
case $remote in
    *github.com/*) repo=${remote#*github.com/} ;;
    *github.com:*) repo=${remote#*github.com:} ;;
    *) printf 'inbox: origin is not a GitHub repository\n' >&2; exit 1 ;;
esac
repo=${repo%.git}
state=$(git rev-parse --git-path team-inbox.last)
if (( ! all )) && [[ -f $state ]]; then read -r since <"$state"; fi
started=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

call() {
    local result
    result=$(gh "$@" 2>&1) || {
        printf 'inbox: %s\n' "${result%%$'\n'*}" >&2
        return 1
    }
    printf '%s' "$result"
}
has_agent() {
    [[ -z $agent || ,$1, == *",agent:$agent,"* ]]
}
emit() { out+="$1"$'\n'; }
comments() {
    call issue view "$1" -R "$repo" --json comments --jq '.comments[]? | [.createdAt // "", .author.login // "", ((.body // "") | split("\n")[0])] | @tsv'
}
issue_rows() {
    call issue list -R "$repo" --state open --limit 1000 "$@" --json number,title,createdAt,updatedAt,labels,author --jq '.[] | [.number, .title, .createdAt, .updatedAt, ([.labels[].name] | join(",")), .author.login] | @tsv'
}

out=
if [[ -f HACKATHON.md ]]; then
    now=$(date -u +%s)
    while IFS='|' read -r _ kind _ utc _; do
        [[ $kind == *'code freeze'* || $kind == *'submit'* ]] || continue
        utc=${utc//[[:space:]]/}
        epoch=$(date -u -d "$utc" +%s 2>/dev/null) || epoch=$(date -j -u -f '%Y-%m-%dT%H:%MZ' "$utc" +%s 2>/dev/null) || continue
        remaining=$((epoch - now))
        if ((remaining > 0 && remaining <= 3600)); then
            kind=${kind#"${kind%%[![:space:]]*}"}
            kind=${kind%"${kind##*[![:space:]]}"}
            emit "⏰ $kind in $(((remaining + 59) / 60)) min"
            break
        fi
    done <HACKATHON.md
fi

me=$(call api user --jq .login) || exit 1
prs=$(call pr list -R "$repo" --author '@me' --state open --limit 1000 --json number,updatedAt,labels --jq '.[] | [.number, .updatedAt, ([.labels[].name] | join(","))] | @tsv') || exit 1
while IFS=$'\t' read -r n updated labels; do
    [[ -n $n ]] || continue
    has_agent "$labels" || continue
    reviews=$(call pr view "$n" -R "$repo" --json reviews --jq '.reviews[]? | [.submittedAt // "", .author.login // "", .state // "", ((.body // "") | split("\n")[0])] | @tsv') || exit 1
    newest_time= newest_author= newest_state= newest_body=
    while IFS=$'\t' read -r at author review_state body; do
        [[ -n $at ]] || continue
        if [[ -z $newest_time || $at > $newest_time ]]; then
            newest_time=$at newest_author=$author newest_state=$review_state newest_body=$body
        fi
    done <<<"$reviews"
    if [[ $newest_state == CHANGES_REQUESTED && ( $newest_author != "$me" || -n $agent ) ]]; then
        emit "REVIEW  #$n changes requested by $newest_author: \"$newest_body\""
    elif [[ $newest_time > $since && -n $newest_author && ( $newest_author != "$me" || -n $agent ) ]]; then
        emit "REVIEW  #$n new review by $newest_author: \"$newest_body\""
    fi
    notes=$(call pr view "$n" -R "$repo" --json comments --jq '.comments[]? | [.createdAt // "", .author.login // "", ((.body // "") | split("\n")[0])] | @tsv') || exit 1
    while IFS=$'\t' read -r at author body; do
        [[ -n $at && $at > $since && -n $author ]] || continue
        [[ $author != "$me" || -n $agent ]] || continue
        emit "REVIEW  #$n new comment by $author: \"$body\""
    done <<<"$notes"
done <<<"$prs"

assigned=$(issue_rows --label question --assignee '@me') || exit 1
mentioned=$(issue_rows --label question --mention '@me') || exit 1
seen=' '
while IFS=$'\t' read -r n title created updated labels author; do
    [[ -n $n ]] || continue
    has_agent "$labels" || continue
    [[ $seen != *" $n "* ]] || continue
    seen+="$n "
    notes=$(comments "$n") || exit 1
    answered=0
    while IFS=$'\t' read -r at writer body; do
        [[ $writer == "$me" ]] && answered=1
    done <<<"$notes"
    ((answered)) || emit "QUESTION #$n for you from $author: \"$title\""
done <<<"$assigned"$'\n'"$mentioned"

authored=$(issue_rows --label question --author '@me') || exit 1
while IFS=$'\t' read -r n title created updated labels author; do
    [[ -n $n ]] || continue
    has_agent "$labels" || continue
    notes=$(comments "$n") || exit 1
    while IFS=$'\t' read -r at writer body; do
        [[ -n $at && $at > $since && -n $writer && $writer != "$me" ]] || continue
        [[ $body == *'this is waiting on you'* ]] && continue
        emit "ANSWER  #$n answered by $writer: \"$body\""
    done <<<"$notes"
done <<<"$authored"

owned=$(issue_rows --assignee '@me') || exit 1
while IFS=$'\t' read -r n title created updated labels author; do
    [[ -n $n ]] || continue
    has_agent "$labels" || continue
    if [[ $updated > $since ]]; then
        notes=$(comments "$n") || exit 1
        while IFS=$'\t' read -r at writer body; do
            [[ -n $at && $at > $since && $body == 'Brief updated by the lead'* ]] || continue
            emit "BRIEF   #$n Brief updated by the lead — re-read it"
        done <<<"$notes"
        if [[ ,$labels, == *,vertical,* ]]; then
            while IFS=$'\t' read -r at writer body; do
                [[ -n $at && $at > $since && -n $writer && $writer != "$me" ]] || continue
                [[ $body == 'Brief updated by the lead'* ]] && continue
                emit "GRILL   #$n question from $writer: \"$body\""
            done <<<"$notes"
        fi
        if [[ ,$labels, == *,task,* && ,$labels, != *,draft,* ]]; then
            removed=$(call api "repos/$repo/issues/$n/timeline" --paginate --jq '.[] | select(.event == "unlabeled" and .label.name == "draft") | .created_at') || exit 1
            while read -r at; do
                [[ -n $at && $at > $since ]] || continue
                emit "READY   #$n draft removed: build it"
                break
            done <<<"$removed"
        fi
    fi
    if [[ $created > $since && ,$labels, == *,task,* ]]; then
        emit "NEW     #$n assigned to you: \"$title\""
    fi
done <<<"$owned"

if ((lead)); then
    verticals=$(issue_rows --label vertical) || exit 1
    while IFS=$'\t' read -r v _; do
        [[ -n $v ]] || continue
        subs=$(call api "repos/$repo/issues/$v/sub_issues" --paginate --jq '.[] | select(.state == "open") | [.number, .title, .created_at, ([.labels[].name] | join(",")), .user.login] | @tsv') || exit 1
        while IFS=$'\t' read -r n title created labels author; do
            [[ -n $n && $created > $since && ,$labels, == *,draft,* ]] || continue
            emit "DRAFT   #$n in #$v by $author: \"$title\""
        done <<<"$subs"
    done <<<"$verticals"
fi

printf '%s' "$out"
printf '%s\n' "$started" >"$state"
