# Security policy

## Reporting a vulnerability

Please report suspected vulnerabilities privately using [GitHub's private vulnerability reporting](https://github.com/Blue-View-Inc/blue-view-sophos-vpn-client/security/advisories/new). Do not post exploit details, credentials, VPN configuration files, private keys, or work network information in public issues. Describe the affected version, prerequisites, impact, and safe reproduction steps using synthetic data. We will review reports as resources permit; there is no guaranteed response time.

## Security model and limitations

The client delegates VPN connections to NetworkManager and OpenVPN. It transmits credentials to `nmcli` over standard input, not command-line arguments, and can store passwords in the desktop Secret Service keyring. One-time codes entered in the separate code field are submitted with the password for compatible Sophos configurations and are not stored by this app. If a code is typed into the password field instead, it is treated as part of the password and could be saved; use the separate code field. Imported configurations can contain private keys; protect them like passwords. The temporary import directory is private and is removed after use, but a forced termination may leave it behind. NetworkManager may store imported certificates and private keys on disk according to its own settings.

Only import profiles from a trusted administrator. The app rejects several executable directives and requires a CA and a server-certificate check in newly imported profiles. This is a precaution, not a complete safety validation. Existing NetworkManager profiles are not revalidated by these import checks. Verify server identity, encryption, firewall policy, keyring protection, and allowed routing with your VPN administrator. Imported profiles currently use split tunneling; this may not be appropriate or permitted for every organization. The VPN server and authentication provider control MFA. The app does not provide FIDO2 security-key authentication or direct Keeper integration.

This project has not received an independent security audit or penetration test. No software can guarantee protection from a compromised operating system, malicious same-user processes, or a compromised VPN server. Please keep the operating system, NetworkManager, OpenVPN, and this application updated.
