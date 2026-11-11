# Maintenance and distribution

## Compatibility

Sophos controls its VPN configuration and authentication behavior. Maintainers should regularly review the [Sophos Firewall release notes](https://docs.sophos.com/releasenotes/output/en-us/nsg/sf_230_rn.html), [SSL VPN documentation](https://docs.sophos.com/nsg/sophos-firewall/22.0/Help/en-us/webhelp/onlinehelp/VPNAndUserPortalHelp/VPN/RemoteAccessVPN/SSLVPNRemoteAccess/index.html), NetworkManager OpenVPN plugin changes, and OpenVPN security advisories. Review changes to supported profile syntax, certificate verification, authentication, one-time codes, and routing. Test representative synthetic profiles in CI and test actual firewall compatibility in an authorized non-production environment before publishing releases. Mock tests alone do not establish Sophos compatibility.

Dependabot proposes Rust and GitHub Actions updates weekly. CI builds and runs simulated credential and profile tests. Maintainers must review these updates and monitor security advisories for OS packages and Qt separately. Neither mechanism guarantees compatibility or security.

## Distribution plan

A future release should provide distribution-specific packages, checksums, a signed release, documented signing-key fingerprints, and an installation page. Package and release builds should be reproducible or independently verifiable, with a rollback path and a clear update policy. A link to download a signed package is preferable to asking users to run an unreviewed shell script from the internet. Package support and a trusted signing process need to be tested before advertising one-click installation. Currently users can build and install for themselves with `bin/install-user`; no release package or automatic updater is provided.

## Arch package candidate

On an Arch or Omarchy machine with the dependencies in the package recipe installed, `bin/package-arch 0.1.0rc1` builds an Arch package from the current clean Git commit and writes it with a `SHA256SUMS` file under `dist/`. The source archive is checksummed and Cargo uses the lockfile. Run `python3 tests/package_smoke.py dist/arch-0.1.0rc1/blue-view-sophos-vpn-client-0.1.0rc1-1-x86_64.pkg.tar.zst` (adjust the filename for the version and architecture) to inspect and start the package without installing it. This is a local candidate build, not a signed or independently verified release. A release maintainer must test it on a clean system and sign the package and checksums before publishing them. The optional Omarchy bar integration is not yet included.

The Blue View release public key is in `packaging/keys/blueview-release.asc`. Its fingerprint is `2219 C779 1A59 8A47 B550 BE9B 020A 8265 66E7 C7B0`. Verify that fingerprint through an independent trusted Blue View channel before relying on signatures. Keep the private key and its passphrase separate and backed up securely. Public-key publication in the same repository as the package is not, by itself, proof of authenticity.
