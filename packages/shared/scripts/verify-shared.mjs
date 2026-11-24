#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const sharedDir = path.resolve(__dirname, '..');

function assert(cond, msg) {
  if (!cond) {
    console.error(`FAIL: ${msg}`);
    process.exit(1);
  }
}

const cssPath = path.join(sharedDir, 'web', 'theme-glass.css');
const installerPath = path.join(sharedDir, 'web', 'theme-installer.js');
const bridgePath = path.join(sharedDir, 'web', 'bridge.js');
const vectorsPath = path.join(sharedDir, 'test-vectors', 'core-vectors.json');

const css = fs.readFileSync(cssPath, 'utf8');
const installer = fs.readFileSync(installerPath, 'utf8');
const bridge = fs.readFileSync(bridgePath, 'utf8');
const vectors = JSON.parse(fs.readFileSync(vectorsPath, 'utf8'));

assert(css.includes('--ytmg-accent-rgb'), 'theme-glass.css has accent CSS variable');
assert(css.includes('ytmusic-player-bar'), 'theme-glass.css styles ytmusic-player-bar');

// Syntax-check JS scripts with Node VM without executing DOM runtime
new vm.Script(installer, { filename: 'theme-installer.js' });
new vm.Script(bridge, { filename: 'bridge.js' });

assert(bridge.includes('emitToNative('), 'bridge.js uses unified emitToNative');
assert(bridge.includes('window.__TAURI_INTERNALS__'), 'bridge.js supports Tauri IPC');
assert(bridge.includes('window.webkit.messageHandlers.ytmgBridge'), 'bridge.js supports WebKit bridge');

assert(Array.isArray(vectors.metadata) && vectors.metadata.length >= 3, 'metadata test vectors present');
assert(Array.isArray(vectors.koreanRomanization) && vectors.koreanRomanization.length >= 3, 'romanizer vectors present');
assert(Array.isArray(vectors.semver) && vectors.semver.length >= 5, 'semver vectors present');

console.log('SHARED_ASSETS_VERIFIED');
