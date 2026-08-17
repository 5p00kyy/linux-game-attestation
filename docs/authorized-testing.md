# Authorized Testing Policy

## Default Rule

Public development uses only project-owned synthetic clients and servers,
openly licensed fixtures, and isolated infrastructure controlled by the
developer. Lack of network connectivity or an offline game mode does not make
testing protected software authorized or ban-safe.

## Prohibited Without Written Authorization

- Launching a protected retail game through an unsupported compatibility path.
- Loading, emulating, altering, or probing a proprietary anti-cheat driver.
- Forging or replaying vendor trust signals.
- Reverse engineering protected protocols or binaries.
- Contacting production anti-cheat, identity, or enforcement endpoints.
- Using cracked, leaked, modified, or otherwise unauthorized game builds.
- Using disposable accounts or hardware to evade enforcement consequences.

## Authorization Requirements

A non-synthetic integration requires written approval from an authorized owner
of the game and anti-cheat integration. The approval must identify:

- Test binaries, versions, accounts, devices, and time window.
- Staging or non-enforcement endpoints.
- Allowed instrumentation and evidence collection.
- Handling and retention of logs and protected information.
- Contacts for technical escalation and enforcement remediation.
- Disclosure, publication, and adapter-distribution constraints.

A generic support response, game ownership, public bug-bounty scope, or absence
of an explicit prohibition is not sufficient authorization.

## Repository Boundary

Publisher SDKs, credentials, private policies, protected telemetry, and
proprietary adapters must not be committed. The public repository contains
only stable adapter interfaces, mock adapters, synthetic workloads, and
legally distributable test material.

## Release Gate

Every integration test target must declare its owner, license, authorization
basis, assurance level, endpoints, and cleanup procedure. CI and default Make
targets must never invoke non-synthetic targets.
