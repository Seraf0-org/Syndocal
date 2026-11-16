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
    $single = Join-Path $testRoot 'reproducible.tar'
    Set-Content -LiteralPath $single -Value 'original'
    $singleBefore = Assert-DatedCleanupSnapshot -Path $single
    if ($singleBefore.FileCount -ne 1 -or $singleBefore.DirectoryCount -ne 0) { throw 'File snapshot failed' }
    $count++
    Expect-Rejection { Assert-DatedCleanupTargetKind -Path $single -Spec ([pscustomobject]@{kind='cargo-cache'}) }
    Expect-Rejection { Assert-DatedCleanupTargetKind -Path $single -Spec ([pscustomobject]@{kind='regenerable-git-archive'}) }
    Expect-Rejection { Assert-DatedCleanupTargetKind -Path $single -Spec ([pscustomobject]@{kind='unknown-future-kind'}) }
    Assert-DatedCleanupTargetKind -Path $tree -Spec ([pscustomobject]@{kind='cargo-cache'})
    $count++
    Add-Content -LiteralPath $single -Value 'mutation'
    Expect-Rejection { Assert-DatedCleanupSnapshot -Path $single -Expected $singleBefore }
    $fileAlias = Join-Path $testRoot 'file-alias.tar'
    [void](New-Item -ItemType HardLink -Path $fileAlias -Target $single)
    Expect-Rejection { Assert-DatedCleanupSnapshot -Path $single }
    Remove-Item -LiteralPath $fileAlias
    Remove-DatedCleanupTarget -Path $single -KeepNames @() -Before (Assert-DatedCleanupSnapshot -Path $single)
    if (Test-Path -LiteralPath $single) { throw 'File removal failed' }
    $count++
    $partial = Join-Path $testRoot 'partial'
    [void](New-Item -ItemType Directory -Path (Join-Path $partial 'nested') -Force)
    Set-Content -LiteralPath (Join-Path $partial 'nested/cache.rlib') -Value 'cache'
    $keep = @('syndocal.exe','syndocal.pdb')
    foreach ($name in $keep) {
        $outsideFile = Join-Path $testRoot $name
        Set-Content -LiteralPath $outsideFile -Value "keep $name"
        [void](New-Item -ItemType HardLink -Path (Join-Path $partial $name) -Target $outsideFile)
    }
    Expect-Rejection { Assert-DatedCleanupSnapshot -Path $partial }
    $partialBefore = Assert-DatedCleanupSnapshot -Path $partial -KeepNames $keep
    if ($partialBefore.FileCount -ne 1 -or $partialBefore.RetainedFiles.Count -ne 2) { throw 'Partial accounting failed' }
    $count++
    Add-Content -LiteralPath (Join-Path $partial 'syndocal.exe') -Value 'changed'
    Expect-Rejection { Assert-DatedCleanupSnapshot -Path $partial -KeepNames $keep -Expected $partialBefore }
    Expect-Rejection { Get-DatedCleanupKeepRecordSet -Path $partial -KeepNames @('../escape') }
    $partialBefore = Assert-DatedCleanupSnapshot -Path $partial -KeepNames $keep
    Remove-DatedCleanupTarget -Path $partial -KeepNames $keep -Before $partialBefore
    $afterPartial = Get-DatedCleanupKeepRecordSet -Path $partial -KeepNames $keep
    if ($afterPartial.Fingerprint -cne $partialBefore.RetainedFingerprint -or
        @(Get-ChildItem -LiteralPath $partial).Count -ne 2) { throw 'Partial removal lost alias or left cache' }
    $count++
    Expect-Rejection { Assert-DatedCleanupReleaseCachePolicy -RepositoryRoot $testRoot -Path (Join-Path $testRoot 'target/release/syndocal.exe') -KeepNames @() }
    Expect-Rejection { Assert-DatedCleanupReleaseCachePolicy -RepositoryRoot $testRoot -Path (Join-Path $testRoot 'target/release/deps') -KeepNames @() }
    Expect-Rejection { Assert-DatedCleanupReleaseCachePolicy -RepositoryRoot $testRoot -Path (Join-Path $testRoot 'target/release/deps/child') -KeepNames $keep }
    Assert-DatedCleanupReleaseCachePolicy -RepositoryRoot $testRoot -Path (Join-Path $testRoot 'target/release/build') -KeepNames @()
    $count++
    $sourceProofTree = Join-Path $testRoot 'source-proof'
    [void](New-Item -ItemType Directory -Path (Join-Path $sourceProofTree 'nested') -Force)
    [IO.File]::WriteAllText((Join-Path $sourceProofTree 'b.txt'), "first`n", [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $sourceProofTree 'nested/a.txt'), "second`r`n", [Text.UTF8Encoding]::new($false))
    $proofSpec = [pscustomobject]@{
        root='repo';relative='target/qa/steroids-60fps-design-20261025/c5/build-111111111111-normal-2611150442/source/qa'
        kind='regenerable-git-source-copy';commit=('1'*40);gitPrefix='qa';bytes=14;fileCount=2
        contentTreeSha256='09e6923b4b2b28181cfdda277b1f8820e15192fadc697ed0a742824c0bcaab6e';archive_config='core.autocrlf=true'
    }
    Assert-DatedCleanupSourceCopyProof -Spec $proofSpec
    $proofBefore = Assert-DatedCleanupSnapshot -Path $sourceProofTree -ContentTree
    Assert-DatedCleanupSnapshotProof -Spec $proofSpec -Snapshot $proofBefore
    $count++
    $oldTicks = (Get-Item -LiteralPath (Join-Path $sourceProofTree 'b.txt')).LastWriteTimeUtc
    [IO.File]::WriteAllText((Join-Path $sourceProofTree 'b.txt'), "other`n", [Text.UTF8Encoding]::new($false))
    [IO.File]::SetLastWriteTimeUtc((Join-Path $sourceProofTree 'b.txt'), $oldTicks)
    Expect-Rejection { Assert-DatedCleanupSnapshotProof -Spec $proofSpec -Snapshot (Assert-DatedCleanupSnapshot -Path $sourceProofTree -ContentTree) }
    [IO.File]::WriteAllText((Join-Path $sourceProofTree 'b.txt'), "first`n", [Text.UTF8Encoding]::new($false))
    Set-Content -LiteralPath (Join-Path $sourceProofTree 'new.txt') -Value 'untracked'
    Expect-Rejection { Assert-DatedCleanupSnapshotProof -Spec $proofSpec -Snapshot (Assert-DatedCleanupSnapshot -Path $sourceProofTree -ContentTree) }
    Remove-Item -LiteralPath (Join-Path $sourceProofTree 'new.txt')
    Remove-Item -LiteralPath (Join-Path $sourceProofTree 'b.txt')
    Expect-Rejection { Assert-DatedCleanupSnapshotProof -Spec $proofSpec -Snapshot (Assert-DatedCleanupSnapshot -Path $sourceProofTree -ContentTree) }
    $proofSpec.commit = '2'*40
    Expect-Rejection { Assert-DatedCleanupSourceCopyProof -Spec $proofSpec }
    $proofSpec.commit = '1'*40; $proofSpec.archive_config='unsafe'
    Expect-Rejection { Assert-DatedCleanupSourceCopyProof -Spec $proofSpec }
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
