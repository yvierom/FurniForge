# Preview improvements — development branch

These source changes are a candidate, not a verified SketchUp release. The existing 0.4.2 RBZ has not been rebuilt and does not contain them.

- Assistant choices now identify Codex background availability and mark the other assistants as manual setup and unverified.
- The startup indicator no longer says the session failed while its runner is still starting; users can stop it.
- The optional **Save draft in model** action stores entered values and reference identifiers in the current SketchUp model. Save the SKP file to persist the metadata. Image bytes remain in the local FurniForge cache; missing files must be reattached, especially on another computer. This restores inputs, not an in-progress AI session. Only an explicit action saves the draft; unsaved edits are not automatically preserved.
- Dimension fields are validated separately; dimensions in free-text descriptions are not automatically checked.
- `check-setup.ps1` performs read-only local prerequisite checks; a state file alone does not confirm a live connection.

Seven existing Node tests passed against the local dependencies. Browser-preview checks passed for assistant labels, disabled generation for other assistants, image selection and browser-only save notice. An isolated Ruby regression passed in SketchUp. The candidate draft methods saved a real test SKP and restored its description, dimension and cached image after reopening; missing-reference detection also passed. These checks used the draft methods in an isolated module, not the packaged extension's UI. The candidate UI, startup timeout and real end-to-end Codex modelling still require testing before release.
