use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct DesktopUpdateInfo {
    pub status: String,
    pub message: String,
    pub version: Option<String>,
    pub download_url: Option<String>,
    pub release_url: Option<String>,
    pub asset_name: Option<String>,
    pub asset_size_bytes: Option<i64>,
}

impl Default for DesktopUpdateInfo {
    fn default() -> Self {
        Self {
            status: "idle".to_string(),
            message: "Ready to check GitHub Releases".to_string(),
            version: None,
            download_url: None,
            release_url: None,
            asset_name: None,
            asset_size_bytes: None,
        }
    }
}

pub fn normalize_semver(raw: &str) -> Vec<i64> {
    let mut cleaned = raw.trim().to_string();
    if cleaned.starts_with('v') || cleaned.starts_with('V') {
        cleaned.remove(0);
    }
    if let Some(idx) = cleaned.find(['-', '+']) {
        cleaned.truncate(idx);
    }
    cleaned
        .split('.')
        .map(|part| part.parse::<i64>().unwrap_or(0))
        .collect()
}

pub fn is_newer_semver(remote: &str, current: &str) -> bool {
    let r = normalize_semver(remote);
    let c = normalize_semver(current);
    let count = r.len().max(c.len());
    if count == 0 {
        return false;
    }
    for i in 0..count {
        let rv = *r.get(i).unwrap_or(&0);
        let cv = *c.get(i).unwrap_or(&0);
        if rv != cv {
            return rv > cv;
        }
    }
    false
}

pub fn pick_best_desktop_asset(assets: &[serde_json::Value], os: &str) -> Option<(String, String, i64)> {
    let preferred_exts: &[&str] = match os {
        "windows" => &[".exe", ".zip", ".msi"],
        "linux" => &[".appimage", ".deb"],
        _ => &[".dmg"],
    };

    let mut best: Option<(i32, String, String, i64)> = None;
    for asset in assets {
        let Some(name) = asset.get("name").and_then(|v| v.as_str()) else {
            continue;
        };
        let Some(url) = asset.get("browser_download_url").and_then(|v| v.as_str()) else {
            continue;
        };
        let size = asset.get("size").and_then(|v| v.as_i64()).unwrap_or(0);
        let lower = name.to_lowercase();
        for (idx, ext) in preferred_exts.iter().enumerate() {
            if lower.ends_with(ext) {
                let score = 100 - (idx as i32) * 10;
                if best.as_ref().map(|b| score > b.0).unwrap_or(true) {
                    best = Some((score, name.to_string(), url.to_string(), size));
                }
                break;
            }
        }
    }

    best.map(|(_, name, url, size)| (name, url, size))
}

pub async fn check_github_updates(current_version: &str) -> DesktopUpdateInfo {
    let client = match reqwest::Client::builder()
        .user_agent(format!("YTMusicGlass-Desktop/{current_version}"))
        .timeout(std::time::Duration::from_secs(12))
        .build()
    {
        Ok(c) => c,
        Err(e) => {
            return DesktopUpdateInfo {
                status: "error".to_string(),
                message: e.to_string(),
                ..Default::default()
            };
        }
    };

    let resp = match client
        .get("https://api.github.com/repos/ravizikrillah/yt-music-glass/releases/latest")
        .header("Accept", "application/vnd.github+json")
        .send()
        .await
    {
        Ok(r) => r,
        Err(e) => {
            return DesktopUpdateInfo {
                status: "error".to_string(),
                message: format!("Update check failed: {e}"),
                ..Default::default()
            };
        }
    };

    if resp.status().as_u16() == 404 {
        return DesktopUpdateInfo {
            status: "upToDate".to_string(),
            message: format!("You're on v{current_version} (no GitHub releases published yet)"),
            ..Default::default()
        };
    }
    if !resp.status().is_success() {
        return DesktopUpdateInfo {
            status: "error".to_string(),
            message: format!("GitHub Releases returned HTTP {}", resp.status()),
            ..Default::default()
        };
    }

    let Ok(obj) = resp.json::<serde_json::Value>().await else {
        return DesktopUpdateInfo {
            status: "error".to_string(),
            message: "Invalid release JSON from GitHub".to_string(),
            ..Default::default()
        };
    };

    let tag = obj.get("tag_name").and_then(|v| v.as_str()).unwrap_or("1.0.0");
    let clean_ver = tag.trim_start_matches(['v', 'V']).to_string();
    let html_url = obj
        .get("html_url")
        .and_then(|v| v.as_str())
        .unwrap_or("https://github.com/ravizikrillah/yt-music-glass/releases")
        .to_string();

    if !is_newer_semver(&clean_ver, current_version) {
        return DesktopUpdateInfo {
            status: "upToDate".to_string(),
            message: format!("You're up to date (v{current_version})"),
            version: Some(clean_ver),
            release_url: Some(html_url),
            ..Default::default()
        };
    }

    let assets = obj.get("assets").and_then(|v| v.as_array()).cloned().unwrap_or_default();
    let os = if cfg!(target_os = "windows") {
        "windows"
    } else if cfg!(target_os = "linux") {
        "linux"
    } else {
        "macos"
    };
    let chosen = pick_best_desktop_asset(&assets, os);

    DesktopUpdateInfo {
        status: "available".to_string(),
        message: format!("Update available: v{clean_ver}"),
        version: Some(clean_ver),
        download_url: chosen.as_ref().map(|x| x.1.clone()),
        release_url: Some(html_url),
        asset_name: chosen.as_ref().map(|x| x.0.clone()),
        asset_size_bytes: chosen.as_ref().map(|x| x.2),
    }
}
