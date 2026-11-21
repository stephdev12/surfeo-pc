# Surfeo Client Multi-Plateforme (PC & Mobile)

Client VPN haute performance pour Windows, Linux, macOS et iOS, conçu avec **Flutter** et le moteur réseau **Surfeo Core** (Go).

---

## Architecture

- **Interface Utilisateur (`lib/`)** : Développée en Flutter. Offre une expérience fluide, réactive et identique sur toutes les plateformes (Thème Dark Neon, monitoring en temps réel des débits Tx/Rx, durée de session, jauge de consommation et gestion d'activation).
- **Moteur Réseau Core (`core/`)** : Développé en Go (`surfeo-core`).
  - Injection de payload HTTP personnalisée (compatible avec toutes les macros Surfeo : `[crlf]`, `[host]`, `[port]`, etc.).
  - Tunnel SSH (direct-tcpip) & SOCKS5 local sur `127.0.0.1:10808`.
  - Résolveur DNS sécurisé avec filtrage AAAA NODATA (0ms) et résolution DNS-over-TCP via SSH (1.1.1.1).
  - Filtrage QUIC (port 443 UDP drop) pour bascule automatique vers TCP HTTPS.
  - Pilote virtuel **Wintun** (`wintun.dll`) pour Windows et `/dev/net/tun` pour Linux.
  - API locale de contrôle REST sur `http://127.0.0.1:20888`.

---

## Compilation

### Compilation Automatique (GitHub Actions)
Chaque push sur la branche `master` ou `main` déclenche automatiquement les workflows :
- `.github/workflows/build-windows.yml` -> produit `Surfeo-Windows-x64.zip`
- `.github/workflows/build-linux.yml` -> produit `Surfeo-Linux-x64.tar.gz`

### Compilation Manuelle Locale (Windows)
1. **Compiler le moteur réseau :**
   ```powershell
   cd core
   go build -ldflags="-s -w -H=windowsgui" -o ../windows_bundle/surfeo-core.exe main.go
   cd ..
   ```
2. **Télécharger Wintun :**
   Placer `wintun.dll` (x64) dans le dossier de l'exécutable.
3. **Compiler Flutter :**
   ```powershell
   flutter pub get
   flutter build windows --release
   ```
