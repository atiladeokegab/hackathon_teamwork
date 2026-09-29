param([switch]$All, [switch]$Lead, [string]$Agent)
$ErrorActionPreference = 'Stop'

function Gh([string[]]$Arguments) {
    $result = & gh @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw (($result | Out-String).Trim()) }
    return $result
}
function GhJson([string[]]$Arguments) {
    $raw = Gh $Arguments
    return ($raw | Out-String | ConvertFrom-Json)
}
function FirstLine($Body) {
    if ($null -eq $Body) { $Body = '' }
    return ($Body -split '\r?\n', 2)[0]
}
function HasAgent($Item) {
    return (!$Agent -or (@($Item.labels | ForEach-Object { $_.name }) -contains "agent:$Agent"))
}
function Comments($Number) {
    $item = GhJson @('issue', 'view', "$Number", '-R', $repo, '--json', 'comments')
    return @($item.comments)
}
function Flags($Number) {
    $comments = @(Comments $Number)
    foreach ($comment in $comments) {
        if (!$comment -or !$comment.createdAt -or !$comment.body.StartsWith('FLAG:')) { continue }
        $at = [DateTimeOffset]::Parse($comment.createdAt)
        if ($at -le $since) { continue }
        $answered = @($comments | Where-Object {
            $_.createdAt -and [DateTimeOffset]::Parse($_.createdAt) -gt $at -and
            $_.author.login -eq $me -and !$_.body.StartsWith('FLAG:')
        })
        if (!$answered.Count) {
            $lines.Add("FLAG    #$Number from $($comment.author.login): `"$(FirstLine $comment.body)`"")
        }
    }
}
function Issues([string[]]$Filter) {
    return @(GhJson (@('issue', 'list', '-R', $repo, '--state', 'open', '--limit', '1000') + $Filter + @('--json', 'number,title,createdAt,updatedAt,labels,author')))
}

try {
    $remote = (git remote get-url origin 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { throw $remote }
    if ($remote -notmatch 'github\.com[:/](.+)$') { throw 'origin is not a GitHub repository' }
    $repo = $Matches[1] -replace '\.git$', ''
    $state = (git rev-parse --git-path team-inbox.last).Trim()
    $since = [DateTimeOffset]::MinValue
    if (!$All -and (Test-Path $state)) { $since = [DateTimeOffset]::Parse((Get-Content $state -Raw).Trim()) }
    $started = [DateTimeOffset]::UtcNow
    $lines = [System.Collections.Generic.List[string]]::new()

    if (Test-Path HACKATHON.md) {
        foreach ($line in Get-Content HACKATHON.md) {
            $parts = $line -split '\|'
            if ($parts.Count -lt 4) { continue }
            $kind = $parts[1].Trim()
            if ($kind -notin @('code freeze', 'submit')) { continue }
            $deadline = [DateTimeOffset]::MinValue
            if (![DateTimeOffset]::TryParse($parts[3].Trim(), [ref]$deadline)) { continue }
            $minutes = ($deadline - $started).TotalMinutes
            if ($minutes -gt 0 -and $minutes -le 60) {
                $lines.Add("⏰ $kind in $([math]::Ceiling($minutes)) min")
                break
            }
        }
    }

    $me = (Gh @('api', 'user', '--jq', '.login') | Out-String).Trim()
    $prs = @(GhJson @('pr', 'list', '-R', $repo, '--author', '@me', '--state', 'open', '--limit', '1000', '--json', 'number,updatedAt,labels'))
    foreach ($pr in $prs) {
        if (!$pr -or !(HasAgent $pr)) { continue }
        $detail = GhJson @('pr', 'view', "$($pr.number)", '-R', $repo, '--json', 'reviews,comments')
        $latest = @($detail.reviews | Where-Object { $_.submittedAt } | Sort-Object submittedAt | Select-Object -Last 1)
        if ($latest.Count -and $latest[0].author.login -and ($latest[0].author.login -ne $me -or $Agent)) {
            $review = $latest[0]
            $body = FirstLine $review.body
            if ($review.state -eq 'CHANGES_REQUESTED') {
                $lines.Add("REVIEW  #$($pr.number) changes requested by $($review.author.login): `"$body`"")
            } elseif ([DateTimeOffset]::Parse($review.submittedAt) -gt $since) {
                $lines.Add("REVIEW  #$($pr.number) new review by $($review.author.login): `"$body`"")
            }
        }
        foreach ($comment in @($detail.comments)) {
            if (!$comment -or !$comment.createdAt -or !$comment.author.login) { continue }
            if ([DateTimeOffset]::Parse($comment.createdAt) -le $since) { continue }
            if ($comment.author.login -eq $me -and !$Agent) { continue }
            $body = FirstLine $comment.body
            $lines.Add("REVIEW  #$($pr.number) new comment by $($comment.author.login): `"$body`"")
        }
    }

    $seen = @{}
    $forMe = @(Issues @('--label', 'question', '--assignee', '@me')) + @(Issues @('--label', 'question', '--mention', '@me'))
    foreach ($issue in $forMe) {
        if (!$issue -or !(HasAgent $issue) -or $seen.ContainsKey($issue.number)) { continue }
        $seen[$issue.number] = $true
        $mine = @(Comments $issue.number | Where-Object { $_.author.login -eq $me })
        if (!$mine.Count) { $lines.Add("QUESTION #$($issue.number) for you from $($issue.author.login): `"$($issue.title)`"") }
    }

    foreach ($issue in (Issues @('--label', 'question', '--author', '@me'))) {
        if (!$issue -or !(HasAgent $issue)) { continue }
        foreach ($comment in (Comments $issue.number)) {
            if (!$comment -or !$comment.createdAt -or !$comment.author.login) { continue }
            if ([DateTimeOffset]::Parse($comment.createdAt) -le $since -or $comment.author.login -eq $me) { continue }
            $body = FirstLine $comment.body
            if ($body -like '*this is waiting on you*') { continue }
            $lines.Add("ANSWER  #$($issue.number) answered by $($comment.author.login): `"$body`"")
        }
    }

    foreach ($issue in (Issues @('--assignee', '@me'))) {
        if (!$issue -or !(HasAgent $issue)) { continue }
        if ([DateTimeOffset]::Parse($issue.updatedAt) -gt $since) {
            foreach ($comment in (Comments $issue.number)) {
                if ($comment -and $comment.createdAt -and [DateTimeOffset]::Parse($comment.createdAt) -gt $since -and $comment.body -like 'Brief updated by the lead*') {
                    $lines.Add("BRIEF   #$($issue.number) Brief updated by the lead — re-read it")
                }
            }
            $names = @($issue.labels | ForEach-Object { $_.name })
            if ($names -contains 'task' -and $names -notcontains 'draft') {
                # ponytail: first 100 timeline events only; a hackathon task never gets near that.
                $events = @(GhJson @('api', "repos/$repo/issues/$($issue.number)/timeline?per_page=100"))
                $removed = @($events | Where-Object { $_.event -eq 'unlabeled' -and $_.label.name -eq 'draft' -and [DateTimeOffset]::Parse($_.created_at) -gt $since })
                if ($removed.Count) { $lines.Add("READY   #$($issue.number) draft removed: build it") }
            }
        }
        if (@($issue.labels | ForEach-Object { $_.name }) -contains 'vertical') {
            Flags $issue.number
            $children = @(GhJson @('api', "repos/$repo/issues/$($issue.number)/sub_issues?per_page=100"))
            foreach ($child in $children) {
                if ($child) { Flags $child.number }
            }
        }
        if ([DateTimeOffset]::Parse($issue.createdAt) -gt $since -and (@($issue.labels | ForEach-Object { $_.name }) -contains 'task')) {
            $lines.Add("NEW     #$($issue.number) assigned to you: `"$($issue.title)`"")
        }
    }

    if ($Lead) {
        foreach ($vertical in (Issues @('--label', 'vertical'))) {
            if (!$vertical) { continue }
            $subs = @(GhJson @('api', "repos/$repo/issues/$($vertical.number)/sub_issues?per_page=100"))
            foreach ($sub in $subs) {
                if (!$sub) { continue }
                $created = [DateTimeOffset]::Parse($sub.created_at)
                $updated = [DateTimeOffset]::Parse($sub.updated_at)
                $draft = @($sub.labels | ForEach-Object { $_.name }) -contains 'draft'
                $prefix = "#$($sub.number) in #$($vertical.number) by $($sub.user.login): `"$($sub.title)`""
                if ($created -gt $since) {
                    if ($draft) { $lines.Add("DRAFT   $prefix") }
                    else { $lines.Add("NEW     $prefix") }
                }
                if ($sub.closed_at -and [DateTimeOffset]::Parse($sub.closed_at) -gt $since) {
                    $reason = if ($sub.state_reason) { $sub.state_reason } else { 'completed' }
                    $lines.Add("CLOSED  $prefix ($reason)")
                } elseif ($created -le $since -and $sub.state -eq 'open' -and $updated -gt $since) {
                    if ($draft) {
                        $events = @(GhJson @('api', "repos/$repo/issues/$($sub.number)/timeline?per_page=100"))
                        $added = @($events | Where-Object {
                            $_.event -eq 'labeled' -and $_.label.name -eq 'draft' -and
                            [DateTimeOffset]::Parse($_.created_at) -gt $since
                        })
                        if ($added.Count) { $lines.Add("DRAFT   $prefix"); continue }
                    }
                    $lines.Add("CHANGED $prefix")
                }
            }
        }
    }

    foreach ($line in $lines) { Write-Output $line }
    [IO.File]::WriteAllText($state, $started.ToString('yyyy-MM-ddTHH:mm:ssZ') + "`n", (New-Object System.Text.UTF8Encoding($false)))
} catch {
    [Console]::Error.WriteLine("inbox: $($_.Exception.Message.Split("`n")[0])")
    exit 1
}
