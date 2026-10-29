# Development candidate verification (29 October 2026)

- Seven Node tests passed and browser-preview checks covered assistant labels, unsupported background generation, image selection, and the browser-only draft notice.
- The installed candidate was loaded in SketchUp 2026. Its UI saved a draft; description and width restored after saving the SKP and restarting SketchUp. A reference supplied via the Ruby upload handler restored from the local cache after reopening the SKP. Missing-image feedback was observed in the UI and tested separately. File-picker upload was not exercised during this test.
- An isolated Ruby regression covered draft restoration, missing cache, and malformed draft. A simulated 65-second startup remained in the starting state and a real failed status remained failed.
- One Codex background session ran against the saved test SKP using one reference and a manually entered width of 1,800 mm. The user delegated approval of actions for the test; the session finished with 42 named parts, 18,294 faces and no non-solid parts reported. Overall width matched 1,800 mm; depth 1,800 mm and height 620 mm were estimated. Visual fidelity is not quantified.
- The 0.4.2 RBZ remains unchanged; the candidate has not been packaged as a release. One successful case does not establish repeatability or commercial readiness.

# 0.4.2 verification

- Five automated tests pass for MCP startup, approval wait, stale decision rejection, approve, decline, cancellation and fail-closed server isolation. Simulated events are used for runner tests.
- A real Codex App Server requested permission for a narrowly scoped apply_parts test against a nonexistent job; the test accepted that request, and the FurniForge bridge returned “Job not found”. This verifies the approval protocol without modifying scene geometry. Only FurniForge exposed tools in the session.
- Live SketchUp 0.4.2 end-to-end: the user supplied six sofa references and approved multiple actual apply_parts requests in the workspace. Codex completed the job directly in SketchUp with 94 named parts and 45,696 faces; bounding dimensions were 3450 x 3450 x 810 mm. The approval dialog and per-action responses were exercised. Visual similarity is not quantified, and the supplied dimensions were in free-text description rather than validated dimension fields.

# 0.4.1 current verification

- Eight Node protocol and supervisor tests pass, including incomplete sessions and tool errors.
- A live FurniForge bridge diagnostic inserted and removed a temporary 20 mm box in an existing empty job, returning it to zero parts.
- Live 0.4.1: SketchUp bridge health indicator reported connected; Codex session read six references and created a planning job, but apply_parts was rejected with “MCP tool call requires approval, but approval policy is never”. Result: 0 parts and 0 faces. AI model generation and viewport framing remain unverified; approval handling is not implemented.

# FurniForge 0.4 verification
28 October 2026 · Windows / SketchUp 26.0.429 / Node.js 24.

Passed:
- Six Node tests: MCP initialization and eight tools; model vector schema validation; restricted CLI arguments; supervisor status from actual JSONL-shaped events; nonzero exit; zero exit without a completed turn; cancellation of only the owned process tree. These supervisor tests use a simulated child process.
- Seven live SketchUp checks: two-image upload in one batch, original filenames, atomic invalid-batch rejection, eight-image limit, description persistence, launcher path validation and preservation of the existing scene.
- Seventeen native HtmlDialog checks, with captured callbacks: navigation, description replacing Model, multi-select input, upload batch containing two images, request description, explicit session opt-in, start/run/stop/failure UI and unsupported assistant labels. No modelling request was sent by this UI harness.
- Actual Codex CLI authenticated session using the same restricted launcher arguments: called furniforge_status through MCP and returned version 0.4.0 / bridge running, with a successful turn and exit code 0. Geometry-tool schema incompatibility found during the first test was fixed; the repeated live session had no tool exposure errors.
- Actual loopback bridge rejected an invalid background request scope before dispatch. A live native cancellation check confirmed the request ID is revoked immediately.
- All Ruby source files compile in SketchUp. JavaScript syntax checks passed.
- Visually inspected the native workspace. User's six existing references and two top-level scene entities remain in place.

Limits:
The live AI test reads bridge status only; it does not create furniture or send the user's images. Full photo-to-model generation through the new background button has not been run on the user's existing scene. UI callbacks, native upload and the supervisor are tested separately. This is not a model-fidelity benchmark. Automatic Claude Code, Cursor and Gemini CLI integrations are not implemented.

Reports: ../FurniForge-v4-native-test-report.json and ../FurniForge-v4-ui-test-report.json. Local CLI smoke-test details stay in the development work folder and are not included in the source package.
