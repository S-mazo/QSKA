<#
.SYNOPSIS
    Bootstrap de conexión SSH: crea el alias en el config, gestiona la llave
    y la instala en el servidor remoto (equivalente a ssh-copy-id en Windows).

.NOTA DE SEGURIDAD
    Este script se distribuye para ejecutarse con "irm https://ssh.s-mazo.tech/ | iex". Antes de
    correrlo en tu equipo, si quieres, revisa el código fuente aquí:
    https://raw.githubusercontent.com/S-mazo/QSKA/main/quickconnect.ps1
    Solo toca tu carpeta ~/.ssh (config y llaves). No cambia políticas del
    sistema, no envía datos a ningún lado ni instala nada fuera de OpenSSH.

.USAGE
    irm https://raw.githubusercontent.com/S-mazo/QSKA/main/quickconnect.ps1 | iex
    ó alternativamente puedes usar
    irm https://ssh.s-mazo.tech/ | iex
 
#>

$ErrorActionPreference = "Stop"

function Write-Info($msg) { Write-Host $msg -ForegroundColor Cyan }
function Write-Warn($msg) { Write-Host $msg -ForegroundColor Yellow }
function Write-Ok($msg)   { Write-Host $msg -ForegroundColor Green }
function Write-Err($msg)  { Write-Host $msg -ForegroundColor Red }

Write-Host ""
Write-Err "====================================="
Write-Warn " Script hecho por Samuel Mazo"
Write-Warn " Visita mi web: https://s-mazo.tech/"
Write-Err "====================================="
Write-Host ""
Write-Info "Fuente de este script: https://github.com/S-mazo/QSKA (eres bienvenid@ a revisar el codigo si quieres)"
Write-Info "Este script solo modifica tu carpeta ~/.ssh (config y llaves)."
Write-Host ""

# --- 1. Datos de conexión (con validación) ---
do {
    $ip = Read-Host "IP o hostname del servidor"
} while ([string]::IsNullOrWhiteSpace($ip))

do {
    $port = Read-Host "Puerto SSH (Enter = 22)"
    if ([string]::IsNullOrWhiteSpace($port)) { $port = "22" }
    $portValid = $port -match '^\d+$' -and [int]$port -ge 1 -and [int]$port -le 65535
    if (-not $portValid) { Write-Warn "Puerto invalido, debe ser un numero entre 1 y 65535." }
} while (-not $portValid)

do {
    $alias = Read-Host "Alias para este host (solo letras, numeros, guiones o guion bajo)"
    $aliasValid = $alias -match '^[A-Za-z0-9_-]+$'
    if (-not $aliasValid) { Write-Warn "Alias invalido. Usa solo letras, numeros, '-' o '_'." }
} while (-not $aliasValid)

do {
    $user = Read-Host "Usuario SSH remoto"
} while ([string]::IsNullOrWhiteSpace($user))

$sshDir     = Join-Path $HOME ".ssh"
$configPath = Join-Path $sshDir "config"

if (-not (Test-Path $sshDir)) {
    New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
}

# --- 2. Backup y actualización del config ---
$overwriteBlock = $false

if (Test-Path $configPath) {
    Copy-Item $configPath "$configPath.bak" -Force
    Write-Info "Backup creado en: $configPath.bak"

    $existingConfig = Get-Content $configPath -Raw
    if ($existingConfig -match "(?ms)^Host\s+$([regex]::Escape($alias))\s*$.*?(?=^Host\s|\z)") {
        Write-Warn "Ya existe un Host '$alias' en tu config."
        $resp = Read-Host "Quieres reemplazarlo? (S/N, N = cancelar)"
        if ($resp -match '^[sS]') {
            $overwriteBlock = $true
            $newConfig = [regex]::Replace(
                $existingConfig,
                "(?ms)^Host\s+$([regex]::Escape($alias))\s*$.*?(?=^Host\s|\z)",
                ""
            )
            Set-Content -Path $configPath -Value $newConfig.TrimEnd()
        }
        else {
            Write-Err "Cancelado. No se modifico el alias existente."
            exit 1
        }
    }
}

$entry = @"

Host $alias
    HostName $ip
    Port $port
    User $user
"@

Add-Content -Path $configPath -Value $entry
Write-Ok "Alias '$alias' agregado a $configPath"

# --- 3. Detección / creación de llave ---
$keyTypes = @("id_ed25519", "id_ecdsa", "id_rsa")
$existingKeys = $keyTypes | Where-Object { Test-Path (Join-Path $sshDir $_) }

$selectedKey = $null

if ($existingKeys.Count -gt 0) {
    Write-Info "Llaves SSH encontradas:"
    for ($i = 0; $i -lt $existingKeys.Count; $i++) {
        Write-Host "  [$i] $($existingKeys[$i])"
    }

    $defaultKey = $existingKeys | Where-Object { $_ -eq "id_ed25519" } | Select-Object -First 1
    $promptDefault = if ($defaultKey) { " (Enter = id_ed25519)" } else { "" }
    $choice = Read-Host "Cual quieres usar?$promptDefault"

    if ([string]::IsNullOrWhiteSpace($choice)) {
        $selectedKey = if ($defaultKey) { $defaultKey } else { $existingKeys[0] }
    }
    elseif ($choice -match '^\d+$' -and [int]$choice -lt $existingKeys.Count) {
        $selectedKey = $existingKeys[[int]$choice]
    }
    else {
        Write-Warn "Opción inválida, usando la primera disponible: $($existingKeys[0])"
        $selectedKey = $existingKeys[0]
    }
}
else {
    $create = Read-Host "No hay llaves SSH. Quieres crear una nueva ed25519? (S/N)"
    if ($create -match '^[sS]') {
        $newKeyPath = Join-Path $sshDir "id_ed25519"
        ssh-keygen -t ed25519 -f $newKeyPath
        $selectedKey = "id_ed25519"
    }
    else {
        Write-Warn "No se puede continuar sin una llave SSH. Abortando."
        exit 1
    }
}

$pubKeyPath = Join-Path $sshDir "$selectedKey.pub"
if (-not (Test-Path $pubKeyPath)) {
    Write-Warn "No se encontró la llave pública en $pubKeyPath. Abortando."
    exit 1
}
$pubKeyContent = (Get-Content $pubKeyPath -Raw).Trim()

# --- 4. Instalar la llave en el servidor remoto ---
# Usamos el alias recien creado (ssh ya lee el config actualizado al vuelo,
# no hace falta reiniciar la sesion) en vez de user@ip directo.
Write-Info "Conectando a '$alias' ($user@$ip`:$port) para instalar la llave publica..."
Write-Info "Te pedira la contrasena del usuario remoto (una sola vez)."

$remoteCmd = 'umask 077; mkdir -p ~/.ssh && touch ~/.ssh/authorized_keys && cat >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys'

try {
    $pubKeyContent | ssh $alias $remoteCmd
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "Llave instalada correctamente en el servidor."
        Write-Ok "Listo. Ahora puedes conectarte simplemente con: ssh $alias"
    }
    else {
        Write-Warn "El comando ssh termino con codigo $LASTEXITCODE. Revisa la conexion manualmente:"
        Write-Warn "  ssh $alias"
    }
}
catch {
    Write-Err "No se pudo conectar al servidor para instalar la llave: $($_.Exception.Message)"
    Write-Warn "El alias y la llave ya quedaron configurados localmente; intenta instalar la llave manualmente con:"
    Write-Warn "  type $pubKeyPath | ssh $alias `"mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys`""
}
