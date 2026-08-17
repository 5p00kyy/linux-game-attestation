#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
# shellcheck disable=SC1091
source "$ROOT/lab/lib/state.sh"
export LGA_KEYLIME_STATE_DIR=${LGA_KEYLIME_STATE_DIR:-"$LGA_STATE_HOME/keylime-guest"}
export LGA_ALLOW_SOFTWARE_TPM_EK=1
ENABLE_MB_POLICY=${LGA_ENABLE_MB_POLICY:-0}
EXPECT_MB_FAILURE=${LGA_EXPECT_MB_FAILURE:-0}

# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"
KEYLIME_STATE_ROOT=$STATE_ROOT
KEYLIME_SERVER_STATE=$SERVER_STATE
KEYLIME_REPORT_DIR=$REPORT_DIR
KEYLIME_AGENT_UUID=$AGENT_UUID
KEYLIME_API=$KEYLIME_API_VERSION
RUST_AGENT_IMAGE=$KEYLIME_AGENT_IMAGE
TENANT_IMAGE=$KEYLIME_TENANT_IMAGE

# shellcheck disable=SC1091
source "$ROOT/lab/guest/common.sh"

cleanup() {
    "$ROOT/lab/guest/stop.sh" >/dev/null 2>&1 || true
    LGA_KEYLIME_STATE_DIR="$KEYLIME_STATE_ROOT" \
        "$SCRIPT_DIR/server-stop.sh" >/dev/null 2>&1 || true
}
trap cleanup EXIT

cleanup
rm -rf -- "$KEYLIME_STATE_ROOT"
mkdir -p "$KEYLIME_STATE_ROOT"

LGA_KEYLIME_STATE_DIR="$KEYLIME_STATE_ROOT" "$SCRIPT_DIR/server-start.sh"
"$ROOT/lab/guest/prepare.sh"
"$ROOT/lab/guest/start.sh"
"$ROOT/lab/guest/wait-ready.sh"

ssh_guest_ephemeral 'sudo dnf install --assumeyes podman'
scp_guest_to "$KEYLIME_SERVER_STATE/cv_ca/cacert.crt" /tmp/lga-keylime-ca.crt
ssh_guest_ephemeral \
    'sudo rm -rf /var/lib/lga-keylime-agent && sudo install -d /var/lib/lga-keylime-agent/cv_ca && sudo install -m 0444 /tmp/lga-keylime-ca.crt /var/lib/lga-keylime-agent/cv_ca/cacert.crt && sudo chown -R 999:999 /var/lib/lga-keylime-agent'

ssh_guest_ephemeral "sudo podman pull '$RUST_AGENT_IMAGE'"
ssh_guest_ephemeral 'sudo podman rm --force lga-keylime-agent >/dev/null 2>&1 || true'
ssh_guest_ephemeral "sudo podman run --detach --name lga-keylime-agent --network host --security-opt label=disable --device /dev/tpmrm0:/dev/tpmrm0 --volume /var/lib/lga-keylime-agent:/var/lib/keylime --volume /sys/kernel/security:/sys/kernel/security:ro --tmpfs /var/lib/keylime/secure:rw,size=1m,mode=0700 --env TCTI=device:/dev/tpmrm0 --env KEYLIME_AGENT_IP=0.0.0.0 --env KEYLIME_AGENT_CONTACT_IP=127.0.0.1 --env KEYLIME_AGENT_REGISTRAR_IP=10.0.2.2 --env KEYLIME_AGENT_REGISTRAR_PORT=8890 --env KEYLIME_AGENT_ENABLE_AGENT_MTLS=true --env RUST_LOG=keylime_agent=info '$RUST_AGENT_IMAGE'"

agent_ready=0
for _ in {1..120}; do
    if ssh_guest_ephemeral "sudo podman logs lga-keylime-agent 2>&1 | grep -q 'Listening on https://0.0.0.0:9002'"; then
        agent_ready=1
        break
    fi
    sleep 1
done

if [[ $agent_ready -ne 1 ]]; then
    ssh_guest_ephemeral 'sudo podman logs lga-keylime-agent' >"$KEYLIME_REPORT_DIR/guest-agent.log" 2>&1 || true
    cat "$KEYLIME_REPORT_DIR/guest-agent.log" >&2
    printf 'guest Keylime agent did not become ready\n' >&2
    exit 1
fi

ssh_guest_ephemeral \
    "sudo podman exec --user keylime lga-keylime-agent sh -c 'test \"\$(wc -c < /sys/kernel/security/tpm0/binary_bios_measurements)\" -gt 0 && sha256sum /sys/kernel/security/tpm0/binary_bios_measurements'" \
    >"$KEYLIME_REPORT_DIR/guest-agent-event-log.sha256"
ssh_guest_ephemeral 'sudo cp /sys/kernel/security/tpm0/binary_bios_measurements /tmp/lga-eventlog && sudo chown lga:lga /tmp/lga-eventlog'
scp_guest_from /tmp/lga-eventlog "$KEYLIME_SERVER_STATE/guest-eventlog.bin"
tenant_policy_args=()
if [[ $ENABLE_MB_POLICY == 1 ]]; then
    ssh_guest_ephemeral 'sudo tpm2_pcrread sha256:0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15' \
        >"$KEYLIME_REPORT_DIR/live-pcrs.txt"
    podman run --rm \
        --volume "$KEYLIME_SERVER_STATE:/var/lib/keylime" \
        --entrypoint tpm2_eventlog \
        "$TENANT_IMAGE" \
        /var/lib/keylime/guest-eventlog.bin \
        >"$KEYLIME_REPORT_DIR/eventlog-replay.txt" 2>&1
    podman run --rm \
        --volume "$KEYLIME_SERVER_STATE:/var/lib/keylime" \
        --entrypoint keylime-policy \
        "$TENANT_IMAGE" \
        create measured-boot \
        --eventlog-file /var/lib/keylime/guest-eventlog.bin \
        --without-secureboot \
        --output /var/lib/keylime/measured-boot-policy.json
    tenant_policy_args=(--mb-policy /var/lib/keylime/measured-boot-policy.json)
fi

ssh_guest_ephemeral 'sudo cp /var/lib/lga-keylime-agent/server-cert.crt /tmp/lga-agent-cert.crt && sudo chown lga:lga /tmp/lga-agent-cert.crt'
mkdir -p "$KEYLIME_STATE_ROOT/agent"
scp_guest_from /tmp/lga-agent-cert.crt "$KEYLIME_STATE_ROOT/agent/server-cert.crt"

LGA_KEYLIME_STATE_DIR="$KEYLIME_STATE_ROOT" "$SCRIPT_DIR/tenant.sh" \
    -c regstatus \
    -u "$KEYLIME_AGENT_UUID" \
    -r 127.0.0.1 \
    -rp 8891 >"$KEYLIME_REPORT_DIR/registrar-status.log" 2>&1

LGA_KEYLIME_STATE_DIR="$KEYLIME_STATE_ROOT" "$SCRIPT_DIR/tenant.sh" \
    -c add \
    -t 127.0.0.1 \
    -tp 9002 \
    -v 127.0.0.1 \
    -u "$KEYLIME_AGENT_UUID" \
    "${tenant_policy_args[@]}" \
    --tpm_policy '{}' >"$KEYLIME_REPORT_DIR/tenant-add.log" 2>&1

attestation_reached=0
for _ in {1..30}; do
    if LGA_KEYLIME_STATE_DIR="$KEYLIME_STATE_ROOT" "$SCRIPT_DIR/tenant.sh" \
        -c cvstatus \
        -u "$KEYLIME_AGENT_UUID" \
        -v 127.0.0.1 >"$KEYLIME_REPORT_DIR/verifier-status.log" 2>&1; then
        if [[ $EXPECT_MB_FAILURE == 1 ]] \
            && grep -q '"attestation_status": "FAIL"' "$KEYLIME_REPORT_DIR/verifier-status.log" \
            && grep -q '"last_event_id": "measured_boot.invalid_pcr_9"' "$KEYLIME_REPORT_DIR/verifier-status.log"; then
            attestation_reached=1
            break
        fi
        if [[ $EXPECT_MB_FAILURE == 0 ]] \
            && grep -q '"attestation_status": "PASS"' "$KEYLIME_REPORT_DIR/verifier-status.log"; then
            attestation_reached=1
            break
        fi
    fi
    sleep 1
done

if [[ $attestation_reached -ne 1 ]]; then
    cat "$KEYLIME_REPORT_DIR/verifier-status.log" >&2
    printf 'guest agent verifier did not reach the expected state\n' >&2
    exit 1
fi

if [[ $ENABLE_MB_POLICY == 1 ]] && ! grep -q '"has_mb_refstate": 1' "$KEYLIME_REPORT_DIR/verifier-status.log"; then
    cat "$KEYLIME_REPORT_DIR/verifier-status.log" >&2
    printf 'guest agent has no measured-boot reference state\n' >&2
    exit 1
fi

if [[ $EXPECT_MB_FAILURE == 1 ]]; then
    ssh_guest_ephemeral 'sudo podman logs lga-keylime-agent' >"$KEYLIME_REPORT_DIR/guest-agent.log" 2>&1 || true
    printf 'measured-boot probe rejected the known PCR 9 replay mismatch as expected; reports: %s\n' "$KEYLIME_REPORT_DIR"
    exit 0
fi

python "$SCRIPT_DIR/identity_check.py" "$KEYLIME_STATE_ROOT" "$KEYLIME_AGENT_UUID" "$KEYLIME_API"
ssh_guest_ephemeral 'sudo podman logs lga-keylime-agent' >"$KEYLIME_REPORT_DIR/guest-agent.log" 2>&1 || true
printf 'guest Keylime smoke test passed; reports: %s\n' "$KEYLIME_REPORT_DIR"
