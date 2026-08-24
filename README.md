# pg5-rumbles-gitops

GitOps configuration repo for the **rumbles** service. Argo CD (running on the
hub cluster via the Amazon EKS Capability for Argo CD) watches this repo and
deploys to the `dev` and `prod` spoke clusters.

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
    analysistemplate.yaml  Health gate (web / cloudwatch / datadog), prod only
envs/
  dev/values.yaml        Fast: single canary step to 100%, no gate, 1 replica
  prod/values.yaml       Progressive: stepped canary + bake + analysis gate, 3 replicas
appprojects/             (step 3) Argo CD AppProject for the spoke workloads
applicationsets/         (step 3) ApplicationSet (cluster generator) fanning to spokes
bootstrap/               (step 3) root app-of-apps
```

## Promotion model

An immutable image is built once and promoted **by digest**. Promotion is a
commit to this repo that updates `image.digest` in the target environment's
`values.yaml`:

1. Pipeline builds image, pushes to ECR, signs it, resolves the digest.
2. Pipeline writes the digest into `envs/dev/values.yaml` and commits.
   Argo CD (dev app, auto-sync) deploys to the dev spoke.
3. After a gate passes, the same digest is written into `envs/prod/values.yaml`
   (via PR). Argo CD (prod app) deploys to the prod spoke with a canary rollout.

The Rollout object is identical across environments; only the strategy
parameters and the digest differ per env. This keeps promotion a clean values
diff rather than a change in resource kind.

## Local validation

```bash
helm lint charts/rumbles -f envs/dev/values.yaml
helm lint charts/rumbles -f envs/prod/values.yaml
helm template rumbles charts/rumbles -f envs/prod/values.yaml --namespace rumbles-prod
```
