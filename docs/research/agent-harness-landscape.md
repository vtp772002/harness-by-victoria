# Agent Harness Landscape And Gap Map

Date: 2026-08-31

## Purpose

This is a dated landscape sweep, not a claim that one framework wins every
task. It compares primary documentation and source repositories for the
capabilities that matter to `harness-by-victoria`: context portability,
authority and permission boundaries, durable recovery, evaluation, isolation,
observability, interoperability, and release integrity.

The conclusion is intentionally narrow: `harness-by-victoria` should be the
repository protocol and proof layer that other agent runtimes can consume. It
should not become another general-purpose agent runtime or orchestration
control plane.

## Reference Set

| Reference | What it demonstrates | Implication for Harness |
| --- | --- | --- |
| [AGENTS.md](https://agents.md/) and [Agent Skills](https://agentskills.io/) | Small, portable repository instructions and progressively loaded skill bundles | Keep the root entrypoint short, route to authoritative files, and ship skills as portable folders rather than one oversized prompt. |
| [OpenHands SDK](https://docs.openhands.dev/sdk/index) | Coding-agent tools, task decomposition, context compression, security analysis, model choice, and local/remote execution | These are runtime capabilities. Harness should expose clean repository boundaries for them, not duplicate the runtime. |
| [Inspect AI](https://inspect.aisi.org.uk/) | Composable datasets, solvers, agents, tools, scorers, logs, traces, and sandbox backends | Add repository-owned evaluation fixtures and evidence contracts so an external runner can score Harness behavior. |
| [METR Task Standard](https://github.com/METR/task-standard) | A common task shape: environment, instructions, and optional automatic scoring; adaptors for multiple suites | Define benchmark cases around observable repository state and scoring, without adding a task database. |
| [OpenAI Agents SDK](https://openai.github.io/openai-agents-python/running_agents/) | Guardrails, handoffs, input shaping, and [structured tracing](https://openai.github.io/openai-agents-js/guides/tracing/) | Preserve explicit authority stops and make proof machine-readable where the current CLI already promises machine output. |
| [Claude Code permissions and hooks](https://code.claude.com/docs/en/permissions) | Deny-first tool permissions, pre-tool hooks, and runtime decisions | Keep permission ownership with the host agent; Harness can document safe repository boundaries and never imply that a text instruction is enforcement. |
| [Claude Code MCP](https://code.claude.com/docs/en/mcp) and [MCP authorization](https://modelcontextprotocol.io/specification/2025-06-18/basic/authorization) | Standard tool/data connectivity with explicit authorization considerations | Do not invent a generic connector layer. If future integration is authorized, require tool scope and trust evidence. |
| [LangGraph](https://langchain-ai.github.io/langgraph/) | Durable execution, persistence, streaming, and human-in-the-loop graph interruption | Harness already has durable filesystem transactions and human-directed merge resolution; keep this repository boundary deterministic and recoverable. |
| [Google ADK evaluation](https://github.com/google/adk-docs/blob/main/docs/evaluate/index.md) | Separate trajectory/tool-use evaluation from final-response evaluation, with evalsets and conformance tests | A final answer is not enough. Benchmark discovery, authority behavior, tool/action trajectory where observable, and final repository outcome separately. |
| [AutoGen AgentChat](https://microsoft.github.io/autogen/stable/user-guide/agentchat-user-guide/tutorial/index.html) | Typed agents, teams, termination conditions, and human-in-the-loop coordination | Coordination belongs to an agent runtime. Harness should remain compatible with teams without owning their lifecycle. |
| [SWE-bench](https://github.com/SWE-bench/SWE-bench) | Repository-level tasks evaluated in reproducible environments against tests | Use behavior-level acceptance and recovery scenarios, but do not claim arbitrary consumer application execution. |
| [BrowserGym](https://arxiv.org/abs/2412.05467), [OSWorld](https://github.com/xlang-ai/OSWorld), and [AgentBench](https://github.com/THUDM/AgentBench) | Standardized environments and outcome benchmarks across web, desktop, OS, database, and knowledge tasks | These show the value of reproducible environments; they are outside the generic repository protocol boundary. |
| [OpenTelemetry semantic conventions](https://opentelemetry.io/docs/concepts/semantic-conventions/) | Stable names for cross-system traces and operations | Keep observability claims bounded: Harness can emit repository evidence, but does not own provider, model, or runtime telemetry. |

## Current Capability Matrix

| Capability | Current evidence in this repository | Assessment |
| --- | --- | --- |
| Repository authority and small context | `AGENTS.md`, `docs/WORKFLOW.md`, `docs/README.md`, product/decision/plan maps | Strong |
| Portable skills and client shims | Canonical `.agents/skills/`, thin `.claude/skills/` discovery wrappers, optional Claude and Copilot instruction loaders, exact installer manifests | Strong for Codex, Claude Code, GitHub Copilot, and Cursor's documented standard paths; other client adapters are not established |
| Human-owned ambiguity boundary | Workflow authority gate and task-authority contract | Strong |
| Safe maintenance and recovery | Rust transactions, three-way merge, conflict staging, drift detection, rollback, symlink checks | Strong |
| Release identity and byte integrity | Versioned release pointer, binary version check, SHA-256 sidecar, exact asset inventory, and Decision 0032 GitHub artifact provenance | Strong hosted integrity and provenance; independent publisher trust root remains explicitly absent and own-release attestation is not yet observed |
| Agent trajectory evaluation | Deterministic workflow fixtures, the v1 scorecard, and an optional metadata-only trajectory validator cover Harness-owned behavior; no LLM action trace is collected | Partial by design; the adapter validates structure and proof ordering, not model quality or raw action traces |
| Final outcome evaluation | Rust and repository contracts prove Harness-owned outcomes | Strong for Harness itself; consumer application outcomes remain out of scope |
| Runtime sandbox and secret isolation | Not owned by this repository | Deliberately external; must not be implied by install |
| Tool permissions, MCP, and multi-agent orchestration | Not owned by this repository | Deliberately external; require host/runtime authority |
| Cross-run telemetry and cost accounting | Not implemented | Open gap, but no current authority for a telemetry backend or data retention policy |

## Prioritized Gap Map

### P0: Make proof portable and claim-matched

The first repository-owned benchmark contract is implemented at
`scripts/evaluate-harness.sh` and
`tests/evaluation/test-harness-evaluator.sh`. It covers deterministic cases
for:

- read-only discovery preserving the complete workspace fingerprint;
- bounded change staying beside its authority;
- ambiguous product choice stopping before mutation;
- durable work using one Git-native plan;
- invariant work requiring authority plus positive and negative proof;
- interrupted maintenance recovering before new work; and
- completion reporting separating passed, unknown, and unverified evidence.

The contract emits a stable machine-readable result and keeps negative fixtures
recoverable. It does not create a task database or pretend to run an arbitrary
LLM. Decision 0029 authorizes an optional metadata-only external trajectory
adapter; the runner remains outside this repository, and raw prompts,
transcripts, content, tool payloads, credentials, and tokens are rejected.

### P1: Improve machine-facing failure evidence

The existing CLI supports `--json` for successful reports. Before changing the
error channel, the repository needs an explicit output contract for non-zero
errors: stream, schema, stable error code, redaction, and compatibility. This
is a decision-shaped gap, not permission to guess.

### P1: Cross-client portability audit

The current product supports the canonical `AGENTS.md` entrypoint, an optional
Claude shim and skill-discovery wrappers, and an optional GitHub Copilot
repository-instructions loader. The Copilot loader points back to `AGENTS.md`
and does not create a duplicate `.github/skills/` tree. Cursor and Copilot
surfaces that directly consume `AGENTS.md` and `.agents/skills/` need no extra
copy. Survey additional clients only when their file format, precedence, and
installation ownership are authoritative; do not scatter duplicate
instructions that can drift.

### P2: Independent release trust root

The architecture explicitly states that SHA-256 is relative to the selected
GitHub release and not an independent publisher-compromise defense. Decision
0032 adds hosted GitHub artifact provenance, but a publisher-controlled signed
channel, key rotation, revocation, and recovery policy still require a new
accepted decision.

### P2: Runtime observability adapter

An optional evidence exporter could map repository operations to external
trace conventions, but only after the owner, schema, privacy/redaction, and
retention boundary are decided. It must remain optional and never turn local
validation into a claim of production telemetry.

## Recommendation

The P0 benchmark/evidence contract is now the baseline gate. The optional
metadata-only adapter is the repository boundary for an authorized external
runner. The next integration step, if desired, is to wire one external runner
to emit this schema without moving execution, raw traces, or retention policy
into Harness. This compounds the repository's existing strengths, matches the
trajectory-plus-outcome practice used by Inspect and Google ADK, and stays
faithful to Harness's strongest differentiator: making agent work legible and
safe at the repository boundary.

Do not add an agent runtime, task database, MCP server, or hosted control plane
as a reaction to this landscape. Those would make the product broader but not
more trustworthy, and the current repository authority explicitly rejects that
boundary.
