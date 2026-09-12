
# 🔐 QSKA — Quick SSH Key Assistant

<div  align="center">

**Configura tu acceso SSH en segundos desde Windows.**

Un script de PowerShell que pregunta IP, puerto y alias, los agrega a tu `~/.ssh/config`, gestiona tu llave `ed25519` (o crea una nueva) y la instala en el servidor remoto. Todo en un solo comando.

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell&logoColor=white)](https://github.com/S-mazo/QSKA)

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

[![Platform](https://img.shields.io/badge/Platform-Windows-lightgrey?logo=windows&logoColor=white)](https://github.com/S-mazo/QSKA)

</div>

---

## 📖 ¿Qué es QSKA?

**QSKA** (*Quick SSH Key Assistant*) es un *bootstrap* de conexión SSH para Windows. Está pensado para ejecutarse directamente desde internet con `irm | iex` y dejar tu acceso SSH listo en menos de un minuto, sin tener que editar manualmente archivos de configuración ni recordar comandos de `ssh-keygen` o `ssh-copy-id` (que ni siquiera existe nativamente en Windows).

En resumen, hace esto por ti:

1. 📝 **Pregunta** la IP/hostname, puerto, alias y usuario del servidor.

2. 💾 **Agrega** el alias a tu `~/.ssh/config` (con backup automático del archivo anterior).

3. 🔑 **Detecta** tus llaves SSH existentes (`ed25519`, `ecdsa`, `rsa`) o **crea** una nueva llave `ed25519` si no tienes ninguna.

4. 🚀 **Instala** tu llave pública en el servidor remoto (equivalente a `ssh-copy-id` en Linux/Mac).

Al terminar, solo necesitas escribir:

```powershell

ssh mi-alias

```

...y ya estás dentro. Sin contraseñas, sin IPs largas, sin puertos raros.

---

## 🚀 Uso rápido

### Opción 1 — Ejecución directa desde internet (recomendada)

Abre PowerShell y pega:

```powershell

irm https://ssh.s-mazo.tech/ | iex

```

O directamente desde GitHub:

```powershell

irm https://raw.githubusercontent.com/S-mazo/QSKA/main/quickconnect.ps1 | iex

```

> ⚠️ **Transparencia total:** Este script está diseñado para ejecutarse de esta forma, pero puedes (y debes) revisar el código fuente antes de correrlo. Solo toca tu carpeta `~/.ssh` (config y llaves). No cambia políticas del sistema, no envía datos a ningún lado ni instala nada fuera de OpenSSH.

### Opción 2 — Descarga local

```powershell

# Clona el repo

git clone https://github.com/S-mazo/QSKA.git

cd QSKA

# Ejecuta el script

.\quickconnect.ps1

```

---

## 🧩 Requisitos

| Requisito | Detalle |
|-----------|---------|
| **Sistema operativo** | Windows 10/11 (o Windows Server con PowerShell) |
| **PowerShell** | 5.1 o superior |
| **OpenSSH Client** | Habilitado en Windows (viene por defecto en Windows 10 1809+) |

Para verificar que tienes OpenSSH instalado:

```powershell

Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH*'

```

Si no está instalado:

```powershell

Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0

```

---

## 🛡️ ¿Qué hace exactamente el script?

### 1. Recolección de datos local (no se envían tus datos a ningún servidor)

Te pide 4 cosas, validando cada una:

| Campo | Validación | Ejemplo |
|-------|-----------|---------|
| **IP o hostname** | No puede estar vacío | `192.168.1.100` o `mi-servidor.com` |
| **Puerto SSH** | Número entre 1 y 65535 (Enter = 22) | `22` o `2222` |
| **Alias** | Solo letras, números, `-` y `_` | `mi-vps`, `servidor_prod` |
| **Usuario SSH** | No puede estar vacío | `root`, `ubuntu`, `sam` |

### 2. Backup y actualización del `~/.ssh/config`

- Si ya tienes un `config`, crea un backup automático en `config.bak`.

- Si el alias ya existe, te pregunta si quieres reemplazarlo (con opción de cancelar).

- Agrega el nuevo bloque `Host` al final del archivo.

Ejemplo de lo que añade:

```ssh-config

Host mi-vps

HostName 192.168.1.100

Port 22

User root

```

### 3. Gestión de llaves SSH

-  **Si tienes llaves existentes** (`id_ed25519`, `id_ecdsa`, `id_rsa`), te las lista y te deja elegir cuál usar (con `id_ed25519` como opción por defecto).

-  **Si no tienes llaves**, te ofrece crear una nueva `ed25519` con `ssh-keygen`.

### 4. Instalación de la llave en el servidor remoto

Usa el alias recién creado para conectar vía SSH y añade tu llave pública a `~/.ssh/authorized_keys` del servidor remoto, con los permisos correctos (`700` para `~/.ssh`, `600` para `authorized_keys`). Esto es exactamente lo que hace `ssh-copy-id` en Linux/Mac, pero desde Windows.

---

## 🔒 Seguridad

- ✅ **Solo toca `~/.ssh`**: El script únicamente modifica archivos dentro de tu carpeta `.ssh` (config y llaves). No toca nada más del sistema.

- ✅ **Backup automático**: Tu `config` original siempre queda respaldado en `config.bak`.

- ✅ **Sin envío de datos**: No se envía información a servidores externos. La única conexión que se hace es la SSH que tú mismo configuras.

- ✅ **Código abierto**: Puedes revisar línea por línea el script antes de ejecutarlo. Está en [`quickconnect.ps1`](quickconnect.ps1).

- ✅ **Validación de entradas**: IP, puerto y alias se validan antes de escribir nada.

---

## 📂 Estructura del repositorio

```

QSKA/

├── quickconnect.ps1 # Script principal (todo ocurre aquí)

├── LICENSE # Licencia MIT

└── README.md # Este archivo

```

---

## ❓ FAQ

### ¿Puedo usar esto en Linux o Mac?

No es necesario. En Linux/Mac ya existe `ssh-copy-id` y la edición de `~/.ssh/config` es trivial. QSKA está pensado específicamente para Windows, donde ese proceso es más tedioso.

### ¿Qué pasa si ya tengo un alias con el mismo nombre?

El script detecta el conflicto, te muestra un aviso y te pregunta si quieres reemplazarlo. Si eliges "N", cancela la operación sin cambiar nada.

### ¿Necesito ejecutar PowerShell como administrador?

No. El script trabaja únicamente dentro de tu carpeta de usuario (`~/.ssh`), así que no necesitas privilegios elevados.

### ¿Funciona con llaves passphrase-protegidas?

Sí, pero tendrás que introducir la passphrase cuando el script use la llave para conectar al servidor. Considera usar `ssh-agent` si quieres evitar escribirla repetidamente.

### ¿Puedo contribuir?

¡Claro! Haz fork, abre un issue o envía un PR. Toda mejora es bienvenida.

---

## 📜 Licencia

Este proyecto está bajo la licencia [MIT](LICENSE). Siéntete libre de usarlo, modificarlo y distribuirlo.

---

<div  align="center">

**Hecho con ❤️ por [Samuel Mazo](https://s-mazo.tech/)**

⭐ Si te sirvió, considera darle una estrella al repo.

</div>
