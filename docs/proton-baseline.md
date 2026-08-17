# Proton Baseline

The public fork is available at <https://github.com/5p00kyy/Proton>.

## Source

- Branch: `proton_11.0`
- Commit: `0745bfbc4cf4365e8cf048b003990c59def29948`
- Description after fetching upstream tags: `proton-11.0-1b`
- Upstream remote: `https://github.com/ValveSoftware/Proton.git`

The fork's relative `wine` submodule URL initially resolved to a nonexistent
`5p00kyy/wine` repository. A matching public companion fork now exists at
<https://github.com/5p00kyy/wine>, so fresh recursive clones can resolve the
tracked relative URL. The local Wine checkout uses that fork as `origin` and
`ValveSoftware/wine` as `upstream`; the tracked `.gitmodules` file is unchanged.

## Build

- Host: Linux, x86-64
- Engine: rootless Podman
- Steam Runtime SDK:
  `registry.gitlab.steamos.cloud/proton/steamrt4/sdk/x86_64:4.0.20260331.220802-0`
- SDK digest:
  `sha256:97526b794ce1a9bed5f891084462260b3a02399569f7438a3a57b5a253001db9`
- Verification: `make test-container` and `make redist`
- Redistributable size: approximately 1.4 GiB

The build was created out of tree and was not installed into Steam.

## Artifact hashes

```text
66c35ec79ac9062084c53059d56ef3339b15ca7aae399d8711e9a60a4f954eb0  version
b56de46d7619ebf6975a625e47c202c81baa375ca3576983e221bc9892b0633b  proton
a6c02cc3b4ae284b8bf0c82079ab986fdd2f71f7a5c15506936e4df344faa1fc  compatibilitytool.vdf
```

## Expected limitation

The public source build contains no proprietary vendor bridge payloads. Proton
exposes conditional build hooks, but bridge sources and runtime authorization
are supplied by Valve and the relevant vendors. They will not be reconstructed
in this fork.

## Candidate build-system issue

With ccache disabled, the generated outer Makefile evaluates an empty
`ENABLE_CCACHE` value numerically and prints `integer expected` before
continuing successfully. This is a small reproducible upstream cleanup
candidate, separate from anti-cheat functionality.
