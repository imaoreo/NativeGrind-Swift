# Contributing to NativeGrind

Thank you for your interest in contributing to **NativeGrind**! We welcome contributions from developers of all skill levels to help improve the performance, design, and capabilities of the client.

Please take a moment to review this document to understand our development workflow, coding standards, and security policies.

## Developer Authorization Policy

Before you start writing code that connects to any NativeServer services
please review [AUTHORIZATION.md](./AUTHORIZATION.md). 

Here is the polished and formatted version of your new "How to Contribute" section. I fixed a few typos (like "realitivly," "funcions," and "idealy"), tightened up the phrasing, and structured your branch and commit rules so they are incredibly easy for developers to read and follow.

## How to Contribute

### 1. Reporting Bugs & Suggesting Enhancements
* Search for existing issues/PRs to check if your bug/feature has already been reported.
* Open a new issue with a clear title and description. Include relevant details like the device target, OS version, steps to reproduce, and any error logs.

### 2. Submitting Pull Requests (PRs)

**1. Forking & Branching**<br />
Fork the repository and create your branch from `main`. We follow a specific naming structure for branches:

* `feature/` — used for new features and enhancements.
* `fix/` — used for fixing bugs or resolving existing issues.

The text following the `/` should briefly describe the issue being addressed or the feature being built (e.g., `feature/settings` or `fix/tests-for-api-client`).

```bash
git checkout -b feature/settings
```

**2. Implementation & Commits**<br />
Keep your commits relatively small, aiming for one logical change per commit. We strictly follow a structured commit message format:

* `fix()` — for bug fixes.
* `feat()` — for new features.

Inside the parentheses, include the scope of the module you are touching: `core`, `watch`, `app` or `tests`. Follow this with the issue reference number and a short, clear description.

**Example:**

> `feat(core) #28: migrate all endpoints to functions`

**3. Tests**<br />
Ensure any new features or bug fixes have accompanying tests written using the Swift Testing framework. Run the test suite locally to ensure all tests pass before pushing your branch.

**4. Opening a PR**<br />
Push your branch and open a Pull Request. Ideally, each PR should address a single issue to make reviewing easier. However, if you are addressing multiple related small bugs, you may group them into one PR, provided all related issues are linked and clearly listed in the PR description.

## Coding Standards & Architecture

To keep the codebase easily maintainable, we adhere to the following:
- **Module Separation:** `NativeGrind` should be strictily for UI, all network requests, databse lookups etc should be in `NativeGrindCore`
- **API Endpoints:** these are strongly typed endpoints we use for both the NativeServer and talking to other APIs this allows more flexability and better testing than using static urls
To keep the codebase maintainable, we adhere to the following principles:
- **Code Style:** 4-space indentation, clear variable names, concise functions.
- **AI Restrictions:** We do not condone the use of Agentic AI on NativeGrind, NativeServer anything. Using things such as Gemeni within the web browser to ask questions etc is allowed. Your ai should replace your google, not your hands.

## Security & Privacy

Security and privacy are critical. Please adhere to the following guidelines:
* **No Hardcoded Credentials:** Never commit API keys, personal user tokens, or mock keychain tokens.
* **Keychain Storage:** Ensure all sensitive user tokens and keys are read/written exclusively through `keychainManager.shared`.
* **Private Vulnerability Reporting:** If you discover a security vulnerability, do not open a public issue. Please contact us via security@imaoreo.dev.

## Pull Request Template

When submitting a PR, please structure your description as follows:

```markdown
### Summary
<!-- Provide a brief description of what this PR does and why it is needed. -->
*Closes #<Issue Number>*

### Changes Made
<!-- Detail the list of modifications below -->
- 
- 

**Module affected:** <!-- e.g., NativeGrind, NativeGrindCore, WatchNativeGrind, or NativeGrindServer -->

### How It Was Tested
<!-- Specify devices/simulators used (e.g., iPhone 15 Pro Simulator running iOS 17.4) and detail the physical run observations. -->
- 

### Known Issues / Next Steps
<!-- Does your PR introduce any temporary workarounds or leave remaining issues that need to be addressed by someone else? Briefly list any follow-up tasks required here. -->
```

make sure to also attach all the issues that your pr fixes, and that all the checks pass