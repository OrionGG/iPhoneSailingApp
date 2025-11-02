param(
    [Parameter(Mandatory=$true)]
    [string]$Path,
    [string]$Out = "-"
)

if (-Not (Test-Path $Path)) {
    Write-Error "File not found: $Path"
    exit 1
}

$b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($Path))

if ($Out -eq "-") {
    Write-Output $b64
} else {
    Set-Content -Path $Out -Value $b64
    Write-Output "Wrote base64 to $Out"
}

Write-Output "# Usage:`n# PowerShell (Windows): .\encode_p12.ps1 -Path .\\mycert.p12 > p12_base64.txt`n# macOS (pwsh): pwsh ./encode_p12.ps1 -Path ./mycert.p12 > p12_base64.txt"
