# Contributing to FurniForge

FurniForge is an early developer preview. Bug reports, documentation improvements and focused pull requests are welcome.

## Report a problem

Open a GitHub issue with the steps to reproduce the problem, what you expected, what happened, your Windows and SketchUp versions, the FurniForge package version, and the assistant and Node.js versions if relevant. Include screenshots or sanitized logs when useful. Do not post credentials, connection tokens, private reference images, or confidential model files.

## Propose a change

Open an issue first for substantial changes so the scope can be discussed. For a pull request, describe the problem, the change, and how you tested it. Keep changes focused and include any relevant documentation updates.

## Local checks

From a clean checkout with Node.js 20 or newer:

```sh
npm ci --ignore-scripts
npm test
```

SketchUp integration changes also need testing in a supported SketchUp installation. The Node tests do not replace a full modelling or installation test. If you change the extension source, rebuild and verify any distributed RBZ separately; modifying the source does not update an existing package automatically.
