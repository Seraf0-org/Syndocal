function Assert-DatedCleanupSourceCopyProof {
    param($Spec)
    foreach ($field in @('commit','gitPrefix','bytes','fileCount','contentTreeSha256','archive_config')) {
        if ($null -eq $Spec.PSObject.Properties[$field]) { throw 'Source-copy proof is incomplete' }
    }
    $pattern = '^target/qa/steroids-60fps-design-20261025/c5/build-([0-9a-f]{12})-(normal|timing)-[0-9]{10}/source/(qa|crates|licenses|tools|app/src|app/scripts|app/src-tauri)$'
    $match = [regex]::Match($Spec.relative, $pattern)
    if ($Spec.root -ne 'repo' -or -not $match.Success) { throw 'Source-copy path is not an approved snapshot component' }
    $short = $match.Groups[1].Value
    $prefix = $match.Groups[3].Value
    if ($Spec.commit -notmatch '^[0-9a-f]{40}$' -or -not $Spec.commit.StartsWith($short) -or
        $Spec.gitPrefix -cne $prefix -or $Spec.contentTreeSha256 -notmatch '^[0-9a-f]{64}$' -or
        $Spec.archive_config -cne 'core.autocrlf=true' -or $Spec.fileCount -lt 1 -or $Spec.bytes -lt 1) {
        throw 'Source-copy proof does not bind the snapshot path and content'
    }
}

function Assert-DatedCleanupSnapshotProof {
    param($Spec, $Snapshot)
    if ($Spec.kind -eq 'regenerable-git-archive') {
        if ($Snapshot.ContentSha256 -ine $Spec.sha256) { throw 'Archive differs from verified Git bytes' }
    } elseif ($Spec.kind -eq 'regenerable-git-source-copy') {
        if ($Snapshot.ContentTreeSha256 -ine $Spec.contentTreeSha256 -or
            $Snapshot.FileCount -ne $Spec.fileCount -or $Snapshot.LogicalBytes -ne $Spec.bytes) {
            throw 'Source copy has modified, extra or missing content'
        }
    } elseif ($Spec.kind -eq 'generated-app-dist') {
        if ($Snapshot.LogicalBytes -ne $Spec.bytes -or $Snapshot.FileCount -ne $Spec.files) { throw 'Generated copy content set changed' }
    }
}
