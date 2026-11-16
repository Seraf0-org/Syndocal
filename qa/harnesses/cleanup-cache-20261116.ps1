#Requires -Version 7.0
[CmdletBinding()]
param([switch]$Apply, [switch]$FunctionsOnly, [switch]$Additional, [switch]$Copies)

# One dated, reviewed target list; never enumerate new deletion targets at apply time.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$datedApply = [bool]$Apply
$datedFunctionsOnly = [bool]$FunctionsOnly
. (Join-Path $PSScriptRoot 'cleanup-cache-native-path.ps1')
. (Join-Path $PSScriptRoot 'cleanup-cache-extra-policy.ps1')
. (Join-Path $PSScriptRoot 'cleanup-source-copy-policy.ps1')
$script:SyndocalCleanupHarnessRelativePath = 'qa/harnesses/cleanup-cache-20261116.ps1'

function Resolve-DatedCleanupTarget {
    param([string]$Root, [string]$Relative)
    if ([string]::IsNullOrWhiteSpace($Relative) -or [IO.Path]::IsPathRooted($Relative) -or
        $Relative.Contains('\') -or $Relative.Contains(':') -or
        @($Relative.Split('/') | Where-Object { $_ -in '', '.', '..' }).Count -gt 0) {
        throw "Invalid relative deletion path: $Relative"
    }
    $full = Get-SyndocalCleanupFullPath -Path (Join-Path $Root $Relative)
    if (-not (Test-SyndocalCleanupPathUnder -Path $full -Root $Root)) { throw 'Target escaped root' }
    return $full
}

function Assert-DatedCleanupSnapshot {
    param([string]$Path, $Expected, [string[]]$KeepNames = @(), [switch]$ContentTree)
    $actual = Get-DatedCleanupSnapshot -Path $Path -KeepNames $KeepNames -ContentTree:$ContentTree
    if ($null -ne $Expected) { Assert-SyndocalCleanupSnapshotsEqual -Expected $Expected -Actual $actual }
    return $actual
}

function Get-DatedCleanupEntryProbe {
    param([string]$Path)
    $full = Get-SyndocalCleanupFullPath -Path $Path
    # Win32 CreateFileW requires its extended-length form beyond MAX_PATH.
    $nativePath = if ($full.StartsWith('\\')) { '\\?\UNC\' + $full.Substring(2) } else { '\\?\' + $full }
    return [Syndocal.Cleanup.NativePathProbe]::Probe($nativePath)
}

function Get-DatedCleanupSnapshot {
    param([string]$Path, [string[]]$KeepNames = @(), [switch]$ContentTree)
    Assert-SyndocalCleanupNoReparseAncestry -Path $Path
    $root = Get-Item -LiteralPath $Path -Force
    $identity = Get-DatedCleanupEntryProbe -Path $Path
    if (-not (Test-SyndocalCleanupPathEqual -Left $identity.FinalPath -Right $Path)) { throw 'Resolved target mismatch' }
    if (-not $root.PSIsContainer) {
        if ($KeepNames.Count) { throw 'File target cannot keep children' }
        return Get-DatedCleanupFileSnapshot -Path $Path -Item $root -Identity $identity
    }
    $retained = Get-DatedCleanupKeepRecordSet -Path $Path -KeepNames $KeepNames
    $stack = [Collections.Generic.Stack[IO.DirectoryInfo]]::new()
    $stack.Push($root)
    $lines = [Collections.Generic.List[string]]::new()
    $contentLines = [Collections.Generic.List[string]]::new()
    $files = @{}
    [int64]$logical = 0
    [int64]$distinct = 0
    [int64]$newest = $root.LastWriteTimeUtc.Ticks
    $fileCount = 0
    $directoryCount = 1
    while ($stack.Count) {
        $dir = $stack.Pop()
        foreach ($entry in $dir.EnumerateFileSystemInfos()) {
            Assert-SyndocalCleanupNoReparseItem -Item $entry
            if ($dir.FullName -eq $Path -and $entry.Name -in $KeepNames) { continue }
            $relative = $entry.FullName.Substring($Path.Length)
            $ticks = $entry.LastWriteTimeUtc.Ticks
            $newest = [Math]::Max($newest, $ticks)
            if ($entry.Attributes -band [IO.FileAttributes]::Directory) {
                $directoryCount++
                $stack.Push([IO.DirectoryInfo]$entry)
                $lines.Add("D|$relative|$ticks")
            } else {
                $probe = Get-DatedCleanupEntryProbe -Path $entry.FullName
                $key = "$($probe.VolumeSerialNumber):$($probe.FileIndex)"
                if (-not $files.ContainsKey($key)) {
                    $files[$key] = @{ Count = 0; Links = $probe.LinkCount }
                    $distinct += $entry.Length
                }
                if ($files[$key].Links -ne $probe.LinkCount) { throw 'Hardlink count changed during snapshot' }
                $files[$key].Count++
                $logical += $entry.Length
                $fileCount++
                $fileLine = "F|$relative|$($entry.Length)|$ticks|$key|$($probe.LinkCount)"
                $lines.Add($fileLine)
                if ($ContentTree) {
                    $normalized = $relative.TrimStart('\').Replace('\','/')
                    $hash = (Get-FileHash -LiteralPath $entry.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
                    $contentLines.Add("$normalized|$hash")
                }
            }
        }
    }
    foreach ($file in $files.Values) {
        # Cargo creates internal aliases (e.g. build-script executables). Allow
        # them only when EVERY link to that identity occurs inside this target.
        if ($file.Count -ne $file.Links) { throw 'Hardlink crosses deletion boundary; target retained' }
    }
    $lines.Sort([StringComparer]::Ordinal)
    if ($KeepNames.Count) { $lines.Add("K|$($retained.Fingerprint)") }
    $fingerprint = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes([string]::Join("`n", $lines))))
    $contentLines.Sort([StringComparer]::Ordinal)
    $contentHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes([string]::Join("`n", $contentLines))))
    return [pscustomobject]@{
        Path = $Path; ResolvedPath = $identity.FinalPath; VolumeSerialNumber = $identity.VolumeSerialNumber
        FileIndex = $identity.FileIndex; LogicalBytes = $logical; DistinctFileBytes = $distinct
        NewestWriteTicks = $newest; FileCount = $fileCount; DirectoryCount = $directoryCount
        FingerprintSha256 = $fingerprint
        RetainedFiles = $retained.Records; RetainedFingerprint = $retained.Fingerprint
        ContentTreeSha256 = $contentHash
    }
}

function Assert-DatedCleanupNoWriters {
    param([object[]]$Targets)
    # Treat any active native build as a blocker. Do not infer ownership from
    # recycled parent PIDs of long-running desktop processes.
    foreach ($process in @(Get-CimInstance Win32_Process -ErrorAction Stop)) {
        if ($process.ProcessId -eq $PID) { continue }
        if ($process.Name -match '^(cargo|rustc|rustdoc|cl|link|lld-link|msbuild|cmake|ninja)\.exe$' -or
            $process.CommandLine -match '(prepare-exe|run-c5)\.py') { throw "Active build/QA process: $($process.ProcessId) $($process.Name)" }
        if ($process.Name -match '^(node|python|pnpm|pwsh|powershell|syndocal|ffmpeg)\.exe$' -and
            -not $process.ExecutablePath -and -not $process.CommandLine) { throw "Unverifiable process: $($process.ProcessId)" }
        foreach ($target in $Targets) {
            if ($process.ExecutablePath -and (Test-SyndocalCleanupPathUnder -Path $process.ExecutablePath -Root $target.Path)) {
                throw "Executable in deletion target: $($process.ProcessId)"
            }
            if ($process.CommandLine -and $process.CommandLine.IndexOf($target.Path, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                throw "Command references deletion target: $($process.ProcessId)"
            }
        }
    }
}

if ($datedFunctionsOnly) { return }
if ($Additional -and $Copies) { throw 'Select only one cleanup target set' }
$Apply = $datedApply
$repo = Get-SyndocalCleanupFullPath -Path (Join-Path $PSScriptRoot '../..')
$dev = Get-SyndocalCleanupFullPath -Path (Join-Path $env:LOCALAPPDATA 'SyndocalDev')
$manifestName = if ($Copies) { 'cleanup-cache-copies-20261116.targets.json' } elseif ($Additional) { 'cleanup-cache-extra-20261116.targets.json' } else { 'cleanup-cache-20261116.targets.json' }
$manifestPath = Join-Path $PSScriptRoot $manifestName
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ($manifest.schema -ne 1) { throw 'Unsupported cleanup schema' }
if ((Split-Path $repo -Leaf) -cne 'Syndocal' -or $repo -cne (Get-SyndocalCleanupFullPath -Path (Join-Path $env:USERPROFILE 'OneDrive/ドキュメント/GitHub/Syndocal'))) {
    throw 'This dated cleanup belongs to the original checkout only'
}
$protected = @(
    (Join-Path $repo 'target/qa/ffmpeg-selfbuild-20261027'),
    (Join-Path $repo 'target/qa/release-candidate-20261115'), (Join-Path $repo 'app/node_modules'),
    (Join-Path $dev 'recovery'), (Join-Path $dev 'tools'), (Join-Path $dev 'sol-handoff'),
    (Join-Path $dev 'vj-bench-media'), (Join-Path $dev 'presentmon'),
    (Join-Path $dev 'node-v22.22.1-win-x64'), (Join-Path $dev 'ffmpeg-n8.1-latest-win64-lgpl-shared-8.1')
)
if ($Additional) {
    $protected += @(Get-ChildItem -LiteralPath (Join-Path $repo 'target/release') -Force |
        Where-Object { -not $_.PSIsContainer -or $_.Name -notin @('deps','build','.fingerprint','examples','incremental') } |
        Select-Object -ExpandProperty FullName)
} else { $protected += (Join-Path $repo 'target/release') }
if ($env:FFMPEG_DIR) { $protected += $env:FFMPEG_DIR }
$protected += @($env:PATH.Split(';') | Where-Object { $_ -and (Test-SyndocalCleanupPathUnder -Path $_ -Root $dev) })
$targets = @()
foreach ($spec in $manifest.targets) {
    $root = switch ($spec.root) { 'repo' { $repo } 'dev' { $dev } default { throw 'Unknown target root' } }
    $path = Resolve-DatedCleanupTarget -Root $root -Relative $spec.relative
    $keepNames = @(if ($null -ne $spec.PSObject.Properties['keepNames']) { $spec.keepNames })
    if ($Additional) { Assert-DatedCleanupReleaseCachePolicy -RepositoryRoot $repo -Path $path -KeepNames $keepNames }
    if ($spec.root -eq 'repo' -and -not $spec.relative.StartsWith('target/')) { throw 'Repo target outside target/' }
    foreach ($keep in $protected) {
        if ((Test-SyndocalCleanupPathEqual -Left $path -Right $keep) -or
            (Test-SyndocalCleanupPathUnder -Path $path -Root $keep) -or
            (Test-SyndocalCleanupPathUnder -Path $keep -Root $path)) { throw "Protected target overlap: $path" }
    }
    foreach ($other in $targets) {
        if ((Test-SyndocalCleanupPathEqual -Left $path -Right $other.Path) -or
            (Test-SyndocalCleanupPathUnder -Path $path -Root $other.Path) -or
            (Test-SyndocalCleanupPathUnder -Path $other.Path -Root $path)) { throw "Overlapping targets: $path" }
    }
    $targets += [pscustomobject]@{ Path = $path; Root = $root; Spec = $spec; KeepNames = $keepNames }
}

if ($Apply) {
    [void](Assert-SyndocalCleanupRepositoryCheckpoint -RepositoryRoot $repo)
    foreach ($file in @('qa/harnesses/cleanup-cache-20261116.ps1', 'qa/harnesses/cleanup-cache-native-path.ps1', 'qa/harnesses/cleanup-cache-extra-policy.ps1', 'qa/harnesses/cleanup-source-copy-policy.ps1', ('qa/harnesses/' + $manifestName), 'qa/harnesses/test-cleanup-cache-20261116.ps1')) {
        $tracked = @(Invoke-SyndocalCleanupGit -RepositoryRoot $repo -Arguments @('ls-files', '--', $file) -FailureCode 'TrackingFailed')
        if ($tracked.Count -ne 1) { throw "Dated cleanup file is not tracked: $file" }
    }
}
Assert-DatedCleanupNoWriters -Targets $targets
$log = Join-Path $env:TEMP ('syndocal-cleanup-20261116-' + $(if ($Copies) { 'copies-' } elseif ($Additional) { 'extra-' } else { '' }) + $(if ($Apply) { 'apply' } else { 'plan' }) + '.jsonl')
$freeBefore = (Get-PSDrive C).Free
@{ Mode = $(if ($Apply) { 'Apply' } else { 'Plan' }); FreeBefore = $freeBefore; Started = (Get-Date).ToString('o') } | ConvertTo-Json -Compress | Set-Content -LiteralPath $log -Encoding utf8
[int64]$bytes = 0
foreach ($target in $targets) {
    if (-not (Test-Path -LiteralPath $target.Path)) { continue }
    Assert-DatedCleanupTargetKind -Path $target.Path -Spec $target.Spec -RepositoryRoot $repo
    if ($target.Spec.root -eq 'repo') { Assert-SyndocalCleanupCandidateUntracked -RepositoryRoot $repo -RelativePath $target.Spec.relative }
    Write-Output "Inspecting $($target.Spec.root)/$($target.Spec.relative)"
    $isSourceCopy = $target.Spec.kind -eq 'regenerable-git-source-copy'
    $before = Assert-DatedCleanupSnapshot -Path $target.Path -KeepNames $target.KeepNames -ContentTree:$isSourceCopy
    Assert-DatedCleanupSnapshotProof -Spec $target.Spec -Snapshot $before
    if ($Apply) {
        [void](Assert-SyndocalCleanupRepositoryCheckpoint -RepositoryRoot $repo)
        Assert-DatedCleanupNoWriters -Targets @($target)
        Assert-DatedCleanupTargetKind -Path $target.Path -Spec $target.Spec -RepositoryRoot $repo
        $finalSnapshot = Assert-DatedCleanupSnapshot -Path $target.Path -Expected $before -KeepNames $target.KeepNames -ContentTree:$isSourceCopy
        Assert-DatedCleanupSnapshotProof -Spec $target.Spec -Snapshot $finalSnapshot
        # No reparse points or external hardlinks are accepted. Native
        # final-path and identity probes run again immediately before deletion.
        $probe = Get-DatedCleanupEntryProbe -Path $target.Path
        if (-not (Test-SyndocalCleanupPathEqual -Left $probe.FinalPath -Right $target.Path) -or
            $probe.FileIndex -ne $before.FileIndex -or $probe.VolumeSerialNumber -ne $before.VolumeSerialNumber) { throw 'Final target identity changed' }
        @{ Event = 'BeforeDelete'; Path = $target.Path; Snapshot = $before } | ConvertTo-Json -Depth 5 -Compress | Add-Content -LiteralPath $log -Encoding utf8
        try {
            Remove-DatedCleanupTarget -Path $target.Path -KeepNames $target.KeepNames -Before $before
        } catch {
            @{ Event = 'DeleteFailed'; Path = $target.Path; Error = $_.Exception.Message; FreeNow = (Get-PSDrive C).Free } | ConvertTo-Json -Compress | Add-Content -LiteralPath $log -Encoding utf8
            throw
        }
    }
    $bytes += $before.LogicalBytes
    @{ Path = $target.Path; LogicalBytes = $before.LogicalBytes; Snapshot = $before; Deleted = ([bool]$Apply -and -not $target.KeepNames.Count); Pruned = ([bool]$Apply -and $target.KeepNames.Count -gt 0); PreservedNames = $target.KeepNames } | ConvertTo-Json -Depth 6 -Compress | Add-Content -LiteralPath $log -Encoding utf8
}
@{ Completed = (Get-Date).ToString('o'); LogicalBytes = $bytes; FreeBefore = $freeBefore; FreeAfter = (Get-PSDrive C).Free } | ConvertTo-Json -Compress | Add-Content -LiteralPath $log -Encoding utf8
Write-Output "Completed: $bytes logical bytes; ledger: $log"
