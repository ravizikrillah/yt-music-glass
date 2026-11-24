#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(__dirname, '../..');
const changelogPath = path.join(rootDir, 'CHANGELOG.md');

const DEFAULT_REPO_URL = 'https://github.com/ravizikrillah/yt-music-glass';

function getRepoUrl() {
  const server = process.env.GITHUB_SERVER_URL;
  const repo = process.env.GITHUB_REPOSITORY;
  if (server && repo) {
    return `${server.replace(/\/$/, '')}/${repo}`;
  }
  return DEFAULT_REPO_URL;
}

function parseSections(markdown) {
  const headingRegex = /^## \[([^\]]+)\](?:[^\n]*)?$/gm;
  const matches = [...markdown.matchAll(headingRegex)];
  return matches.map((match, idx) => {
    const start = match.index + match[0].length;
    const end = idx + 1 < matches.length ? matches[idx + 1].index : markdown.length;
    return {
      version: match[1].trim(),
      body: markdown.slice(start, end).trim(),
    };
  });
}

function findPreviousTag(version, sections) {
  const currentTag = `v${version}`;
  try {
    const out = execFileSync('git', ['tag', '--sort=-v:refname'], {
      cwd: rootDir,
      encoding: 'utf8',
    });
    const tags = out
      .split(/\r?\n/)
      .map((t) => t.trim())
      .filter((t) => /^v\d+\.\d+\.\d+/.test(t) && t !== currentTag);
    if (tags.length > 0) {
      return tags[0];
    }
  } catch {
    // Fallback to CHANGELOG section ordering when git tags are absent.
  }

  const idx = sections.findIndex((s) => s.version === version);
  if (idx >= 0 && idx + 1 < sections.length) {
    return `v${sections[idx + 1].version}`;
  }
  return null;
}

function getCommitHighlights(prevTag, version) {
  const range = prevTag ? `${prevTag}..HEAD` : 'HEAD';
  try {
    const out = execFileSync(
      'git',
      ['log', range, '--no-merges', '--pretty=format:%s'],
      { cwd: rootDir, encoding: 'utf8' },
    );
    const lines = out
      .split(/\r?\n/)
      .map((s) => s.trim())
      .filter(Boolean);
    const nonBump = lines.filter(
      (s) => !/^chore\(release\):|^release:/i.test(s) && !new RegExp(`\\bv?${version}\\b`).test(s),
    );
    const chosen = nonBump.length > 0 ? nonBump : lines;
    if (chosen.length > 0) {
      return chosen.map((line) => `- ${line}`).join('\n');
    }
  } catch {
    // Ignore git log failures in shallow/tarball contexts.
  }
  return '- Maintenance and cross-platform desktop release updates';
}

function buildCompareLine(repoUrl, prevTag, version) {
  if (prevTag) {
    return `**Full Changelog**: ${repoUrl}/compare/${prevTag}...v${version}`;
  }
  return `**Full Changelog**: ${repoUrl}/commits/v${version}`;
}

function buildInstallSection() {
  return [
    '### Install',
    '- **macOS (Apple Silicon & Intel, 13.0+):** Download `YT-Music-Glass-macOS-arm64.dmg` (M1–M4) or `YT-Music-Glass-macOS-x86_64.dmg` (Intel), drag **YT Music Glass.app** into **Applications**, and on first launch right-click → **Open** (or run `xattr -cr "/Applications/YT Music Glass.app"`).',
    '- **Windows (10/11 x64):** Run `YT-Music-Glass-Windows-x64-Setup.exe` (NSIS installer) or extract `YT-Music-Glass-Windows-x64-Portable.zip`. If SmartScreen prompts on first launch, click **More info → Run anyway**.',
    '- **Linux (x86_64 / amd64):** Run `chmod +x YT-Music-Glass-Linux-x86_64.AppImage && ./YT-Music-Glass-Linux-x86_64.AppImage` or install via `sudo apt install ./YT-Music-Glass-Linux-amd64.deb`.',
  ].join('\n');
}

export function generateReleaseNotes(tagName) {
  const version = String(tagName || '').replace(/^v/, '').trim();
  if (!version) {
    throw new Error('Tag or version argument is required (e.g. v1.2.0)');
  }

  const markdown = fs.existsSync(changelogPath)
    ? fs.readFileSync(changelogPath, 'utf8')
    : '';
  const sections = parseSections(markdown);
  const match = sections.find((s) => s.version === version);
  const repoUrl = getRepoUrl();
  const prevTag = findPreviousTag(version, sections);

  if (match && match.body.length > 0) {
    const lines = [`## YT Music Glass v${version}`, '', match.body];
    if (!/\*\*Full Changelog\*\*:/.test(match.body)) {
      lines.push('', buildCompareLine(repoUrl, prevTag, version));
    }
    return `${lines.join('\n').trim()}\n`;
  }

  const highlights = getCommitHighlights(prevTag, version);
  return [
    `## YT Music Glass v${version}`,
    '',
    'Lightweight cross-platform desktop client for YouTube Music & YouTube — **macOS (Apple Silicon & Intel, 13.0+)**, **Windows**, and **Linux** (zero Electron).',
    '',
    '### Highlights',
    highlights,
    '',
    buildInstallSection(),
    '',
    buildCompareLine(repoUrl, prevTag, version),
    '',
  ].join('\n');
}

function verifyChangelog() {
  if (!fs.existsSync(changelogPath)) {
    throw new Error('CHANGELOG.md is missing at repository root');
  }
  const markdown = fs.readFileSync(changelogPath, 'utf8');
  const sections = parseSections(markdown);
  if (sections.length === 0) {
    throw new Error('CHANGELOG.md contains no `## [X.Y.Z]` version sections');
  }

  for (const section of sections) {
    if (!/^### Highlights/m.test(section.body)) {
      throw new Error(`CHANGELOG.md [${section.version}] is missing \`### Highlights\``);
    }
    if (!/^### Install/m.test(section.body)) {
      throw new Error(`CHANGELOG.md [${section.version}] is missing \`### Install\``);
    }
    if (!/\*\*Full Changelog\*\*:/.test(section.body)) {
      throw new Error(`CHANGELOG.md [${section.version}] is missing \`**Full Changelog**:\``);
    }
  }

  const latestNotes = generateReleaseNotes(`v${sections[0].version}`);
  if (!latestNotes.startsWith(`## YT Music Glass v${sections[0].version}`)) {
    throw new Error('Generated release notes header failed sanity check');
  }

  console.log(`CHANGELOG_VERIFIED (${sections.length} releases; latest v${sections[0].version})`);
}

const args = process.argv.slice(2);
if (args[0] === '--verify') {
  verifyChangelog();
} else {
  const tagArg = args[0] || process.env.GITHUB_REF_NAME;
  const outArg = args[1];
  const notes = generateReleaseNotes(tagArg);
  if (outArg) {
    fs.mkdirSync(path.dirname(outArg), { recursive: true });
    fs.writeFileSync(outArg, notes, 'utf8');
  } else {
    process.stdout.write(notes);
  }
}
