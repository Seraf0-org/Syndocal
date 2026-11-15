# Build cache cleanup — 2026-11-16

Completed the owner's initial cleanup and explicit request to remove more. **293 reviewed operations succeeded: 292 whole paths removed and one cache pruned**, with zero deletion failures. Observed C-drive free space increased from **125729153024 to 490422026240 bytes**, approximately **364.7 GB recovered**. The follow-up alone recovered **14.8 GB**. Base commits are recorded in each summary; initial base is `2beefbb1dc89720c191493314b82e503599d1bb9` and follow-up base is `052b1c30c47832379bae809f8f01dcc1edae8c6a`.

| Scope | Operations | Logical bytes | Distinct-file bytes |
| --- | ---: | ---: | ---: |
| Initial Cargo caches, runtime copies and installer downloads | 248 | 382654667321 | 350359575966 |
| Follow-up release caches, test browser profiles and reproducible archives | 45 | 15266393026 | 14732841896 |

Logical lengths count internal Cargo aliases. Physical free-space measurements, distinct-file lengths and exact-path ledgers are recorded separately.

## Preserved and intentionally removed

Owner-used root `target/release/syndocal.exe`, PDB, DLLs, FFmpeg executable, resources and licenses remain. The follow-up removed only the reviewed generated release `build`, `.fingerprint`, `examples` and `incremental` trees; `deps` retains its exact `syndocal.exe` and `syndocal.pdb` hardlink aliases. Their native file IDs, link counts and SHA-256 values matched before/after. Release logical size decreased from 10,493,215,643 to 824,456,848 bytes. Existing distribution bundles remain as evidence.

C5 scripts/selftests, fixtures, plans, provenance, measurements and all 39 source snapshots remain, along with active FFmpeg and Node/PATH tools, VJ benchmark media, PresentMon, Codex scripts, pinned `target/qa/ffmpeg-selfbuild-20261027`, current rc.2 evidence, recovery backups and signed ASIO/source/license records. `SyndocalDev/ffmpeg-pinned-8.1.2-sdk` remains because retained QA scripts reference it. Dependency packages and worktrees were not removed; no dependency restoration was needed.

The 39 obsolete C5 `source.tar` copies (4,044,840,960 bytes) were individually proven byte-identical to fresh streamed `git archive --format=tar <commit>` output. Every commit remains reachable from the verified live old-origin/main `955ce8283c9ee9397ce2ba03d0736f9188a7b014`. Each commit/SHA/length is retained in the extra manifest so the archives can be reconstructed exactly; actual sources and receipts remain. This supersedes their blanket retention at the first checkpoint. Old executable receipts reference removed build products; rebuild obsolete QA binaries before reuse.

Repository browser profiles were obsolete disposable test profiles recreated by their harnesses. The sole remaining AppData QA profile is only about 74 MB and contains project backups/authority records; it was retained. The ordinary owner profile was not touched.

## Validation and execution boundary

- Independent adversarial review accepted all exact target sets and the stable deletion implementation before clean/pushed checkpoints. The original 248-target manifest is unchanged (SHA-256 `B288F0C8E06C8F555F4194AAAD806C87AEB7720D150B62AA690E05ECC2E7F33B`); the extra 45-target manifest is `0B59D0EBA25946C1666009DC37ED8B931C74913E6838D8C48992885A276137D1`. Initial/follow-up safety suites passed 19/36 cases, all final plan/apply runs exited 0, and `git diff --check` passed.
- Canonical native paths/identities, full ancestry/reparse checks, hardlink-boundary counts, stable second snapshots, writer/process checks and tracked/pushed Git guards precede literal-path PowerShell deletion. Known directory kinds cannot become file targets; only the exact C5 archive kind with SHA/commit/size proof accepts a regular file. Removed files still reject external hardlinks. Partial deps pruning leaves the two reviewed aliases untouched and reports `Pruned` separately from `Deleted`.
- After the follow-up, **all original 411 protected SHA-256 values plus 22 runtime/alias file checks matched**. All 292 whole-path targets are absent; the pruned directory contains exactly its two retained aliases. All 39 source snapshot directories remain.
- Node 22.22.1, Vite 6.4.2, TypeScript 5.9.3 and the local pnpm graph resolve; active FFmpeg's version query succeeds. The canonical pinned SDK passes independent DLL/encoder SHA-256, PE, header and library checks. No native build/window or physical-output acceptance is claimed. Compiler warning baseline/current/delta were not measured by this maintenance validation.

## Records

All evidence is under `artifacts/build-cache-cleanup-20261116/`: initial `apply-cache.jsonl`, `apply-runtime.jsonl`, `apply-performance-runtime.jsonl` and follow-up `apply-extra.jsonl` record exact paths, identities and byte counts. `summary.json` / `summary-extra.json` retain separate measurements, `verification-extra.txt` records final preservation/dependency checks, and `retained-inventory.json` records current retained logical sizes without following reparse points. No unresolved cleanup failure remains.
