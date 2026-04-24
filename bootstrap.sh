#!/bin/bash
# bootstrap.sh — install OpenShift GitOps for rhoai-demo-foundations
set -e

echo "🔍 Checking for OpenShift GitOps..."

if oc get deployment openshift-gitops-server -n openshift-gitops &>/dev/null; then
  echo "✅ OpenShift GitOps is already installed. Skipping installation."
  echo ""
  echo "ArgoCD URL:"
  oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='https://{.spec.host}{"\n"}' 2>/dev/null || echo "  (Route not yet available)"
  exit 0
fi

echo "📦 Installing OpenShift GitOps Operator..."
oc apply -k bootstrap/gitops-operator/base/

echo "⏳ Waiting for GitOps Operator to be ready..."
# oc wait fails immediately if the Deployment does not exist yet; OLM creates it
# after the Subscription reconciles. Newer GitOps may use openshift-gitops-operator;
# older installs keep the controller in openshift-operators.
timeout=300
elapsed=0
operator_ns=""
while [ "$elapsed" -lt "$timeout" ]; do
  for try_ns in openshift-operators openshift-gitops-operator; do
    if oc get deployment openshift-gitops-operator-controller-manager -n "$try_ns" &>/dev/null; then
      operator_ns=$try_ns
      break 2
    fi
  done
  echo "  Waiting for operator deployment to appear... (${elapsed}s / ${timeout}s)"
  sleep 5
  elapsed=$((elapsed + 5))
done

if [ -z "$operator_ns" ]; then
  echo "❌ Timeout: deployment/openshift-gitops-operator-controller-manager not found."
  echo "   Check: oc get subscription openshift-gitops-operator -n openshift-operators"
  echo "   and: oc get csv -n openshift-operators; oc get installplan -n openshift-operators"
  exit 1
fi

oc wait --for=condition=Available \
  deployment/openshift-gitops-operator-controller-manager \
  -n "$operator_ns" --timeout=300s

echo "🚀 Creating ArgoCD instance..."
oc apply -k bootstrap/gitops-operator/instance/

echo "⏳ Waiting for ArgoCD to be ready..."
# oc wait exits immediately with "no matching resources found" if no pods exist yet.
elapsed=0
while [ "$elapsed" -lt "$timeout" ]; do
  if oc get pod -l app.kubernetes.io/name=openshift-gitops-server \
       -n openshift-gitops --no-headers 2>/dev/null | grep -q .; then
    break
  fi
  echo "  Waiting for openshift-gitops-server pod to appear... (${elapsed}s / ${timeout}s)"
  sleep 5
  elapsed=$((elapsed + 5))
done

oc wait --for=condition=Ready \
  pod -l app.kubernetes.io/name=openshift-gitops-server \
  -n openshift-gitops --timeout=300s

echo ""
echo "✅ GitOps installation complete!"
echo ""
echo "ArgoCD Details:"
echo "  URL: https://$(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}')"
echo "  Username: admin"
echo "  Password: $(oc get secret openshift-gitops-cluster -n openshift-gitops -o jsonpath='{.data.admin\.password}' | base64 -d)"
echo ""
