.PHONY: test rust-test prototype-test static-check format vtpm-smoke keylime-start keylime-stop keylime-status keylime-smoke keylime-guest-smoke keylime-mb-probe guest-fetch guest-prepare guest-start guest-stop guest-status guest-smoke mkosi-keys mkosi-build mkosi-verify ovmf-enroll guest-custom-prepare guest-custom-start guest-custom-stop guest-custom-status guest-custom-smoke verify-pins check integration-check vm-integration-check

test: rust-test prototype-test

rust-test:
	cargo test --workspace

prototype-test:
	PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=prototypes/hmac-v0/src python -m unittest discover -s prototypes/hmac-v0/tests -v

static-check:
	./scripts/static-check.sh

format:
	cargo fmt --all

vtpm-smoke:
	./lab/vtpm/smoke.sh

keylime-start:
	./lab/keylime/start.sh

keylime-stop:
	./lab/keylime/stop.sh

keylime-status:
	LGA_ALLOW_SOFTWARE_TPM_EK=1 ./lab/keylime/status.sh

keylime-smoke:
	./lab/keylime/smoke.sh

keylime-guest-smoke:
	./lab/keylime/guest-smoke.sh

keylime-mb-probe:
	./lab/keylime/measured-boot-probe.sh

guest-fetch:
	./lab/guest/fetch.sh

guest-prepare:
	./lab/guest/prepare.sh

guest-start:
	./lab/guest/start.sh

guest-stop:
	./lab/guest/stop.sh

guest-status:
	./lab/guest/status.sh

guest-smoke:
	./lab/guest/smoke.sh

mkosi-keys:
	./lab/image/generate-keys.sh

mkosi-build:
	./lab/image/build.sh

mkosi-verify:
	./lab/image/verify.sh

ovmf-enroll:
	./lab/image/enroll-ovmf.sh

guest-custom-prepare:
	./lab/guest/custom/prepare.sh

guest-custom-start:
	./lab/guest/custom/start.sh

guest-custom-stop:
	./lab/guest/custom/stop.sh

guest-custom-status:
	./lab/guest/custom/status.sh

guest-custom-smoke:
	./lab/guest/custom/smoke.sh

verify-pins:
	./lab/keylime/verify-pins.sh

check: static-check test vtpm-smoke verify-pins

integration-check: check keylime-smoke

vm-integration-check: keylime-guest-smoke
