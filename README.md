# FurniForge

> **Developer preview:** The [PBR development candidate](releases/FurniForge-PBR-development-candidate.rbz) adds procedural fabric and wood materials. It is unsigned and not a stable release; its internal version label still displays 0.4.2. Install it with the matching repository source and bridge. The [previous candidate](releases/FurniForge-development-candidate.rbz) and [original 0.4.2 package](releases/FurniForge-0.4.2.rbz) remain available for rollback. See [PBR materials](docs/PBR-MATERIALS.md) and [preview improvements](docs/PREVIEW-IMPROVEMENTS.md).

**Turn furniture reference images into editable SketchUp geometry, with help from your AI assistant.**

FurniForge is an early developer preview for interior designers who want to bring a pictured furniture product into their SketchUp workflow. Add one or more reference images, provide any dimensions or context you know, and let the assistant build a model directly in the open SketchUp scene.

![FurniForge logo](docs/furniforge-banner.png)

> **Developer preview · Windows · v0.4.2**  
> The current background workflow uses GPT Codex and asks for approval when needed. Model fidelity depends on the reference images and the assistant; hidden details and unknown dimensions may be estimated.

## Table of Contents

- [Original sofa reference example](#original-sofa-reference-example)
- [What you can do](#what-you-can-do)
- [Assistant support](#assistant-support)
- [Install from the repository ZIP](#install-from-the-repository-zip)
  - [GPT Codex background setup](#gpt-codex-background-setup)
  - [Claude Code, Cursor and Gemini CLI](#claude-code-cursor-and-gemini-cli)
- [MCP configuration examples](#mcp-configuration-examples)
  - [Claude Code and Cursor](#claude-code-and-cursor)
  - [Gemini CLI](#gemini-cli)
  - [GPT Codex](#gpt-codex)
- [Before you use it](#before-you-use-it)
- [Documentation](#documentation)
- [Author & License](#author--license)

## Original sofa reference example

See an [original AI-generated sofa reference and its FurniForge model](docs/SOFA-TEST.md). Dimensions and unseen details are approximate; visual similarity has not been measured.

## What you can do

- Add up to eight PNG or JPEG reference images, including multiple views.
- Provide optional product details, dimensions, material notes and a description.
- Start a GPT Codex session from FurniForge and review requested actions as it builds.
- Receive named, editable geometry directly in SketchUp and refine it there.
- Save a draft in the model and restore its details and locally cached references when reopening the saved SketchUp file.

## Assistant support

| Assistant | Current support |
| --- | --- |
| GPT Codex | Background workflow from the FurniForge panel; tested with a furniture model. |
| Claude Code | MCP setup guide available; manual assistant workflow is unverified. Background launch is not implemented. |
| Cursor | MCP setup guide available; manual assistant workflow is unverified. Background launch is not implemented. |
| Gemini CLI | MCP setup guide available; manual assistant workflow is unverified. Background launch is not implemented. |

The selected assistant requires its own account and access. AI processing uses that provider's applicable allowance or billing. FurniForge does not include an AI subscription.

## Install from the repository ZIP

1. On GitHub, select **Code → Download ZIP**, then extract it to a stable local folder. 
2. Open that folder as a project in your coding assistant. The assistant needs access to the extracted files on your computer.
3. Ask it: **“Read the FurniForge README and help me install and connect FurniForge for my assistant. Preserve my existing settings and verify the connection to SketchUp.”**
4. For the latest development preview, install [FurniForge-PBR-development-candidate.rbz](releases/FurniForge-PBR-development-candidate.rbz) in SketchUp through **Extension Manager → Install Extension**. Complete any sign-in and permission prompts yourself.
5. Start SketchUp and FurniForge. Follow the assistant-specific setup below, then verify that the bridge responds before starting a model.

**Requirements:** FurniForge has its own MCP bridge; mhyrr's SketchUp MCP connector is not required. Windows for the tested background launcher, SketchUp with the extension installed, Node.js 20+, and the selected assistant's supported access. The extension package is an unsigned developer preview. Do not move the extracted folder after configuration without updating the launcher paths.

### GPT Codex background setup

From the extracted repository folder, run `npm ci --ignore-scripts`, install and sign in to Codex CLI, then run `setup-launcher.ps1` in PowerShell. If `codex` resolves to a `.cmd` wrapper, provide the native executable with `-CodexPath`. The launcher stores local executable paths in `%LOCALAPPDATA%/FurniForge/launcher.json`; it does not include account credentials. Open **Extensions → FurniForge → Open workspace**, select GPT Codex, attach images, allow the background session, and choose **Create model**. Approve or decline each requested action in the panel.

### Claude Code, Cursor and Gemini CLI

Ask the assistant to read [Assistant setup](integrations/ASSISTANT-SETUP.md). It can help configure that assistant's MCP connection and test `furniforge_status`. This is a manual assistant workflow, not a background session initiated by the FurniForge panel. The integrations have not yet been tested end-to-end with those providers. See the [background integration brief](integrations/BACKGROUND-INTEGRATION.md) for the remaining work.

## MCP configuration examples

The bridge runs locally through Node.js. These examples are for Windows and require an extracted FurniForge repository, installed dependencies, and the FurniForge extension running in SketchUp. Replace every example path with the actual path on your computer. Merge only the `furniforge` entry into your existing configuration; preserve other settings.

### Claude Code and Cursor

For Claude Code, add the entry to the project-root `.mcp.json`. For Cursor, add it to the selected project or user `.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "furniforge": {
      "command": "C:\\Program Files\\nodejs\\node.exe",
      "args": [
        "C:\\path\\to\\FurniForge\\server\\index.mjs"
      ],
      "env": {
        "FURNIFORGE_STATE": "C:\\Users\\YOUR_USER\\AppData\\Local\\FurniForge\\bridge.json"
      }
    }
  }
}
```

### Gemini CLI

Merge the same `furniforge` entry into `.gemini/settings.json` under `mcpServers`, keeping `trust: false`. For provider-specific steps and generated configuration snippets, see [Assistant setup](integrations/ASSISTANT-SETUP.md).

### GPT Codex

For a manual MCP connection, merge this example into the appropriate Codex configuration:

```toml
[mcp_servers.furniforge]
command = 'C:\Program Files\nodejs\node.exe'
args = ['C:\path\to\FurniForge\server\index.mjs']
startup_timeout_sec = 20
tool_timeout_sec = 30

[mcp_servers.furniforge.env]
FURNIFORGE_STATE = 'C:\Users\YOUR_USER\AppData\Local\FurniForge\bridge.json'
```

The state file contains a connection token: provide its **path only**, and do not share or commit its contents. Restart or reload the assistant as needed, then verify the connection with `furniforge_status`. A configuration entry alone does not confirm a working connection. These examples configure MCP; they do not enable background launch for Claude Code, Cursor or Gemini, which remains unimplemented and unverified.

## Before you use it

- FurniForge is a preview, not a guarantee of a photo-identical or manufacturing-ready model. Hidden surfaces, proportions and material appearance may be approximated; check the result in SketchUp.
- Supplied information takes precedence. If overall dimensions are not provided, scale is approximate. Image analysis, modelling and review can still consume AI usage even when details are supplied.
- Reference files are cached locally and sent to the chosen assistant when it reads them. Use **Save draft in model** and save the SketchUp file to restore saved details and locally cached reference bindings later. Unsaved edits and active AI sessions do not resume; reattach any missing images, especially on another computer.
- Commercial activation, texture mapping, and background integrations for Claude Code, Cursor and Gemini are not implemented.

## Documentation

- [Assistant-guided MCP setup](integrations/ASSISTANT-SETUP.md)
- [Background integration development brief](integrations/BACKGROUND-INTEGRATION.md)
- [Technical details and MCP tools](docs/TECHNICAL-DETAILS.md)
- [Procedural PBR materials](docs/PBR-MATERIALS.md)
- [Test results](TEST-RESULTS.md)
- [Commercial readiness notes](docs/COMMERCIAL-READINESS.md)
- [Third-party notices](THIRD-PARTY-NOTICES.md)

## Author & License

**Created by Yuan Viero Mahendra** (yviero_m).

Copyright © 2026 Yuan Viero Mahendra.

FurniForge is a developer preview. Its original source code is licensed under the [MIT License](LICENSE.txt). The MIT license does not grant trademark rights. Third-party components and brand marks have their own terms; see [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).

---

*FurniForge — furniture modelling in SketchUp from reference images.*
