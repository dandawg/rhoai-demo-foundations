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

4. **MinIO (optional but recommended for pipelines)** — Follow the [rhoai-deploy README](https://github.com/redhat-ai-americas/rhoai-deploy/blob/main/README.md) MinIO section: create namespace `minio` and Secret `minio-secret` with keys `MINIO_ROOT_USER` and `MINIO_ROOT_PASSWORD`, then **Sync** the `minio` Application manually in Argo CD.

5. **JobSet operand (for Kubeflow Trainer v2)** — After the JobSet Operator CSV is healthy, **Sync** the `jobset-operator-instance` Application (or create the `JobSetOperator` from the OperatorHub UI if the manifest does not match your OpenShift version).

6. **Pipelines (optional)** — After MinIO is healthy and the `pipelines` bucket exists, create the DSPA connection Secret in `demo` using the same credentials as `minio-secret` (see [rhoai-distributed README](https://github.com/redhat-ai-americas/rhoai-distributed/blob/main/README.md)), then **Sync** `pipelines-server`.

7. **Ray (optional)** — **Sync** the `ray-dsc-patch` Application when you want KubeRay enabled on the cluster.

## What syncs automatically vs manually

| Argo CD Application | Policy |
|---------------------|--------|
| `rhoai-dependencies`, `nvidia-gpu-operator`, `nfd-instance`, `rhoai-operator`, `rhoai-instance` | Automated |
| `jobset-operator-subscription`, `kueue-cluster-default`, `kueue-localqueue-demo` | Automated |
| `model-base-resources`, `oss-vllm-runtime`, hardware profile apps | Automated |
| `minio`, `jobset-operator-instance`, `ray-dsc-patch`, `pipelines-server` | **Manual sync** |

## Sync waves (summary)

Lower waves run first: dependencies and GPU operator (0) → NFD and RHOAI operator (1) → DSC (2) → JobSet subscription (3) → MinIO and Kueue cluster queue (4) → optional Ray patch (5, manual) → model namespace and runtime (8–9) → Kueue `LocalQueue` in `demo` (9) → hardware profiles (10) → optional pipelines server (12, manual). **Sync** `jobset-operator-instance` manually once the JobSet Operator CSV is installed.

## Related repositories

- [rhoai-deploy](https://github.com/redhat-ai-americas/rhoai-deploy) — RHOAI operator, DSC, MinIO manifests
- [rhoai-distributed](https://github.com/redhat-ai-americas/rhoai-distributed) — JobSet, Kueue defaults, optional Ray and DSPA
- [rhoai-model-serving](https://github.com/redhat-ai-americas/rhoai-model-serving) — Hardware profiles and serving runtimes

## License

Apache License 2.0
