# Build cache cleanup — 2026-11-16 / 2026-11-17

The owner's repeated cleanup requests are complete. The latest run removed **303 paths / 3,815,072,599 file bytes**, with zero failures; observed free space increased from **446153641984 to 450107682816 bytes** during that run. Across all checkpoints, **595 whole paths were removed and one cache was pruned**. The summaries record each run's free-space snapshots separately; file lengths and dependency-preflight allocation changes are also separate.

| Scope | Operations | Logical bytes | Distinct-file bytes |
| --- | ---: | ---: | ---: |
| Initial Cargo caches, runtimes and installer downloads | 248 | 382654667321 | 350359575966 |
| Release caches, test profiles and reproducible archives | 45 | 15266393026 | 14732841896 |
| Git-identical source copies and generated frontend output | 303 | 3815072599 | 3815072599 |
| Total | 596 | 401736132946 | 368907490461 |

Initial base: `2beefbb1dc89720c191493314b82e503599d1bb9`. Follow-up bases: `052b1c30c47832379bae809f8f01dcc1edae8c6a` and `198363189046e5dd028507f643df1c83df29f88c`. All work used the original main checkout.

## Preserved

The current checkout, current owner executable/PDB/DLLs, FFmpeg executable, release resources/licenses, C5 scripts/selftests/fixtures/media/measurements, active FFmpeg and Node/PATH tools, PresentMon, Codex handoff scripts, pinned FFmpeg SDK, current rc.2 evidence, recovery backups, signed ASIO documents and source/license records remain. The referenced old FFmpeg8.1.2 SDK and historical distribution bundles remain. The release deps cache retains its exact two runtime aliases; their bytes/native IDs/link counts remain unchanged. Release logical size remains 824,456,848 bytes after the previous cache reduction.

Unique or unverified experiment sources are retained. The sole AppData QA profile (about 74 MB) contains project backups/authority records and remains; the ordinary owner profile was not touched. Protected sol-handoff outputs remain. No worktree or dependency-package tree was removed.

## Reproducible copies removed

39 old C5 source.tar copies (4,044,840,960 bytes) were individually matched against streamed Git archives, with exact lengths/SHA values recorded in the extra manifest. Source commits are reachable from verified old-origin/main `955ce8283c9ee9397ce2ba03d0736f9188a7b014`. Old executable receipts remain as historical evidence; obsolete binaries require a fresh retained preparation/build procedure.

The latest sweep removed 236 copied source components (3,393,043,544 bytes) and 67 generated app/dist folders (422,029,055 bytes). Every source component matched fresh `git -c core.autocrlf=true archive --format=tar <commit>` bytes, exact file set and SHA-256 content-tree digest. 29 owning commits were verified pushed/reachable. Modified, missing/extra or reparse-bearing components were excluded. The manifest binds commit, component prefix, bytes, file count, content digest and archive configuration; both plan and final apply recompute the proof. To reconstruct a removed component, archive its recorded commit and gitPrefix and extract into its original source root after confirming that component target is absent.

## Native shared-link finding

Ten old node_modules copies were retained. Python stat information initially failed to establish native NTFS alias independence; the full native snapshot rejected the first candidate before any deletion. All 10 copies each have 3,369 native multilink files (often 12+ aliases); independently single-linked content is only about 0.37 MB per copy. Their apparent 808 MB is largely shared content. Node targets and experimental unlink logic were removed from the final scope; strict external-hardlink/reparse rejection remains intact.

A preliminary `pnpm --dir app install --offline --frozen-lockfile --ignore-scripts` succeeded and reported already up to date. It regenerated `.modules.yaml`; its before/after SHA values and free-space delta are retained in dependency-preflight.json. No dependency packages were removed. Final checks distinguish 410 immutable original files from this regenerated metadata.

## Validation

- Exact manifests and stable implementation independently reviewed before clean/pushed checkpoints. Manifest hashes: initial 248 `B288F0C8E06C8F555F4194AAAD806C87AEB7720D150B62AA690E05ECC2E7F33B`; extra 45 `0B59D0EBA25946C1666009DC37ED8B931C74913E6838D8C48992885A276137D1`; copies 303 `FFA057F2A7A36CEE85A62B0BC7DA9829504629124EB2B514DF6B2B27368DEDFB`.
- Latest focused suite: **42 cases PASS**, including same-length content modification with restored mtime, extra/missing source files, independent Python/PowerShell tree-digest agreement, invalid proof binding, long paths, junction ancestry, hardlinks and runtime-alias retention. All final plan/apply runs exited 0. The native node investigation's failed plan is recorded as a retained-data boundary, not completion evidence.
- Canonical native identity/ancestry checks, repeated stable snapshots, per-candidate writer checks, pushed/clean Git guards and literal-path deletion protect each operation. Only explicit proven archive kinds may be files; other kinds require directories. Shared links and reparse points are rejected. The release partial operation reports Pruned separately from Deleted.
- After the latest run, all 303 targets are absent; **410 immutable original SHA values plus 22 runtime/alias hashes match**. Regenerated dependency metadata matches the recorded frozen preflight. All 10 shared dependency copies remain. Node 22.22.1, Vite 6.4.2, TypeScript 5.9.3 and pnpm graph resolve; pinned SDK DLL/encoder SHA/PE/header/library checks pass.
- Diff whitespace checks pass. No native product build/window or physical-output acceptance is claimed. Compiler warning baseline/current/delta were not measured by this maintenance validation.

## Records

Evidence is under `artifacts/build-cache-cleanup-20261116/`. Exact-path/identity ledgers: apply-cache.jsonl, apply-runtime.jsonl, apply-performance-runtime.jsonl, apply-extra.jsonl and apply-copies.jsonl. Separate summaries: summary.json, summary-extra.json, summary-copies.json. Latest preservation evidence: verification-copies.txt, dependency-preflight.json and retained-dependency-aliases.json. retained-inventory.json contains current logical sizes without following reparse points. The latest manifest/ledger set equality is verified. No unresolved cleanup failure remains.
