#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'cleanup-cache-20261116.ps1') -FunctionsOnly
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('syndocal-dated-cleanup-test-' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $testRoot)
$count = 0
function Expect-Rejection([scriptblock]$Action) {
    $rejected = $false
    try { & $Action | Out-Null } catch { $rejected = $true }
    if (-not $rejected) { throw 'Expected rejection' }
    $script:count++
}
try {
    foreach ($invalid in @('', '.', '..', '../sibling', 'a/../b', 'a//b', '/absolute', 'C:/absolute', 'a\b', 'a:stream')) {
        Expect-Rejection { Resolve-DatedCleanupTarget -Root $testRoot -Relative $invalid }
    }
    $tree = Join-Path $testRoot '日本語-cache'
    [void](New-Item -ItemType Directory -Path $tree)
    Set-Content -LiteralPath (Join-Path $tree 'data.txt') -Value 'preserve' -Encoding utf8
    $resolved = Resolve-DatedCleanupTarget -Root $testRoot -Relative '日本語-cache'
    if ($resolved -cne $tree) { throw 'Unicode path mismatch' }
    $count++
    $snapshot = Assert-DatedCleanupSnapshot -Path $tree
    [void](Assert-DatedCleanupSnapshot -Path $tree -Expected $snapshot)
    $count++
    Add-Content -LiteralPath (Join-Path $tree 'data.txt') -Value 'changed'
    Expect-Rejection { Assert-DatedCleanupSnapshot -Path $tree -Expected $snapshot }
    $junction = Join-Path $testRoot 'junction'
    [void](New-Item -ItemType Junction -Path $junction -Target $tree)
    Expect-Rejection { Assert-DatedCleanupSnapshot -Path $junction }
    $nested = Join-Path $tree 'outside'
    [void](New-Item -ItemType Junction -Path $nested -Target $testRoot)
    Expect-Rejection { Assert-DatedCleanupSnapshot -Path $tree }
    # Remove links themselves with the directory API, never recurse into them.
    [IO.Directory]::Delete($nested)
    [IO.Directory]::Delete($junction)
    [void](New-Item -ItemType HardLink -Path (Join-Path $tree 'hardlink.txt') -Target (Join-Path $tree 'data.txt'))
    $internalLinks = Assert-DatedCleanupSnapshot -Path $tree
    if ($internalLinks.LogicalBytes -ne 2 * $internalLinks.DistinctFileBytes) { throw 'Internal alias accounting failed' }
    $count++
    [void](New-Item -ItemType HardLink -Path (Join-Path $testRoot 'external.txt') -Target (Join-Path $tree 'data.txt'))
    Expect-Rejection { Assert-DatedCleanupSnapshot -Path $tree }
    if (-not (Test-Path -LiteralPath (Join-Path $tree 'data.txt'))) { throw 'Safety probe mutated fixture' }
    $count++
    $longRoot = Join-Path $testRoot 'long'
    $longDir = Join-Path $longRoot (('a' * 90) + '/' + ('b' * 90) + '/' + ('c' * 90))
    [void](New-Item -ItemType Directory -Path $longDir -Force)
    Set-Content -LiteralPath (Join-Path $longDir '長い名前.txt') -Value 'long path'
    $longSnapshot = Assert-DatedCleanupSnapshot -Path $longRoot
    if ($longSnapshot.FileCount -ne 1) { throw 'Long path scan failed' }
    $count++
    Write-Output "PASS: $count dated cleanup safety checks"
} finally {
    $verified = [IO.Path]::GetFullPath($testRoot)
    if ((Split-Path $verified -Parent) -cne ([IO.Path]::GetTempPath().TrimEnd('\')) -or
        (Split-Path $verified -Leaf) -notmatch '^syndocal-dated-cleanup-test-[0-9a-f]{32}$') { throw 'Test cleanup escaped temp root' }
    foreach ($link in @((Join-Path $tree 'outside'), (Join-Path $testRoot 'junction'))) {
        if (Test-Path -LiteralPath $link) { [IO.Directory]::Delete($link) }
    }
    Remove-Item -LiteralPath $verified -Recurse -Force
}
