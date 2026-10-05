# Tailscale and networking

## Install and log in

```bash
curl -fsSL https://tailscale.com/install.sh -o /tmp/ts-install.sh   # read it, then:
sudo sh /tmp/ts-install.sh
sudo timeout 600 tailscale up > /tmp/ts-up.log 2>&1 &   # prints a login URL; give it to the user
cat /tmp/ts-up.log                                       # "Success." once they approve
tailscale ip -4; tailscale status
```

`tailscale status` may list devices the user doesn't control (shared tailnets, old
machines). Mention them: anything bound to the tailnet IP is reachable by them if ACLs
allow.

## Binding rules

- Bind dev servers to the **tailnet IP** (or 127.0.0.1), never `0.0.0.0` when you can
  avoid it. If a tool binds all interfaces (ws-scrcpy's `server.listen(port)`, Metro's
  `[::]`), patch it or rely on the existing default-deny firewall, and say which.
- Tailscale inserts its own accept rule for `tailscale0`, so tailnet peers reach ports the
  public ufw rules don't allow. You usually need no firewall change at all.
- **Shared servers: don't touch ufw.** A blanket "allow SSH only" plan would break other
  tenants' services (mail, previews…). Read the rules, report them, leave them.
- Docker-published ports bypass ufw; not relevant to these services, but remember it.
- Root-level persistence (new system units, iptables NAT rules) may be refused by the
  permission layer. Prefer user units and app-level fixes (e.g. `EXPO_PACKAGER_PROXY_URL`
  instead of an iptables redirect).

## Ports used in this setup

| Port | What | Bound to |
|---|---|---|
| 8554 | emulator gRPC | emulator (localhost) |
| 8887 | live view bridge | tailnet IP |
| 8081 | metro-proxy (what devices use) | 127.0.0.1 + tailnet IP |
| 18081 | Metro itself | all (firewall-protected) |
| 8888 | APK download page (`python3 -m http.server --bind <tailnet-ip>`) | tailnet IP |

Check a port is free first: `ss -tln | grep ':PORT '`. On the Optimal box 8090 was taken
by another tenant (Metro failed with "port in use" in non-interactive mode and the service
restart-looped).

## Measuring the link to the phone

```bash
tailscale ping -c 3 <phone-tailnet-ip>          # "via <ip:port>" = direct; "via DERP" = relayed
head -c 4000000 /dev/urandom > /tmp/4mb.bin && adb -s <serial> push /tmp/4mb.bin /data/local/tmp/   # prints MB/s
```

A user abroad on mobile/home broadband gave ~220–380 ms RTT and 0.05–0.5 MB/s. Design every
phone transfer for that: compress, batch, avoid re-downloads.

## Watching what a device actually sends

```bash
sudo timeout 70 tcpdump -i tailscale0 -nn -s 300 -A "tcp port 8081 and host <phone-ip>" > /tmp/tcp.txt &
grep -aoE "(GET|POST) /[^ ]{0,120} HTTP|HTTP/1.1 [0-9]{3}[^\r]*|Content-Encoding: [a-z]+" /tmp/tcp.txt
```

This found both the uncompressed multipart bundle and, later, that a failing app sent zero
packets (so the bug was on-device, not network). `ss -tni state established '( sport = :8081 )'`
shows live queues (`notsent`, `bytes_acked`) without root.
