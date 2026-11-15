# Build cache cleanup — 2026-11-16

Base: `main` at `2beefbb1dc89720c191493314b82e503599d1bb9` (clean and equal to origin/main before this task).

The owner requested maximal obsolete-cache removal and asked Codex to resume Claude's interrupted cleanup. Claude's temporary script was not executed: it pruned unknown children, crossed shells for deletion, and would remove C5 test sources, current rc.2 evidence and unique recovery files.

## Exact boundary

The dated manifest `harnesses/cleanup-cache-20261116.targets.json` owns 157 exact directory targets: 78 generated Cargo cache trees, 75 C5 staged runtime directories, and four obsolete build-output trees. It never deletes source snapshots, source archives, scripts, fixtures, logs, screenshots, dependency packages, worktrees or QA profiles. Those small or non-regenerable items remain available for evidence and recovery. Rebuild obsolete QA executables with the retained C5 preparation scripts when needed; old executable receipts alone no longer identify a retained binary.

Protected: this checkout's entire `target/release`; both the active FFMPEG_DIR SDK and `target/qa/ffmpeg-selfbuild-20261027`; active Node/PATH tools; VJ benchmark media; PresentMon; Codex handoff scripts; C5 scripts/selftests/projects/provenance/ledger; `target/qa/release-candidate-20261115`; signed ASIO documents; `SyndocalDev/recovery` and authored helper scripts. No physical outputs are enabled.

## Validation before deletion

- Focused dated harness safety suite: **19 checks pass**, including Unicode, long paths, traversal rejection, junction/ancestry rejection, changed snapshots, internal hardlink accounting and external hardlink rejection.
- Independent adversarial review accepted all 157 exact targets. Manifest SHA-256: `80D4A38E9B21701B400DAFD619E5E681EAC0A5BDAB5FCD64376EF86B8A8C4CC8`. Harness SHA-256: `AFCE45CE1CC1D0C8418FB6CE0E75DBDA7E1C98CB6E64D5B64A56ABBD651C6E8A`.
- Reviewer verified the live old-origin/main ref `955ce8283c9ee9397ce2ba03d0736f9188a7b014` and reachability of all 67 C5 build commits. These historical commits are not ancestors of the rewritten two-commit current main; their pushed history remains in old-origin.
- The harness rejects reparse points anywhere in each target or its ancestry. Native file identities and link counts prove that every hardlink stays within that exact target. It verifies a second full metadata/identity snapshot and the final canonical root identity immediately before each literal-path PowerShell deletion.
- Active native builders, C5 runners, unverifiable relevant processes and processes referencing deletion targets block apply. This dated guard avoids the existing generic guard's stale parent-PID cycle on an unrelated long-lived interactive PowerShell process.
- Native path/checkpoint helpers are tracked in `harnesses/cleanup-cache-native-path.ps1` (SHA-256 `8C3A3754A2203D1627ABD9E32AC15CC419BDDFF31CBBC45DF64BB1206BB4D1FF`), extracted unchanged from the locally excluded historical harness; there is no dependency on that untracked file. The initial apply gate correctly stopped before deletion until this dependency was made explicit.
- Apply requires tracked harness/helper/list/test files and a clean checkout equal to its pushed upstream. The pre-delete and failed-delete ledger events retain partial-failure boundaries.
- This maintenance changes no product runtime. No native build or hardware acceptance is claimed. Compiler warning baseline/current/delta are not measured by this maintenance validation.

## Execution evidence

All 157 plan inspections passed (exit 0): 361,094,222,699 logical bytes; 328799131344 distinct-file bytes. No production deletion performed at this document's initial checkpoint; apply follows this tracked/pushed checkpoint. The execution ledger records exact absolute paths and logical bytes. Physical reclaimed space must be measured independently because Cargo has internal hardlinks and filesystem allocation differs from logical lengths.
