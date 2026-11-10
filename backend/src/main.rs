use serde_json::{json, Value};
use std::os::unix::fs::PermissionsExt;
use std::{
    env, fs,
    io::{self, BufRead, Write},
    path::{Path, PathBuf},
    process::{Command, Stdio},
};
use zeroize::{Zeroize, Zeroizing};

fn run(program: &str, args: &[&str], input: Option<&str>) -> Result<String, String> {
    let mut cmd = Command::new(program);
    cmd.args(args).stdout(Stdio::piped()).stderr(Stdio::piped());
    if input.is_some() {
        cmd.stdin(Stdio::piped());
    }
    let mut child = cmd.spawn().map_err(|e| format!("{program}: {e}"))?;
    if let Some(data) = input {
        child
            .stdin
            .take()
            .unwrap()
            .write_all(data.as_bytes())
            .map_err(|e| e.to_string())?;
    }
    let output = child.wait_with_output().map_err(|e| e.to_string())?;
    if !output.status.success() {
        return Err(String::from_utf8_lossy(&output.stderr).trim().to_string());
    }
    Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
}
fn state() -> PathBuf {
    PathBuf::from(env::var("HOME").unwrap_or_default()).join(".local/share/work-vpn/selected-uuid")
}
fn selected() -> String {
    let saved = fs::read_to_string(state())
        .unwrap_or_default()
        .trim()
        .to_owned();
    let list = profiles().unwrap_or_default();
    if list.iter().any(|(id, _)| id == &saved) {
        return saved;
    }
    let old = run(
        "nmcli",
        &[
            "-g",
            "connection.uuid",
            "connection",
            "show",
            "sophos-networkmanager",
        ],
        None,
    )
    .unwrap_or_default();
    if list.iter().any(|(id, _)| id == &old) {
        return old;
    }
    list.first().map(|(id, _)| id.clone()).unwrap_or_default()
}
fn profiles() -> Result<Vec<(String, String)>, String> {
    let uuids = run("nmcli", &["-g", "UUID,TYPE", "connection", "show"], None)?;
    let mut result = Vec::new();
    for row in uuids.lines() {
        let Some((uuid, kind)) = row.split_once(':') else {
            continue;
        };
        if kind != "vpn" {
            continue;
        }
        if run(
            "nmcli",
            &["-g", "vpn.service-type", "connection", "show", "uuid", uuid],
            None,
        )
        .unwrap_or_default()
            != "org.freedesktop.NetworkManager.openvpn"
        {
            continue;
        }
        let name = run(
            "nmcli",
            &[
                "--escape",
                "no",
                "-g",
                "connection.id",
                "connection",
                "show",
                "uuid",
                uuid,
            ],
            None,
        )
        .unwrap_or_else(|_| uuid.into());
        result.push((uuid.to_string(), name));
    }
    Ok(result)
}
fn save_selection(uuid: &str) -> Result<(), String> {
    let path = state();
    fs::create_dir_all(path.parent().unwrap()).map_err(|e| e.to_string())?;
    let temp = path.with_extension(format!("tmp-{}", std::process::id()));
    fs::write(&temp, uuid).map_err(|e| e.to_string())?;
    fs::set_permissions(&temp, fs::Permissions::from_mode(0o600)).map_err(|e| e.to_string())?;
    fs::rename(temp, path).map_err(|e| e.to_string())
}
fn action(req: &Value) -> Result<Value, String> {
    let get = |key| req.get(key).and_then(Value::as_str).unwrap_or("");
    match get("action") {
        "status" => {
            let list = profiles()?;
            let saved = selected();
            let uuid = if list.iter().any(|(id, _)| id == &saved) {
                saved
            } else {
                list.first().map(|(id, _)| id.clone()).unwrap_or_default()
            };
            let active = run(
                "nmcli",
                &["-t", "-f", "UUID,TYPE", "connection", "show", "--active"],
                None,
            )?;
            let connected = active.lines().any(|s| s == format!("{uuid}:vpn"));
            let detail = if connected {
                run(
                    "nmcli",
                    &[
                        "--escape",
                        "no",
                        "-g",
                        "IP4.ADDRESS,IP4.DNS",
                        "connection",
                        "show",
                        "uuid",
                        &uuid,
                    ],
                    None,
                )
                .unwrap_or_default()
            } else {
                String::new()
            };
            let user = run(
                "nmcli",
                &[
                    "--escape",
                    "no",
                    "-g",
                    "vpn.user-name",
                    "connection",
                    "show",
                    "uuid",
                    &uuid,
                ],
                None,
            )
            .unwrap_or_default();
            let addresses: Value = serde_json::from_str(
                &run("ip", &["-j", "-4", "address", "show"], None).unwrap_or_default(),
            )
            .unwrap_or(json!([]));
            let vpn_ip = detail
                .lines()
                .next()
                .unwrap_or("")
                .split('/')
                .next()
                .unwrap_or("");
            let iface = addresses
                .as_array()
                .and_then(|items| {
                    items.iter().find(|i| {
                        !vpn_ip.is_empty()
                            && i["addr_info"]
                                .as_array()
                                .map(|a| a.iter().any(|v| v["local"].as_str() == Some(vpn_ip)))
                                .unwrap_or(false)
                    })
                })
                .and_then(|v| v["ifname"].as_str())
                .unwrap_or("");
            let data = run(
                "nmcli",
                &[
                    "--escape",
                    "no",
                    "-g",
                    "vpn.data",
                    "connection",
                    "show",
                    "uuid",
                    &uuid,
                ],
                None,
            )
            .unwrap_or_default();
            let server = data
                .split(", ")
                .find_map(|part| part.strip_prefix("remote = "))
                .unwrap_or("");
            let split = run(
                "nmcli",
                &[
                    "-g",
                    "ipv4.never-default",
                    "connection",
                    "show",
                    "uuid",
                    &uuid,
                ],
                None,
            )
            .unwrap_or_default();
            let counter = |name: &str| -> u64 {
                if iface.is_empty() {
                    return 0;
                }
                fs::read_to_string(format!("/sys/class/net/{iface}/statistics/{name}_bytes"))
                    .unwrap_or_default()
                    .trim()
                    .parse()
                    .unwrap_or(0)
            };
            Ok(
                json!({"connected": connected, "details": detail, "username": user, "rx": counter("rx"), "tx": counter("tx"), "server": server, "interface": iface, "split": split, "selected": uuid, "profiles": list.iter().map(|(id, name)| json!({"id":id,"name":name})).collect::<Vec<_>>() }),
            )
        }
        "select" => {
            let uuid = get("uuid");
            if !profiles()?.iter().any(|(id, _)| id == uuid) {
                return Err("The selected profile is unavailable.".into());
            }
            let active = run(
                "nmcli",
                &["-t", "-f", "UUID,TYPE", "connection", "show", "--active"],
                None,
            )?;
            if active.lines().any(|s| s == format!("{}:vpn", selected())) {
                return Err("Disconnect the current VPN before switching profiles.".into());
            }
            save_selection(uuid)?;
            Ok(json!({"message":"Profile selected."}))
        }
        "import" => {
            let file = Path::new(get("file"));
            if file
                .extension()
                .and_then(|s| s.to_str())
                .map(|s| s.to_ascii_lowercase())
                != Some("ovpn".into())
            {
                return Err("Choose an .ovpn configuration file.".into());
            }
            if fs::metadata(file)
                .map_err(|e| format!("Cannot read profile: {e}"))?
                .len()
                > 1024 * 1024
            {
                return Err("Profile exceeds 1 MB.".into());
            }
            let input = Zeroizing::new(
                fs::read_to_string(file).map_err(|e| format!("Cannot read profile: {e}"))?,
            );
            let mut in_block = false;
            let mut has_ca = false;
            let mut verifies_server = false;
            for line in input.lines() {
                let line = line.trim();
                if line == "<ca>" {
                    has_ca = true;
                }
                if line.starts_with('<') {
                    if !line.starts_with("</")
                        && !matches!(
                            line,
                            "<ca>"
                                | "<cert>"
                                | "<key>"
                                | "<tls-auth>"
                                | "<tls-crypt>"
                                | "<tls-crypt-v2>"
                                | "<pkcs12>"
                        )
                    {
                        return Err("The profile contains an unsupported embedded section. Ask your VPN administrator for a supported profile.".into());
                    }
                    in_block = !line.starts_with("</");
                    continue;
                }
                if in_block || line.starts_with('#') || line.starts_with(';') {
                    continue;
                }
                let directive = line
                    .split_whitespace()
                    .next()
                    .unwrap_or("")
                    .trim_start_matches('-');
                if directive == "ca" {
                    has_ca = true;
                }
                if matches!(directive, "verify-x509-name" | "peer-fingerprint")
                    || (directive == "remote-cert-tls"
                        && line.split_whitespace().nth(1) == Some("server"))
                {
                    verifies_server = true;
                }
                if matches!(
                    directive,
                    "up" | "down"
                        | "route-up"
                        | "route-pre-down"
                        | "ipchange"
                        | "tls-verify"
                        | "auth-user-pass-verify"
                        | "client-connect"
                        | "client-disconnect"
                        | "learn-address"
                        | "plugin"
                        | "script-security"
                        | "config"
                        | "management"
                        | "management-client"
                        | "management-external-key"
                        | "management-external-cert"
                ) {
                    return Err(format!("This profile contains the unsupported directive '{directive}'. Ask your VPN administrator for a safe profile."));
                }
            }
            if !has_ca || !verifies_server {
                return Err("The profile must include a trusted CA and a server certificate check. Ask your VPN administrator for a verified profile.".into());
            }
            let content = Zeroizing::new(
                input
                    .lines()
                    .map(|line| {
                        let parts: Vec<_> = line.split_whitespace().collect();
                        if parts.len() >= 4
                            && parts[0] == "route"
                            && parts[1] == "remote_host"
                            && parts[3] == "net_gateway"
                        {
                            "# Server route handled by NetworkManager"
                        } else {
                            line
                        }
                    })
                    .collect::<Vec<_>>()
                    .join("\n"),
            );
            let mut builder = tempfile::Builder::new();
            builder.prefix("blueview-vpn-");
            let temp = match env::var_os("XDG_RUNTIME_DIR") {
                Some(dir) if Path::new(&dir).is_dir() => builder.tempdir_in(dir),
                _ => builder.tempdir(),
            }
            .map_err(|e| e.to_string())?;
            let path = temp.path().join("Sophos VPN.ovpn");
            use std::os::unix::fs::OpenOptionsExt;
            let mut private_file = fs::OpenOptions::new()
                .write(true)
                .create_new(true)
                .mode(0o600)
                .open(&path)
                .map_err(|e| e.to_string())?;
            private_file
                .write_all(content.as_bytes())
                .map_err(|e| e.to_string())?;
            drop(private_file);
            let output = run(
                "nmcli",
                &[
                    "connection",
                    "import",
                    "type",
                    "openvpn",
                    "file",
                    path.to_str().unwrap(),
                ],
                None,
            )?;
            let uuid = output
                .split('(')
                .nth(1)
                .and_then(|v| v.split(')').next())
                .filter(|v| v.len() == 36)
                .ok_or("NetworkManager did not return a profile ID.")?;
            let name = file
                .file_stem()
                .and_then(|s| s.to_str())
                .filter(|s| !s.is_empty())
                .unwrap_or("VPN profile");
            if let Err(e) = run(
                "nmcli",
                &[
                    "connection",
                    "modify",
                    "uuid",
                    uuid,
                    "connection.id",
                    name,
                    "ipv4.never-default",
                    "yes",
                ],
                None,
            ) {
                let _ = run("nmcli", &["connection", "delete", "uuid", uuid], None);
                return Err(e);
            }
            save_selection(uuid)?;
            Ok(json!({"message":"Profile imported. Enter your VPN credentials."}))
        }
        "forget" => {
            let uuid = selected();
            if uuid.is_empty() {
                return Err("Select a VPN profile first.".into());
            }
            run(
                "secret-tool",
                &["clear", "application", "work-vpn", "connection", &uuid],
                None,
            )?;
            Ok(json!({"message":"Saved password removed from the keyring."}))
        }
        "connect" => {
            let uuid = selected();
            let username = get("username");
            if !username.is_empty() {
                run(
                    "nmcli",
                    &[
                        "connection",
                        "modify",
                        "uuid",
                        &uuid,
                        "vpn.user-name",
                        username,
                    ],
                    None,
                )?;
            }
            let entered = get("password");
            let password = Zeroizing::new(if entered.is_empty() {
                run(
                    "secret-tool",
                    &["lookup", "application", "work-vpn", "connection", &uuid],
                    None,
                )
                .unwrap_or_default()
            } else {
                entered.to_owned()
            });
            if password.is_empty() || password.contains(['\n', '\r']) {
                return Err("Enter a valid VPN password.".into());
            }
            let code = Zeroizing::new(get("otp").to_owned());
            if !code.is_empty() && (code.len() > 12 || !code.bytes().all(|b| b.is_ascii_digit())) {
                return Err("Enter a valid numeric one-time code.".into());
            }
            let payload = Zeroizing::new(format!(
                "vpn.secrets.password:{}{}\n",
                password.as_str(),
                code.as_str()
            ));
            run("nmcli", &["--wait", "60", "connection", "up", "uuid", &uuid, "passwd-file", "/dev/stdin"], Some(payload.as_str()))
                .map_err(|_| "VPN connection failed. Check the credentials, one-time code, and network connection.".to_string())?;
            let mut message = "Connected.".to_string();
            if req.get("save").and_then(Value::as_bool).unwrap_or(false)
                && run(
                    "secret-tool",
                    &[
                        "store",
                        "--label=Sophos VPN password",
                        "application",
                        "work-vpn",
                        "connection",
                        &uuid,
                    ],
                    Some(password.as_str()),
                )
                .is_err()
            {
                message.push_str(" Password could not be saved in the keyring.");
            }
            let _ = run(
                "notify-send",
                &["Sophos VPN", "Connected successfully"],
                None,
            );
            Ok(json!({"message":message}))
        }
        "disconnect" => {
            let uuid = selected();
            run("nmcli", &["connection", "down", "uuid", &uuid], None)?;
            let _ = run(
                "notify-send",
                &["Sophos VPN", "Disconnected successfully"],
                None,
            );
            Ok(json!({"message":"Disconnected."}))
        }
        _ => Err("Unknown action.".into()),
    }
}
fn main() {
    let mut input = Zeroizing::new(String::new());
    let _ = io::stdin().lock().read_line(&mut input);
    let result = match serde_json::from_str::<Value>(&input) {
        Ok(mut request) => {
            let result = action(&request);
            for key in ["password", "otp"] {
                if let Some(Value::String(secret)) = request.get_mut(key) {
                    secret.zeroize();
                }
            }
            result
        }
        Err(error) => Err(error.to_string()),
    };
    println!(
        "{}",
        match result {
            Ok(v) => json!({"ok":true,"result":v}),
            Err(e) => json!({"ok":false,"error":e}),
        }
    );
}
