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
            if ($names -contains 'vertical') {
                foreach ($comment in (Comments $issue.number)) {
                    if (!$comment -or !$comment.createdAt -or !$comment.author.login) { continue }
                    if ([DateTimeOffset]::Parse($comment.createdAt) -le $since -or $comment.author.login -eq $me) { continue }
                    if ($comment.body -like 'Brief updated by the lead*') { continue }
                    $lines.Add("GRILL   #$($issue.number) question from $($comment.author.login): `"$(FirstLine $comment.body)`"")
                }
            }
            if ($names -contains 'task' -and $names -notcontains 'draft') {
                # ponytail: first 100 timeline events only; a hackathon task never gets near that.
                $events = @(GhJson @('api', "repos/$repo/issues/$($issue.number)/timeline?per_page=100"))
                $removed = @($events | Where-Object { $_.event -eq 'unlabeled' -and $_.label.name -eq 'draft' -and [DateTimeOffset]::Parse($_.created_at) -gt $since })
                if ($removed.Count) { $lines.Add("READY   #$($issue.number) draft removed: build it") }
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
                if (!$sub -or $sub.state -ne 'open' -or [DateTimeOffset]::Parse($sub.created_at) -le $since) { continue }
                if (@($sub.labels | ForEach-Object { $_.name }) -notcontains 'draft') { continue }
                $lines.Add("DRAFT   #$($sub.number) in #$($vertical.number) by $($sub.user.login): `"$($sub.title)`"")
            }
        }
    }

    foreach ($line in $lines) { Write-Output $line }
    [IO.File]::WriteAllText($state, $started.ToString('yyyy-MM-ddTHH:mm:ssZ') + "`n", (New-Object System.Text.UTF8Encoding($false)))
} catch {
    [Console]::Error.WriteLine("inbox: $($_.Exception.Message.Split("`n")[0])")
    exit 1
}
