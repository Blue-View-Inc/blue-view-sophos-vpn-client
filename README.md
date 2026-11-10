# Blue View VPN

A Linux desktop client for Sophos-compatible OpenVPN profiles, by Blue View Intelligence and powered by BvOs Intelligence. A Qt Quick interface uses a Rust backend and NetworkManager to import a profile, connect or disconnect, and display tunnel status and traffic rates. Passwords can be saved in the user's Secret Service keyring.

## Requirements

Linux with NetworkManager, its OpenVPN plugin, OpenVPN, `nmcli`, `secret-tool`, `ip`, `notify-send`, a running Secret Service, Qt 6 Quick Controls, qmake6, a C++17 compiler, Rust and Cargo. The desktop file chooser uses Qt's desktop portal support.

## Build and run

```sh
bin/build
build/sophosvpn
```

The build uses Cargo offline; ensure the Rust dependencies in `backend/Cargo.lock` are cached first, or run `cargo fetch --manifest-path backend/Cargo.toml` when online. Press Ctrl+Q to quit.

## Usage

Select **Import VPN configuration**, choose the `.ovpn` file supplied by your organization, then import it. Enter your VPN username and password and select **Connect VPN**. The application saves the password to the desktop keyring when requested after a successful connection. Profile import creates a separate NetworkManager profile with split tunneling enabled. DNS and network routes are supplied by the VPN configuration and server; check your organization's VPN policy and test access after importing.

Multiple imported profiles remain available in the profile selector, with a separate saved password per profile. Disconnect before switching profiles.

The app does not bundle a VPN configuration or credentials. Existing NetworkManager profiles are not deleted. Only OpenVPN configurations supported by NetworkManager can be imported; configurations that refer to external files may require additional setup.

## Independent community project

This free-to-use community application is not affiliated with, endorsed by, sponsored by, or supported by Sophos. See [legal and community information](LEGAL.md) for trademark, warranty, licensing, and networking disclosures.

## License

Copyright 2026 The Blue View Group Corporation. Source available under the [PolyForm Noncommercial License 1.0.0](LICENSE); see [NOTICE](NOTICE). This is a noncommercial license, not an OSI-approved open-source license.

Sophos and the Sophos logo are trademarks of Sophos and are not licensed under the project license. Blue View branding is a trademark of The Blue View Group Corporation.

The Lexend Exa typeface is distributed under the [SIL Open Font License 1.1](src/LexendExa-OFL.txt).
