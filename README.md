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

3. Apply the bootstrap Application:

   ```bash
   oc apply -f gitops/foundations-bootstrap.yaml
   ```

4. **MinIO (optional but recommended for pipelines)** — Follow the [rhoai-deploy README](https://github.com/redhat-ai-americas/rhoai-deploy/blob/main/README.md) MinIO section: create namespace `minio` and Secret `minio-secret` with keys `MINIO_ROOT_USER` and `MINIO_ROOT_PASSWORD`, then **Sync** the `minio` Application manually in Argo CD. After MinIO is healthy, **Sync** the `access` Application (wave 5) to install the External Secrets Operator and sync `minio-dspa-connection` into `demo`.

5. **JobSet operand (for Kubeflow Trainer v2)** — The base `default-dsc` enables **`trainer`**. After the JobSet Operator CSV is healthy, **Sync** the `jobset-operator-instance` Application (or create the `JobSetOperator` from the OperatorHub UI if the manifest does not match your OpenShift version).

6. **Pipelines (optional)** — After MinIO is healthy, the `access` Application has synced (ESO running, `minio-dspa-connection` reconciled in `demo`), and the `pipelines` bucket exists, **Sync** `pipelines-server` (see [rhoai-distributed README](https://github.com/redhat-ai-americas/rhoai-distributed/blob/main/README.md)).

7. **Ray** — KubeRay is **Managed** by default in the base `default-dsc`. Optionally **Sync** `ray-dsc-patch` if you only want to touch the Ray stanza.

### Customizing `default-dsc` and DSPA after install

The `rhoai-instance` Application uses Argo CD **`ignoreDifferences` on `/spec`** for the cluster `DataScienceCluster` **`default-dsc`**. After the first successful sync, changes you make on the cluster (for example turning **Ray** or **Trainer v2** off, or toggling **`aipipelines`**) are **not** treated as drift, so **selfHeal does not revert them**. **Sync** `rhoai-instance` when you want Git to be applied again and reset that spec.

The `pipelines-server` Application does the same for **`DataSciencePipelinesApplication` `dspa`** in `demo`: you can delete it or change its **spec** without the app fighting you; **Sync** `pipelines-server` to restore the manifest from Git. (If you delete a resource entirely, Argo CD will typically show **OutOfSync** until you sync—**ignoreDifferences** applies to field drift when the object still exists.)

## What syncs automatically vs manually

| Argo CD Application | Policy |
|---------------------|--------|
| `rhoai-dependencies`, `nvidia-gpu-operator`, `nfd-instance`, `rhoai-operator`, `rhoai-instance` | Automated |
| `jobset-operator-subscription`, `kueue-cluster-default`, `kueue-localqueue-demo` | Automated |
| `model-base-resources`, `oss-vllm-runtime`, hardware profile apps | Automated |
| `access-operator`, `access` | Automated |
| `minio`, `jobset-operator-instance`, `ray-dsc-patch`, `pipelines-server` | **Manual sync** |

## Sync waves (summary)

Lower waves run first: dependencies and GPU operator (0) → NFD and RHOAI operator (1) → DSC (2; base includes Ray, Trainer v2, and managed pipelines component) → JobSet subscription (3) → MinIO and Kueue cluster queue (4) → ESO operator (`access-operator`, wave 5, automated) → ESO instance + pipeline credentials (`access`, wave 6, automated) → optional Ray patch (5, manual) → model namespace and runtime (8–9) → Kueue `LocalQueue` in `demo` (9) → hardware profiles (10) → optional pipelines server (12, manual). **Sync** `jobset-operator-instance` manually once the JobSet Operator CSV is installed.

## Related repositories

- [rhoai-deploy](https://github.com/redhat-ai-americas/rhoai-deploy) — RHOAI operator, DSC, MinIO manifests
- [rhoai-distributed](https://github.com/redhat-ai-americas/rhoai-distributed) — JobSet, Kueue defaults, optional Ray and DSPA
- [rhoai-model-serving](https://github.com/redhat-ai-americas/rhoai-model-serving) — Hardware profiles and serving runtimes

## License

Apache License 2.0
