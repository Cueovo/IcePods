$originalCookie = $env:QQMUSIC_COOKIE

if ([string]::IsNullOrWhiteSpace($originalCookie)) {
    throw 'QQMUSIC_COOKIE is not set'
}

$testCookie = $originalCookie -replace `
    '(^|;\s*)login_type=1(?=;|$)', `
    '$1login_type=2'

$expires = [regex]::Match(
    $testCookie,
    '(?:^|;\s*)psrf_access_token_expiresAt=([^;]+)'
)

if (
    $expires.Success -and
    $testCookie -notmatch '(?:^|;\s*)expired_at='
) {
    $testCookie = $testCookie + '; expired_at=' + $expires.Groups[1].Value
}

$env:QQMUSIC_COOKIE = $testCookie
$scriptExit = 1

try {
    python (Join-Path $PSScriptRoot 'refresh_qqmusic_credential.py') `
        like 523664346 `
        --refresh-first login `
        --retry-delays 1 5 `
        --minimal-cookie

    $scriptExit = $LASTEXITCODE
}
finally {
    $env:QQMUSIC_COOKIE = $originalCookie
}

Write-Output ('script_exit={0}' -f $scriptExit)
exit $scriptExit
