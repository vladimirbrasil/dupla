#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');

const ini = Number(process.argv[2]);
const fim = Number(process.argv[3]);
const brainDir = process.env.AGY_BRAIN || path.join(os.homedir(), '.gemini', 'antigravity-cli', 'brain');

if (!fs.existsSync(brainDir) || Number.isNaN(ini) || Number.isNaN(fim)) {
  console.log('TOKENS conversas=0');
  process.exit(0);
}

let entries;
try {
  entries = fs.readdirSync(brainDir, { withFileTypes: true });
} catch {
  console.log('TOKENS conversas=0');
  process.exit(0);
}

let conversas = 0;
let passos = 0;
let tools = 0;
let entrada = 0;
let cache = 0;
let saida = 0;
const modelosMap = new Map();

for (const entry of entries) {
  if (!entry.isDirectory()) continue;
  const transcriptPath = path.join(brainDir, entry.name, '.system_generated', 'logs', 'transcript_full.jsonl');
  let stat;
  try {
    stat = fs.statSync(transcriptPath);
  } catch {
    continue;
  }
  const mtimeSec = Math.floor(stat.mtimeMs / 1000);
  if (mtimeSec < ini || mtimeSec > fim) continue;

  let content;
  try {
    content = fs.readFileSync(transcriptPath, 'utf8');
  } catch {
    continue;
  }

  conversas++;
  const lines = content.split('\n');
  for (const line of lines) {
    if (!line.trim()) continue;
    let obj;
    try {
      obj = JSON.parse(line);
    } catch {
      continue;
    }
    if (obj.type !== 'PLANNER_RESPONSE') continue;

    passos++;
    if (Array.isArray(obj.tool_calls)) {
      tools += obj.tool_calls.length;
    }
    entrada += Number(obj.input_tokens) || 0;
    cache += Number(obj.cache_read_tokens) || 0;
    saida += Number(obj.output_tokens) || 0;

    const modelSlug = obj.model || '?';
    modelosMap.set(modelSlug, (modelosMap.get(modelSlug) || 0) + 1);
  }
}

if (conversas === 0) {
  console.log('TOKENS conversas=0');
  process.exit(0);
}

const volume = entrada + cache + saida;
const modelosStr = Array.from(modelosMap.entries())
  .map(([slug, count]) => `${slug}:${count}`)
  .join(',');

console.log(
  `TOKENS conversas=${conversas} passos=${passos} tools=${tools} entrada=${entrada} cache=${cache} saida=${saida} volume=${volume} modelos=${modelosStr}`
);
