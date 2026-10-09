# Architecture

Iranian PC-POS SDKs are Windows .NET Framework services. The browser (or your
backend) never talks to the terminal directly.

```
Your app / curl / browser
        │
        │  HTTP (SignalR or REST — PSP-specific)
        ▼
Linux host (Docker + Wine)
        │  official Windows PC-POS service
        ▼
POS terminal on LAN  (SEP: TCP 1197, Iran Kish: TCP 1100)
```

## Why Wine

The vendor packages are PE32 .NET Framework 4.x Windows services (OWIN
SignalR or WCF/REST). They are not .NET Core apps. Wine + Wine Mono is the
path that actually runs them on Linux.

## Why `network_mode: host`

The container must open a TCP session to the terminal’s LAN IP. Docker bridge
NAT often breaks that. Host networking is the reliable default on Linux.

## Do not run two stacks at once

Local Wine and the Docker container both bind the same host ports
(`8080` for SEP, `9500` for Iran Kish). Stop one before starting the other.

## Optional REST helper (SEP)

SEP’s native API is ASP.NET SignalR hub `SSP1126HUB`. The small Python
bridge in `psp/sep/docker/api_bridge.py` only exists so `curl` can send an
amount in one HTTP POST. Production apps can speak SignalR directly.
