# GitHub Actions Reusable Workflows — Workshop Guide

> **Audience:** Developers with basic GitHub Actions knowledge but limited experience with reusable workflows.
> **Format:** 6 progressive demos in a single repo, all triggered on-demand via `workflow_dispatch`.

---

## Demo 1 — Basic Reusable Workflow

### Scenario
Your team has 5 Node.js repos that all copy-paste the same CI steps. When you need to add a linting step, you have to update all 5. Let's extract the shared logic into a **reusable workflow** so changes happen in one place.

### Concept demonstrated
- `workflow_call` trigger (what makes a workflow "reusable")
- Passing **inputs** from a caller to a reusable workflow
- Calling a reusable workflow with `uses:` at the **job level** (not step level)

### File structure
```
.github/workflows/
├── demo1-reusable-build.yml   ← the reusable workflow (workflow_call)
└── demo1-ci.yml               ← the caller workflow
```

### Key YAML — `demo1-reusable-build.yml`
```yaml
on:
  workflow_call:          # ← this is what makes it reusable
    inputs:
      node-version:
        required: true
        type: string
      run-lint:
        required: false
        type: boolean
        default: true
```

### Key YAML — `demo1-ci.yml` (caller)
```yaml
on:
  workflow_dispatch:      # ← manual trigger only

jobs:
  call-build:
    uses: ./.github/workflows/demo1-reusable-build.yml   # ← job-level uses
    with:
      node-version: "20"
      run-lint: true
```

### What to demo live
1. **Open `demo1-reusable-build.yml`** — point out `workflow_call` and the `inputs:` block. Explain: "This is just a normal workflow, but the trigger is `workflow_call` instead of `push`."
2. **Open `demo1-ci.yml`** — show `uses:` at the job level. Emphasize: "Notice this is NOT a step — it's a whole job pointing to another workflow file."
3. **Go to Actions → "Demo 1: CI Pipeline" → Run workflow.** Show the run — the caller workflow appears, and the reusable workflow runs nested inside it.
4. **Show the logs** — expand the reusable workflow's steps. Point out inputs flowing through.
5. **Live edit:** Change `run-lint: false` in `demo1-ci.yml`, push, run again, show the lint step is skipped.

### Key takeaway
> A reusable workflow is triggered by `workflow_call` and called with `uses:` at the job level. Inputs let you parameterize the behavior — one workflow, many consumers.

---

## Demo 2 — Reusable Workflow with Outputs

### Scenario
You've extracted your build into a reusable workflow. Now you need downstream jobs (like deploying a preview) to know **which artifact was built** and **what version** it is. The reusable workflow needs to return data back to the caller.

### Concept demonstrated
- Workflow-level **outputs** from a reusable workflow
- Chaining outputs: `step → job → workflow → caller`
- Using `needs.<job>.outputs.<name>` in the caller
- Multi-job pipeline: build → deploy-preview

### File structure
```
.github/workflows/
├── demo2-reusable-build.yml   ← returns artifact-name + app-version
└── demo2-ci-cd.yml            ← consumes outputs in deploy-preview job
```

### Key YAML — outputs chain
```yaml
# In demo2-reusable-build.yml:
on:
  workflow_call:
    outputs:
      artifact-name:
        value: ${{ jobs.build.outputs.artifact-name }}   # workflow ← job
      app-version:
        value: ${{ jobs.build.outputs.app-version }}

jobs:
  build:
    outputs:
      artifact-name: ${{ steps.meta.outputs.artifact-name }}  # job ← step
    steps:
      - id: meta
        run: echo "artifact-name=my-build" >> "$GITHUB_OUTPUT"  # step sets it
```

```yaml
# In demo2-ci-cd.yml (caller):
jobs:
  build:
    uses: ./.github/workflows/demo2-reusable-build.yml

  deploy-preview:
    needs: build
    steps:
      - run: echo "${{ needs.build.outputs.artifact-name }}"  # caller reads it
```

### What to demo live
1. **Draw the output chain on a whiteboard** (or slide): `step → job → workflow → caller`. This is the #1 confusion point — spend time here.
2. **Open `demo2-reusable-build.yml`** — trace the output from `steps.meta` → `jobs.build.outputs` → `workflow_call.outputs`.
3. **Open `demo2-ci-cd.yml`** — show `needs.build.outputs.artifact-name` in the deploy job. Explain: "The caller sees the reusable workflow's outputs on the job it called — using the job name from the *caller*, not the reusable workflow."
4. **Go to Actions → "Demo 2: CI / CD Pipeline" → Run workflow.** Click the deploy-preview job and show the echoed artifact name and version.
5. **Show the artifact** in the Actions run summary — it was uploaded by the reusable workflow and downloaded by the caller.

### Key takeaway
> Outputs flow from **step → job → workflow → caller** via three levels of `outputs:` declarations. This lets you build real pipelines where downstream jobs react to upstream results.

---

## Demo 3 — Org-Level Workflow Template

### Scenario
Your org has 50 Node.js repos. You want every team to use the same CI pipeline — same lint rules, same test runner, same coverage upload. Instead of asking each team to write their own workflow, you provide an **org-level reusable workflow** and a **workflow template** that appears in the "Actions" tab.

### Concept demonstrated
- The special **`.github`** repository at the org level
- **Reusable workflows** stored centrally and called cross-repo
- **Workflow templates** (`workflow-templates/` directory + `.properties.json`)
- Standardization and governance across an organization

### File structure

The reusable workflow lives in a **separate repo** (`eldong/.github`). The caller stays in this repo.

```
eldong/.github (separate repo)            ← central shared repo
├── .github/workflows/
│   └── demo3-reusable-ci.yml             ← reusable workflow (shared logic)
└── workflow-templates/                   ← org-only feature (requires GitHub org)
    ├── node-ci.yml                       ← template starter file
    └── node-ci.properties.json           ← metadata for the picker

this repo:
.github/workflows/
├── demo3-ci.yml                          ← caller (cross-repo reference)
└── demo3-reusable-ci.yml                 ← local copy for reference
```

> **Note:** Workflow templates (the "New workflow" picker) require a **GitHub Organization**. Under a personal account, only the cross-repo reusable workflow call works.

### Key YAML — cross-repo call
```yaml
# demo3-ci.yml — calls the reusable workflow from a different repo
on:
  workflow_dispatch:

jobs:
  ci:
    uses: eldong/.github/.github/workflows/demo3-reusable-ci.yml@main
    with:
      node-version: "20"
      enable-coverage: true
```

### Key YAML — workflow template (org-only)
```yaml
# workflow-templates/node-ci.yml — what new repos get when they click "Use this template"
name: Standard Node.js CI
on:
  push:
    branches: [$default-branch]      # ← GitHub replaces this automatically

jobs:
  ci:
    uses: eldong/.github/.github/workflows/demo3-reusable-ci.yml@main
    with:
      node-version: "20"
```

```json
// workflow-templates/node-ci.properties.json
{
  "name": "Standard Node.js CI",
  "description": "Org-standard CI for Node.js — calls the shared reusable workflow.",
  "categories": ["Node.js", "CI"]
}
```

### What to demo live
1. **Show the `eldong/.github` repo** — explain its special role (central reusable workflows, templates).
2. **Open `demo3-reusable-ci.yml`** — show how it's a complete, production-quality CI with sensible defaults and optional inputs like `enable-coverage`.
3. **Switch to this repo and open `demo3-ci.yml`** — show the cross-repo `uses:` reference. Say: "This is ALL a consuming repo needs — everything else is inherited from the central repo."
4. **Go to Actions → "Demo 3: CI (org consumer)" → Run workflow.** Show the reusable workflow running from the other repo.
5. **Highlight the governance angle:** "If we update the linting tool, we change one file in the `.github` repo. All consuming repos get the update on their next run — zero PRs needed."
6. *(Optional, if using a GitHub org)* **Show the workflow template picker** — go to another repo in the org → Actions → "New workflow" and point out the template.

### Key takeaway
> A central repo (typically `.github`) is your org's control plane for CI/CD. Any repo can call its reusable workflows cross-repo. With a GitHub org, workflow templates make them discoverable in the UI. Consuming repos write a few lines — you maintain the standard.

---

## Demo 4 — Advanced: Multi-Environment Pipeline with Matrix & Secrets

### Scenario
You're shipping to production. The pipeline needs to: build across multiple Node versions (matrix), deploy through dev → staging → production, pass secrets per environment, and require manual approval before production.

### Concepts demonstrated
- **Matrix strategy** inside a reusable workflow (parameterized via JSON input)
- **Secrets handling** — passing named secrets to reusable workflows
- **Environment protection rules** — approval gates on the `production` environment
- **Conditional execution** — `if:` to skip stages (`skip-staging`)
- **`workflow_dispatch`** — manual trigger with custom inputs
- **Composing multiple reusable workflows** in one pipeline

### File structure
```
.github/workflows/
├── demo4-reusable-build.yml    ← matrix build across Node versions
├── demo4-reusable-deploy.yml   ← deploy to any environment (parameterized)
└── demo4-pipeline.yml          ← orchestrator: build → dev → staging → prod
```

### Key YAML — matrix input
```yaml
# reusable-build.yml
on:
  workflow_call:
    inputs:
      node-versions:
        type: string
        default: '["20"]'          # JSON array as a string

jobs:
  build:
    strategy:
      matrix:
        node-version: ${{ fromJson(inputs.node-versions) }}   # ← dynamic matrix
```

### Key YAML — secrets + environments
```yaml
# reusable-deploy.yml
on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
    secrets:
      DEPLOY_TOKEN:
        required: true

jobs:
  deploy:
    environment:
      name: ${{ inputs.environment }}    # ← GitHub applies protection rules
      url: "https://${{ inputs.environment }}.example.com"
    steps:
      - run: echo "Deploying with token ${#DEPLOY_TOKEN} chars"
        env:
          DEPLOY_TOKEN: ${{ secrets.DEPLOY_TOKEN }}
```

### Key YAML — pipeline orchestration
```yaml
# pipeline.yml
on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      skip-staging:
        type: boolean
        default: false

jobs:
  build:
    uses: ./.github/workflows/reusable-build.yml
    with:
      node-versions: '["18", "20"]'

  deploy-dev:
    needs: build
    uses: ./.github/workflows/reusable-deploy.yml
    with:
      environment: dev
      artifact-name: ${{ needs.build.outputs.artifact-name }}
      app-version: ${{ needs.build.outputs.app-version }}
    secrets:
      DEPLOY_TOKEN: ${{ secrets.DEV_DEPLOY_TOKEN }}

  deploy-staging:
    needs: [build, deploy-dev]
    if: ${{ !(inputs.skip-staging) }}       # ← conditional stage
    uses: ./.github/workflows/reusable-deploy.yml
    # ...

  deploy-production:
    needs: [build, deploy-dev, deploy-staging]
    uses: ./.github/workflows/reusable-deploy.yml
    with:
      environment: production              # ← triggers approval gate
    secrets:
      DEPLOY_TOKEN: ${{ secrets.PROD_DEPLOY_TOKEN }}
```

### What to demo live
1. **Go to Actions → "Demo 4: Build & Deploy Pipeline" → Run workflow.** Point out the visual DAG: build → dev → staging → production.
2. **Expand the build job** — show the matrix running Node 18 and 20 in parallel. Explain `fromJson()` converting the string input into a real matrix.
3. **Show secrets handling** — open `demo4-reusable-deploy.yml` and point to the `secrets:` block. Explain: "Each environment gets its own secret. The caller passes the right one for each stage."
4. **Show the production approval** — the pipeline pauses at `deploy-production` because the `production` environment has a required reviewer. Click "Review deployments" to approve live.
5. **Run again with "skip-staging" checked** — show how the staging job gets a "skipped" status.
6. **Zoom out:** "We have 3 YAML files, 0 duplication, and a full build→deploy pipeline with matrix, secrets, and approval gates."

### Key takeaway
> Reusable workflows compose like building blocks. Combine matrix builds, per-environment secrets, protection rules, and conditional logic to create production-grade pipelines with minimal YAML per repo.

---

## Demo 5 — Dependency & Build Caching

### Scenario
Your CI pipeline reinstalls dependencies and rebuilds from scratch on every run — even when nothing changed. This wastes time and runner minutes. Let's add **caching** to the reusable workflow to skip redundant work.

### Concepts demonstrated
- **Built-in cache** via `setup-node` with `cache: npm` (one-line dependency caching)
- **Manual cache** via `actions/cache` for build output (`dist/`)
- **Cache keys** using `hashFiles()` to invalidate when dependencies change
- **Conditional step execution** — skip `npm run build` when cache hits
- **`$GITHUB_STEP_SUMMARY`** — writing a cache report to the run summary

### File structure
```
.github/workflows/
├── demo5-reusable-build-cached.yml   ← reusable workflow with two cache strategies
└── demo5-ci-cached.yml               ← caller with cache report
```

### Key YAML — built-in dependency cache
```yaml
- name: Setup Node.js (with npm cache)
  uses: actions/setup-node@v4
  with:
    node-version: ${{ inputs.node-version }}
    cache: npm                              # ← one line, done
```

### Key YAML — manual build output cache
```yaml
- name: Cache build output
  id: build-cache
  uses: actions/cache@v4
  with:
    path: dist/
    key: build-${{ runner.os }}-${{ hashFiles('package.json', 'package-lock.json') }}

- name: Build (skip if cached)
  if: steps.build-cache.outputs.cache-hit != 'true'    # ← conditional!
  run: npm run build
```

### Key YAML — cache report in step summary
```yaml
- name: Cache summary
  run: |
    echo "## Cache Report" >> "$GITHUB_STEP_SUMMARY"
    echo "| Cache | Hit? |" >> "$GITHUB_STEP_SUMMARY"
    echo "|-------|------|" >> "$GITHUB_STEP_SUMMARY"
    echo "| npm dependencies | ${{ needs.build.outputs.cache-hit-deps }} |" >> "$GITHUB_STEP_SUMMARY"
    echo "| Build output | ${{ needs.build.outputs.cache-hit-build }} |" >> "$GITHUB_STEP_SUMMARY"
```

### What to demo live
1. **Go to Actions → "Demo 5: CI with Caching" → Run workflow.** First run — both caches miss. Note the run time.
2. **Run it again immediately** (no code changes). Both caches hit — the build step is skipped entirely. Compare the run times.
3. **Click the run summary** — show the cache report table written via `$GITHUB_STEP_SUMMARY`.
4. **Open `demo5-reusable-build-cached.yml`** — point out the two strategies: one-line `cache: npm` vs. explicit `actions/cache` with `hashFiles()`.
5. **Run again with "Enable build output caching" unchecked** — show the build runs again even though deps are cached.
6. **Key point:** "Caching inputs you pass to `actions/cache` via `key:` — when the key changes (e.g., new dependencies), the cache misses and rebuilds automatically."

### Key takeaway
> Use `setup-node`'s built-in `cache` for dependencies (one line). Use `actions/cache` with `hashFiles()` for custom outputs like build artifacts. Conditional steps (`if: cache-hit != 'true'`) let you skip expensive work entirely.

---

## Demo 6 — Composite Actions (Step-Level Reuse)

### Scenario
You have a group of steps — setup Node, install deps, build, verify output — that you repeat across multiple jobs in the same workflow. A reusable workflow is overkill (you don't need a separate job/runner). You want to bundle steps together and call them as a single `uses:` at the **step level**.

### Concepts demonstrated
- **Composite actions** (`runs: using: "composite"`) — step-level reuse vs. job-level
- Composite action **inputs and outputs**
- Local action path (`uses: ./.github/actions/<name>`)
- Explicit `shell:` requirement in composite steps
- How composite steps expand inline in the caller's job logs

### File structure
```
.github/
├── actions/
│   └── setup-build/
│       └── action.yml              ← the composite action
└── workflows/
    └── demo6-composite-action.yml  ← caller workflow
```

### Key YAML — composite action (`action.yml`)
```yaml
name: "Setup, Build & Report"
description: "Sets up Node, installs, builds, and verifies output"

inputs:
  node-version:
    required: false
    default: "20"

outputs:
  build-time:
    description: "How long the build took"
    value: ${{ steps.timer.outputs.duration }}

runs:
  using: "composite"               # ← this makes it a composite action
  steps:
    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: ${{ inputs.node-version }}

    - name: Install dependencies
      shell: bash                   # ← required for every run step!
      run: npm install

    - name: Build (timed)
      id: timer
      shell: bash
      run: |
        START=$(date +%s)
        npm run build
        DURATION=$(( $(date +%s) - START ))
        echo "duration=${DURATION}" >> "$GITHUB_OUTPUT"
```

### Key YAML — caller workflow
```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup, build & report
        id: build
        uses: ./.github/actions/setup-build    # ← step-level, not job-level!
        with:
          node-version: "20"

      - name: Use the output
        run: echo "Build took ${{ steps.build.outputs.build-time }}s"
```

### Reusable Workflow vs. Composite Action

| | Reusable Workflow | Composite Action |
|---|---|---|
| Called at | **Job** level (`jobs: { x: { uses: } }`) | **Step** level (`steps: [{ uses: }]`) |
| Gets its own runner | Yes | No (shares caller's job) |
| Can contain jobs | Yes | No (steps only) |
| Shares workspace | No (separate job) | Yes (same job, same filesystem) |
| Where it lives | `.github/workflows/*.yml` | Any dir with `action.yml` |
| Cross-repo | `owner/repo/.github/workflows/x.yml@ref` | `owner/repo/path@ref` |

### What to demo live
1. **Open `.github/actions/setup-build/action.yml`** — point out `runs: using: "composite"`. Explain: "This is NOT a workflow — it's an action. It bundles steps, not jobs."
2. **Highlight `shell: bash`** on every `run:` step. Explain: "Unlike workflows, composite actions require an explicit shell. This is the #1 gotcha."
3. **Open `demo6-composite-action.yml`** — show `uses: ./.github/actions/setup-build` at the step level. Contrast with Demo 1 where `uses:` was at the job level.
4. **Go to Actions → "Demo 6: CI with Composite Action" → Run workflow.**
5. **Expand the job logs** — show all the composite action's steps appear inline in the same job (no separate job created). Point out: "Same runner, same workspace, same job."
6. **Show the output** — `steps.build.outputs.build-time` flows directly to subsequent steps without the three-level output chain needed for reusable workflows.
7. **Key point:** "Use composite actions when you want to share *steps within a job*. Use reusable workflows when you want to share *entire jobs*."  

### Key takeaway
> Composite actions are step-level building blocks — they run inside the caller's job, share its workspace, and expose outputs directly to sibling steps. Use them for bundling related steps; use reusable workflows for encapsulating entire jobs.

---

## Quick Reference

| Concept | Where it's shown | Key syntax |
|---|---|---|
| `workflow_call` trigger | Demo 1 | `on: workflow_call:` |
| `workflow_dispatch` | All callers | `on: workflow_dispatch:` |
| Inputs | Demo 1, 2, 3, 4, 5, 6 | `inputs: { name: { type: string } }` |
| Outputs (step→job→workflow→caller) | Demo 2, 5 | `outputs:` at 3 levels |
| Cross-repo reusable workflow | Demo 3 | `uses: owner/repo/.github/workflows/x.yml@main` |
| Workflow templates (org-only) | Demo 3 | `workflow-templates/` + `.properties.json` |
| Matrix via input | Demo 4 | `fromJson(inputs.node-versions)` |
| Secrets passing | Demo 4 | `secrets: { DEPLOY_TOKEN: ... }` |
| Environment gates | Demo 4 | `environment: { name: production }` |
| Conditional execution | Demo 4, 5 | `if: ${{ !(inputs.skip-staging) }}` |
| Dependency cache (built-in) | Demo 5 | `setup-node` with `cache: npm` |
| Build output cache (manual) | Demo 5 | `actions/cache` with `hashFiles()` |
| Step summary | Demo 5, 6 | `$GITHUB_STEP_SUMMARY` |
| Composite action | Demo 6 | `runs: using: "composite"` in `action.yml` |
| Local action path | Demo 6 | `uses: ./.github/actions/<name>` |

## Setup Checklist (Before the Workshop)

- [ ] Push all workflow files to the `master` branch of `eldong/reusabletemplates`
- [ ] For Demo 3: push `demo3-reusable-ci.yml` to `eldong/.github` repo at `.github/workflows/`
- [ ] For Demo 3 (org-only): add `workflow-templates/node-ci.yml` + `node-ci.properties.json` to `.github` repo
- [ ] For Demo 4: configure GitHub environments (`dev`, `staging`, `production`) with `production` requiring a reviewer
- [ ] For Demo 4: add repository secrets: `DEV_DEPLOY_TOKEN`, `STAGING_DEPLOY_TOKEN`, `PROD_DEPLOY_TOKEN` (values don't matter — use `dummy-token`)
- [ ] Pre-run Demo 5 once to warm up caches (second run shows cache hit)
- [ ] Have the Actions tab open in a browser, ready to click "Run workflow" per demo
