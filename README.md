# k8s-vdefend-layered

Layered Kubernetes network security for the **music-store** app on a VKS cluster, combining
**VMware vDefend DFW** (NSX, pushed into the cluster as Antrea ClusterNetworkPolicies) with
**native Antrea policies** owned by the application and platform teams.

Each team owns one layer, works in its own tool, and cannot accidentally override another team's intent.

## The layers at a glance

| # | Layer | Persona | Tool | Antrea tier (priority) | Source in this repo |
|---|-------|---------|------|------------------------|---------------------|
| 1 | **Security guardrails** | Security / SecOps team | vDefend DFW (NSX Manager, Terraform) | `nsx-category-application` (4) | `main.tf` |
| 2 | **App microsegmentation** | Application team | `kubectl` / GitOps | `application` (250) | `k8s/app-svc-to-svc.yaml` |
| 3 | **Default deny** | Platform team | `kubectl` / GitOps | `baseline` (253) | `k8s/baseline-default-deny.yaml` |

## Quickstart - To deploy

1. Infrastructure team provisions vSphere Namespace (TF)
2. Infra team creates Antrea Addonconfig to automatically integrate Antrea CNI to NSX for VKS Clusters in this namespace (TF - Addons)
3. Infrastructure team provisions VKS Cluster (TF)
5. Platform team creates music-store K8s Namespace on the VKS cluster. (TF)
   ```bash
   k config use-context vks-cluster-context
   k create ns music-store
   ```
7. Infra team applies Infra Security Guardrail policies controlling traffic into and out of the music-store K8s Namespace. This will get turned into Antrea Cluster Network Policy (ACNP) (TF)
```bash
git clone https://github.com/NiranEC77/tf4-metal-music-store.git
```
9. Platform Team managing Kubernetes creates Baseline default deny catchall ACNP rule (./k8s/baseline-default-deny.yaml) (kubectl or Gitops)
10. Application Team deploys their metal-music Application via kubectl or Gitops NOTE: Application will not fully work as the internal svc --> svc communication has not been allowed by the application level network policy. (kubectl or Gitops)
11. Application Team deploys their Application level ACNP rules enabling all all svc-->svc communication between application components within the same Namespace. (kubectl or Gitops)



## Evaluation order

Antrea evaluates every policy in one pipeline, **lowest tier priority first**. Within a tier, lower
policy `priority` wins, then rule order. The **first matching rule decides** (`Allow`, `Drop`, `Reject`).

```
 packet ─►  vDefend tiers (NSX-managed, read-only in the cluster)
            0  nsx-category-ethernet
            1  nsx-category-emergency
            2  nsx-category-infrastructure
            3  nsx-category-environment
            4  nsx-category-application    ◄── LAYER 1  Security team
                     │ no match
                     ▼
            Native Antrea tiers
           50  emergency
          100  securityops
          150  networkops
          200  platform
          250  application                 ◄── LAYER 2  Application team
                     │ no match
                     ▼
            Kubernetes NetworkPolicy (if any)
                     │ no match
                     ▼
          253  baseline                    ◄── LAYER 3  Platform team (default deny)
```

Every vDefend tier is evaluated before every native tier. That one fact drives the rules for each layer below.

## Layer 1: Security guardrails (vDefend, Security team)

**Persona:** Security / SecOps. Manages policy in NSX Manager (`nsx01.gpu.set.lab`) through Terraform (`main.tf`).
NSX pushes the policy into the cluster via the Antrea ccp-adapter as an ACNP with a UUID name, labelled
`ccp-adapter.antrea.tanzu.vmware.com/managedBy: ccp-adapter`.

**Owns:** flows the business mandates regardless of what app teams do.

| Rule | Source | Destination (applied to) | Port | Action |
|------|--------|--------------------------|------|--------|
| `frontend-avi` | Avi SEs `100.64.32.0/24`, Antrea node gateways `240.0.{0..3}.1` | `Music-store-frontend` (`app=music-store-1`) | TCP 5000 | ALLOW |
| `store->database` | `store-service` | `database-service` | TCP 5432 | ALLOW |

**Rules for this layer**
- **Allow rules only. No catch-all DROP.** A cleanup DROP here (tier 4) would match before the
  application tier (250), so app-team policies could never allow anything.
- Use DROP only for true guardrails (quarantine, environment isolation) in the Emergency or Environment categories.
- A vDefend `ALLOW` is final: app teams cannot tighten it. Mandate only what security must own.
- Avoid `JUMP_TO_APPLICATION` / `Pass` if app teams use Antrea-native policies. Pass skips **all**
  remaining Antrea tiers, including the application tier, and goes straight to K8s NetworkPolicy and baseline.
- Never edit the pushed ACNP with `kubectl`. The ccp-adapter reconciles it back. Change it in NSX or Terraform.

**Why the frontend sources are the SE and node gateways:** AKO uses NodePortLocal, so Avi SE traffic
arrives at the pod from the SE data IP. NodePort/LoadBalancer traffic is SNATed to each node's `antrea-gw0`
(`240.0.N.1`). If the cluster scales out, add the new node's gateway IP, or the frontend loses traffic from it.

## Layer 2: App microsegmentation (native Antrea, Application team)

**Persona:** Application team. Applies via `kubectl` or GitOps.

**Owns:** service-to-service flows inside `music-store`, in the native `application` tier.

| Rule | Source | Destination | Port |
|------|--------|-------------|------|
| `store-to-cart` | `service-name=store` | `service-name=cart` | TCP 5002 |
| `store-to-users` | `service-name=store` | `service-name=users` | TCP 5003 |
| `store-and-cart-to-order` | `service-name in (store, cart)` | `service-name=order` | TCP 5001 |
| `store-to-database` | `service-name=store` | `service-name=database` | TCP 5432 |

**Rules for this layer**
- Only traffic not already decided by vDefend reaches this layer.
- `store-to-database` duplicates the vDefend rule on purpose, so the app keeps working if the security policy changes.
- This is a cluster-scoped ACNP and needs cluster-level RBAC. To give app teams self-service without cluster
  rights, use a namespaced **Antrea NetworkPolicy** (ANNP, `kind: NetworkPolicy`, `crd.antrea.io`) in
  `music-store` instead. An ANNP's `podSelector` only matches pods in its own namespace.

## Layer 3: Default deny (native Antrea, Platform team)

**Persona:** Platform team. Applies via `kubectl` or GitOps.

**Owns:** the catch-all. `music-store-baseline-default-deny` drops all ingress to `music-store` that no
earlier layer allowed. It sits in `baseline`, the last tier, so it never shadows layers 1 or 2.
Logging is enabled, so every drop shows up in the Antrea policy log.

## Rollout order

The *evaluation* order is fixed by tier. The *apply* order is chosen so traffic is never cut and never left open:

| Step | Persona | Action |
|------|---------|--------|
| 1 | Security | `terraform apply`: vDefend allow rules (no cleanup DROP) |
| 2 | Application | `kubectl apply -f k8s/app-svc-to-svc.yaml` |
| 3 | Platform | `kubectl apply -f k8s/baseline-default-deny.yaml` |
| 4 | All | Verify with Traceflow and the policy logs (below) |

**Migrating from a vDefend cleanup DROP:** apply step 3 first. It has no effect while the vDefend DROP still
matches first. Then step 2, then remove the cleanup rule (step 1). That way there is never a window without a default deny.

## Verify

```bash
# What is enforced, and in which tier
kubectl get tiers --sort-by=.spec.priority
kubectl get acnp -o custom-columns=NAME:.metadata.name,TIER:.spec.tier,PRIO:.spec.priority
```

```bash
# Traceflow: which tier/policy decided a flow
kubectl apply -f - <<EOF
apiVersion: crd.antrea.io/v1beta1
kind: Traceflow
metadata: {name: tf-store-cart}
spec:
  source:      {namespace: music-store, pod: <store-pod>}
  destination: {namespace: music-store, pod: <cart-pod>}
  packet: {transportHeader: {tcp: {dstPort: 5002, flags: 2}}}
EOF
kubectl get traceflow tf-store-cart -o jsonpath='{range .status.results[*].observations[?(@.component=="NetworkPolicy")]}{.action} {.networkPolicy}{"\n"}{end}'
```

```bash
# Policy log on a node (shows Allow/Drop and the matching policy for logged rules)
kubectl exec -n kube-system <antrea-agent-pod> -c antrea-agent -- tail -f /var/log/antrea/networkpolicy/np.log
```

Expected results:

| Flow | Decided by |
|------|------------|
| Avi SE → frontend :5000 | vDefend ACNP (`nsx-category-application`) |
| store → database :5432 | vDefend ACNP |
| store → cart / users / order, cart → order | `music-store-app-svc-to-svc` |
| anything else into `music-store` (e.g. users → cart) | **Dropped** by `music-store-baseline-default-deny` |

## Repo layout

```
k8s-vdefend-layered/
├── main.tf                        # Layer 1: vDefend services, groups, policy, rules (Security team)
├── variables.tf / outputs.tf
├── terraform.tfvars.example       # copy to terraform.tfvars (gitignored)
├── dev_overrides.tfrc             # custom NSX provider override
└── k8s/
    ├── app-svc-to-svc.yaml        # Layer 2: Application team
    └── baseline-default-deny.yaml # Layer 3: Platform team
```

> **Note:** `main.tf` contains only the two Layer 1 rules (`frontend-avi`, `store->database`).
> Service-to-service flows are deliberately not in vDefend, so the Application team owns them in Layer 2.
> If they were added back, vDefend would decide them at tier 4 and the Layer 2 rules would never match.

## Terraform setup (Layer 1)

This requires a custom NSX provider build with Antrea container-cluster support
([ksamoray/terraform-provider-nsxt, branch `security-policy-antrea`](https://github.com/ksamoray/terraform-provider-nsxt/tree/security-policy-antrea)).

```bash
# 1. Point Terraform at the custom provider (edit the path in dev_overrides.tfrc first)
export TF_CLI_CONFIG_FILE="$(pwd)/dev_overrides.tfrc"

# 2. Configure the connection (terraform.tfvars is gitignored, never commit it)
cp terraform.tfvars.example terraform.tfvars
#   nsx_manager              = "nsx01.gpu.set.lab"
#   nsx_username             = "admin"
#   nsx_password             = "..."
#   cluster_control_plane_id = "<antrea cluster control plane id>"

# 3. Deploy
terraform init && terraform plan && terraform apply
```

Pods must carry the labels the NSX groups and Antrea selectors match on: `app`, `app-name`, `service-name`, `env`.

## References

- [Antrea-native policies: tiers, priorities, Pass action](https://antrea.io/docs/main/docs/antrea-network-policy/)
- [Antrea Traceflow](https://antrea.io/docs/main/docs/traceflow-guide/)
- [NSX Terraform provider](https://registry.terraform.io/providers/vmware/nsxt/latest/docs)
