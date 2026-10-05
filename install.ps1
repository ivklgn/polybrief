# Install polybrief on Windows (PowerShell 5.1+):
#   irm https://raw.githubusercontent.com/ivklgn/polybrief/main/install.ps1 | iex
# $env:POLYBRIEF_VERSION = 'vX.Y.Z' picks a release (default: latest).
# $env:POLYBRIEF_INSTALL_DIR picks the target directory (default: %LOCALAPPDATA%\Programs\polybrief).
& {
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'
    $repo = 'ivklgn/polybrief'
    $arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'amd64' }
    $base = if ($env:POLYBRIEF_VERSION) { "https://github.com/$repo/releases/download/$env:POLYBRIEF_VERSION" }
            else { "https://github.com/$repo/releases/latest/download" }
    $dir = if ($env:POLYBRIEF_INSTALL_DIR) { $env:POLYBRIEF_INSTALL_DIR } else { "$env:LOCALAPPDATA\Programs\polybrief" }
    $file = "polybrief_windows_$arch.zip"

    $tmp = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid())
    New-Item -ItemType Directory $tmp | Out-Null
    try {
        Write-Host "Downloading $base/$file"
        Invoke-WebRequest "$base/$file" -OutFile "$tmp\$file" -UseBasicParsing
        Invoke-WebRequest "$base/checksums.txt" -OutFile "$tmp\checksums.txt" -UseBasicParsing
        $line = Get-Content "$tmp\checksums.txt" | Where-Object { $_ -match " $([regex]::Escape($file))$" } | Select-Object -First 1
        $want = if ($line) { ($line -split '\s+')[0] }
        $got = (Get-FileHash "$tmp\$file" -Algorithm SHA256).Hash
        if (-not $want -or $want -ne $got) { throw "checksum mismatch for $file" }

        Expand-Archive "$tmp\$file" -DestinationPath "$tmp\x" -Force
        New-Item -ItemType Directory $dir -Force | Out-Null
        Move-Item "$tmp\x\polybrief.exe" "$dir\polybrief.exe" -Force
    } finally {
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }

    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ((";$userPath;" -split ';') -notcontains $dir) {
        $newPath = if ($userPath) { "$($userPath.TrimEnd(';'));$dir" } else { $dir }
        [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
        $env:Path += ";$dir"
        Write-Host "Added $dir to your user PATH; new terminals will see it."
    }
    Write-Host "Installed $(& "$dir\polybrief.exe" --version) to $dir\polybrief.exe"
}
