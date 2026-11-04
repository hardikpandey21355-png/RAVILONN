param(
    [string]$DeviceId
)

$ErrorActionPreference = 'Stop'
$adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'

if (-not (Test-Path -LiteralPath $adb)) {
    throw "Android Debug Bridge was not found at $adb."
}

$listeners = Get-NetTCPConnection -State Listen -LocalPort 5000 -ErrorAction SilentlyContinue
if (-not $listeners) {
    throw 'The backend is not listening on port 5000. Start it with python run.py first.'
}

$connectedDevices = @(
    & $adb devices |
        Select-Object -Skip 1 |
        Where-Object { $_ -match '^(\S+)\s+device$' } |
        ForEach-Object { [regex]::Match($_, '^(\S+)').Groups[1].Value }
)

if (-not $DeviceId) {
    if ($connectedDevices.Count -ne 1) {
        throw 'Connect one Android phone, or pass its serial with -DeviceId.'
    }
    $DeviceId = $connectedDevices[0]
} elseif ($connectedDevices -notcontains $DeviceId) {
    throw "Android device '$DeviceId' is not connected and authorized."
}

& $adb -s $DeviceId reverse tcp:5000 tcp:5000
if ($LASTEXITCODE -ne 0) {
    throw "Could not forward API port 5000 to device '$DeviceId'."
}

Push-Location (Split-Path $PSScriptRoot -Parent)
try {
    flutter run --debug -d $DeviceId
    if ($LASTEXITCODE -ne 0) {
        throw 'Flutter could not launch the app on the connected phone.'
    }
} finally {
    Pop-Location
}
