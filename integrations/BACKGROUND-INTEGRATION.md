# Background integrations: implementation brief

This is a development brief, not a completed setup procedure. FurniForge v0.4.2 has a tested Codex background runner; Claude Code, Cursor and Gemini CLI are not yet launched by the panel. Do not label them connected or functional without live verification. The user may ask an assistant to implement these integrations in a future development session.

## Intended outcome

Selecting a configured assistant in FurniForge should start a new background session with the user's own supported authentication and billing, read the attached images, create editable SketchUp geometry through the scoped FurniForge MCP bridge, display actual connection/progress/failure state, request and relay any required approval, and support cancellation. Model accuracy remains dependent on images and assistant capabilities.

## Integration requirements

- Research the current official provider documentation for supported programmatic launch, MCP, account authentication, allowed distribution, billing, Windows support and interactive permissions before choosing a method. Do not reuse credentials or assume a consumer subscription supports third-party products.
- Possible starting points, subject to current documentation: [Claude Agent SDK permissions](https://code.claude.com/docs/en/agent-sdk/permissions), [Cursor ACP](https://cursor.com/docs/cli/acp), [Gemini ACP](https://geminicli.com/docs/cli/acp-mode/). MCP alone does not provide a background session.
- Preserve the working Codex flow. Use separate provider adapters and an explicit capability/availability status. If an assistant, executable, version, sign-in or approval mechanism is unavailable, show an actionable setup or error state rather than simulated progress.
- Scope every modelling operation to the active request and model. Preserve manual values and reference authorization. Do not expose arbitrary shell, filesystem, browser or unrelated MCP tools; verify isolation rather than assuming that project settings override user/global settings.
- Display each actual permission request and its parameters, bind a user's decision to the pending request, support decline and cancellation, and never silently approve or bypass host safety policies. Do not write credentials or bridge tokens into the repository or logs.
- Do not claim success based only on process exit. Require evidence that a current job contains geometry and completed successfully. Preserve partial geometry on cancellation, explain its state, and preserve existing non-FurniForge scene objects.
- Write meaningful tests for authentication failures, unavailable executables, server isolation, image payloads, permission approval/denial/stale decisions, cancellation, stale request IDs and truthful status. Simulated tests are not evidence of a working provider.
- Perform an end-to-end test on each provider with the user's explicit authorization, a signed-in account and an isolated test model. If any provider cannot be tested, leave its background launch disabled and document the precise limitation.

Do not install software, create credentials, start paid API usage, change user settings, or publish a new version merely because this document exists. Follow the user's request and applicable permission requirements.
