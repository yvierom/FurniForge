# Preview improvements — development branch

These source changes are a candidate, not a verified SketchUp release. The existing 0.4.2 RBZ has not been rebuilt and does not contain them.

- Assistant choices now identify Codex background availability and mark the other assistants as manual setup and unverified.
- The startup indicator no longer says the session failed while its runner is still starting; users can stop it.
- The optional **Save draft in model** action stores entered values and reference identifiers in the current SketchUp model. Save the SKP file to persist the metadata. Image bytes remain in the local FurniForge cache; missing files must be reattached, especially on another computer. This restores inputs, not an in-progress AI session. Only an explicit action saves the draft; unsaved edits are not automatically preserved.
- Dimension fields are validated separately; dimensions in free-text descriptions are not automatically checked.
- `check-setup.ps1` performs read-only local prerequisite checks; a state file alone does not confirm a live connection.

Seven existing Node tests passed against the local dependencies. Browser-preview checks passed for assistant labels, disabled generation for other assistants, image selection and browser-only save notice. Live checks on SketchUp 2026: an isolated Ruby regression passed; the installed candidate displayed assistant status and correctly reported a missing cached image. The Save draft button saved description and dimensions, which were restored after restarting SketchUp. A reference added through the extension's Ruby upload handler was also restored from the normal local cache after reopening the SKP; the file picker was not exercised in this test. A simulated slow startup remained active and cancellable. One background Codex test created a model in the test SKP after tool approvals: 42 named parts, 18,294 faces and an overall width of 1,800 mm matching the entered field. Depth and height were estimates. This is one example, not a fidelity or reliability benchmark. Clean-machine installation, repeated tests, and the other assistants remain unverified.
