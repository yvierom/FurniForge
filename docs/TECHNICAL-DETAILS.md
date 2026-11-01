# FurniForge 0.4.2
Developer preview by yviero_m.

Build editable SketchUp furniture models from reference images, with optional dimensions and an additional description. The Windows extension can start GPT Codex in the background through the locally installed Codex CLI, using the account signed in to that CLI. No manual copy/send step is needed. Codex tool calls that require approval are presented in the workspace for the user to approve or decline.

## Use in SketchUp
1. Open **Extensions > FurniForge > Open workspace**, click the logo and choose **GPT Codex**.
2. Click **Add reference images**. Select several files in one picker with Ctrl or Shift. Up to eight PNG/JPEG images are allowed in total, 5 MB each; you may add another batch later.
3. Optionally add dimensions/material or fill in **Additional description**. The description supplements the images and is saved with the same request.
4. Enable **Allow a background AI session for this request** and click **Create model**.
5. When Codex requests permission, review the tool name and parameters, then select **Approve this action** or **Decline**. Each decision applies to the current request. Watch the separate SketchUp bridge and Codex session indicators. The bridge indicator runs a loopback health check; Codex shows whether the current session has made an MCP call. Watch the session status. Geometry is created directly in the active SketchUp model, beside existing geometry, and the camera frames the component when geometry first appears and when the job completes. **Stop session** cancels the owned Codex process tree and revokes its request scope; geometry already created remains in the scene.

The previous Model panel has been replaced by the description input. Save or export geometry using SketchUp. Open `sketchup/furniforge/ui/panel.html` in a browser for a design preview; uploads there do not send a live request to SketchUp.

## Install / update on Windows
1. Extract the source package to a stable location. Install Node.js 20+ and run `npm ci --ignore-scripts` in the bridge folder.
2. Install `../releases/FurniForge-0.4.2.rbz` using SketchUp Extension Manager. Restart SketchUp after upgrading.
3. Install Codex CLI and sign in with your own account. Verify `codex login status`.
4. Run `setup-launcher.ps1` from PowerShell in the bridge folder. The launcher uses a native `codex.exe`; if your PATH resolves to a `.cmd` wrapper, pass the actual executable using `-CodexPath`.
5. The script writes `%LOCALAPPDATA%/FurniForge/launcher.json` with absolute paths for Node, Codex and `server/index.mjs`. See `config/launcher.example.json` for manual configuration. Update these paths if you move the bridge or replace the Codex executable.
6. Open the workspace, select GPT Codex and follow the steps above.

The automatic session receives its own FurniForge MCP configuration; manually registering this server in the Codex desktop app is not required for that session. It runs without a terminal window and does not open a visible desktop chat. This release's native launcher is Windows-only.

For assistant-guided MCP setup see [integrations/ASSISTANT-SETUP.md](../integrations/ASSISTANT-SETUP.md). Claude Code, Cursor and Gemini CLI remain visible as assistant choices, but automatic generation is disabled for them until their background integrations are implemented. For independent manual MCP development, `config/codex.example.toml` and `config/mcp.example.json` show stdio configuration. Set `FURNIFORGE_STATE` to the real SketchUp bridge.json path when profiles differ.

Keep bridge.json private: it contains a local connection token. The package contains no account credentials. The source and packaged extension are maintained in this repository. This is an unsigned developer package.

## Input, usage and model quality
- At least one image is required. Dimensions, product details and description are optional.
- Supplied values are preserved rather than re-estimated. Image interpretation, geometry construction and visual review still use the assistant's account usage. Blank dimensions result in approximate scale, not measured product dimensions.
- The session reads all attached references before starting a job and builds named editable parts. It is instructed to compare perspective, front and bottom previews with the reference, check visible support connections and correct obvious defects in up to three rounds. Final-revision captures from these three views are required before completion; a geometry change invalidates them. Captures do not prove the AI inspected them or that hidden connections are structurally sound. Codex tool approvals are requested when needed.
- The assistant is instructed to model the pictured product. Accuracy depends on image coverage and the assistant's modelling; exact reconstruction from a single photograph is not guaranteed. Hidden surfaces are inferred.
- Native uploads are cached under `%LOCALAPPDATA%/FurniForge/references`. These cached files remain after a request ends. The assistant receives image bytes when it calls the reference-reading tool.
- Live requests are per-model in memory. With the development candidate, choose Save draft in model and save the SKP to restore the saved fields and cached reference bindings after reopening. Images remain in the local cache; reattach missing files. Unsaved edits and active AI sessions do not resume.

## Background session boundaries
The Node supervisor launches Codex App Server in a read-only filesystem sandbox. It disables shell, apps, browser, computer-use, hooks and multi-agent features, disables other discovered MCP servers for this thread, and checks that only FurniForge exposes tools before starting the turn. Codex user configuration is loaded by App Server; the session applies scoped overrides and fails closed if isolation cannot be verified. It supplies the request ID on every MCP call; the bridge rejects calls when that request is no longer current. Stop immediately changes that ID before the process shuts down. Existing Codex sign-in is used; authentication is not copied into the package or launcher config.

A process starting or a completed conversation without a successful finish_model call is not reported as a completed model. An incomplete session shows the assistant’s final explanation when available. The UI reports Starting, Creating, Model created, Model not completed, Session failed or Session stopped based on actual events. Model created additionally requires the job's completed state. A session has a 30-minute limit. If Codex is signed out, unavailable or fails, the UI reports the error. Supported account usage and limits follow the installed Codex CLI/account.

Background automation uses the supported [Codex non-interactive mode](https://learn.chatgpt.com/docs/non-interactive-mode).

## MCP tools
| Tool | Purpose |
|---|---|
| furniforge_status | Check the local SketchUp bridge |
| furniforge_get_request | Read image IDs, optional details and request_id |
| furniforge_read_reference | Return an attached image to the assistant |
| furniforge_create_job | Start a model after reading its reference images |
| furniforge_apply_parts | Build/edit named boxes and custom triangle meshes |
| furniforge_get_job | Read geometry state and feedback |
| furniforge_capture_preview | Capture a model view |
| furniforge_finish_model | Finish modelling |

Custom geometry supports named parts, flat colours, position/rotation and triangle meshes. Limits: 20 changes and 20,000 triangles per batch, 10,000 vertices per mesh, 500 parts and 200,000 triangles per job, 2 MB per request. Five checkpoints remain available internally. Invalid batches roll back atomically. The bridge exposes no arbitrary Ruby or file-access tool. It uses a loopback socket with a random port and token; one SketchUp instance is supported. Last-caller metadata is not verified identity.

Texture mapping, commercial activation keys and background integrations for other assistants are not implemented.

## Verification
Run `npm test` for protocol/schema and supervisor tests. `tests/live-background.rb` checks multiple-image storage and description persistence in SketchUp, preserving the current request. `tests/live-background-ui.js` runs in a temporary HtmlDialog harness with captured callbacks. `tests/live-image-workflow.rb` is a historical development fixture requiring an external synthetic test image and is not part of the standalone automated test suite. Historical UI checks are archived under `tests/legacy-v0.3`.

See TEST-RESULTS.md for actual checks and limitations. Integration tests do not establish a numerical photo-matching accuracy claim.

## 0.4.2 diagnostic note
A live diagnostic on a current job added and removed a temporary box successfully through the FurniForge bridge; the existing job returned to zero parts. This proves the geometry path for a basic box, but does not prove that a full AI-generated reference model has completed. Final assistant messages and tool errors are now surfaced when the session does not complete a model.


## Approval support
The workspace displays Codex MCP tool approval requests and their parameters. Each request waits for an explicit user decision; unrelated permission requests are declined. Requests are scoped to the current modelling request and rejected if stale. **Stop session** cancels the process and revokes the active request.
