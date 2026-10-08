[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Message,

    [string]$Tag,

    [switch]$SkipVerify,

    [switch]$NoPush,

    [switch]$AllowEmpty
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location -LiteralPath $projectRoot

if (-not (Test-Path -LiteralPath (Join-Path $projectRoot '.git'))) {
    throw "Not a Git repository: $projectRoot"
}

if (-not $SkipVerify) {
    $verifyScript = Join-Path $PSScriptRoot 'verify_project.ps1'
    & powershell -NoProfile -ExecutionPolicy Bypass -File $verifyScript
    if ($LASTEXITCODE -ne 0) {
        throw "Project verification failed; no commit was created."
    }
}

git add -A
if (-not $AllowEmpty) {
    git diff --cached --quiet
    if ($LASTEXITCODE -eq 0) {
        Write-Output 'No staged changes; nothing to save.'
        exit 0
    }
}

git commit -m $Message
if ($LASTEXITCODE -ne 0) {
    throw "Git commit failed."
}

$commitSha = (git rev-parse HEAD).Trim()
Write-Output "LOCAL_COMMIT=$commitSha"

if ($Tag) {
    git tag -a $Tag -m $Message
    if ($LASTEXITCODE -ne 0) {
        throw "Git tag creation failed: $Tag"
    }
    Write-Output "TAG=$Tag"
}

if (-not $NoPush) {
    git push -u origin HEAD:main
    if ($LASTEXITCODE -ne 0) {
        Write-Warning 'Direct GitHub push failed. The local commit is preserved; retry with GitHub Desktop or after fixing the network. Do not upload large binary project files one-by-one through a connector.'
        exit 2
    }
    if ($Tag) {
        git push origin $Tag
        if ($LASTEXITCODE -ne 0) {
            throw "Tag push failed: $Tag"
        }
    }
    Write-Output 'GITHUB_PUSH=OK'
}
