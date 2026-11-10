# Contributing

Thank you for helping improve Blue View Sophos VPN Client. Issues, documentation improvements, accessibility feedback, translations, and code are welcome. Please follow the [code of conduct](CODE_OF_CONDUCT.md).

For vulnerabilities, **do not open a public issue**. Follow [SECURITY.md](SECURITY.md).

## Develop

The interface is in `src/Main.qml` and the Qt launcher is in `src/main.cpp`. The Rust NetworkManager backend is in `backend/src/main.rs`. You need Qt 6, qmake6, a C++ compiler, Rust, Cargo, Python 3, NetworkManager with its OpenVPN plugin, and Secret Service. On a fresh machine, fetch the Rust dependencies once:

```sh
cargo fetch --locked --manifest-path backend/Cargo.toml
bin/build
python3 tests/backend_smoke.py
build/sophosvpn
```

The smoke tests use temporary files and simulated NetworkManager and keyring commands; they do not require a real VPN. For interface changes, test both themes at a small window size. Never add real VPN configurations, certificates, passwords, OTP codes, internal addresses, or other private data to an issue, test fixture, log, screenshot, or pull request.

## Send a change

1. Open an issue for substantial changes so the approach can be discussed.
2. Fork the repository, create a focused branch, and describe the problem and solution in your pull request.
3. Include the tests you ran and, for interface changes, screenshots with synthetic data.
4. Keep third-party assets and dependencies properly licensed. Contributions are subject to the repository license; discuss any licensing questions before submitting.

Maintainers will review changes for correctness, accessibility, compatibility, and security. Automated checks help catch regressions but do not replace a security review.
