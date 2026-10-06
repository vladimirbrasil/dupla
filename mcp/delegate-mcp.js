#!/usr/bin/env node
/*
 * dupla — MCP server (stdio, sem dependências) que expõe ao Claude uma
 * ferramenta de primeira classe: delegate(task).
 *
 * Vantagem sobre o Bash cru: o CONTRATO (o agente faz no disco, devolve só
 * resumo) fica garantido aqui no servidor — o Claude recebe sempre a saída
 * enxuta, não depende de disciplina de prompt. Por baixo, reutiliza o mesmo
 * script ./bin/delegate (backend = Antigravity CLI / agy, na assinatura AI Pro).
 *
 * JSON-RPC 2.0 sobre stdio, newline-delimited.
 */
'use strict';
const { spawnSync } = require('child_process');
const path = require('path');

const DELEGATE = path.join(__dirname, '..', 'bin', 'delegate');
let buf = '';

process.stdin.setEncoding('utf8');
process.stdin.on('data', (chunk) => {
  buf += chunk;
  let nl;
  while ((nl = buf.indexOf('\n')) >= 0) {
    const line = buf.slice(0, nl).trim();
    buf = buf.slice(nl + 1);
    if (line) handle(line);
  }
});

function send(obj) {
  process.stdout.write(JSON.stringify(obj) + '\n');
}

function handle(line) {
  let msg;
  try { msg = JSON.parse(line); } catch { return; }
  const { id, method, params } = msg;

  // Notificações (sem id) não recebem resposta.
  if (id === undefined || id === null) return;

  if (method === 'initialize') {
    return send({
      jsonrpc: '2.0', id,
      result: {
        protocolVersion: (params && params.protocolVersion) || '2024-11-05',
        capabilities: { tools: {} },
        serverInfo: { name: 'dupla', version: '0.2.0' },
      },
    });
  }

  if (method === 'tools/list') {
    return send({
      jsonrpc: '2.0', id,
      result: {
        tools: [{
          name: 'delegate',
          description:
            'Entrega uma tarefa braçal/pesada em tokens ao Antigravity CLI (agy, Gemini Flash), ' +
            'headless e auto-aprovado, na assinatura Google AI Pro (sem API paga). O agente ' +
            'planeja, edita arquivos, RODA comandos e verifica no disco, e devolve SÓ um resumo ' +
            'curto (o diff/saída crua fica em .handoff/). Use para refac mecânico, edição em ' +
            'massa, processar arquivos grandes, loops repetitivos.',
          inputSchema: {
            type: 'object',
            properties: {
              task: {
                type: 'string',
                description: 'Briefing claro e acionável: objetivo, contexto mínimo, caminhos de arquivo, entregável esperado.',
              },
              cwd: {
                type: 'string',
                description: 'Diretório do projeto onde rodar (default: diretório atual do servidor).',
              },
            },
            required: ['task'],
          },
        }],
      },
    });
  }

  if (method === 'tools/call') {
    const name = params && params.name;
    const args = (params && params.arguments) || {};
    if (name !== 'delegate') {
      return send({ jsonrpc: '2.0', id, error: { code: -32601, message: `Tool desconhecida: ${name}` } });
    }
    const r = spawnSync(DELEGATE, ['--', String(args.task || '')], {
      cwd: args.cwd || process.cwd(),
      encoding: 'utf8',
      maxBuffer: 8 * 1024 * 1024,
    });
    const out = (r.stdout || '') + (r.status !== 0 ? `\n[stderr]\n${r.stderr || ''}` : '');
    return send({
      jsonrpc: '2.0', id,
      result: {
        content: [{ type: 'text', text: out.trim() || '(sem saída)' }],
        isError: r.status !== 0,
      },
    });
  }

  // Método não tratado.
  send({ jsonrpc: '2.0', id, error: { code: -32601, message: `Método não suportado: ${method}` } });
}
