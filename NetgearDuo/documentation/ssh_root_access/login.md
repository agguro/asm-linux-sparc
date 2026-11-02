# SSH Access to Netgear ReadyNAS

This document describes how to enable root SSH access on a legacy Netgear ReadyNAS running firmware 4.1.10.

## 1. Enable Root SSH

Root SSH access must first be enabled using the ReadyNAS add-on.

1. Open the ReadyNAS FrontView administration interface.
2. Log in as administrator.
3. Navigate to the add-on installation section.
4. Upload and install `EnableRootSSH_1.0.bin`.
5. Follow the installation instructions and reboot if required.

## 2. Connect as Root

The legacy ReadyNAS requires older SSH algorithms that modern OpenSSH clients may disable by default.

```bash
ssh -oKexAlgorithms=+diffie-hellman-group14-sha1 \
    -oHostKeyAlgorithms=+ssh-rsa \
    root@192.168.0.198
```

### Login credentials

- **Username:** `root`
- **Password:** The configured NAS root password (do not publish passwords in a public repository).

## 3. SSH Options Explained

| Option | Description |
|---|---|
| `KexAlgorithms` | Enables legacy Diffie-Hellman key exchange. |
| `HostKeyAlgorithms` | Enables legacy RSA/SHA-1 host-key signatures. |
| `root` | Root account on the ReadyNAS. |
| `192.168.0.198` | IP address of the ReadyNAS; replace if different. |

## 4. Security

These compatibility options apply only to this SSH connection. They do not modify the global SSH configuration or `~/.ssh/config`.

Use legacy cryptographic algorithms only when connecting to a trusted device on an isolated network.

Do not publish actual NAS passwords in public repositories.
