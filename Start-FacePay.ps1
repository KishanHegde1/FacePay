[CmdletBinding()]
param(
    [ValidateSet('app', 'build', 'check', 'backend')]
    [string]$Mode = 'app',
    [string]$Device,
    [string]$ApiBaseUrl = 'https://facepay-rtyr.onrender.com'
)

$ErrorActionPreference = 'Stop'
$frontendRoot = Join-Path $PSScriptRoot 'Frontend\flutter'
$backendRoot = Join-Path $PSScriptRoot 'Backend\rust'

function Invoke-Checked {
    param([string]$Executable, [string[]]$Arguments)
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "The command failed with exit code $LASTEXITCODE. See the output above."
    }
}

if (!(Test-Path -LiteralPath (Join-Path $frontendRoot 'pubspec.yaml')) -or
    !(Test-Path -LiteralPath (Join-Path $backendRoot 'Cargo.toml'))) {
    throw 'Keep this script at the FacePay project root, next to Frontend and Backend.'
}

if ($Mode -eq 'backend') {
    $cargoCommand = (Get-Command cargo -ErrorAction Stop).Source
    Push-Location -LiteralPath $backendRoot
    try { Invoke-Checked -Executable $cargoCommand -Arguments @('run') }
    finally { Pop-Location }
    return
}

[Uri]$apiUri = $null
if (![Uri]::TryCreate($ApiBaseUrl, [UriKind]::Absolute, [ref]$apiUri) -or
    $apiUri.Scheme -notin @('http', 'https') -or $apiUri.UserInfo -or
    $apiUri.Query -or $apiUri.Fragment) {
    throw 'ApiBaseUrl must be an HTTP(S) backend URL without credentials, query or fragment.'
}

$flutterCommand = (Get-Command flutter -ErrorAction Stop).Source
Push-Location -LiteralPath $frontendRoot
try {
    Invoke-Checked -Executable $flutterCommand -Arguments @('pub', 'get')
    switch ($Mode) {
        'app' {
            $runArguments = @('run', '--no-pub', "--dart-define=API_BASE_URL=$ApiBaseUrl")
            if ($Device) { $runArguments += @('-d', $Device) }
            Invoke-Checked -Executable $flutterCommand -Arguments $runArguments
        }
        'build' {
            Invoke-Checked -Executable $flutterCommand -Arguments @(
                'build', 'apk', '--debug', '--no-pub', "--dart-define=API_BASE_URL=$ApiBaseUrl"
            )
        }
        'check' {
            Invoke-Checked -Executable $flutterCommand -Arguments @('analyze', '--no-pub')
            Invoke-Checked -Executable $flutterCommand -Arguments @('test', '--no-pub')
        }
    }
} finally { Pop-Location }

if ($Mode -eq 'check') {
    $cargoCommand = (Get-Command cargo -ErrorAction Stop).Source
    Push-Location -LiteralPath $backendRoot
    try {
        Invoke-Checked -Executable $cargoCommand -Arguments @('fmt', '--check')
        Invoke-Checked -Executable $cargoCommand -Arguments @('test')
    } finally { Pop-Location }
}
