use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct TapSyncLine {
    pub index: usize,
    pub text: String,
    pub timestamp: Option<f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct TapSyncSession {
    pub track_key: String,
    pub lines: Vec<TapSyncLine>,
    pub current_index: usize,
}

impl TapSyncSession {
    pub fn new(track_key: String, plain_lines: &[String]) -> Self {
        let lines = plain_lines
            .iter()
            .map(|l| l.trim().to_string())
            .filter(|l| !l.is_empty())
            .enumerate()
            .map(|(index, text)| TapSyncLine {
                index,
                text,
                timestamp: None,
            })
            .collect();
        Self {
            track_key,
            lines,
            current_index: 0,
        }
    }

    pub fn total_count(&self) -> usize {
        self.lines.len()
    }

    pub fn tapped_count(&self) -> usize {
        self.lines.iter().filter(|l| l.timestamp.is_some()).count()
    }

    pub fn is_complete(&self) -> bool {
        !self.lines.is_empty() && self.tapped_count() == self.lines.len()
    }

    pub fn tap_next(&mut self, playback_time: f64) {
        if self.current_index >= self.lines.len() {
            return;
        }
        let mut ts = playback_time.max(0.0);
        if self.current_index > 0 {
            if let Some(prev) = self.lines[self.current_index - 1].timestamp {
                if ts <= prev {
                    ts = prev + 0.05;
                }
            }
        }
        self.lines[self.current_index].timestamp = Some(ts);
        self.current_index += 1;
    }

    pub fn undo_last_tap(&mut self) {
        if self.current_index == 0 {
            return;
        }
        self.current_index -= 1;
        self.lines[self.current_index].timestamp = None;
    }

    pub fn format_lrc_timestamp(seconds: f64) -> String {
        let clamped = seconds.max(0.0);
        let total_cs = (clamped * 100.0).round() as i64;
        let mins = total_cs / 6000;
        let secs = (total_cs % 6000) / 100;
        let cs = total_cs % 100;
        format!("[{mins:02}:{secs:02}.{cs:02}]")
    }

    pub fn export_lrc(&self) -> Option<String> {
        let out: Vec<String> = self
            .lines
            .iter()
            .filter_map(|line| {
                line.timestamp
                    .map(|ts| format!("{} {}", Self::format_lrc_timestamp(ts), line.text))
            })
            .collect();
        if out.is_empty() {
            None
        } else {
            Some(out.join("\n"))
        }
    }
}
