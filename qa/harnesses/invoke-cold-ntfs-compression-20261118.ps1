#Requires -Version 7.0
[CmdletBinding()]
param([switch]$Apply,[switch]$FunctionsOnly)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'cleanup-cache-native-path.ps1')
. (Join-Path $PSScriptRoot 'ntfs-cold-file-compression.ps1')
$script:SyndocalCleanupHarnessRelativePath='qa/harnesses/invoke-cold-ntfs-compression-20261118.ps1'
$script:ColdActivePaths=@()
$scopeRoots=@([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../target/qa')),[IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'SyndocalDev')))
foreach($entry in @($env:FFMPEG_DIR)+@($env:PATH.Split(';'))){
    $expanded=if($entry){[Environment]::ExpandEnvironmentVariables($entry)}else{''}
    if($expanded -and [IO.Path]::IsPathFullyQualified($expanded)){
        $absolute=[IO.Path]::GetFullPath($expanded).TrimEnd('\')
        foreach($scope in $scopeRoots){
            if($absolute.Equals($scope,[StringComparison]::OrdinalIgnoreCase) -or $absolute.StartsWith($scope+'\',[StringComparison]::OrdinalIgnoreCase) -or $scope.StartsWith($absolute+'\',[StringComparison]::OrdinalIgnoreCase)){$script:ColdActivePaths+=$absolute;break}
        }
    }
}

function Resolve-ColdCompressionPath {
    param([string]$RepositoryRoot,[string]$DevRoot,$Spec)
    $root=switch($Spec.root){'repo'{$RepositoryRoot}'dev'{$DevRoot}default{throw 'Unknown compression root'}}
    $relative=[string]$Spec.relative
    if(-not $relative -or [IO.Path]::IsPathRooted($relative) -or $relative.Contains(':') -or $relative.Contains('\') -or
        @($relative.Split('/')|Where-Object{$_ -in '', '.', '..'}).Count){throw 'Invalid compression path'}
    $full=Get-SyndocalCleanupFullPath -Path (Join-Path $root $relative)
    if(-not(Test-SyndocalCleanupPathUnder -Path $full -Root $root)){throw 'Compression path escaped root'}
    foreach($protected in $script:ColdActivePaths){
        if($full.Equals($protected,[StringComparison]::OrdinalIgnoreCase) -or $full.StartsWith($protected+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Active environment tool path protected'}
    }
    $segments=$relative.Split('/')
    foreach($segment in $segments){
        if($segment -in @('node_modules','sdk','SDK','recovery','tools','sol-handoff','presentmon','vj-bench-media') -or
            $segment -like 'ffmpeg*' -or $segment -like 'node-v*'){throw 'Protected tool/dependency/media path'}
    }
    if($Spec.root -eq 'repo'){
        if(-not $relative.StartsWith('target/qa/')){throw 'Only historical QA files are eligible'}
        foreach($prefix in @('target/qa/release-candidate-20261115','target/qa/physical-midi-dmx-20261110','target/qa/task20')){
            if($relative -eq $prefix -or $relative.StartsWith($prefix+'/')){throw 'Current protected QA path'}
        }
        if(($relative.Substring(0,$relative.LastIndexOf('/'))) -eq 'target/qa/steroids-60fps-design-20261025/c5'){throw 'C5 tools and direct fixtures protected'}
    }
    $extensions=@('.dll','.exe','.pdb','.tar','.rs','.json','.jsonl','.log','.txt','.mjs','.cjs','.py','.sdc','.csv','.md','.yaml','.yml','.ts','.tsx','.js','.css','.html','.xml','.fs','.h','.cpp','.c','.d','.rlib','.rmeta','.obj','.lib','.bin','.raw','.data')
    if([IO.Path]::GetExtension($relative).ToLowerInvariant() -notin $extensions){throw 'File format outside cold-compression scope'}
    return $full
}

function Read-ColdCompressionManifest {
    param([string]$Path)
    $file=[IO.File]::OpenRead($Path)
    try{$gzip=[IO.Compression.GZipStream]::new($file,[IO.Compression.CompressionMode]::Decompress);$reader=[IO.StreamReader]::new($gzip,[Text.Encoding]::UTF8);try{return($reader.ReadToEnd()|ConvertFrom-Json)}finally{$reader.Dispose()}}finally{$file.Dispose()}
}

function Write-ColdCompressionManifest {
    param([string]$Path,$Value)
    $file=[IO.File]::Create($Path)
    try{$gzip=[IO.Compression.GZipStream]::new($file,[IO.Compression.CompressionLevel]::Optimal);$writer=[IO.StreamWriter]::new($gzip,[Text.UTF8Encoding]::new($false));try{$writer.Write(($Value|ConvertTo-Json -Depth 8 -Compress))}finally{$writer.Dispose()}}finally{$file.Dispose()}
}

if($FunctionsOnly){return}
$repo=Get-SyndocalCleanupFullPath -Path (Join-Path $PSScriptRoot '../..')
$dev=Get-SyndocalCleanupFullPath -Path (Join-Path $env:LOCALAPPDATA 'SyndocalDev')
if($repo -ine (Get-SyndocalCleanupFullPath -Path (Join-Path $env:USERPROFILE 'OneDrive/ドキュメント/GitHub/Syndocal'))){throw 'Wrong checkout'}
$cutoff=([datetime]'2026-11-17T00:00:00Z').ToUniversalTime().ToFileTimeUtc()
$manifestPath=Join-Path $PSScriptRoot 'ntfs-cold-files-20261118.plan.json.gz'
if(-not $Apply){
    $inputPath=Join-Path $env:TEMP 'syndocal-compression-scope-20261118.json'
    $candidates=@(Get-Content -LiteralPath $inputPath -Raw|ConvertFrom-Json)
    $files=[Collections.Generic.List[object]]::new();$skips=[Collections.Generic.List[object]]::new()
    $seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $i=0
    foreach($spec in $candidates){
        $path=Resolve-ColdCompressionPath -RepositoryRoot $repo -DevRoot $dev -Spec $spec
        if(-not $seen.Add($path)){throw 'Duplicate compression candidate'}
        try{
            $proof=[Syndocal.Maintenance.ColdCompression]::Process($path,$false,$null)
            if($proof.WriteTime -gt $cutoff -or $proof.CreatedTime -gt $cutoff -or $proof.FormatBefore -ne 0){throw 'Recent or already-compressed file'}
            $files.Add([pscustomobject]@{root=$spec.root;relative=$spec.relative;proof=$proof})
        }catch{$skips.Add([pscustomobject]@{root=$spec.root;relative=$spec.relative;reason=$_.Exception.Message})}
        $i++;if($i%500 -eq 0){Write-Output "Planned $i/$($candidates.Count)"}
    }
    $manifest=[ordered]@{schema=1;base=(git -C $repo rev-parse HEAD);cutoff=$cutoff;files=$files.ToArray();skips=$skips.ToArray()}
    Write-ColdCompressionManifest -Path $manifestPath -Value $manifest
    Write-Output "Plan ready: $($files.Count) eligible; $($skips.Count) retained; $manifestPath"
    return
}
[void](Assert-SyndocalCleanupRepositoryCheckpoint -RepositoryRoot $repo)
foreach($file in @('qa/harnesses/ntfs-cold-file-compression.ps1','qa/harnesses/invoke-cold-ntfs-compression-20261118.ps1','qa/harnesses/test-cold-ntfs-compression-20261118.ps1','qa/harnesses/ntfs-cold-files-20261118.plan.json.gz')){
    if(@(Invoke-SyndocalCleanupGit -RepositoryRoot $repo -Arguments @('ls-files','--',$file) -FailureCode 'CompressionTrackingFailed').Count -ne 1){throw 'Compression checkpoint is incomplete'}
}
$manifest=Read-ColdCompressionManifest -Path $manifestPath
if($manifest.schema -ne 1 -or $manifest.cutoff -ne $cutoff -or $manifest.files.Count -lt 1 -or $manifest.files.Count -gt 50000){throw 'Invalid compression manifest'}
$seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$log=Join-Path $env:TEMP 'syndocal-ntfs-compression-20261118-apply.jsonl'
$freeBefore=(Get-PSDrive C).Free
@{Event='Started';FreeBefore=$freeBefore;At=(Get-Date).ToString('o')}|ConvertTo-Json -Compress|Set-Content -LiteralPath $log -Encoding utf8
$index=0
foreach($spec in $manifest.files){
    if($index%250 -eq 0){[void](Assert-SyndocalCleanupRepositoryCheckpoint -RepositoryRoot $repo)}
    $path=Resolve-ColdCompressionPath -RepositoryRoot $repo -DevRoot $dev -Spec $spec
    if(-not $seen.Add($path)){throw 'Duplicate compression manifest path'}
    $proof=[Syndocal.Maintenance.CompressionRecord]::new()
    foreach($field in @('Path','Volume','FileId','WriteTime','CreatedTime','LogicalBytes','Sha256')){$proof.$field=$spec.proof.$field}
    if($proof.WriteTime -gt $cutoff -or $proof.CreatedTime -gt $cutoff -or $proof.Sha256 -notmatch '^[0-9A-F]{64}$' -or $spec.proof.FormatBefore -ne 0){throw 'Manifest violates reviewed compression proof'}
    try{
        $result=[Syndocal.Maintenance.ColdCompression]::Process($path,$true,$proof)
        $result|ConvertTo-Json -Depth 4 -Compress|Add-Content -LiteralPath $log -Encoding utf8
        if($result.Status -eq 'FailedRolledBack'){throw ('Compression failed and was rolled back: '+$result.Failure)}
    }catch{
        @{Event='Stopped';Path=$path;Error=$_.Exception.Message;At=(Get-Date).ToString('o')}|ConvertTo-Json -Compress|Add-Content -LiteralPath $log -Encoding utf8
        throw
    }
    $index++;if($index%250 -eq 0){Write-Output "Verified $index/$($manifest.files.Count)"}
}
@{Event='Completed';Count=$index;FreeBefore=$freeBefore;FreeAfter=(Get-PSDrive C).Free;At=(Get-Date).ToString('o')}|ConvertTo-Json -Compress|Add-Content -LiteralPath $log -Encoding utf8
Write-Output "Completed $index verified files; $log"
