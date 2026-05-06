# GitHub Actions Reusable Workflows — Workshop Guide

> **Audience:** Developers with basic GitHub Actions knowledge but limited experience with reusable workflows.
> **Format:** 4 progressive demos, each building on the previous.

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
demo1-basic-reusable/
├── .github/workflows/
│   ├── reusable-build.yml   ← the reusable workflow (workflow_call)
│   └── ci.yml               ← the caller workflow
└── package.json
```

### Key YAML — `reusable-build.yml`
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

### Key YAML — `ci.yml` (caller)
```yaml
jobs:
  call-build:
    uses: ./.github/workflows/reusable-build.yml   # ← job-level uses
    with:
      node-version: "20"
      run-lint: true
```

### What to demo live
1. **Open `reusable-build.yml`** — point out `workflow_call` and the `inputs:` block. Explain: "This is just a normal workflow, but the trigger is `workflow_call` instead of `push`."
2. **Open `ci.yml`** — show `uses:` at the job level. Emphasize: "Notice this is NOT a step — it's a whole job pointing to another workflow file."
3. **Push a commit** and open the Actions tab. Show the run — the caller workflow appears, and the reusable workflow runs nested inside it.
4. **Show the logs** — expand the reusable workflow's steps. Point out inputs flowing through.
5. **Live edit:** Change `run-lint: false` in `ci.yml`, push, show the lint step is skipped.

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
demo2-outputs/
├── .github/workflows/
│   ├── reusable-build.yml   ← returns artifact-name + app-version
│   └── ci-cd.yml            ← consumes outputs in deploy-preview job
└── package.json
```

### Key YAML — outputs chain
```yaml
# In reusable-build.yml:
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
# In ci-cd.yml (caller):
jobs:
  build:
    uses: ./.github/workflows/reusable-build.yml

  deploy-preview:
    needs: build
    steps:
      - run: echo "${{ needs.build.outputs.artifact-name }}"  # caller reads it
```

### What to demo live
1. **Draw the output chain on a whiteboard** (or slide): `step → job → workflow → caller`. This is the #1 confusion point — spend time here.
2. **Open `reusable-build.yml`** — trace the output from `steps.meta` → `jobs.build.outputs` → `workflow_call.outputs`.
3. **Open `ci-cd.yml`** — show `needs.build.outputs.artifact-name` in the deploy job. Explain: "The caller sees the reusable workflow's outputs on the job it called."
4. **Push and run.** In the Actions tab, click the deploy-preview job and show the echoed artifact name and version.
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
```
my-org/.github/                         ← the special .github repo
├── .github/workflows/
│   └── node-ci.yml                     ← reusable workflow (shared logic)
└── workflow-templates/
    ├── node-ci.yml                     ← template (starter file for new repos)
    └── node-ci.properties.json         ← metadata (name, icon, categories)

my-org/team-service/                    ← any consumer repo
└── .github/workflows/
    └── ci.yml                          ← 6-line file calling the org workflow
```

### Key YAML — workflow template
```yaml
# workflow-templates/node-ci.yml — what new repos get when they click "Use this template"
name: Standard Node.js CI
on:
  push:
    branches: [$default-branch]      # ← GitHub replaces this automatically

jobs:
  ci:
    uses: my-org/.github/.github/workflows/node-ci.yml@main
    with:
      node-version: "20"
```

```json
// workflow-templates/node-ci.properties.json
{
  "name": "Standard Node.js CI",
  "description": "Org-standard CI pipeline for Node.js projects.",
  "categories": ["Node.js", "CI"]
}
```

### Key YAML — consumer repo
```yaml
# team-service/.github/workflows/ci.yml — the ENTIRE CI config for a team
jobs:
  ci:
    uses: my-org/.github/.github/workflows/node-ci.yml@main
    with:
      node-version: "20"
      enable-coverage: true
```

### What to demo live
1. **Show the `.github` repo** in the org — explain its special role (profile, reusable workflows, templates).
2. **Open `node-ci.yml` (reusable)** — show how it's a complete, production-quality CI with sensible defaults and optional inputs like `enable-coverage`.
3. **Open the workflow template** — show the `$default-branch` variable and the `.properties.json` file. Explain: "This is what appears in the Actions tab when a team clicks 'New workflow'."
4. **Switch to the consumer repo** — show the 6-line `ci.yml`. Say: "This is ALL a team needs to write. Everything else is inherited."
5. **Highlight the governance angle:** "If we need to update the linting tool, we change `node-ci.yml` in the `.github` repo. All 50 repos get the update on their next run — zero PRs needed."

### Key takeaway
> The `.github` repo is your org's control plane for CI/CD. Reusable workflows provide shared logic; workflow templates make them discoverable. Teams write 6 lines — you maintain the standard.

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
demo4-advanced/
├── .github/workflows/
│   ├── reusable-build.yml    ← matrix build across Node versions
│   ├── reusable-deploy.yml   ← deploy to any environment (parameterized)
│   └── pipeline.yml          ← orchestrator: build → dev → staging → prod
└── package.json
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
1. **Show the pipeline graph** — push to `main` and open the Actions tab. Point out the visual DAG: build → dev → staging → production.
2. **Expand the build job** — show the matrix running Node 18 and 20 in parallel. Explain `fromJson()` converting the string input into a real matrix.
3. **Show secrets handling** — open `reusable-deploy.yml` and point to the `secrets:` block. Explain: "Each environment gets its own secret. The caller passes the right one for each stage."
4. **Show the production approval** — the pipeline pauses at `deploy-production` because the `production` environment has a required reviewer. Click "Review deployments" to approve live.
5. **Demo `workflow_dispatch`** — go to Actions → "Run workflow" → check "skip-staging". Show how the staging job gets a "skipped" status.
6. **Zoom out:** "We have 3 YAML files, 0 duplication, and a full build→deploy pipeline with matrix, secrets, and approval gates."

### Key takeaway
> Reusable workflows compose like building blocks. Combine matrix builds, per-environment secrets, protection rules, and conditional logic to create production-grade pipelines with minimal YAML per repo.

---

## Quick Reference

| Concept | Where it's shown | Key syntax |
|---|---|---|
| `workflow_call` trigger | Demo 1 | `on: workflow_call:` |
| Inputs | Demo 1, 2, 3, 4 | `inputs: { name: { type: string } }` |
| Outputs (step→job→workflow→caller) | Demo 2 | `outputs:` at 3 levels |
| Org `.github` repo | Demo 3 | `uses: org/.github/.github/workflows/x.yml@main` |
| Workflow templates | Demo 3 | `workflow-templates/` + `.properties.json` |
| Matrix via input | Demo 4 | `fromJson(inputs.node-versions)` |
| Secrets passing | Demo 4 | `secrets: { DEPLOY_TOKEN: ... }` |
| Environment gates | Demo 4 | `environment: { name: production }` |
| Conditional execution | Demo 4 | `if: ${{ !(inputs.skip-staging) }}` |
| `workflow_dispatch` | Demo 4 | Manual trigger with typed inputs |

## Setup Checklist (Before the Workshop)

- [ ] Create 4 repos (or branches) — one per demo
- [ ] For Demo 3: create an org-level `.github` repo with the reusable workflow and template
- [ ] For Demo 4: configure GitHub environments (`dev`, `staging`, `production`) with `production` requiring a reviewer
- [ ] For Demo 4: add repository secrets: `DEV_DEPLOY_TOKEN`, `STAGING_DEPLOY_TOKEN`, `PROD_DEPLOY_TOKEN` (values don't matter — use `dummy-token`)
- [ ] Pre-run each demo once to verify everything works and cache dependencies
- [ ] Have the Actions tab open in a browser tab per demo for quick switching
