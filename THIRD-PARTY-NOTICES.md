# Third-party components

FurniForge original implementation: copyright 2026 Yuan Viero Mahendra, MIT License; see LICENSE.txt.

- @modelcontextprotocol/sdk 1.32.2 — MIT, copyright Anthropic, PBC. License: licenses/MCP-SDK-LICENSE.txt.
- Zod — MIT. Installed package contains its license.
- DM Sans — SIL Open Font License 1.1. Bundled license: sketchup/furniforge/ui/DM-Sans-LICENSE.txt.
- Transitive Node dependencies: installed via package-lock.json; retain each package's included license when distributing node_modules. This source package does not redistribute node_modules.

The protocol server uses the official MCP SDK. No source from the pre-existing SketchUp MCP extension was copied. That connection was used solely to load the development extension and inspect test results.
SketchUp is a third-party product. FurniForge is an independent extension.


## Assistant brand assets — review pending

The assistant selector contains four third-party brand icons retained from the design prototype. The repository history does not identify their source, an asset license, or a permission grant. Their appearance in this repository does not establish that FurniForge has permission to distribute or use them. Product names identify compatibility and do not imply endorsement or affiliation.

| Asset | Provider guidance | Review status |
| --- | --- | --- |
| `sketchup/furniforge/ui/openai.svg` | [OpenAI design guidelines](https://openai.com/brand/) | Source and permission for this specific asset and use are not documented. |
| `sketchup/furniforge/ui/claude.svg` | [Anthropic trademark guidelines](https://www.anthropic.com/legal/trademark-guidelines) | Source and prior permission or approval are not documented. |
| `sketchup/furniforge/ui/cursor.svg` | [Cursor brand guidelines](https://cursor.com/brand) | Source and terms applicable to this specific asset and use are not documented. |
| `sketchup/furniforge/ui/googlegemini.svg` | [Google brand guidance](https://about.google/brand-resource-center/guidance/) and [brand terms](https://about.google/intl/en/brand-resource-center/brand-terms/) | Source and permission for this specific asset and use are not documented. |

The same icons may also be included in distributed RBZ files and historical Git revisions. Review the relevant provider terms and provenance before distributing those assets, or replace them with independent artwork and rebuild the packages. This inventory is not a legal determination.
