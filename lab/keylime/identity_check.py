#!/usr/bin/env python3
"""Verify one Keylime identity quote with correct and incorrect nonces."""

from __future__ import annotations

import json
import secrets
import ssl
import sys
import urllib.parse
import urllib.request
from pathlib import Path


def read_json(url: str, context: ssl.SSLContext) -> dict[str, object]:
    with urllib.request.urlopen(url, context=context, timeout=10) as response:
        return json.load(response)


def main() -> int:
    if len(sys.argv) != 4:
        print("usage: identity_check.py STATE_ROOT AGENT_UUID API_VERSION", file=sys.stderr)
        return 2

    state_root = Path(sys.argv[1])
    agent_uuid = sys.argv[2]
    api_version = sys.argv[3]
    nonce = secrets.token_hex(20)
    wrong_nonce = secrets.token_hex(20)

    agent_context = ssl.create_default_context(cafile=str(state_root / "agent/server-cert.crt"))
    # QEMU loopback forwarding changes the endpoint name. The exact self-signed
    # agent certificate is copied over the authenticated provisioning channel.
    agent_context.check_hostname = False
    agent_context.load_cert_chain(
        certfile=str(state_root / "server/cv_ca/client-cert.crt"),
        keyfile=str(state_root / "server/cv_ca/client-private.pem"),
    )
    quote_url = (
        f"https://127.0.0.1:9002/v{api_version}/quotes/identity?"
        + urllib.parse.urlencode({"nonce": nonce})
    )
    quote_response = read_json(quote_url, agent_context)
    evidence = quote_response["results"]
    if not isinstance(evidence, dict):
        raise RuntimeError("agent returned malformed identity evidence")

    verifier_context = ssl.create_default_context(cafile=str(state_root / "server/cv_ca/cacert.crt"))
    base_query = {
        "agent_uuid": agent_uuid,
        "quote": evidence["quote"],
        "hash_alg": evidence["hash_alg"],
    }

    results: dict[str, object] = {}
    for label, supplied_nonce in (("correct_nonce", nonce), ("wrong_nonce", wrong_nonce)):
        query = urllib.parse.urlencode({**base_query, "nonce": supplied_nonce})
        url = f"https://127.0.0.1:8881/v{api_version}/verify/identity?{query}"
        response = read_json(url, verifier_context)
        results[label] = response["results"]

    correct = results["correct_nonce"]
    wrong = results["wrong_nonce"]
    if not isinstance(correct, dict) or correct.get("valid") != 1:
        raise RuntimeError(f"correct nonce was not accepted: {correct}")
    if not isinstance(wrong, dict) or wrong.get("valid") != 0:
        raise RuntimeError(f"wrong nonce was not rejected: {wrong}")

    report = {
        "agent_uuid": agent_uuid,
        "api_version": api_version,
        "correct_nonce": correct,
        "wrong_nonce": wrong,
    }
    report_path = state_root / "reports/identity-check.json"
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
