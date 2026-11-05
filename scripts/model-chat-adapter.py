#!/usr/bin/env python3
"""Tool-free model command for scripts/eval-test-integrity-model.py run.

Reads one planned request ({"messages": [...]}) on stdin, sends exactly those
messages to an OpenAI-compatible chat-completions endpoint, and writes the
model's reply text to stdout unchanged. The model gets no tools, shell, files,
or MCP servers, so it cannot read the corpus answers.

Environment:
  C2TI_MODEL_BASE_URL  endpoint base, e.g. https://host/v1
  C2TI_MODEL           model id
  C2TI_MODEL_TOKEN     bearer token
"""

import json
import os
import sys
import urllib.request


def main():
    base = os.environ.get("C2TI_MODEL_BASE_URL", "").rstrip("/")
    model = os.environ.get("C2TI_MODEL", "")
    token = os.environ.get("C2TI_MODEL_TOKEN", "")
    if not base or not model or not token:
        sys.stderr.write("C2TI_MODEL_BASE_URL, C2TI_MODEL and C2TI_MODEL_TOKEN are required\n")
        return 2
    request = json.loads(sys.stdin.buffer.read())
    body = json.dumps({"model": model, "messages": request["messages"], "temperature": 0}).encode("utf-8")
    http = urllib.request.Request(
        base + "/chat/completions",
        data=body,
        headers={
            "Authorization": "Bearer " + token,
            "Content-Type": "application/json",
            "User-Agent": "c2ti-eval/1.0",
        },
    )
    with urllib.request.urlopen(http, timeout=110) as response:
        payload = json.load(response)
    sys.stdout.write(payload["choices"][0]["message"]["content"] or "")
    return 0


if __name__ == "__main__":
    sys.exit(main())
