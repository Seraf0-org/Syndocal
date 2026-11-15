# Build cache cleanup — 2026-11-16

Completed the owner's maximal obsolete-cache cleanup from a clean main base `2beefbb1dc89720c191493314b82e503599d1bb9`. All **248 exact directory targets** were deleted with zero failures. The observed C-drive free space increased from **125729153024 to 475659431936 bytes**, a gain of **349930278912 bytes** (approximately 349.9 GB). Logical lengths count internal Cargo aliases; distinct-file lengths and physical free space are reported separately.

| Deleted scope | Targets | Logical bytes | Distinct-file bytes |
| --- | ---: | ---: | ---: |
| Generated Cargo caches and initial C5 staged runtimes | 157 | 361094222699 | 328799131344 |
| Obsolete runtime copies and downloaded installers | 21 | 7959955758 | 7959955758 |
| Remaining generated performance-QA EXE/DLL/PDB leaves | 70 | 13600488864 | 13600488864 |
| Total | 248 | 382654667321 | 350359575966 |

## Preserved

The entire owner-used `target/release`; active FFmpeg and Node/PATH tools; VJ benchmark media; PresentMon; Codex handoff scripts; C5 scripts, selftests, fixtures, plans, provenance and measurements; pinned `target/qa/ffmpeg-selfbuild-20261027`; current rc.2 QA evidence; authored helper scripts; recovery backups; source snapshots/archives; signed ASIO documents; and FFmpeg source/license/build records remain. `SyndocalDev/ffmpeg-pinned-8.1.2-sdk` also remains because retained historical QA scripts reference it. The final retained-directory inventory records logical file sizes and skips reparse traversal; it is not a physical-allocation measurement.

Old QA executable receipts remain as historical evidence; the deleted executables must be rebuilt with retained preparation scripts when needed. Sources, recovery content, dependency packages and worktrees were not deleted. No dependency restoration was needed.

## Evidence and safety

- Dated safety suite: **19 meaningful checks passed**, covering Unicode/long paths, traversal, junction ancestry, changed snapshots, internal hardlink accounting and external-link rejection. The final plan for each sweep (157 + 21 + 70 targets) and all three apply runs exited 0.
- Independent adversarial review accepted every exact target before its tracked, pushed checkpoint. Final 248-target manifest SHA-256: `B288F0C8E06C8F555F4194AAAD806C87AEB7720D150B62AA690E05ECC2E7F33B`. The two expansions preserved every preceding target unchanged. All 67 historical C5 build commits were verified reachable from live old-origin/main `955ce8283c9ee9397ce2ba03d0736f9188a7b014`; the rewritten current main has separate history.
- The harness accepts only exact manifest paths in the original checkout/cache roots. Native final paths and identities, reparse rejection, complete hardlink-boundary counts, a second stable snapshot, process/writer checks and clean/pushed Git checks precede literal-path PowerShell deletion. Native safety helpers are tracked with the harness; no locally excluded historical script is required. Before-delete/failure events preserve partial-failure recovery boundaries.
- **All 411 protected SHA-256 values matched after the final sweep**, including the owner executable/DLLs, C5 top-level files, lockfile and dependency metadata. All 248 targets were verified absent.
- Node 22.22.1, Vite 6.4.2, TypeScript 5.9.3 and the local pnpm dependency graph resolve. Active FFmpeg's version query succeeds. The canonical pinned SDK passes its independent DLL/encoder SHA-256, PE, header and library checks. See `artifacts/build-cache-cleanup-20261116/verification.txt`.
- `git diff --check` passes. This maintenance makes no product-runtime changes; no native build/window or physical-output acceptance is claimed. Compiler warning baseline/current/delta were not measured by this maintenance validation.

Exact absolute deletion paths, byte counts and identities are in `artifacts/build-cache-cleanup-20261116/apply-cache.jsonl`, `apply-runtime.jsonl` and `apply-performance-runtime.jsonl`. `summary.json` records totals; `retained-inventory.json` records retained sizes. No unresolved cleanup failure remains. Further deletion of retained sources, archives or evidence requires a separate ownership/dependency decision.
## Owner-requested additional cleanup

Follow-up base: `052b1c30c47832379bae809f8f01dcc1edae8c6a`. The owner requested further removal after the initial checkpoint. The original 248-target list remains unchanged. The separate `cleanup-cache-extra-20261116.targets.json` contains 45 additional operations: generated release build/fingerprint/examples/incremental trees, old test browser profiles, 39 byte-reproducible C5 Git archives, and pruning the release deps cache while retaining its `syndocal.exe`/`syndocal.pdb` hardlink aliases. Root runtime files, resources, licenses and authored sources remain protected.

All 39 archives (4,044,840,960 bytes) were hashed against fresh streamed `git archive --format=tar <commit>` output, with exact size/SHA equality; every commit is reachable from the live old-origin/main ref recorded above. The extra manifest records each commit/SHA/size, permitting exact reconstruction. Actual source snapshots and historical receipts remain. This supersedes the initial blanket retention of those reproducible archive copies and generated release subdirectories.

The additional path uses explicit file kinds and proofs; original directory kinds cannot become file deletion targets. A partial operation keeps the two runtime aliases untouched, hashes their native identities/link counts/contents before and after, and reports `Pruned` separately from whole-path `Deleted`. All removed entries still reject external hardlinks and reparse points. An independent reviewer accepted the exact manifest (SHA-256 `0B59D0EBA25946C1666009DC37ED8B931C74913E6838D8C48992885A276137D1`) and stable implementation. The focused suite now passes **36 cases**. The final 45-target plan passed with 15,266,393,026 logical bytes / 14,732,841,896 distinct-file bytes. Apply follows this tracked/pushed checkpoint. No compiler warning measurement or native-window acceptance is claimed.

An additional AppData QA-profile audit found only one 74 MB profile containing project backups and output-authority records. It remains intact; no whole QA-profile deletion is included.
