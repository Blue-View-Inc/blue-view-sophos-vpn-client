# Blue View Sophos VPN Client

![Blue View Sophos VPN Client with a fictional example profile](docs/screenshot.png)

A Linux desktop client for Sophos-compatible OpenVPN profiles, by Blue View Intelligence and powered by BvOs Intelligence. A Qt Quick interface uses a Rust backend and NetworkManager to import a profile, connect or disconnect, and display tunnel status and traffic rates. Passwords can be saved in the user's Secret Service keyring.

## Requirements

Linux with NetworkManager, its OpenVPN plugin, OpenVPN, `nmcli`, `secret-tool`, `ip`, `notify-send`, a running Secret Service, Qt 6 Quick Controls, qmake6, a C++17 compiler, Rust and Cargo. The desktop file chooser uses Qt's desktop portal support.

## Build and run

```sh
bin/build
build/sophosvpn
```

To install the built app and launcher entry for the current user, run `bin/install-user`.

The build uses Cargo offline; ensure the Rust dependencies in `backend/Cargo.lock` are cached first, or run `cargo fetch --manifest-path backend/Cargo.toml` when online. Press Ctrl+Q to quit.

## Usage

Select **Import VPN configuration**, choose the `.ovpn` file supplied by your organization, then import it. Enter your VPN username and password and, if required, a one-time code from your authenticator or hardware token; then select **Connect VPN**. One-time codes are not saved. The app does not directly support FIDO2 security keys or Keeper integration. The application saves the password to the desktop keyring only when you enable the save option and the connection succeeds. Put one-time codes in their separate field, never in the password field when saving the password. Previously saved passwords remain available until you choose to forget them. Profile import creates a separate NetworkManager profile with split tunneling enabled. DNS and network routes are supplied by the VPN configuration and server; check your organization's VPN policy and test access after importing.

Multiple imported profiles remain available in the profile selector, with a separate saved password per profile. Disconnect before switching profiles.

The app does not bundle a VPN configuration or credentials. Existing NetworkManager profiles are not deleted. Only OpenVPN configurations supported by NetworkManager can be imported. New imports must specify a trusted CA and a server-certificate check; configurations containing unsupported executable directives or external file references may require a different profile from the administrator. Existing NetworkManager profiles are not revalidated by the importer.

## Independent community project

This free-to-use community application is not affiliated with, endorsed by, sponsored by, or supported by Sophos. See [legal and community information](LEGAL.md) for trademark, warranty, licensing, and networking disclosures.

## Contributing and security

See [MAINTENANCE.md](MAINTENANCE.md) for release and compatibility plans. See [CONTRIBUTING.md](CONTRIBUTING.md) for development and pull-request guidance and [SECURITY.md](SECURITY.md) for private vulnerability reporting and security limitations.

## License

Copyright 2026 The Blue View Group Corporation. Source available under the [PolyForm Noncommercial License 1.0.0](LICENSE); see [NOTICE](NOTICE). This is a noncommercial license, not an OSI-approved open-source license.

Sophos and the Sophos logo are trademarks of Sophos and are not licensed under the project license. Blue View branding is a trademark of The Blue View Group Corporation.

The Lexend Exa and Caveat typefaces are distributed under the SIL Open Font License 1.1; see [Lexend Exa](src/LexendExa-OFL.txt) and [Caveat](src/Caveat-OFL.txt).
