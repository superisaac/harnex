# Harnex TUI Plan

## Goal

Design and implement a terminal user interface for Harnex, the Elixir coding agent, using the Codex TUI as a reference for information hierarchy and interaction patterns while keeping Harnex's own identity, capabilities, and implementation constraints.

## Guiding principles

- Keep the coding loop in one terminal session: inspect, plan, edit, run, review, and continue.
- Make the current task, model, permissions, workspace, and execution state visible at a glance.
- Keep user input fast and predictable with multiline editing, history, completion, and keyboard shortcuts.
- Require explicit approval for configured risky operations and show the reason before asking.
- Make long command output, diffs, and agent updates navigable without losing the composer.
- Treat narrow terminals and accessibility as first-class constraints.

## Proposed screen anatomy

### 1. Header

Show a compact session summary:

- Harnex name and version.
- Current project/workspace directory.
- Active model and reasoning mode, when configured.
- Permission and sandbox mode.
- Git branch and dirty state, when the workspace is a repository.
- Connection/session status for local or remote runtimes.

The header should collapse or reduce secondary fields at small widths.

### 2. Transcript

Use a scrollable, structured conversation area as the primary surface. Render distinct blocks for:

- User prompts and attached files.
- Harnex responses, plans, and final summaries.
- Tool calls, shell commands, exit codes, and bounded command output.
- File edits and Git diffs with expandable detail.
- Approval requests and their outcomes.
- Background jobs and delegated agent updates.
- Errors, warnings, retries, and cancellations.

Each block should retain enough metadata to support copy, collapse/expand, retry, and navigation.

### 3. Composer

Provide a multiline prompt editor anchored below the transcript. It should support:

- Enter to submit and a separate shortcut for newline insertion.
- Prompt history and editable drafts.
- Slash-command completion.
- File and directory mentions.
- Attachment indicators.
- Vim editing as an optional mode.
- Clear indication when Harnex is busy, waiting for approval, or ready for input.

### 4. Footer/status line

Show the operational facts needed during a run:

- Context and token usage, if available.
- Current turn state (idle, planning, running, waiting, completed, failed).
- Active permission profile.
- Background process count.
- Git branch or workspace state.
- Keyboard hint for help and the most relevant next action.

Status fields should be configurable and reorderable.

### 5. Overlays and pickers

Implement modal or pane-based selectors for:

- Model and reasoning mode.
- Permissions and sandbox policy.
- Configuration.
- Session resume, rename, fork, and new session.
- Skills, plugins, and MCP tools.
- Theme, status line, terminal title, and keymap.
- Help and shortcut reference.

Overlays must preserve the transcript and return focus to the composer or the invoking block.

## Interaction model

### Slash commands

Reuse the slash commands already implemented by Harnex. The TUI plan does not introduce, rename, or expand the command set. During implementation:

- Inventory the existing command parser and handlers.
- Keep each command's current syntax and behavior.
- Route command input through the existing implementation rather than duplicating command logic in the renderer.
- Add only the TUI presentation needed for existing command output, errors, completion, and prompts.
- Preserve current validation and side-effect rules.

Any future command additions should be planned separately from the initial TUI work.

### Keyboard shortcuts

Define a discoverable default keymap for submit, newline, interrupt, scroll, search, copy, help, command completion, and transcript navigation. Support configurable bindings after the initial release.

### Approval flow

When a tool requests approval, pause the turn and present:

- The exact command or operation.
- Workspace and permission context.
- Why approval is required.
- Allow once, allow for the session, deny, and cancel options where applicable.

Record the decision in the transcript and make the resulting state obvious.

## Elixir architecture plan

1. **TUI boundary** — define a small application-facing event model for user input, rendering updates, tool events, approvals, and session state.
2. **Runtime adapter** — consume Harnex agent events without coupling rendering code to the agent implementation.
3. **State store** — maintain transcript blocks, composer state, overlays, scroll position, focus, and status data in one deterministic state structure.
4. **Renderer** — render the state into terminal cells with width-aware wrapping, stable colors, and graceful degradation.
5. **Input router** — translate keyboard events into commands, text edits, scrolling, cancellation, and overlay navigation.
6. **Terminal process** — isolate raw-mode setup, alternate-screen handling, resize events, clipboard integration, and shutdown cleanup.
7. **Persistence/configuration** — load project and user settings, then persist TUI preferences such as theme, keymap, status fields, and terminal mode.
8. **Test harness** — provide deterministic event playback and terminal snapshots so rendering and interaction can be tested without a real terminal.

Select the terminal rendering/input dependency only after checking its maintenance status, Unicode width behavior, resize support, and compatibility with the project's supported OTP/Elixir versions.

## Delivery phases

### Phase 0 — Discovery and decisions

- Inspect the current Harnex agent loop, event types, configuration, and dependency policy.
- Identify supported terminals and minimum dimensions.
- Decide fullscreen versus scrollback behavior for the first release.
- Record the rendering library and state/event boundaries in an implementation decision record.

### Phase 1 — Vertical slice

- Start Harnex in a terminal and render header, transcript, composer, and footer.
- Submit a prompt, receive streamed text, and exit cleanly.
- Handle terminal resize and keyboard interrupt.
- Keep the first phase focused on the core single-session coding loop; MCP, plugins, skills, and delegated agents are out of scope.

### Phase 2 — Tool execution and approvals

- Render command/tool lifecycle events and bounded output.
- Add approval prompts, cancellation, and retry behavior.
- Show errors and recoverable failures without corrupting the session.

### Phase 3 — Files, diffs, and context

- Add file mentions and attachments.
- Add collapsible diffs, copy actions, search, and transcript navigation.
- Add `/status`, `/diff`, `/review`, `/compact`, and help flows.

### Phase 4 — Session and runtime management

- Add new, resume, rename, fork, and clear session actions.
- Add background job and delegated-agent status.
- Add configurable model, permissions, and runtime settings.

### Phase 5 — Personalization and hardening

- Add themes, configurable status line, keymaps, terminal title, and optional Vim editing.
- Verify narrow terminals, Unicode, long lines, large outputs, non-Git directories, and interrupted processes.
- Document installation, commands, shortcuts, configuration, and troubleshooting.

## Validation checklist

- Unit-test state transitions, command parsing, approval decisions, wrapping, truncation, and resize behavior.
- Snapshot-test representative screens at narrow, normal, and wide terminal widths.
- Replay streamed agent/tool events and verify deterministic transcript rendering.
- Test clean shutdown on normal exit, interrupt, crash, and terminal resize.
- Exercise permission boundaries and ensure denied operations remain denied.
- Run the existing Elixir formatter, compiler, and test suite for every phase.
- Manually verify the complete happy path: start, prompt, plan, approve a command, inspect a diff, review, and resume.

## Initial implementation status

- A dependency-free Mix application skeleton now provides `Harnex.TUI.State`, `Harnex.TUI.Renderer`, and `Harnex.TUI`.
- The vertical slice renders Header, Transcript, Composer, and Footer regions.
- Both `:fullscreen` and `:scrollback` state modes are represented; fullscreen cleanup uses ANSI screen clearing while scrollback leaves terminal history intact.
- Existing slash commands are forwarded through a runtime adapter point; the TUI does not define a new command set.
- The concrete Harnex Agent implementation is still pending; the runtime boundary and adapter are now in place for it.
- `Harnex.AgentRuntime` and `Harnex.AgentAdapter` now define the real runtime boundary; `Harnex.TUI.process_prompt/3` accepts `runtime: Module` and validates returned stable events before applying and persisting them.
- The production worktree keeps its existing `Harnex.TUI.Input`, `Session`, `Renderer`, and TermUI implementations; experimental key handling is exposed as `Harnex.TUI.InteractiveInput`, and `Harnex.TUI.EventBridge` converts `Harnex.Events.Event` values into the experimental stable event model.
- `Harnex.TUI.Session` now starts runs through `Harnex.TUI.RuntimeAdapter`; runtime status, cancellation, approval delegation, and event conversion are exposed through one TUI-facing boundary.
- `RuntimeAdapter.run_with_tui_events/2` provides batch event projection for non-interactive callers, while `EventBridge` preserves unknown runtime events as opaque `:runtime_event` blocks.
- `Harnex.TUI.TermUIApp` now stores an experimental `Harnex.TUI.State`, projects real `Harnex.Events.Event` values through `EventBridge` and `Adapter`, and synchronizes the existing TermUI transcript/status view from that state.
- `ApprovalPicker` is now connected to the real `Agent.Loop` approval callback: TermUI receives an approval request, navigates the four picker decisions, and sends `:allow` or `:deny` back to the waiting tool task.
- TUI resume now supports production `RunStore` snapshots through `SessionStore.resume_run/2`; the snapshot's run ID, status, and conversation transcript are projected into TUI state without introducing a second production persistence backend.
- The stable event boundary is now represented by `Harnex.TUI.Event` and `Harnex.TUI.Adapter`; streamed assistant deltas, tools, approvals, completion, failure, and cancellation update the TUI state without exposing runtime-private events.
- `Harnex.TUI.SessionStore` now provides versioned, append-only event persistence and readable-prefix recovery when the final record is truncated or invalid.
- `Harnex.TUI.SessionStore.resume/2` replays persisted stable events through the adapter and returns a reconstructed state plus recovery metadata.
- `Harnex.TUI.process_prompt/3` can persist the user event and every stable Agent event in order through the `session_path` option, making the append-only store part of the interactive prompt flow.
- `Harnex.TUI.start/1` now restores the session automatically when `session_path` points to an existing log; `resume_state/2` keeps startup recovery independently testable.
- `Harnex.TUI.Composer` now provides pure multiline editing, cursor movement, backspace, newline, and submit operations; raw terminal key handling can be layered on top without duplicating editing rules.
- `Harnex.TUI.Keymap` now defines default actions and decodes common Enter, arrow, Home/End, backspace, interrupt, help, and text input sequences.
- `Harnex.TUI.Input` now applies decoded actions to the TUI state and returns explicit continue, submit, or interrupt results for the terminal loop.
- Composer cursor position is now part of `Harnex.TUI.State`, so insertion after navigation preserves the correct editing position.
- `Harnex.TUI.Loop` now provides one dispatcher for terminal bytes: key decoding, input state updates, prompt submission, and Agent callback events.
- Added validated `Harnex.TUI.Config`, a `:window_resized` event, and tests for mode/status configuration and resize transcript handling.
- Session status, resume target, model/session identity, branch, and context usage are now visible in the TUI, with corresponding README guidance.
- `mix harnex --permissions ...` now carries the selected initial permission label into TUI state; the supported values match the planned permission model.
- `mix harnex` now starts the TUI, with `--scrollback` for scrollback mode and `--session PATH` for session restoration and persistence.
- Terminal lifecycle sequences are isolated in `Harnex.TUI.Terminal`; approval labels and operation checks are centralized in `Harnex.TUI.Approval`; `:diff` events render as transcript blocks.
- The main TUI now uses `Harnex.TUI.Terminal` for lifecycle and width detection, highlights approval/failure transcript blocks, updates status after approval decisions, and exposes `SessionStore.last/1` for resume diagnostics.
- Added validated `Harnex.TUI.Config`, a `:window_resized` event, and tests for mode/status configuration and resize transcript handling.

## Open questions

- **Rendering library decision:** evaluate `TermUI` first against Harnex's supported Elixir/OTP versions, Unicode width handling, resize support, raw input, and maintenance activity. If it does not satisfy the matrix, use a small Harnex-owned renderer built on `IO.ANSI` and OTP terminal I/O primitives. Avoid making the initial TUI depend on an older framework whose native or transitive dependencies constrain the supported matrix.
- **Terminal modes:** support both fullscreen alternate-screen mode and scrollback mode in the first release. Choose and document the default, provide a configuration or startup switch for selecting the mode, and ensure both modes share the same transcript, input, approval, and cleanup behavior.
- **Initial permission model:** provide `read-only`, `workspace-write + on-request`, `workspace-write + auto`, and explicitly opt-in `danger-full-access` modes. Use `workspace-write + on-request` as the default, keep `read-only` available for inspection, and require explicit opt-in for unrestricted access. The TUI must show the active mode and approval scope, and approval prompts should support allow once, allow for the session, deny, and cancel where applicable.
- Should the first release use fullscreen alternate-screen mode, scrollback mode, or both?
- **Transcript event boundary:** expose the following user-observable events first, through a TUI adapter: `session_started`, `user_message`, `turn_started`, streamed `assistant_delta`, `assistant_message_completed`, `tool_started`, `tool_output`, `tool_completed`, `approval_requested`, `approval_resolved`, `turn_completed`, `turn_failed`, and `turn_cancelled`. Internal reasoning, scheduler details, and tool-specific private events must not be exposed directly to the TUI; the adapter may translate them into stable user-observable events when appropriate. Each event should carry a stable identifier, timestamp or ordering value, status, and enough metadata for rendering, retry, cancellation, and transcript replay.
- What is the initial permission model and how should it map to approval UI?
- MCP, plugins, skills, and delegated agents are deferred beyond Phase 1 and should be planned separately when the core TUI is stable.
- **Transcript persistence and resume guarantees:** persist sessions as versioned, append-only records with a stable session ID, workspace identity, timestamps, event ordering, and enough metadata to reconstruct the transcript and active configuration. Flush each user message, approval decision, completed tool result, and completed assistant response before treating it as durable. Treat in-progress streaming deltas as recoverable temporary state; after a crash, resume from the last committed event and mark any interrupted turn clearly instead of fabricating completion. Resume must preserve the transcript, working directory, model and permission context, while allowing configuration changes that are explicitly supported. Detect truncated or invalid records, retain the readable prefix, and report the recovery point.
