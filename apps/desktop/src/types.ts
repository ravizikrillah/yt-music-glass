export type HudDisplayMode = 'full' | 'compact';
export type FontStyle = 'roboto' | 'sfpro';
export type PillEdge = 'top' | 'bottom';

export interface LyricWord {
  startTime: number;
  endTime: number;
  text: string;
}

export interface LyricLine {
  startTime: number;
  endTime: number;
  text: string;
  words?: LyricWord[] | null;
  isInstrumental: boolean;
}

export interface ParsedLyrics {
  mode: 'synced' | 'plain';
  hasWordSync: boolean;
  lines: LyricLine[];
  plainLines: string[];
}

export interface SyncFrame {
  effectiveTime: number;
  activeLineIndex: number;
  nextVocalLineIndex: number;
  lineProgress: number;
  activeWordIndex: number;
  wordProgress: number;
  instrumentalActive: boolean;
  instrumentalProgress: number;
}

export interface TrackSummary {
  trackKey: string;
  title: string;
  artist: string;
  album?: string | null;
  duration: number;
  artworkUrl?: string | null;
}

export interface PlaybackState {
  currentTime: number;
  duration: number;
  paused: boolean;
  playbackRate: number;
  isAdPlaying: boolean;
}

export interface LrclibCandidate {
  id: number;
  trackName: string;
  artistName: string;
  albumName?: string | null;
  duration: number;
  instrumental: boolean;
  syncedLyrics?: string | null;
  plainLyrics?: string | null;
}

export interface TapSyncLineState {
  index: number;
  text: string;
  timestamp: number | null;
}

export interface TapSyncState {
  trackKey: string;
  currentIndex: number;
  totalCount: number;
  tappedCount: number;
  isComplete: boolean;
  lines: TapSyncLineState[];
}

export interface UpdateStatePayload {
  status: 'idle' | 'checking' | 'upToDate' | 'available' | 'downloading' | 'error';
  message: string;
  version?: string | null;
  downloadUrl?: string | null;
  releaseUrl?: string | null;
  assetName?: string | null;
  assetSizeBytes?: number | null;
}

export interface AppSnapshot {
  version: string;
  siteMode: 'ytm' | 'youtube';
  status: string;
  statusMessage: string;
  track: TrackSummary | null;
  playback: PlaybackState;
  parsed: ParsedLyrics | null;
  frame: SyncFrame;
  romanizedLines: (string | null)[];
  translatedLines: (string | null)[];
  candidates: LrclibCandidate[];
  selectedCandidateId: number | null;
  lyricsSource: string | null;
  isOfflinePinned: boolean;
  offlineVaultCount: number;
  kanjiDictReady: boolean;
  kanjiDictDownloading: boolean;
  accentRgb: string;
  offsetMs: number;
  hudOpacity: number;
  hudMode: HudDisplayMode;
  clickThrough: boolean;
  pillEnabled: boolean;
  pillEdge: PillEdge;
  romanizeEnabled: boolean;
  translateEnabled: boolean;
  translateSource: string;
  translateTarget: string;
  themeEnabled: boolean;
  fontStyle: FontStyle;
  tapSync: TapSyncState | null;
  update: UpdateStatePayload;
}
