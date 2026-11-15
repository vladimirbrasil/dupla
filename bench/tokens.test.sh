#!/usr/bin/env bash
set -euo pipefail

BENCH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/conv1/.system_generated/logs"
mkdir -p "$TMP/conv2/.system_generated/logs"
mkdir -p "$TMP/conv3-fora/.system_generated/logs"

cat > "$TMP/conv1/.system_generated/logs/transcript_full.jsonl" << 'EOF'
{"step_index":0,"source":"USER_EXPLICIT","type":"USER_INPUT","status":"DONE"}
{"step_index":1,"source":"MODEL","type":"PLANNER_RESPONSE","status":"DONE","model":"slugA","input_tokens":1000,"cache_read_tokens":200,"output_tokens":50,"tool_calls":[{"name":"read_file","args":{}},{"name":"run_command","args":{}}]}
{"step_index":2,"source":"MODEL","type":"GENERIC","status":"DONE","content":"ok"}
{"step_index":3,"source":"MODEL","type":"PLANNER_RESPONSE","status":"DONE","model":"slugB","input_tokens":1500,"cache_read_tokens":800,"output_tokens":70}
EOF

cat > "$TMP/conv2/.system_generated/logs/transcript_full.jsonl" << 'EOF'
{"step_index":0,"source":"USER_EXPLICIT","type":"USER_INPUT","status":"DONE"}
{"step_index":1,"source":"MODEL","type":"PLANNER_RESPONSE","status":"DONE","model":"slugA","input_tokens":500,"cache_read_tokens":0,"output_tokens":30,"tool_calls":[{"name":"edit_file","args":{}}]}
EOF

cat > "$TMP/conv3-fora/.system_generated/logs/transcript_full.jsonl" << 'EOF'
{"step_index":1,"source":"MODEL","type":"PLANNER_RESPONSE","status":"DONE","model":"slugFora","input_tokens":99999,"cache_read_tokens":99999,"output_tokens":99999,"tool_calls":[{"name":"run_command","args":{}}]}
EOF

touch -d "@1700000100" "$TMP/conv1/.system_generated/logs/transcript_full.jsonl"
touch -d "@1700000200" "$TMP/conv2/.system_generated/logs/transcript_full.jsonl"
touch -d "@1699990000" "$TMP/conv3-fora/.system_generated/logs/transcript_full.jsonl"

GOT="$(AGY_BRAIN="$TMP" node "$BENCH/tokens.js" 1700000000 1700000300)"
EXPECTED="TOKENS conversas=2 passos=3 tools=3 entrada=3000 cache=1000 saida=150 volume=4150 modelos=slugA:2,slugB:1"

diff -u <(echo "$EXPECTED") <(echo "$GOT")
echo "OK: $GOT"

GOT_EMPTY="$(AGY_BRAIN="$TMP" node "$BENCH/tokens.js" 1800000000 1800000100)"
EXPECTED_EMPTY="TOKENS conversas=0"
diff -u <(echo "$EXPECTED_EMPTY") <(echo "$GOT_EMPTY")
echo "OK VAZIO: $GOT_EMPTY"
