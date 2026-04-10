# rhoai-demo-foundations

GitOps **app-of-apps** for a baseline OpenShift AI environment: platform from [rhoai-deploy](https://github.com/redhat-ai-americas/rhoai-deploy), distributed prerequisites from [rhoai-distributed](https://github.com/redhat-ai-americas/rhoai-distributed), and serving scaffolding from [rhoai-model-serving](https://github.com/redhat-ai-americas/rhoai-model-serving) (shared vLLM runtime and hardware profiles only—no pinned models).

## Before GitOps (cluster setup)

Complete these outside this repo as needed for your environment:

1. **Machine capacity** — GPU/CPU MachineSets or other node pools (for example [openshift-infra](https://github.com/redhat-ai-americas/openshift-infra)) so serving and training have schedulable nodes.
2. **Shared / RWX storage (optional)** — If workbooks or distributed training need ReadWriteMany volumes (for example EFS on AWS), install the appropriate CSI driver and StorageClass using your infrastructure process. This repo does not deploy EFS or other RWX stacks.
3. **Git remotes** — Replace `https://github.com/redhat-ai-americas/...` in `gitops/` with your fork or organization if different.

## Install

1. Install OpenShift GitOps (if needed):

   ```bash
   ./bootstrap.sh
   ```

2. Register Git repositories in Argo CD (or allow your Git hosting credentials) so the cluster can pull `rhoai-demo-foundations`, `rhoai-deploy`, `rhoai-distributed`, and `rhoai-model-serving`.

3. **MinIO credentials (required before bootstrap)** — Create the `minio` namespace and root credentials Secret. The `minio` Application auto-syncs on first deploy and the Deployment will not start without this Secret in place.

   ```bash
   MINIO_ROOT_USER="minioadmin"
   MINIO_ROOT_PASSWORD="$(openssl rand -hex 24)"

   oc create namespace minio --dry-run=client -o yaml | oc apply -f -

   oc create secret generic minio-secret -n minio \
     --from-literal=MINIO_ROOT_USER="${MINIO_ROOT_USER}" \
     --from-literal=MINIO_ROOT_PASSWORD="${MINIO_ROOT_PASSWORD}"

   # Save the password — you will need it for the MinIO console and S3 clients
   echo "MinIO root password: ${MINIO_ROOT_PASSWORD}"
   ```

4. Apply the bootstrap Application:

   ```bash
   oc apply -f gitops/foundations-bootstrap.yaml
   ```

   This triggers automated sync for all Applications. `minio` (wave 4) auto-syncs and creates the `models`, `data`, and `pipelines` buckets. After MinIO is healthy, `access-operator` (wave 5) installs the External Secrets Operator and `access` (wave 6) syncs `minio-dspa-connection` into `demo`. `pipelines-server` (wave 12) auto-syncs once its prerequisites are met.

5. **JobSet operand (for Kubeflow Trainer v2)** — The base `default-dsc` enables **`trainer`**. After the JobSet Operator CSV is healthy, **Sync** the `jobset-operator-instance` Application (or create the `JobSetOperator` from the OperatorHub UI if the manifest does not match your OpenShift version).

6. **Ray** — KubeRay is **Managed** by default in the base `default-dsc`. No separate action needed.

### Customizing `default-dsc` and DSPA after install

The `rhoai-instance` Application uses Argo CD **`ignoreDifferences` on `/spec`** for the cluster `DataScienceCluster` **`default-dsc`**. After the first successful sync, changes you make on the cluster (for example turning **Ray** or **Trainer v2** off, or toggling **`aipipelines`**) are **not** treated as drift, so **selfHeal does not revert them**. **Sync** `rhoai-instance` when you want Git to be applied again and reset that spec.

The `pipelines-server` Application does the same for **`DataSciencePipelinesApplication` `dspa`** in `demo`: you can delete it or change its **spec** without the app fighting you; Argo CD will not revert cluster-side changes. Push a git change or manually **Sync** `pipelines-server` to re-apply the manifest from Git. (If you delete a resource entirely, Argo CD will show **OutOfSync** and auto-sync it back on the next git change—**ignoreDifferences** applies to field drift when the object still exists.)

## What syncs automatically vs manually

| Argo CD Application | Policy |
|---------------------|--------|
| `rhoai-dependencies`, `nvidia-gpu-operator`, `nfd-instance`, `rhoai-operator`, `rhoai-instance` | Automated (selfHeal) |
| `jobset-operator-subscription`, `kueue-cluster-default`, `kueue-localqueue-demo` | Automated (selfHeal) |
| `model-base-resources`, `oss-vllm-runtime`, hardware profile apps | Automated (selfHeal) |
| `access-operator`, `access` | Automated (selfHeal) |
| `minio`, `pipelines-server` | Automated, **no selfHeal** — cluster changes are not reverted |
| `jobset-operator-instance` | **Manual sync** |

## Sync waves (summary)

Lower waves run first: dependencies and GPU operator (0) → NFD and RHOAI operator (1) → DSC (2; base includes Ray, Trainer v2, and managed pipelines component) → JobSet subscription (3) → MinIO and Kueue cluster queue (4) → ESO operator (`access-operator`, wave 5) → ESO instance + pipeline credentials (`access`, wave 6) → model namespace and runtime (8–9) → Kueue `LocalQueue` in `demo` (9) → hardware profiles (10) → pipelines server (12). **Sync** `jobset-operator-instance` manually once the JobSet Operator CSV is installed.

## Related repositories

- [rhoai-deploy](https://github.com/redhat-ai-americas/rhoai-deploy) — RHOAI operator, DSC, MinIO manifests
- [rhoai-distributed](https://github.com/redhat-ai-americas/rhoai-distributed) — JobSet, Kueue defaults, optional Ray and DSPA
- [rhoai-model-serving](https://github.com/redhat-ai-americas/rhoai-model-serving) — Hardware profiles and serving runtimes

## License

Apache License 2.0
