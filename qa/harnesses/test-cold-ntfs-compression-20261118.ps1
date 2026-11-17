#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'invoke-cold-ntfs-compression-20261118.ps1') -FunctionsOnly
$fixtureRoot=Join-Path ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../target/qa'))) ('compression-selftest-'+[guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $fixtureRoot)
$count=0
function Reject([scriptblock]$Action){$failed=$false;try{& $Action|Out-Null}catch{$failed=$true};if(-not $failed){throw 'Expected rejection'};$script:count++}
function Write-Fixture([string]$Name,[byte[]]$Bytes){$path=Join-Path $fixtureRoot $Name;[IO.File]::WriteAllBytes($path,$Bytes);return $path}
$repeat=Write-Fixture -Name 'repeat.txt' -Bytes ([Text.Encoding]::UTF8.GetBytes(('payload-'*16384)))
$plan=[Syndocal.Maintenance.ColdCompression]::Process($repeat,$false,$null)
if($plan.FormatBefore -ne 0 -or $plan.LogicalBytes -ne 131072){throw 'Planning modified the fixture'};$count++
$compressed=[Syndocal.Maintenance.ColdCompression]::Process($repeat,$true,$plan)
if($compressed.Status -ne 'Compressed' -or $compressed.AllocatedAfter -ge $compressed.AllocatedBefore -or
    $compressed.VerifiedSha256 -cne $compressed.Sha256 -or (Get-FileHash -LiteralPath $repeat).Hash -cne $plan.Sha256){throw 'Lossless compression failed'};$count++
$again=[Syndocal.Maintenance.ColdCompression]::Process($repeat,$true,$plan)
if($again.Status -ne 'AlreadyCompressed' -or $again.AllocatedAfter -ne $again.AllocatedBefore){throw 'Idempotence failed'};$count++
$random=[byte[]]::new(131072);[Security.Cryptography.RandomNumberGenerator]::Fill($random)
$noise=Write-Fixture -Name 'random.bin' -Bytes $random
$noisePlan=[Syndocal.Maintenance.ColdCompression]::Process($noise,$false,$null)
$noiseResult=[Syndocal.Maintenance.ColdCompression]::Process($noise,$true,$noisePlan)
if($noiseResult.Status -ne 'NoGainReverted' -or $noiseResult.FormatAfter -ne 0 -or
    (Get-FileHash -LiteralPath $noise).Hash -cne $noisePlan.Sha256){throw 'No-gain rollback failed'};$count++
Reject {[Syndocal.Maintenance.ColdCompression]::Process($noise,$true,$null)}
$changed=Write-Fixture -Name 'changed.txt' -Bytes ([Text.Encoding]::UTF8.GetBytes(('b'*131072)))
$changedPlan=[Syndocal.Maintenance.ColdCompression]::Process($changed,$false,$null)
$stamp=(Get-Item -LiteralPath $changed).LastWriteTimeUtc
[IO.File]::WriteAllText($changed,('c'*131072),[Text.UTF8Encoding]::new($false));[IO.File]::SetLastWriteTimeUtc($changed,$stamp)
Reject {[Syndocal.Maintenance.ColdCompression]::Process($changed,$true,$changedPlan)}
if((Get-Item -LiteralPath $changed).Attributes -band [IO.FileAttributes]::Compressed){throw 'Changed proof caused mutation'};$count++
$wrong=[Syndocal.Maintenance.ColdCompression]::Process($changed,$false,$null);$wrong.FileId++
Reject {[Syndocal.Maintenance.ColdCompression]::Process($changed,$true,$wrong)}
$wrong=[Syndocal.Maintenance.ColdCompression]::Process($changed,$false,$null);$wrong.Path=Join-Path $fixtureRoot 'different.txt'
Reject {[Syndocal.Maintenance.ColdCompression]::Process($changed,$true,$wrong)}
$shared=Write-Fixture -Name 'shared.txt' -Bytes ([Text.Encoding]::UTF8.GetBytes(('d'*131072)))
[void](New-Item -ItemType HardLink -Path (Join-Path $fixtureRoot 'alias.txt') -Target $shared)
Reject {[Syndocal.Maintenance.ColdCompression]::Process($shared,$false,$null)}
$writer=[IO.File]::Open($changed,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::ReadWrite)
try{Reject {[Syndocal.Maintenance.ColdCompression]::Process($changed,$false,$null)}}finally{$writer.Dispose()}
$readonly=Write-Fixture -Name 'readonly.txt' -Bytes ([Text.Encoding]::UTF8.GetBytes(('e'*131072)))
[IO.File]::SetAttributes($readonly,[IO.FileAttributes]::ReadOnly)
Reject {[Syndocal.Maintenance.ColdCompression]::Process($readonly,$false,$null)}
$small=Write-Fixture -Name 'small.txt' -Bytes ([Text.Encoding]::UTF8.GetBytes('small'))
Reject {[Syndocal.Maintenance.ColdCompression]::Process($small,$false,$null)}
Reject {[Syndocal.Maintenance.ColdCompression]::Process($fixtureRoot,$false,$null)}
$target=Join-Path $fixtureRoot 'target';[void](New-Item -ItemType Directory -Path $target)
$targetFile=Join-Path $target 'source.txt';[IO.File]::WriteAllText($targetFile,('x'*131072),[Text.UTF8Encoding]::new($false))
$link=Join-Path $fixtureRoot 'link';[void](New-Item -ItemType Junction -Path $link -Target $target)
Reject {[Syndocal.Maintenance.ColdCompression]::Process((Join-Path $link 'source.txt'),$false,$null)}
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'));$dev=Join-Path $env:LOCALAPPDATA 'SyndocalDev'
foreach($bad in @('target/release/example.dll','target/qa/release-candidate-20261115/result.json','target/qa/task20/native/test.txt','target/qa/steroids-60fps-design-20261025/c5/run-c5.py','target/qa/old/node_modules/data.json','target/qa/old/sdk/test.lib','../outside.txt','target/qa/../escape.txt')){
    Reject {Resolve-ColdCompressionPath -RepositoryRoot $repo -DevRoot $dev -Spec ([pscustomobject]@{root='repo';relative=$bad})}
}
$good=Resolve-ColdCompressionPath -RepositoryRoot $repo -DevRoot $dev -Spec ([pscustomobject]@{root='repo';relative='target/qa/old-test/results.json'})
if(-not $good.EndsWith('old-test\results.json')){throw 'Canonical allowed path failed'};$count++
$sample=Join-Path $fixtureRoot 'manifest.json.gz';Write-ColdCompressionManifest -Path $sample -Value ([ordered]@{schema=1;files=@([ordered]@{value='日本語'})})
if((Read-ColdCompressionManifest -Path $sample).files[0].value -cne '日本語'){throw 'Compressed manifest round trip failed'};$count++
Write-Output "PASS $count compression safety checks; retained bounded fixture: $fixtureRoot"
