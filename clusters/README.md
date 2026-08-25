# Cluster registration (step 4)

This folder holds the Argo CD **cluster registration secrets** for the two spoke
clusters. They tell Argo CD (running on the hub via the EKS Capability) that the
spokes exist and how to reach them.

| Cluster | Role | ARN |
|---|---|---|
| `hub-cluster`  | Hub (runs Argo CD Capability) | `arn:aws:eks:eu-north-1:849445096948:cluster/hub-cluster` |
| `dev-cluster`  | Spoke (dev workloads)  | `arn:aws:eks:eu-north-1:849445096948:cluster/dev-cluster` |
| `qa-cluster`   | Spoke (qa workloads)   | `arn:aws:eks:eu-north-1:849445096948:cluster/qa-cluster` |

## Two things are required per spoke

Registering a spoke has **two halves** — miss either and deployment fails:

1. **Cluster secret (this folder)** — tells Argo CD the spoke exists. Applied to
   the hub's `argocd` namespace. Uses the EKS cluster **ARN** as `server` (the
   managed capability convention), and carries the labels the ApplicationSet
   selects on: `app: rumbles` and `env: dev|qa`.

2. **EKS Access Entry (AWS side)** — the spoke must grant the **Argo CD Capability
   IAM role** permission to act on its Kubernetes API. Without this, Argo CD can
   see the cluster but cannot deploy to it.

## Prerequisites

- The hub cluster has the EKS Capability for Argo CD enabled.
- The **Argo CD Capability IAM role** on the hub is:
  `arn:aws:iam::849445096948:role/AmazonEKSCapabilityArgoCDRole`

## Commands

> These touch AWS and the clusters. Run them yourself; review each before applying.

### 1. Grant each spoke an EKS Access Entry for the Argo CD role

```bash
ARGOCD_ROLE_ARN="arn:aws:iam::849445096948:role/AmazonEKSCapabilityArgoCDRole"
REGION=eu-north-1

for CLUSTER in dev-cluster qa-cluster; do
  # Create the access entry for the Argo CD Capability role.
  aws eks create-access-entry \
    --region "$REGION" \
    --cluster-name "$CLUSTER" \
    --principal-arn "$ARGOCD_ROLE_ARN"

  # Associate an access policy. AmazonEKSClusterAdminPolicy is used here for the
  # walkthrough; in production, scope this down to a least-privilege custom policy.
  aws eks associate-access-policy \
    --region "$REGION" \
    --cluster-name "$CLUSTER" \
    --principal-arn "$ARGOCD_ROLE_ARN" \
    --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
    --access-scope type=cluster
done
```

### 2. Register the spokes with Argo CD (apply the secrets to the hub)

```bash
# Point kubectl at the hub cluster first.
aws eks update-kubeconfig --region eu-north-1 --name hub-cluster

kubectl apply -n argocd -f clusters/dev-cluster.yaml
kubectl apply -n argocd -f clusters/qa-cluster.yaml
```

### 3. Verify Argo CD sees the clusters

```bash
kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=cluster \
  -o custom-columns='NAME:.metadata.name,APP:.metadata.labels.app,ENV:.metadata.labels.env'
```

You should see `dev-cluster` and `qa-cluster`, both labelled `app=rumbles`
with `env=dev` / `env=qa`. At that point the `rumbles` ApplicationSet will
generate `rumbles-dev-cluster` and `rumbles-qa-cluster` automatically.

## Security note

`AmazonEKSClusterAdminPolicy` is broad. For production, replace it with a custom
access policy granting only the namespaces/verbs Argo CD needs on the spokes,
per the AWS guidance on least-privilege spoke access.
