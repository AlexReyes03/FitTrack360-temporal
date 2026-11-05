#!/usr/bin/env node
import { exec, execFile, execSync, spawn } from 'node:child_process';
import fs from 'node:fs';
import http from 'node:http';
import net from 'node:net';
import os from 'node:os';
import path from 'node:path';
import readline from 'node:readline';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const API_DIR = path.join(ROOT, 'fit_track_api');
const API_ENV = path.join(API_DIR, '.env');
const FLUTTER_DIR = path.join(ROOT, 'fit_track_360');
const IS_WINDOWS = process.platform === 'win32';

const RESET = '\x1b[0m';
const COLOR_OFF = '\x1b[90m';
const COLOR_WARN = '\x1b[33m';
const COLOR_OK = '\x1b[34m';

const CIRCLE_OFF = `${COLOR_OFF}○${RESET}`;
const CIRCLE_WARN = `${COLOR_WARN}●${RESET}`;
const CIRCLE_OK = `${COLOR_OK}●${RESET}`;

const FOOTER =
  'Flechas ↑↓ (Movimiento). Space (Seleccionar/Apagar). R (Recargar). W (Wi-Fi). P (Prisma Studio). Esc (Salir).';
const TITLE = 'FitTrack360 - Services';
const FLUTTER_TITLE = 'FitTrack Flutter';
const PG_CONTAINER = 'fittrack-postgres';
const API_CONTAINER = 'fittrack-api';
const API_IMAGE = 'fittrack-api:dev';
const API_DATABASE_URL = 'postgresql://fittrack:fittrack@host.docker.internal:5432/fittrack';
const DEFAULT_API_PORT = 3000;
const PRISMA_STUDIO_PORT = 5555;
const POLL_MS = 1000;
const ROW_POLL_TIMEOUT_MS = 60 * 1000;
const AVD_POLL_TIMEOUT_MS = 90 * 1000;
const KEEP_AWAKE_SCREEN_OFF_MS = 30 * 60 * 1000;

const FLUTTER_PS =
  'powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { $_.Name -match \'dart|dartvm\' -and $_.CommandLine -match \'flutter_tools.snapshot.*run\' } | Select-Object -ExpandProperty ProcessId"';

const PENDING = { level: 'off', text: '...' };

let mode = 'main';
let selectedIndex = 0;
let deviceLines = [];
let deviceSelected = 0;
let devicesState = { sdk: null, avds: [], running: new Map(), physical: [] };
let deviceStatus = {};
let deviceBusyName = null;
let devicePoll = null;
let flutterTargets = [];
let flutterTargetSelected = 0;
let flutterKeepAwake = null;
let wirelessPairing = null;
let wirelessCode = '';
let message = null;
const polls = new Map();
let dockerStatus = { available: true, installed: true };

function circleFor(level) {
  if (level === 'ok') {
    return CIRCLE_OK;
  }
  if (level === 'warn') {
    return CIRCLE_WARN;
  }
  return CIRCLE_OFF;
}

function runLine(line, options = {}) {
  return new Promise((resolve) => {
    exec(
      line,
      { cwd: ROOT, windowsHide: true, maxBuffer: 8 * 1024 * 1024, ...options },
      (error, stdout, stderr) => {
        const code = error ? (typeof error.code === 'number' ? error.code : 1) : 0;
        resolve({ code, stdout: stdout ?? '', stderr: stderr ?? '', error });
      },
    );
  });
}

function runArgs(command, args, options = {}) {
  return new Promise((resolve) => {
    execFile(
      command,
      args,
      { cwd: ROOT, windowsHide: true, maxBuffer: 8 * 1024 * 1024, timeout: 15000, ...options },
      (error, stdout, stderr) => {
        const code = error ? (typeof error.code === 'number' ? error.code : 1) : 0;
        resolve({ code, stdout: stdout ?? '', stderr: stderr ?? '', error });
      },
    );
  });
}

function firstLine(text) {
  const line = (text ?? '').split(/\r?\n/).find((entry) => entry.trim().length > 0);
  return (line ?? '').trim();
}

let windowsTerminalPath;

function resolveWindowsTerminal() {
  if (windowsTerminalPath !== undefined) {
    return windowsTerminalPath;
  }
  windowsTerminalPath = null;
  try {
    const result = execSync('where wt.exe', {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    });
    const candidate = result
      .split(/\r?\n/)
      .map((line) => line.trim())
      .find((line) => line.length > 0);
    if (candidate) {
      windowsTerminalPath = candidate;
    }
  } catch {
    windowsTerminalPath = null;
  }
  return windowsTerminalPath;
}

function spawnLegacyWindow(title, innerCommand, cwd) {
  const child = spawn(
    'cmd.exe',
    ['/d', '/s', '/c', `start "${title}" cmd /k ${innerCommand}`],
    { cwd, detached: true, stdio: 'ignore', windowsVerbatimArguments: true },
  );
  child.unref();
}

function openWindow(title, innerCommand, cwd) {
  if (IS_WINDOWS) {
    const terminal = resolveWindowsTerminal();
    if (terminal) {
      const child = spawn(
        terminal,
        ['-w', '0', 'new-tab', '--title', title, '-d', cwd, 'cmd', '/k', innerCommand],
        { cwd, detached: true, stdio: 'ignore' },
      );
      child.on('error', () => {
        spawnLegacyWindow(title, innerCommand, cwd);
      });
      child.unref();
      return;
    }
    spawnLegacyWindow(title, innerCommand, cwd);
    return;
  }
  if (process.platform === 'darwin') {
    const shellCommand = `cd '${cwd}' && ${innerCommand}`
      .replace(/\\/g, '\\\\')
      .replace(/"/g, '\\"');
    const child = spawn('osascript', ['-e', `tell application "Terminal" to do script "${shellCommand}"`], {
      detached: true,
      stdio: 'ignore',
    });
    child.unref();
    return;
  }
  const child = spawn(innerCommand, { cwd, detached: true, stdio: 'ignore', shell: true });
  child.unref();
}

function openUrl(url) {
  if (IS_WINDOWS) {
    const child = spawn('cmd.exe', ['/d', '/s', '/c', `start "" "${url}"`], {
      detached: true,
      stdio: 'ignore',
      windowsVerbatimArguments: true,
    });
    child.unref();
    return;
  }
  const command = process.platform === 'darwin' ? 'open' : 'xdg-open';
  const child = spawn(command, [url], { detached: true, stdio: 'ignore' });
  child.unref();
}

function checkPort(port, host = '127.0.0.1', timeout = 600) {
  return new Promise((resolve) => {
    const socket = new net.Socket();
    let settled = false;
    const finish = (value) => {
      if (settled) {
        return;
      }
      settled = true;
      socket.destroy();
      resolve(value);
    };
    socket.setTimeout(timeout);
    socket.once('connect', () => finish(true));
    socket.once('timeout', () => finish(false));
    socket.once('error', () => finish(false));
    socket.connect(port, host);
  });
}

function httpStatus(port, requestPath, host = '127.0.0.1', timeout = 800) {
  return new Promise((resolve) => {
    const request = http.get({ host, port, path: requestPath, timeout }, (response) => {
      response.resume();
      resolve(response.statusCode ?? 0);
    });
    request.once('timeout', () => {
      request.destroy();
      resolve(null);
    });
    request.once('error', () => resolve(null));
  });
}

async function isApiHttp(port) {
  const withSlash = await httpStatus(port, '/api/v1/');
  if (withSlash === 200) {
    return true;
  }
  if (withSlash === null) {
    return false;
  }
  return (await httpStatus(port, '/api/v1')) === 200;
}

function readApiPort() {
  if (!fs.existsSync(API_ENV)) {
    return DEFAULT_API_PORT;
  }
  const match = fs.readFileSync(API_ENV, 'utf8').match(/^PORT=(\d+)/m);
  if (!match) {
    return DEFAULT_API_PORT;
  }
  const port = Number(match[1]);
  return Number.isInteger(port) && port > 0 && port < 65536 ? port : DEFAULT_API_PORT;
}

function apiDatabaseUrl() {
  if (!fs.existsSync(API_ENV)) {
    return API_DATABASE_URL;
  }
  const match = fs.readFileSync(API_ENV, 'utf8').match(/^DATABASE_URL=(.+)$/m);
  if (!match) {
    return API_DATABASE_URL;
  }
  return match[1]
    .trim()
    .replace(/@(localhost|127\.0\.0\.1)(:|\/)/, '@host.docker.internal$2');
}

function matchesFlutter(line) {
  const lower = line.toLowerCase();
  return lower.includes('flutter_tools.snapshot') && /\brun\b/.test(lower);
}

async function flutterPids() {
  if (IS_WINDOWS) {
    const result = await runLine(FLUTTER_PS, { timeout: 15000 });
    if (result.code !== 0) {
      return [];
    }
    return result.stdout
      .split(/\r?\n/)
      .map((line) => line.trim())
      .filter((line) => /^\d+$/.test(line));
  }
  const result = await runLine('ps -ax -o pid=,command=', { timeout: 10000 });
  return result.stdout
    .split(/\r?\n/)
    .filter((line) => matchesFlutter(line))
    .map((line) => line.trim().split(/\s+/)[0])
    .filter((pid) => /^\d+$/.test(pid));
}

async function killPids(pids) {
  for (const pid of pids) {
    if (IS_WINDOWS) {
      await runArgs('taskkill', ['/PID', String(pid), '/T', '/F'], { timeout: 20000 });
    } else {
      await runArgs('kill', ['-9', String(pid)], { timeout: 20000 });
    }
  }
}

async function keepScreenAwake(deviceId) {
  const sdk = devicesState.sdk ?? resolveSdk();
  if (!sdk?.adb || deviceId === 'chrome') {
    return null;
  }
  const current = await runArgs(sdk.adb, [
    '-s',
    deviceId,
    'shell',
    'settings',
    'get',
    'system',
    'screen_off_timeout',
  ]);
  const previous = current.code === 0 ? current.stdout.trim() : '';
  const applied = await runArgs(sdk.adb, [
    '-s',
    deviceId,
    'shell',
    'settings',
    'put',
    'system',
    'screen_off_timeout',
    String(KEEP_AWAKE_SCREEN_OFF_MS),
  ]);
  if (applied.code !== 0) {
    return null;
  }
  await runArgs(sdk.adb, ['-s', deviceId, 'shell', 'input', 'keyevent', 'KEYCODE_WAKEUP']);
  return { adb: sdk.adb, deviceId, previous, confirmed: false };
}

async function restoreScreenTimeout(session) {
  if (!session) {
    return;
  }
  const args = /^\d+$/.test(session.previous)
    ? ['-s', session.deviceId, 'shell', 'settings', 'put', 'system', 'screen_off_timeout', session.previous]
    : ['-s', session.deviceId, 'shell', 'settings', 'delete', 'system', 'screen_off_timeout'];
  await runArgs(session.adb, args);
}

async function restoreKeepAwake() {
  const session = flutterKeepAwake;
  flutterKeepAwake = null;
  await restoreScreenTimeout(session);
}

async function readFlutter() {
  const pids = await flutterPids();
  if (pids.length > 0) {
    if (flutterKeepAwake) {
      flutterKeepAwake.confirmed = true;
    }
    return { level: 'ok', text: 'Iniciado', pids };
  }
  if (flutterKeepAwake?.confirmed) {
    await restoreKeepAwake();
  }
  return { level: 'off', text: 'No iniciado', pids: [] };
}

async function stopFlutter() {
  const pids = await flutterPids();
  if (pids.length === 0) {
    await refreshRow('flutter');
    await restoreKeepAwake();
    return;
  }
  startPoll('flutter', { text: 'Deteniendo...', isDone: (fresh) => fresh.level === 'off' });
  await killPids(pids);
  await restoreKeepAwake();
}

async function dockerPsRows() {
  const result = await runArgs('docker', ['ps', '-a', '--format', '{{.Names}}|{{.State}}|{{.Ports}}']);
  if (result.code !== 0) {
    dockerStatus = { available: false, installed: result.error?.code !== 'ENOENT' };
    return null;
  }
  dockerStatus = { available: true, installed: true };
  return result.stdout
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line.length > 0)
    .map((line) => {
      const [name = '', state = '', ports = ''] = line.split('|');
      return { name, state, ports };
    });
}

async function readPostgres() {
  const rows = await dockerPsRows();
  if (!rows) {
    return {
      level: 'warn',
      text: dockerStatus.installed ? 'Docker no está corriendo' : 'Docker no está instalado',
      exists: false,
      running: false,
      hasPort: false,
    };
  }
  const publishing = rows.find((row) => row.state === 'running' && row.ports.includes('5432'));
  if (publishing) {
    return {
      level: 'ok',
      text: 'Iniciado en el puerto 5432',
      exists: true,
      running: true,
      hasPort: true,
      name: publishing.name,
    };
  }
  const named = rows.find((row) => row.name === PG_CONTAINER);
  if (named && named.state === 'running') {
    return {
      level: 'warn',
      text: 'Iniciado sin el puerto 5432',
      exists: true,
      running: true,
      hasPort: false,
      name: named.name,
    };
  }
  if (named) {
    return {
      level: 'warn',
      text: 'Detenido',
      exists: true,
      running: false,
      hasPort: false,
      name: named.name,
    };
  }
  return { level: 'off', text: 'No iniciado', exists: false, running: false, hasPort: false };
}

async function readPrisma() {
  if (!fs.existsSync(API_ENV)) {
    return {
      level: 'off',
      text: 'No iniciado (Depende de Postgres)',
      envMissing: true,
      pending: false,
    };
  }
  const result = await runLine('pnpm --dir fit_track_api exec prisma migrate status', {
    timeout: 25000,
  });
  const output = `${result.stdout}\n${result.stderr}`;
  if (/P1001|Can't reach database|ECONNREFUSED/i.test(output)) {
    return {
      level: 'off',
      text: 'No iniciado (Depende de Postgres)',
      envMissing: false,
      pending: false,
    };
  }
  if (/not yet been applied/i.test(output)) {
    return { level: 'warn', text: 'Requiere actualizar', envMissing: false, pending: true };
  }
  if (/Database schema is up to date/i.test(output)) {
    return { level: 'ok', text: 'Iniciado', envMissing: false, pending: false };
  }
  if (result.code !== 0) {
    return {
      level: 'warn',
      text: 'Requiere actualizar',
      envMissing: false,
      pending: true,
      errorLine: firstLine(output),
    };
  }
  return { level: 'ok', text: 'Iniciado', envMissing: false, pending: false };
}

async function readApi() {
  const port = readApiPort();
  const rows = await dockerPsRows();
  if (!rows) {
    return {
      level: 'warn',
      text: dockerStatus.installed ? 'Docker no está corriendo' : 'Docker no está instalado',
      port,
      exists: false,
      running: false,
    };
  }
  const named = rows.find((row) => row.name === API_CONTAINER);
  if (!named) {
    return {
      level: 'off',
      text: 'No iniciado (Depende de Postgres)',
      port,
      exists: false,
      running: false,
    };
  }
  const publishing = named.state === 'running' && named.ports.includes(`:${port}->`);
  if (named.state !== 'running') {
    return { level: 'warn', text: 'Detenido', port, exists: true, running: false };
  }
  if (!publishing) {
    return { level: 'off', text: `Iniciado sin el puerto ${port}`, port, exists: true, running: true };
  }
  const api = await isApiHttp(port);
  if (api) {
    return { level: 'ok', text: `Iniciado en el puerto ${port}`, port, exists: true, running: true };
  }
  return { level: 'warn', text: `Puerto ${port} ocupado`, port, exists: true, running: true };
}

function resolveSdk() {
  const candidates = [];
  if (process.env.ANDROID_HOME) {
    candidates.push(process.env.ANDROID_HOME);
  }
  if (process.env.ANDROID_SDK_ROOT) {
    candidates.push(process.env.ANDROID_SDK_ROOT);
  }
  const localProperties = path.join(FLUTTER_DIR, 'android', 'local.properties');
  if (fs.existsSync(localProperties)) {
    const match = fs.readFileSync(localProperties, 'utf8').match(/^sdk\.dir=(.+)$/m);
    if (match) {
      candidates.push(match[1].trim().replace(/\\\\/g, '\\'));
    }
  }
  if (IS_WINDOWS && process.env.LOCALAPPDATA) {
    candidates.push(path.join(process.env.LOCALAPPDATA, 'Android', 'Sdk'));
  }
  if (process.env.HOME) {
    if (process.platform === 'darwin') {
      candidates.push(path.join(process.env.HOME, 'Library', 'Android', 'sdk'));
    }
    if (process.platform === 'linux') {
      candidates.push(path.join(process.env.HOME, 'Android', 'Sdk'));
    }
  }
  for (const candidate of candidates) {
    const emulator = path.join(candidate, 'emulator', IS_WINDOWS ? 'emulator.exe' : 'emulator');
    if (fs.existsSync(emulator)) {
      const adb = path.join(candidate, 'platform-tools', IS_WINDOWS ? 'adb.exe' : 'adb');
      return { sdk: candidate, emulator, adb: fs.existsSync(adb) ? adb : null };
    }
  }
  return null;
}

async function adbSerials(sdk) {
  if (!sdk?.adb) {
    return [];
  }
  const devices = await runArgs(sdk.adb, ['devices']);
  return devices.stdout
    .split(/\r?\n/)
    .map((line) => line.trim().split(/\s+/))
    .filter((parts) => parts.length >= 2 && parts[1] === 'device')
    .map((parts) => parts[0]);
}

async function runningAvds(sdk, avds) {
  const running = new Map();
  for (const serial of await adbSerials(sdk)) {
    if (!serial.startsWith('emulator-')) {
      continue;
    }
    const name = await runArgs(sdk.adb, ['-s', serial, 'emu', 'avd', 'name']);
    const avd = firstLine(name.stdout);
    if (avds.includes(avd)) {
      running.set(avd, serial);
    }
  }
  return running;
}

async function physicalDevices(sdk) {
  const devices = [];
  for (const serial of await adbSerials(sdk)) {
    if (serial.startsWith('emulator-')) {
      continue;
    }
    const model = await runArgs(sdk.adb, ['-s', serial, 'shell', 'getprop', 'ro.product.model']);
    devices.push({ serial, name: firstLine(model.stdout) || serial });
  }
  return devices;
}

async function mdnsSupported(sdk) {
  if (!sdk?.adb) {
    return false;
  }
  const result = await runArgs(sdk.adb, ['mdns', 'check'], { timeout: 15000 });
  const output = `${result.stdout}\n${result.stderr}`.toLowerCase();
  return result.code === 0 && !output.includes('not running') && !output.includes('unknown');
}

async function discoverWireless(sdk) {
  if (!sdk?.adb) {
    return { supported: false, connect: [], pairing: [] };
  }
  if (!(await mdnsSupported(sdk))) {
    return { supported: false, connect: [], pairing: [] };
  }
  const result = await runArgs(sdk.adb, ['mdns', 'services'], { timeout: 15000 });
  const connect = [];
  const pairing = [];
  for (const line of `${result.stdout}\n${result.stderr}`.split(/\r?\n/)) {
    const match = line.match(/_adb-tls-(connect|pairing)\._tcp\.?\s+(\S+)\s*$/);
    if (!match) {
      continue;
    }
    if (match[1] === 'connect') {
      connect.push(match[2]);
    } else {
      pairing.push(match[2]);
    }
  }
  return { supported: true, connect, pairing };
}

async function connectWireless(sdk, endpoints) {
  const connected = [];
  for (const endpoint of endpoints) {
    const result = await runArgs(sdk.adb, ['connect', endpoint], { timeout: 20000 });
    const output = `${result.stdout}\n${result.stderr}`.toLowerCase();
    if (output.includes('connected to') && !output.includes('failed')) {
      connected.push(endpoint);
    }
  }
  return connected;
}

async function loadDevices() {
  const sdk = resolveSdk();
  if (!sdk) {
    return { sdk: null, avds: [], running: new Map(), physical: [] };
  }
  const listed = await runArgs(sdk.emulator, ['-list-avds'], { timeout: 12000 });
  const avds = `${listed.stdout}\n${listed.stderr}`
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line.length > 0);
  const running = await runningAvds(sdk, avds);
  const physical = await physicalDevices(sdk);
  return { sdk, avds, running, physical };
}

async function readDevicesSummary() {
  const state = await loadDevices();
  devicesState = state;
  if (!state.sdk) {
    return { level: 'warn', text: 'Sin SDK de Android' };
  }
  if (state.running.size > 0 || state.physical.length > 0) {
    return { level: 'ok', text: 'Iniciado' };
  }
  if (state.avds.length === 0) {
    return { level: 'off', text: 'No iniciado' };
  }
  return { level: 'warn', text: 'Detenido' };
}

const ROWS = [
  { id: 'devices', label: 'Dispositivos', read: readDevicesSummary },
  { id: 'flutter', label: 'Flutter', read: readFlutter },
  { id: 'postgres', label: 'Postgres (Docker)', read: readPostgres },
  { id: 'prisma', label: 'Prisma', read: readPrisma },
  { id: 'api', label: 'API Nest (Docker)', read: readApi },
];

const stateMap = {
  flutter: { ...PENDING },
  postgres: { ...PENDING },
  prisma: { ...PENDING },
  api: { ...PENDING },
  devices: { ...PENDING },
};

function rowById(id) {
  return ROWS.find((row) => row.id === id);
}

function deviceTextFor(name) {
  const status = deviceStatus[name];
  if (status?.start === 'stopping') {
    return { level: 'warn', text: 'Deteniendo...' };
  }
  if (devicesState.running.has(name)) {
    return { level: 'ok', text: 'Iniciado' };
  }
  if (status?.start === 'starting') {
    return { level: 'warn', text: 'Iniciando...' };
  }
  if (status?.start === 'error') {
    return { level: 'warn', text: status.errorText || 'El emulador termino con error.' };
  }
  return { level: 'off', text: 'No iniciado' };
}

function buildDeviceLines() {
  if (!devicesState.sdk) {
    return [{ raw: `${COLOR_WARN}No se encontró emulator. Revisa ANDROID_HOME.${RESET}` }];
  }
  const lines = (devicesState.physical ?? []).map((device) => ({
    level: 'ok',
    name: device.name,
    text: `Conectado (${device.serial})`,
  }));
  if (devicesState.avds.length === 0) {
    return lines.length > 0 ? lines : [{ raw: 'No hay AVDs. Crea uno en Android Studio.' }];
  }
  return [...lines, ...devicesState.avds.map((name) => ({ selectable: true, name, ...deviceTextFor(name) }))];
}

function selectableIndices() {
  return deviceLines.map((line, index) => (line.selectable ? index : -1)).filter((index) => index >= 0);
}

function syncDeviceSelection() {
  deviceLines = buildDeviceLines();
  const indices = selectableIndices();
  if (indices.length === 0) {
    deviceSelected = 0;
    return;
  }
  if (!indices.includes(deviceSelected)) {
    deviceSelected = indices[0];
  }
}

function draw() {
  if (mode === 'devices') {
    syncDeviceSelection();
  }
  const lines = [`\x1b[1m${TITLE}${RESET}`, ''];
  if (mode === 'main') {
    ROWS.forEach((row, index) => {
      const state = stateMap[row.id] ?? { level: 'off', text: 'No iniciado' };
      const prefix = index === selectedIndex ? '> ' : '  ';
      lines.push(`${prefix}${circleFor(state.level)} ${row.label} - ${state.text}`);
    });
  } else if (mode === 'pairing') {
    lines.push('Vinculación inalámbrica');
    lines.push(`Endpoint: ${wirelessPairing ?? ''}`);
    lines.push(`Código: ${wirelessCode || '______'}`);
  } else if (mode === 'flutter-target') {
    lines.push('Iniciar Flutter en');
    flutterTargets.forEach((target, index) => {
      const prefix = index === flutterTargetSelected ? '> ' : '  ';
      lines.push(`${prefix}${target.label}`);
    });
  } else {
    lines.push('Dispositivos');
    deviceLines.forEach((line, index) => {
      if (line.raw) {
        lines.push(`  ${line.raw}`);
        return;
      }
      const prefix = index === deviceSelected ? '> ' : '  ';
      lines.push(`${prefix}${circleFor(line.level)} ${line.name} - ${line.text}`);
    });
  }
  lines.push('');
  if (message) {
    lines.push(message);
  }
  lines.push(FOOTER);
  process.stdout.write(`\x1b[2J\x1b[H\x1b[?25l${lines.join('\n')}\n`);
  message = null;
}

function setMessage(text) {
  message = text;
}

function beginRow(id, text) {
  const previous = stateMap[id] ?? { level: 'off', text: 'No iniciado' };
  stateMap[id] = { ...previous, level: 'warn', text };
  draw();
}

async function refreshRow(id) {
  stateMap[id] = await rowById(id).read();
  draw();
}

async function refreshAll() {
  await Promise.all(
    ROWS.map(async (row) => {
      if (row.id === 'devices' && mode === 'devices') {
        return;
      }
      const value = await row.read();
      if ((row.id === 'devices' && mode === 'devices') || polls.has(row.id)) {
        return;
      }
      stateMap[row.id] = value;
      if (mode === 'main') {
        draw();
      }
    }),
  );
}

function stopPoll(id) {
  const timer = polls.get(id);
  if (timer) {
    clearInterval(timer);
    polls.delete(id);
  }
}

function startPoll(id, options) {
  stopPoll(id);
  const started = Date.now();
  const previous = stateMap[id] ?? { level: 'off', text: 'No iniciado' };
  stateMap[id] = { ...previous, level: 'warn', text: options.text };
  draw();
  let ticking = false;
  const timer = setInterval(() => {
    if (ticking) {
      return;
    }
    ticking = true;
    void (async () => {
      try {
        const fresh = await rowById(id).read();
        if (!polls.has(id)) {
          return;
        }
        if (options.isDone(fresh)) {
          stateMap[id] = fresh;
          stopPoll(id);
          draw();
          return;
        }
        if (options.isFailed?.(fresh)) {
          stateMap[id] = fresh;
          stopPoll(id);
          setMessage(options.failMessage?.(fresh) ?? 'El servicio termino con error.');
          draw();
          return;
        }
        if (Date.now() - started >= ROW_POLL_TIMEOUT_MS) {
          stateMap[id] = fresh;
          stopPoll(id);
          draw();
          return;
        }
        stateMap[id] = { ...fresh, level: 'warn', text: options.text };
        draw();
      } finally {
        ticking = false;
      }
    })();
  }, POLL_MS);
  polls.set(id, timer);
}

function moveDeviceSelection(delta) {
  const indices = selectableIndices();
  if (indices.length === 0) {
    return;
  }
  const current = indices.indexOf(deviceSelected);
  const position = current === -1 ? 0 : current;
  const next = Math.min(Math.max(position + delta, 0), indices.length - 1);
  deviceSelected = indices[next];
}

async function buildFlutterTargets() {
  devicesState = await loadDevices();
  const targets = [];
  for (const device of devicesState.physical ?? []) {
    targets.push({ label: `${device.name} (${device.serial})`, deviceId: device.serial });
  }
  for (const [name, serial] of devicesState.running) {
    targets.push({ label: `${name} (${serial})`, deviceId: serial });
  }
  targets.push({ label: 'Chrome (web)', deviceId: 'chrome' });
  return targets;
}

async function prepareFlutterApiUrl(target) {
  const port = readApiPort();
  if (target.deviceId === 'chrome') {
    return `http://localhost:${port}`;
  }
  const sdk = devicesState.sdk ?? resolveSdk();
  if (!sdk?.adb) {
    return null;
  }
  const result = await runArgs(sdk.adb, [
    '-s',
    target.deviceId,
    'reverse',
    `tcp:${port}`,
    `tcp:${port}`,
  ]);
  return result.code === 0 ? `http://127.0.0.1:${port}` : null;
}

async function launchFlutterTarget() {
  const target = flutterTargets[flutterTargetSelected];
  if (!target) {
    mode = 'main';
    draw();
    return;
  }
  const apiUrl = await prepareFlutterApiUrl(target);
  if (!apiUrl) {
    setMessage('No se pudo preparar adb reverse para el API. Revisa la conexión del dispositivo.');
    draw();
    return;
  }
  flutterKeepAwake = await keepScreenAwake(target.deviceId);
  mode = 'main';
  selectedIndex = ROWS.findIndex((row) => row.id === 'flutter');
  beginRow('flutter', 'Iniciando...');
  openWindow(
    FLUTTER_TITLE,
    `flutter run -d ${target.deviceId} --dart-define=API_BASE_URL=${apiUrl}`,
    FLUTTER_DIR,
  );
  startPoll('flutter', { text: 'Iniciando...', isDone: (fresh) => fresh.level === 'ok' });
}

async function actFlutter() {
  if (polls.has('flutter')) {
    return;
  }
  if (stateMap.flutter?.level === 'ok') {
    beginRow('flutter', 'Deteniendo...');
    await stopFlutter();
    return;
  }
  const state = await readFlutter();
  stateMap.flutter = state;
  if (state.level === 'ok') {
    beginRow('flutter', 'Deteniendo...');
    await stopFlutter();
    return;
  }
  setMessage('Buscando dispositivos...');
  draw();
  flutterTargets = await buildFlutterTargets();
  flutterTargetSelected = 0;
  if (flutterTargets.length === 1) {
    await launchFlutterTarget();
    return;
  }
  mode = 'flutter-target';
  draw();
}

async function actPostgres() {
  if (polls.has('postgres')) {
    return;
  }
  if (stateMap.postgres?.running) {
    beginRow('postgres', 'Deteniendo...');
  } else {
    beginRow('postgres', 'Iniciando...');
  }
  const state = await readPostgres();
  stateMap.postgres = state;
  if (!dockerStatus.available) {
    setMessage(
      dockerStatus.installed
        ? 'Docker no está corriendo. Inicia Docker Desktop.'
        : 'Docker no está instalado.',
    );
    await refreshRow('postgres');
    return;
  }
  if (state.running) {
    const result = await runArgs('docker', ['stop', state.name ?? PG_CONTAINER], { timeout: 120000 });
    if (result.code !== 0) {
      setMessage(firstLine(result.stderr) || firstLine(result.stdout) || 'No se pudo detener Postgres.');
      await refreshRow('postgres');
      return;
    }
    startPoll('postgres', { text: 'Deteniendo...', isDone: (fresh) => fresh.running === false });
    return;
  }
  const portBusy = await checkPort(5432);
  if (portBusy) {
    setMessage('Postgres ya está en el puerto 5432.');
    await refreshRow('postgres');
    return;
  }
  const result = state.exists
    ? await runArgs('docker', ['start', PG_CONTAINER], { timeout: 120000 })
    : await runArgs(
        'docker',
        [
          'run',
          '-d',
          '-p',
          '5432:5432',
          '--name',
          PG_CONTAINER,
          '-e',
          'POSTGRES_USER=fittrack',
          '-e',
          'POSTGRES_PASSWORD=fittrack',
          '-e',
          'POSTGRES_DB=fittrack',
          '-v',
          'fittrack-pgdata:/var/lib/postgresql/data',
          'postgres:16',
        ],
        { timeout: 120000 },
      );
  if (result.code !== 0) {
    setMessage(firstLine(result.stderr) || firstLine(result.stdout) || 'No se pudo arrancar Postgres.');
    await refreshRow('postgres');
    return;
  }
  startPoll('postgres', { text: 'Iniciando...', isDone: (fresh) => fresh.hasPort === true });
}

async function actPrisma() {
  beginRow('prisma', 'Iniciando...');
  const postgres = await readPostgres();
  stateMap.postgres = postgres;
  if (!postgres.running) {
    setMessage('Primero inicia Postgres.');
    await refreshRow('prisma');
    return;
  }
  const state = await readPrisma();
  stateMap.prisma = state;
  if (state.envMissing) {
    setMessage('Falta fit_track_api/.env');
    await refreshRow('prisma');
    return;
  }
  if (!state.pending) {
    if (state.level === 'warn') {
      setMessage(state.errorLine || 'Requiere actualizar');
      draw();
      return;
    }
    setMessage('Esquema al dia. No hay migraciones pendientes.');
    await refreshRow('prisma');
    return;
  }
  beginRow('prisma', 'Aplicando migraciones...');
  let errorText = null;
  try {
    execSync('pnpm --dir fit_track_api exec prisma migrate deploy', {
      cwd: ROOT,
      stdio: 'ignore',
    });
  } catch (error) {
    const text = `${error?.stdout ?? ''}\n${error?.stderr ?? ''}`;
    errorText = firstLine(text) || 'Fallo migrate deploy';
  }
  await refreshRow('prisma');
  if (errorText) {
    setMessage(errorText);
    draw();
  }
}

async function actPrismaStudio() {
  const url = `http://localhost:${PRISMA_STUDIO_PORT}`;
  if (!fs.existsSync(API_ENV)) {
    setMessage('Falta fit_track_api/.env');
    draw();
    return;
  }
  if (await checkPort(PRISMA_STUDIO_PORT)) {
    openUrl(url);
    setMessage(`Prisma Studio ya responde en ${url}`);
    draw();
    return;
  }
  openWindow(
    'Prisma Studio',
    `pnpm --dir fit_track_api exec prisma studio --port ${PRISMA_STUDIO_PORT} --browser none`,
    ROOT,
  );
  setMessage(`Iniciando Prisma Studio en ${url}. Cierra su ventana para detenerlo.`);
  draw();
  void (async () => {
    for (let attempt = 0; attempt < 30; attempt += 1) {
      await new Promise((resolve) => setTimeout(resolve, 1000));
      if (await checkPort(PRISMA_STUDIO_PORT)) {
        openUrl(url);
        setMessage(`Prisma Studio: ${url}`);
        draw();
        return;
      }
    }
    setMessage('Prisma Studio no respondió en 30 s. Revisa la ventana que se abrió.');
    draw();
  })();
}

async function actApi() {
  if (polls.has('api')) {
    return;
  }
  const postgres = await readPostgres();
  stateMap.postgres = postgres;
  if (!dockerStatus.available) {
    setMessage(
      dockerStatus.installed
        ? 'Docker no está corriendo. Inicia Docker Desktop.'
        : 'Docker no está instalado.',
    );
    await refreshRow('api');
    return;
  }
  const state = await readApi();
  stateMap.api = state;
  if (state.running) {
    beginRow('api', 'Deteniendo...');
    const result = await runArgs('docker', ['stop', API_CONTAINER], { timeout: 120000 });
    if (result.code !== 0) {
      setMessage(firstLine(result.stderr) || firstLine(result.stdout) || 'No se pudo detener la API.');
      await refreshRow('api');
      return;
    }
    startPoll('api', { text: 'Deteniendo...', isDone: (fresh) => fresh.running === false });
    return;
  }
  if (!postgres.running) {
    setMessage('Primero inicia Postgres.');
    await refreshRow('api');
    return;
  }
  if (!fs.existsSync(API_ENV)) {
    setMessage('Falta fit_track_api/.env');
    await refreshRow('api');
    return;
  }
  beginRow('api', 'Construyendo imagen...');
  const build = await runArgs('docker', ['build', '-t', API_IMAGE, API_DIR], { timeout: 600000 });
  if (build.code !== 0) {
    setMessage(firstLine(build.stderr) || firstLine(build.stdout) || 'No se pudo construir la imagen de la API.');
    await refreshRow('api');
    return;
  }
  if (state.exists) {
    await runArgs('docker', ['rm', '-f', API_CONTAINER], { timeout: 60000 });
  }
  beginRow('api', 'Iniciando...');
  const port = readApiPort();
  const result = await runArgs(
    'docker',
    [
      'run',
      '-d',
      '--name',
      API_CONTAINER,
      '--env-file',
      API_ENV,
      '-e',
      `DATABASE_URL=${apiDatabaseUrl()}`,
      '-e',
      `PORT=${port}`,
      '-p',
      `${port}:${port}`,
      '--add-host',
      'host.docker.internal:host-gateway',
      API_IMAGE,
    ],
    { timeout: 120000 },
  );
  if (result.code !== 0) {
    setMessage(firstLine(result.stderr) || firstLine(result.stdout) || 'No se pudo arrancar la API.');
    await refreshRow('api');
    return;
  }
  const started = Date.now();
  startPoll('api', {
    text: 'Iniciando...',
    isDone: (fresh) => fresh.level === 'ok',
    isFailed: (fresh) => fresh.exists && !fresh.running && Date.now() - started > 2500,
    failMessage: () => 'La API arrancó y se detuvo. Revisa que Postgres esté arriba.',
  });
}

async function actDevices() {
  devicesState = await loadDevices();
  mode = 'devices';
  deviceSelected = 0;
  draw();
}

async function actWireless() {
  const sdk = devicesState.sdk ?? resolveSdk();
  if (!sdk?.adb) {
    setMessage('No se encontró adb. Revisa ANDROID_HOME.');
    draw();
    return;
  }
  setMessage('Buscando dispositivos inalámbricos...');
  draw();
  const found = await discoverWireless(sdk);
  if (!found.supported) {
    setMessage('Este adb no soporta mdns. Usa adb connect <ip>:<puerto> desde la terminal.');
    draw();
    return;
  }
  if (found.connect.length === 0 && found.pairing.length === 0) {
    setMessage('No se detectaron dispositivos. Activa Depuración inalámbrica y comparte la misma red.');
    draw();
    return;
  }
  const connected = await connectWireless(sdk, found.connect);
  if (connected.length === 0 && found.pairing.length > 0) {
    wirelessPairing = found.pairing[0];
    wirelessCode = '';
    mode = 'pairing';
    draw();
    return;
  }
  await refreshRow('devices');
  setMessage(
    connected.length > 0
      ? `Conectados: ${connected.join(', ')}`
      : 'Los dispositivos detectados no aceptaron la conexión. Vincula con el código del teléfono.',
  );
  draw();
}

async function submitPairing() {
  const sdk = devicesState.sdk ?? resolveSdk();
  if (!sdk?.adb || !wirelessPairing) {
    mode = 'main';
    draw();
    return;
  }
  if (!/^\d{6}$/.test(wirelessCode)) {
    setMessage('El código debe tener 6 dígitos.');
    draw();
    return;
  }
  setMessage('Vinculando...');
  draw();
  const endpoint = wirelessPairing;
  const result = await runArgs(sdk.adb, ['pair', endpoint, wirelessCode], { timeout: 30000 });
  const output = `${result.stdout}\n${result.stderr}`.trim();
  wirelessCode = '';
  wirelessPairing = null;
  mode = 'main';
  if (!/successfully paired/i.test(output)) {
    setMessage(firstLine(output) || 'No se pudo vincular el dispositivo.');
    draw();
    return;
  }
  setMessage('Vinculado. Conectando...');
  draw();
  for (let attempt = 0; attempt < 3; attempt += 1) {
    await new Promise((resolve) => setTimeout(resolve, 2000));
    const found = await discoverWireless(sdk);
    const connected = await connectWireless(sdk, found.connect);
    if (connected.length > 0) {
      await refreshRow('devices');
      setMessage(`Conectado: ${connected.join(', ')}`);
      draw();
      return;
    }
  }
  await refreshRow('devices');
  setMessage('Vinculado, pero no se pudo conectar. Revisa la red y vuelve a intentar con W.');
  draw();
}

function clearDevicePoll() {
  if (devicePoll) {
    clearInterval(devicePoll);
    devicePoll = null;
  }
}

function finishDevice(name, status, options = {}) {
  if (deviceBusyName !== name) {
    return;
  }
  clearDevicePoll();
  deviceStatus[name] = status;
  deviceBusyName = null;
  if (options.logPath) {
    fs.rm(options.logPath, { force: true }, () => {});
  }
  if (options.message) {
    setMessage(options.message);
  }
  draw();
}

function startDevicePoll(name, evaluate, logPath) {
  const started = Date.now();
  let ticking = false;
  clearDevicePoll();
  devicePoll = setInterval(() => {
    if (ticking) {
      return;
    }
    ticking = true;
    void (async () => {
      try {
        if (deviceBusyName !== name) {
          clearDevicePoll();
          return;
        }
        devicesState.running = await runningAvds(devicesState.sdk, devicesState.avds);
        devicesState.physical = await physicalDevices(devicesState.sdk);
        if (deviceBusyName !== name) {
          return;
        }
        const verdict = evaluate();
        if (verdict.done) {
          finishDevice(name, { start: 'idle' }, { logPath, message: verdict.message });
          return;
        }
        if (verdict.error) {
          finishDevice(name, { start: 'error', errorText: verdict.error }, { logPath });
          return;
        }
        if (Date.now() - started >= AVD_POLL_TIMEOUT_MS) {
          finishDevice(name, { start: 'error', errorText: 'No aparecio en 90 s.' }, { logPath });
        }
      } finally {
        ticking = false;
      }
    })();
  }, POLL_MS);
}

function launchEmulator(name) {
  const sdk = devicesState.sdk;
  if (!sdk?.emulator) {
    finishDevice(name, { start: 'error', errorText: 'No se encontró emulator. Revisa ANDROID_HOME.' });
    return;
  }
  const logPath = path.join(os.tmpdir(), `fittrack-avd-${name.replace(/[^a-zA-Z0-9._-]/g, '_')}.log`);
  let fd;
  try {
    fd = fs.openSync(logPath, 'w');
  } catch (error) {
    finishDevice(name, {
      start: 'error',
      errorText: firstLine(error.message) || 'No se pudo iniciar el emulador.',
    });
    return;
  }
  let child;
  try {
    child = spawn(sdk.emulator, ['-avd', name], {
      cwd: ROOT,
      detached: true,
      stdio: ['ignore', fd, fd],
    });
  } catch (error) {
    fs.closeSync(fd);
    finishDevice(
      name,
      { start: 'error', errorText: firstLine(error.message) || 'No se pudo iniciar el emulador.' },
      { logPath },
    );
    return;
  }
  fs.closeSync(fd);
  child.unref();

  let exitCode = null;
  child.on('error', (error) => {
    exitCode = exitCode ?? 1;
    if (deviceBusyName === name) {
      finishDevice(
        name,
        { start: 'error', errorText: firstLine(String(error?.message ?? '')) || 'No se pudo iniciar el emulador.' },
        { logPath },
      );
    }
  });
  child.on('exit', (code) => {
    exitCode = code ?? 1;
  });

  startDevicePoll(
    name,
    () => {
      if (devicesState.running.has(name)) {
        return { done: true };
      }
      if (exitCode !== null && exitCode !== 0) {
        let errorText = 'El emulador termino con error.';
        try {
          errorText = firstLine(fs.readFileSync(logPath, 'utf8')) || errorText;
        } catch {
          // El log puede no existir si el proceso murio antes de escribir.
        }
        return { error: errorText };
      }
      return {};
    },
    logPath,
  );
}

async function stopEmulator(name) {
  const sdk = devicesState.sdk;
  const serial = devicesState.running.get(name);
  if (!sdk?.adb || !serial) {
    setMessage('No se pudo identificar el emulador encendido.');
    draw();
    return;
  }
  deviceStatus[name] = { start: 'stopping' };
  deviceBusyName = name;
  draw();
  const result = await runArgs(sdk.adb, ['-s', serial, 'emu', 'kill'], { timeout: 20000 });
  if (result.code !== 0) {
    finishDevice(name, {
      start: 'error',
      errorText: firstLine(result.stderr) || firstLine(result.stdout) || 'No se pudo apagar el emulador.',
    });
    return;
  }
  startDevicePoll(
    name,
    () => (devicesState.running.has(name) ? {} : { done: true, message: `${name} apagado.` }),
    null,
  );
}

async function actDeviceRow() {
  if (deviceBusyName) {
    return;
  }
  const current = deviceLines[deviceSelected];
  if (!current?.selectable) {
    return;
  }
  const wasOn = current.level === 'ok';
  deviceStatus[current.name] = { start: wasOn ? 'stopping' : 'starting' };
  deviceBusyName = current.name;
  draw();
  devicesState = await loadDevices();
  const isOn = devicesState.running.has(current.name);
  if (isOn === wasOn) {
    if (isOn) {
      await stopEmulator(current.name);
    } else {
      launchEmulator(current.name);
    }
    return;
  }
  deviceStatus[current.name] = { start: 'idle' };
  deviceBusyName = null;
  setMessage(isOn ? `${current.name} ya estaba encendido.` : `${current.name} ya estaba apagado.`);
  draw();
}

async function act() {
  if (mode === 'devices') {
    await actDeviceRow();
    return;
  }
  const row = ROWS[selectedIndex];
  if (row.id === 'flutter') {
    await actFlutter();
  } else if (row.id === 'postgres') {
    await actPostgres();
  } else if (row.id === 'prisma') {
    await actPrisma();
  } else if (row.id === 'api') {
    await actApi();
  } else if (row.id === 'devices') {
    await actDevices();
  }
}

function shutdown() {
  for (const id of [...polls.keys()]) {
    stopPoll(id);
  }
  clearDevicePoll();
  if (process.stdin.isTTY) {
    process.stdin.setRawMode(false);
  }
  process.stdin.pause();
  process.stdout.write('\x1b[?25h');
  const session = flutterKeepAwake;
  flutterKeepAwake = null;
  if (!session) {
    process.exit(0);
    return;
  }
  const guard = setTimeout(() => process.exit(0), 3000);
  guard.unref();
  void restoreScreenTimeout(session).finally(() => {
    clearTimeout(guard);
    process.exit(0);
  });
}

function onKeypress(_str, key) {
  if (!key) {
    return;
  }
  if (key.ctrl && key.name === 'c') {
    shutdown();
    return;
  }
  if (deviceBusyName) {
    return;
  }
  if (mode === 'pairing') {
    if (key.name === 'escape') {
      wirelessPairing = null;
      wirelessCode = '';
      mode = 'main';
      draw();
      return;
    }
    if (key.name === 'return' || key.name === 'enter') {
      void submitPairing();
      return;
    }
    if (key.name === 'backspace') {
      wirelessCode = wirelessCode.slice(0, -1);
      draw();
      return;
    }
    if (/^\d$/.test(key.sequence ?? '')) {
      wirelessCode = `${wirelessCode}${key.sequence}`.slice(0, 6);
      draw();
    }
    return;
  }
  if (mode === 'flutter-target') {
    if (key.name === 'escape' || key.name === 'q') {
      mode = 'main';
      selectedIndex = ROWS.findIndex((row) => row.id === 'flutter');
      draw();
      return;
    }
    if (key.name === 'up' || key.name === 'down') {
      const delta = key.name === 'up' ? -1 : 1;
      flutterTargetSelected = Math.min(
        Math.max(flutterTargetSelected + delta, 0),
        Math.max(flutterTargets.length - 1, 0),
      );
      draw();
      return;
    }
    if (key.name === 'space') {
      void launchFlutterTarget();
    }
    return;
  }
  if (key.name === 'r') {
    setMessage('Recargando estados...');
    draw();
    void (async () => {
      if (mode === 'devices') {
        devicesState = await loadDevices();
        draw();
      }
      await refreshAll();
    })();
    return;
  }
  if (key.name === 'w') {
    void actWireless();
    return;
  }
  if (key.name === 'p') {
    void actPrismaStudio();
    return;
  }
  if (key.name === 'escape' || key.name === 'q') {
    if (mode === 'devices') {
      mode = 'main';
      selectedIndex = ROWS.findIndex((row) => row.id === 'devices');
      void refreshRow('devices');
      return;
    }
    shutdown();
    return;
  }
  if (key.name === 'up' || key.name === 'down') {
    const delta = key.name === 'up' ? -1 : 1;
    if (mode === 'devices') {
      moveDeviceSelection(delta);
    } else {
      selectedIndex = Math.min(Math.max(selectedIndex + delta, 0), ROWS.length - 1);
    }
    draw();
    return;
  }
  if (key.name === 'space') {
    void act();
  }
}

if (!process.stdin.isTTY) {
  process.stdout.write('El menú de desarrollo requiere una terminal interactiva.\n');
  process.exit(1);
}

try {
  process.stdout.write('Instalando dependencias (pnpm install)...\n');
  execSync('pnpm install', { cwd: ROOT, stdio: 'inherit' });
} catch {
  process.stdout.write('pnpm install falló; el menú abrirá con el estado actual.\n');
}

readline.emitKeypressEvents(process.stdin);
process.stdin.setRawMode(true);
process.stdin.resume();
process.stdin.on('keypress', onKeypress);
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

draw();
void refreshAll();
