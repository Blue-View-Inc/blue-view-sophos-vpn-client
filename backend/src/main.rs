use serde_json::{json, Value};
use std::os::unix::fs::PermissionsExt;
use std::{env, fs, io::{self, BufRead, Write}, path::{Path, PathBuf}, process::{Command, Stdio}};

fn run(program: &str, args: &[&str], input: Option<&str>) -> Result<String, String> {
    let mut cmd = Command::new(program);
    cmd.args(args).stdout(Stdio::piped()).stderr(Stdio::piped());
    if input.is_some() { cmd.stdin(Stdio::piped()); }
    let mut child = cmd.spawn().map_err(|e| format!("{program}: {e}"))?;
    if let Some(data) = input { child.stdin.take().unwrap().write_all(data.as_bytes()).map_err(|e| e.to_string())?; }
    let output = child.wait_with_output().map_err(|e| e.to_string())?;
    if !output.status.success() { return Err(String::from_utf8_lossy(&output.stderr).trim().to_string()); }
    Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
}
fn state() -> PathBuf { PathBuf::from(env::var("HOME").unwrap_or_default()).join(".local/share/work-vpn/selected-uuid") }
fn selected() -> String {
    let saved = fs::read_to_string(state()).unwrap_or_default().trim().to_owned();
    let list = profiles().unwrap_or_default();
    if list.iter().any(|(id, _)| id == &saved) { return saved; }
    let old = run("nmcli", &["-g", "connection.uuid", "connection", "show", "sophos-networkmanager"], None).unwrap_or_default();
    if list.iter().any(|(id, _)| id == &old) { return old; }
    list.first().map(|(id, _)| id.clone()).unwrap_or_default()
}
fn profiles() -> Result<Vec<(String, String)>, String> {
    let uuids = run("nmcli", &["-g", "UUID,TYPE", "connection", "show"], None)?;
    let mut result = Vec::new();
    for row in uuids.lines() {
        let Some((uuid, kind)) = row.split_once(':') else { continue };
        if kind != "vpn" { continue; }
        if run("nmcli", &["-g", "vpn.service-type", "connection", "show", "uuid", uuid], None).unwrap_or_default() != "org.freedesktop.NetworkManager.openvpn" { continue; }
        let name = run("nmcli", &["--escape", "no", "-g", "connection.id", "connection", "show", "uuid", uuid], None).unwrap_or_else(|_| uuid.into());
        result.push((uuid.to_string(), name));
    }
    Ok(result)
}
fn save_selection(uuid: &str) -> Result<(), String> {
    let path = state(); fs::create_dir_all(path.parent().unwrap()).map_err(|e| e.to_string())?;
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
            let uuid = if list.iter().any(|(id, _)| id == &saved) { saved } else { list.first().map(|(id, _)| id.clone()).unwrap_or_default() };
            let active = run("nmcli", &["-t", "-f", "UUID,TYPE", "connection", "show", "--active"], None)?;
            let connected = active.lines().any(|s| s == format!("{uuid}:vpn"));
            let detail = if connected { run("nmcli", &["--escape", "no", "-g", "IP4.ADDRESS,IP4.DNS", "connection", "show", "uuid", &uuid], None).unwrap_or_default() } else { String::new() };
            let user = run("nmcli", &["--escape", "no", "-g", "vpn.user-name", "connection", "show", "uuid", &uuid], None).unwrap_or_default();
            let addresses: Value = serde_json::from_str(&run("ip", &["-j", "-4", "address", "show"], None).unwrap_or_default()).unwrap_or(json!([]));
            let vpn_ip = detail.lines().next().unwrap_or("").split('/').next().unwrap_or("");
            let iface = addresses.as_array().and_then(|items| items.iter().find(|i| !vpn_ip.is_empty() && i["addr_info"].as_array().map(|a| a.iter().any(|v| v["local"].as_str() == Some(vpn_ip))).unwrap_or(false))).and_then(|v| v["ifname"].as_str()).unwrap_or("");
            let counter = |name: &str| -> u64 { if iface.is_empty() { return 0; } fs::read_to_string(format!("/sys/class/net/{iface}/statistics/{name}_bytes")).unwrap_or_default().trim().parse().unwrap_or(0) };
            Ok(json!({"connected": connected, "details": detail, "username": user, "rx": counter("rx"), "tx": counter("tx"), "selected": uuid, "profiles": list.iter().map(|(id, name)| json!({"id":id,"name":name})).collect::<Vec<_>>() }))
        }
        "select" => {
            let uuid = get("uuid");
            if !profiles()?.iter().any(|(id, _)| id == uuid) { return Err("The selected profile is unavailable.".into()); }
            let active = run("nmcli", &["-t", "-f", "UUID,TYPE", "connection", "show", "--active"], None)?;
            if active.lines().any(|s| s == format!("{}:vpn", selected())) { return Err("Disconnect the current VPN before switching profiles.".into()); }
            save_selection(uuid)?;
            Ok(json!({"message":"Profile selected."}))
        }
        "import" => {
            let file = Path::new(get("file"));
            if file.extension().and_then(|s| s.to_str()).map(|s| s.to_ascii_lowercase()) != Some("ovpn".into()) { return Err("Choose an .ovpn configuration file.".into()); }
            let input = fs::read_to_string(file).map_err(|e| format!("Cannot read profile: {e}"))?;
            if input.len() > 1024 * 1024 { return Err("Profile exceeds 1 MB.".into()); }
            let content = input.lines().map(|line| { let parts: Vec<_> = line.split_whitespace().collect(); if parts.len() >= 4 && parts[0] == "route" && parts[1] == "remote_host" && parts[3] == "net_gateway" { "# Server route handled by NetworkManager" } else { line } }).collect::<Vec<_>>().join("\n");
            let temp = env::temp_dir().join(format!("sophosvpn-{}", std::process::id()));
            fs::create_dir(&temp).map_err(|e| e.to_string())?;
            fs::set_permissions(&temp, fs::Permissions::from_mode(0o700)).map_err(|e| e.to_string())?;
            let path = temp.join("Sophos VPN.ovpn");
            fs::write(&path, content).map_err(|e| e.to_string())?;
            fs::set_permissions(&path, fs::Permissions::from_mode(0o600)).map_err(|e| e.to_string())?;
            let result = run("nmcli", &["connection", "import", "type", "openvpn", "file", path.to_str().unwrap()], None);
            let _ = fs::remove_dir_all(temp);
            let output = result?;
            let uuid = output.split('(').nth(1).and_then(|v| v.split(')').next()).filter(|v| v.len()==36).ok_or("NetworkManager did not return a profile ID.")?;
            let name = file.file_stem().and_then(|s| s.to_str()).filter(|s| !s.is_empty()).unwrap_or("VPN profile");
            if let Err(e) = run("nmcli", &["connection", "modify", "uuid", uuid, "connection.id", name, "ipv4.never-default", "yes"], None) { let _ = run("nmcli", &["connection", "delete", "uuid", uuid], None); return Err(e); }
            save_selection(uuid)?;
            Ok(json!({"message":"Profile imported. Enter your VPN credentials."}))
        }
        "connect" => {
            let uuid = selected(); let username = get("username");
            if !username.is_empty() { run("nmcli", &["connection", "modify", "uuid", &uuid, "vpn.user-name", username], None)?; }
            let entered = get("password");
            let password = if entered.is_empty() { run("secret-tool", &["lookup", "application", "work-vpn", "connection", &uuid], None).unwrap_or_default() } else { entered.to_owned() };
            if password.is_empty() || password.contains(['\n','\r']) { return Err("Enter a valid VPN password.".into()); }
            run("nmcli", &["--wait", "60", "connection", "up", "uuid", &uuid, "passwd-file", "/dev/stdin"], Some(&format!("vpn.secrets.password:{password}\n")))?;
            let mut message = "Connected.".to_string();
            if req.get("save").and_then(Value::as_bool).unwrap_or(false) && run("secret-tool", &["store", "--label=Sophos VPN password", "application", "work-vpn", "connection", &uuid], Some(&password)).is_err() { message.push_str(" Password could not be saved in the keyring."); }
            let _ = run("notify-send", &["Sophos VPN", "Connected successfully"], None);
            Ok(json!({"message":message}))
        }
        "disconnect" => { let uuid = selected(); run("nmcli", &["connection", "down", "uuid", &uuid], None)?; let _ = run("notify-send", &["Sophos VPN", "Disconnected successfully"], None); Ok(json!({"message":"Disconnected."})) }
        _ => Err("Unknown action.".into())
    }
}
fn main() { let mut input = String::new(); let _ = io::stdin().lock().read_line(&mut input); let result = serde_json::from_str::<Value>(&input).map_err(|e| e.to_string()).and_then(|v| action(&v)); println!("{}", match result { Ok(v) => json!({"ok":true,"result":v}), Err(e) => json!({"ok":false,"error":e}) }); }
