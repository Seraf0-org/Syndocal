# Native path, identity and checkpoint gates used by the dated cleanup.
# Extracted unchanged from the retained historical cleanup harness.
Set-StrictMode -Version Latest
if (-not ("Syndocal.Cleanup.NativePathProbe" -as [type])) {
    Add-Type -TypeDefinition @'
namespace Syndocal.Cleanup
{
    using System;
    using System.ComponentModel;
    using System.Runtime.InteropServices;
    using System.Text;

    public sealed class EntryProbe
    {
        public string FinalPath { get; set; }
        public uint VolumeSerialNumber { get; set; }
        public ulong FileIndex { get; set; }
        public uint LinkCount { get; set; }
    }

    public static class NativePathProbe
    {
        [StructLayout(LayoutKind.Sequential)]
        private struct FILETIME
        {
            public uint LowPart;
            public uint HighPart;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct BY_HANDLE_FILE_INFORMATION
        {
            public uint FileAttributes;
            public FILETIME CreationTime;
            public FILETIME LastAccessTime;
            public FILETIME LastWriteTime;
            public uint VolumeSerialNumber;
            public uint FileSizeHigh;
            public uint FileSizeLow;
            public uint NumberOfLinks;
            public uint FileIndexHigh;
            public uint FileIndexLow;
        }

        [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode, ExactSpelling = true)]
        private static extern IntPtr CreateFileW(
            string lpFileName,
            uint dwDesiredAccess,
            uint dwShareMode,
            IntPtr lpSecurityAttributes,
            uint dwCreationDisposition,
            uint dwFlagsAndAttributes,
            IntPtr hTemplateFile);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool GetFileInformationByHandle(
            IntPtr hFile,
            out BY_HANDLE_FILE_INFORMATION lpFileInformation);

        [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        private static extern uint GetFinalPathNameByHandleW(
            IntPtr hFile,
            StringBuilder lpszFilePath,
            uint cchFilePath,
            uint dwFlags);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool CloseHandle(IntPtr hObject);

        private const uint FileReadAttributes = 0x00000080;
        private const uint FileShareReadWriteDelete = 0x00000007;
        private const uint OpenExisting = 3;
        private const uint FileFlagBackupSemantics = 0x02000000;

        private static string ToDosPath(string path)
        {
            if (path.StartsWith(@"\\?\UNC\", StringComparison.OrdinalIgnoreCase))
            {
                return @"\\" + path.Substring(8);
            }
            if (path.StartsWith(@"\\?\", StringComparison.OrdinalIgnoreCase))
            {
                return path.Substring(4);
            }
            return path;
        }

        public static EntryProbe Probe(string path)
        {
            IntPtr handle = CreateFileW(
                path,
                FileReadAttributes,
                FileShareReadWriteDelete,
                IntPtr.Zero,
                OpenExisting,
                FileFlagBackupSemantics,
                IntPtr.Zero);
            if (handle == IntPtr.Zero || handle == new IntPtr(-1))
            {
                throw new Win32Exception(
                    Marshal.GetLastWin32Error(),
                    "Unable to open cleanup entry: " + path);
            }

            try
            {
                BY_HANDLE_FILE_INFORMATION info;
                if (!GetFileInformationByHandle(handle, out info))
                {
                    throw new Win32Exception(
                        Marshal.GetLastWin32Error(),
                        "Unable to query cleanup entry: " + path);
                }

                StringBuilder buffer = new StringBuilder(1024);
                uint length = GetFinalPathNameByHandleW(handle, buffer, (uint)buffer.Capacity, 0);
                if (length == 0)
                {
                    throw new Win32Exception(
                        Marshal.GetLastWin32Error(),
                        "Unable to resolve final cleanup path: " + path);
                }
                if (length >= buffer.Capacity)
                {
                    buffer = new StringBuilder((int)length + 1);
                    length = GetFinalPathNameByHandleW(handle, buffer, (uint)buffer.Capacity, 0);
                    if (length == 0 || length >= buffer.Capacity)
                    {
                        throw new Win32Exception(
                            Marshal.GetLastWin32Error(),
                            "Unable to resolve complete final cleanup path: " + path);
                    }
                }

                return new EntryProbe
                {
                    FinalPath = ToDosPath(buffer.ToString()),
                    VolumeSerialNumber = info.VolumeSerialNumber,
                    FileIndex = ((ulong)info.FileIndexHigh << 32) | info.FileIndexLow,
                    LinkCount = info.NumberOfLinks
                };
            }
            finally
            {
                CloseHandle(handle);
            }
        }
    }
}
'@
}

function New-SyndocalCleanupException {
    param(
        [Parameter(Mandatory)]
        [string]$Code,
        [Parameter(Mandatory)]
        [string]$Message
    )

    $exception = New-Object System.InvalidOperationException($Message)
    $exception.Data["SyndocalCleanupCode"] = $Code
    return $exception
}

function Throw-SyndocalCleanupGate {
    param(
        [Parameter(Mandatory)]
        [string]$Code,
        [Parameter(Mandatory)]
        [string]$Message
    )

    throw (New-SyndocalCleanupException -Code $Code -Message $Message)
}

function Get-SyndocalCleanupFullPath {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        Throw-SyndocalCleanupGate -Code "EmptyPath" -Message "An empty cleanup path is forbidden."
    }
    try {
        $full = [IO.Path]::GetFullPath($Path)
    } catch {
        Throw-SyndocalCleanupGate -Code "InvalidPath" -Message "The cleanup path is invalid: $Path"
    }
    $root = [IO.Path]::GetPathRoot($full)
    if ($full.Length -gt $root.Length) {
        $full = $full.TrimEnd([char[]]@("\", "/"))
    }
    return $full
}

function Test-SyndocalCleanupPathEqual {
    param(
        [Parameter(Mandatory)]
        [string]$Left,
        [Parameter(Mandatory)]
        [string]$Right
    )

    return (Get-SyndocalCleanupFullPath -Path $Left).Equals(
        (Get-SyndocalCleanupFullPath -Path $Right),
        [StringComparison]::OrdinalIgnoreCase
    )
}

function Test-SyndocalCleanupPathUnder {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        [string]$Root
    )

    $pathFull = Get-SyndocalCleanupFullPath -Path $Path
    $rootFull = Get-SyndocalCleanupFullPath -Path $Root
    if ($pathFull.Equals($rootFull, [StringComparison]::OrdinalIgnoreCase)) {
        return $false
    }
    return $pathFull.StartsWith(
        $rootFull + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase
    )
}

function Assert-SyndocalCleanupNoReparseItem {
    param(
        [Parameter(Mandatory)]
        $Item
    )

    if (($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        Throw-SyndocalCleanupGate -Code "ReparsePointDetected" -Message "A reparse point is forbidden in a cleanup path: $($Item.FullName)"
    }
}

function Assert-SyndocalCleanupNoReparseAncestry {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $full = Get-SyndocalCleanupFullPath -Path $Path
    if (-not (Test-Path -LiteralPath $full)) {
        Throw-SyndocalCleanupGate -Code "MissingPath" -Message "Cleanup ancestry path is missing: $full"
    }

    $cursor = Get-Item -LiteralPath $full -Force
    while ($null -ne $cursor) {
        Assert-SyndocalCleanupNoReparseItem -Item $cursor
        $parent = $cursor.Parent
        if ($null -eq $parent -or $parent.FullName -eq $cursor.FullName) {
            break
        }
        $cursor = $parent
    }
}

function Invoke-SyndocalCleanupGit {
    param(
        [Parameter(Mandatory)]
        [string]$RepositoryRoot,
        [Parameter(Mandatory)]
        [string[]]$Arguments,
        [Parameter(Mandatory)]
        [string]$FailureCode
    )

    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $output = @(& git -C $RepositoryRoot @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    if ($exitCode -ne 0) {
        $diagnostic = (($output | ForEach-Object { [string]$_ }) -join " ").Trim()
        Throw-SyndocalCleanupGate -Code $FailureCode -Message "Git gate failed ($FailureCode): $diagnostic"
    }
    return @($output | ForEach-Object { [string]$_ })
}

function Assert-SyndocalCleanupRepositoryCheckpoint {
    param(
        [Parameter(Mandatory)]
        [string]$RepositoryRoot,
        [switch]$TestSeam
    )

    $repositoryFull = Get-SyndocalCleanupFullPath -Path $RepositoryRoot
    $topLevel = (Invoke-SyndocalCleanupGit -RepositoryRoot $repositoryFull -Arguments @("rev-parse", "--show-toplevel") -FailureCode "GitTopLevelUnavailable" | Out-String).Trim()
    $topLevel = Get-SyndocalCleanupFullPath -Path ($topLevel.Replace("/", "\"))
    if (-not (Test-SyndocalCleanupPathEqual -Left $topLevel -Right $repositoryFull)) {
        Throw-SyndocalCleanupGate -Code "CheckoutRootMismatch" -Message "Git top-level does not equal the exact cleanup checkout root: git=$topLevel expected=$repositoryFull"
    }

    $branch = (Invoke-SyndocalCleanupGit -RepositoryRoot $repositoryFull -Arguments @("symbolic-ref", "--quiet", "--short", "HEAD") -FailureCode "BranchUnavailable" | Out-String).Trim()
    $head = (Invoke-SyndocalCleanupGit -RepositoryRoot $repositoryFull -Arguments @("rev-parse", "HEAD") -FailureCode "HeadUnavailable" | Out-String).Trim()
    $upstream = (Invoke-SyndocalCleanupGit -RepositoryRoot $repositoryFull -Arguments @("rev-parse", "@{upstream}") -FailureCode "UpstreamUnavailable" | Out-String).Trim()
    if ($head -cne $upstream) {
        Throw-SyndocalCleanupGate -Code "Diverged" -Message "HEAD must equal its pushed upstream before cleanup: HEAD=$head upstream=$upstream"
    }

    $status = @(Invoke-SyndocalCleanupGit -RepositoryRoot $repositoryFull -Arguments @("status", "--porcelain=v1", "--untracked-files=all") -FailureCode "GitStatusUnavailable")
    $dirtyLines = @($status | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    if ($dirtyLines.Count -ne 0) {
        Throw-SyndocalCleanupGate -Code "DirtyWorktree" -Message "The checkout must be clean before cleanup."
    }

    if (-not $TestSeam) {
        $trackedHarness = @(Invoke-SyndocalCleanupGit -RepositoryRoot $repositoryFull -Arguments @("ls-files", "--", $script:SyndocalCleanupHarnessRelativePath) -FailureCode "HarnessTrackingCheckFailed")
        if (@($trackedHarness | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }).Count -ne 1) {
            Throw-SyndocalCleanupGate -Code "HarnessNotTracked" -Message "The cleanup harness must be tracked at the clean pushed checkpoint before -Apply."
        }
    }

    return [pscustomobject]@{
        Branch = $branch
        Head = $head
        Upstream = $upstream
        Clean = $true
        Toplevel = $topLevel
    }
}

function Assert-SyndocalCleanupCandidateUntracked {
    param(
        [Parameter(Mandatory)]
        [string]$RepositoryRoot,
        [Parameter(Mandatory)]
        [string]$RelativePath
    )

    $gitPath = $RelativePath.Replace("\", "/")
    $tracked = @(Invoke-SyndocalCleanupGit -RepositoryRoot $RepositoryRoot -Arguments @("ls-files", "--", $gitPath) -FailureCode "TrackedFileCheckFailed")
    $tracked = @($tracked | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    if ($tracked.Count -ne 0) {
        Throw-SyndocalCleanupGate -Code "TrackedContentDetected" -Message "The cleanup candidate contains tracked content: $($tracked -join ', ')"
    }
}

function Assert-SyndocalCleanupSnapshotsEqual {
    param(
        [Parameter(Mandatory)]
        $Expected,
        [Parameter(Mandatory)]
        $Actual,
        [string]$FailureCode = "CandidateChanged"
    )

    $same =
        $Expected.ResolvedPath.Equals($Actual.ResolvedPath, [StringComparison]::OrdinalIgnoreCase) -and
        [uint32]$Expected.VolumeSerialNumber -eq [uint32]$Actual.VolumeSerialNumber -and
        [uint64]$Expected.FileIndex -eq [uint64]$Actual.FileIndex -and
        [int64]$Expected.LogicalBytes -eq [int64]$Actual.LogicalBytes -and
        [int64]$Expected.NewestWriteTicks -eq [int64]$Actual.NewestWriteTicks -and
        [int]$Expected.FileCount -eq [int]$Actual.FileCount -and
        [int]$Expected.DirectoryCount -eq [int]$Actual.DirectoryCount -and
        [string]$Expected.FingerprintSha256 -ceq [string]$Actual.FingerprintSha256
    if (-not $same) {
        Throw-SyndocalCleanupGate -Code $FailureCode -Message "Candidate size/mtime/identity changed between safety samples: $($Expected.Path)"
    }
}
