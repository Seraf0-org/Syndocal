# Additional cleanup permits individual reproducible archives and pruning a
# generated cache while retaining its exact runtime hardlink aliases.
function Assert-DatedCleanupTargetKind {
    param([string]$Path, $Spec, [string]$RepositoryRoot)
    $item = Get-Item -LiteralPath $Path -Force
    Assert-SyndocalCleanupNoReparseItem -Item $item
    if ($Spec.kind -eq 'regenerable-git-archive') {
        foreach ($field in @('sha256','commit','bytes')) {
            if ($null -eq $Spec.PSObject.Properties[$field]) { throw 'Archive proof is incomplete' }
        }
        if ($item.PSIsContainer -or $Spec.root -ne 'repo' -or
            $Spec.relative -notmatch '^target/qa/steroids-60fps-design-20261025/c5/build-[0-9a-f]{12}-(normal|timing)-[0-9]{10}/source\.tar$' -or
            $Spec.sha256 -notmatch '^[0-9a-f]{64}$' -or $Spec.commit -notmatch '^[0-9a-f]{40}$' -or
            $item.Length -ne $Spec.bytes) { throw 'Invalid Git archive target/proof' }
    } else {
        $directoryKinds = @('cargo-cache','c5-staged-runtime','obsolete-build-output','obsolete-staged-runtime',
            'obsolete-downloaded-installer','generated-cargo-cache','generated-cargo-cache-prune','generated-qa-browser-profiles',
            'regenerable-git-source-copy','generated-app-dist')
        if ($Spec.kind -notin $directoryKinds -or -not $item.PSIsContainer) { throw 'Directory target type or kind changed' }
        if ($Spec.kind -eq 'regenerable-git-source-copy') {
            Assert-DatedCleanupSourceCopyProof -Spec $Spec
        } elseif ($Spec.kind -eq 'generated-app-dist') {
            $parent = Split-Path $Path -Parent
            if ((Split-Path $Path -Leaf) -cne 'dist' -or (Split-Path $parent -Leaf) -cne 'app' -or
                -not (Test-Path -LiteralPath (Join-Path $Path 'index.html') -PathType Leaf) -or
                -not (Test-Path -LiteralPath (Join-Path $Path 'assets') -PathType Container)) { throw 'Invalid generated frontend output' }
            $lock = (Get-FileHash -LiteralPath (Join-Path $parent 'pnpm-lock.yaml')).Hash
            $activeLock = (Get-FileHash -LiteralPath (Join-Path $RepositoryRoot 'app/pnpm-lock.yaml')).Hash
            $package = Get-Content -LiteralPath (Join-Path $parent 'package.json') -Raw | ConvertFrom-Json
            if ($lock -ine $Spec.lock_sha256 -or $lock -ine $activeLock -or
                $package.scripts.build -cne 'tsc --noEmit && vite build') { throw 'Generated output build provenance changed' }
        }
    }
}

function Get-DatedCleanupFileSnapshot {
    param([string]$Path, $Item, $Identity)
    if ($Identity.LinkCount -ne 1) { throw 'File target has an external hardlink' }
    $hash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    return [pscustomobject]@{
        Path = $Path; ResolvedPath = $Identity.FinalPath; VolumeSerialNumber = $Identity.VolumeSerialNumber
        FileIndex = $Identity.FileIndex; LogicalBytes = $Item.Length; DistinctFileBytes = $Item.Length
        NewestWriteTicks = $Item.LastWriteTimeUtc.Ticks; FileCount = 1; DirectoryCount = 0
        FingerprintSha256 = $hash; ContentSha256 = $hash
    }
}

function Get-DatedCleanupKeepRecordSet {
    param([string]$Path, [string[]]$KeepNames)
    $records = @()
    if (@($KeepNames | Sort-Object -Unique).Count -ne $KeepNames.Count) { throw 'Duplicate kept names' }
    foreach ($name in @($KeepNames | Sort-Object)) {
        if (-not $name -or $name -in '.', '..' -or $name.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0) {
            throw 'Kept entry must be one direct filename'
        }
        $filePath = Join-Path $Path $name
        $item = Get-Item -LiteralPath $filePath -Force
        Assert-SyndocalCleanupNoReparseItem -Item $item
        if ($item.PSIsContainer) { throw 'Kept entry must be a regular file' }
        $probe = Get-DatedCleanupEntryProbe -Path $filePath
        if (-not (Test-SyndocalCleanupPathEqual -Left $filePath -Right $probe.FinalPath)) { throw 'Kept path changed' }
        $records += [pscustomobject][ordered]@{
            Name = $name; Length = $item.Length; Ticks = $item.LastWriteTimeUtc.Ticks
            Volume = $probe.VolumeSerialNumber; FileId = $probe.FileIndex; Links = $probe.LinkCount
            Sha256 = (Get-FileHash -LiteralPath $filePath -Algorithm SHA256).Hash
        }
    }
    $json = ConvertTo-Json -InputObject $records -Depth 4 -Compress
    $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($json)))
    return [pscustomobject]@{ Records = $records; Fingerprint = $hash }
}

function Assert-DatedCleanupReleaseCachePolicy {
    param([string]$RepositoryRoot, [string]$Path, [string[]]$KeepNames)
    $release = Join-Path $RepositoryRoot 'target/release'
    if (-not (Test-SyndocalCleanupPathUnder -Path $Path -Root $release)) { return }
    $allowed = @('deps', 'build', '.fingerprint', 'examples', 'incremental')
    $relative = $Path.Substring($release.Length).TrimStart('\')
    if ($relative -notin $allowed) { throw 'Release cleanup is restricted to exact generated cache directories' }
    if ($relative -eq 'deps') {
        if ($KeepNames.Count -ne 2 -or 'syndocal.exe' -notin $KeepNames -or 'syndocal.pdb' -notin $KeepNames) {
            throw 'Release deps must preserve the exact executable and PDB aliases'
        }
    } elseif ($KeepNames.Count) { throw 'Unexpected partial release target' }
}

function Remove-DatedCleanupTarget {
    param([string]$Path, [string[]]$KeepNames, $Before)
    if (-not $KeepNames.Count) {
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
        if (Test-Path -LiteralPath $Path) { throw "Deletion incomplete: $Path" }
        return
    }
    foreach ($item in @(Get-ChildItem -LiteralPath $Path -Force)) {
        if ($item.Name -in $KeepNames) { continue }
        Assert-SyndocalCleanupNoReparseItem -Item $item
        Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop
    }
    $remaining = @(Get-ChildItem -LiteralPath $Path -Force)
    if ($remaining.Count -ne $KeepNames.Count -or @($remaining | Where-Object { $_.Name -notin $KeepNames }).Count) {
        throw 'Partial cache cleanup left unexpected entries'
    }
    $after = Get-DatedCleanupKeepRecordSet -Path $Path -KeepNames $KeepNames
    if ($after.Fingerprint -cne $Before.RetainedFingerprint) { throw 'Retained runtime alias identity or bytes changed' }
}
