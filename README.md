# pg5-rumbles-gitops

GitOps configuration repo for the **rumbles** service. Argo CD (running on the
hub cluster via the Amazon EKS Capability for Argo CD) watches this repo and
deploys to the `dev` and `qa` spoke clusters.

The application source lives in the separate
[`pg5-rumbles-app`](https://github.com/devanshpoplii/pg5-rumbles-app) repo.
This repo never contains application code — only deployment configuration.

## Layout

```
charts/rumbles/          Helm chart (Argo Rollouts based)
  Chart.yaml
  values.yaml            Chart defaults
  templates/
    rollout.yaml         Rollout (NOT Deployment) — same object type in every env
    service.yaml
    analysistemplate.yaml  Health gate (web / cloudwatch / datadog), qa only
envs/
  dev/values.yaml        Fast: single canary step to 100%, no gate, 1 replica
  qa/values.yaml         Progressive: stepped canary + bake + analysis gate, 3 replicas
bootstrap/               Argo CD control plane (app-of-apps)
  root-app.yaml          Root Application: apply once on the hub; syncs bootstrap/apps
  apps/
    spoke-workloads.yaml AppProject: security boundary + ci-pipeline token role
    rumbles-appset.yaml  ApplicationSet: cluster generator fanning to dev + qa spokes
```

## Control plane (bootstrap)

Apply `bootstrap/root-app.yaml` once on the hub cluster. It is an app-of-apps
that syncs everything under `bootstrap/apps/` via Argo CD directory recursion,
which brings up:

- **AppProject `spoke-workloads`** — restricts which repo, clusters, namespaces,
  and resource kinds Applications may use, and defines a least-privilege
  `ci-pipeline` token role for the promotion pipeline.
- **ApplicationSet `rumbles`** — a cluster generator that creates one Argo CD
  Application per registered spoke cluster labelled `app: rumbles`. Each cluster's
  `env` label (`dev`/`qa`) selects the matching `envs/<env>/values.yaml` and the
  sync policy (dev auto-syncs; qa is manual — the promotion gate).

## Promotion model

An immutable image is built once and promoted **by digest**. Promotion is a
commit to this repo that updates `image.digest` in the target environment's
`values.yaml`:

1. Pipeline builds image, pushes to ECR, signs it, resolves the digest.
2. Pipeline writes the digest into `envs/dev/values.yaml` and commits.
   Argo CD (dev app, auto-sync) deploys to the dev spoke.
3. After a gate passes, the same digest is written into `envs/qa/values.yaml`
   (via PR). Argo CD (qa app) deploys to the qa spoke with a canary rollout.

The Rollout object is identical across environments; only the strategy
parameters and the digest differ per env. This keeps promotion a clean values
diff rather than a change in resource kind.

## Local validation

```bash
helm lint charts/rumbles -f envs/dev/values.yaml
helm lint charts/rumbles -f envs/qa/values.yaml
helm template rumbles charts/rumbles -f envs/qa/values.yaml --namespace rumbles
```
