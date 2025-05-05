#!/bin/bash
set -e

TARGET="aks"
export RESOURCE_GROUP="cadca2-aks-rg"
export STORAGE_ACCOUNT="cadca2storage"
export CLUSTER_NAME="cadca2-aks-cluster"
export LOCATION="EastUS"
export CONTAINER_SUFFIX=$(openssl rand -hex 4)
export CONTAINERS=("logs" "traces" "metrics" "metrics-admin")
export NAMESPACE="monitoring"
STACK_DIR="lgtm-stack"
BACKUP_DIR="${STACK_DIR}_backup_$(date +%Y%m%d_%H%M%S)"

# Move existing stack folder
if [ -d "$STACK_DIR" ]; then
  echo "Moving existing '$STACK_DIR' to '$BACKUP_DIR'..."
  mv "$STACK_DIR" "$BACKUP_DIR"
fi

echo "Cloning LGTM stack..."
git clone https://github.com/daviaraujocc/lgtm-stack.git "$STACK_DIR"

az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME
az storage account create \
    --name $STORAGE_ACCOUNT \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --sku Standard_RAGRS \
    --kind StorageV2 \
    --min-tls-version TLS1_2

echo "Creating Azure Blob containers..."
for container in "${CONTAINERS[@]}"; do
  az storage container create --name "lgtm-${container}-${CONTAINER_SUFFIX}" --account-name $STORAGE_ACCOUNT --auth-mode login
done
  az storage container create --name "lgtm-logs" --account-name cadca2storage --auth-mode login

STORAGE_KEY=$(az storage account keys list --resource-group $RESOURCE_GROUP --account-name $STORAGE_ACCOUNT --query '[0].value' -o tsv)
kubectl create namespace $NAMESPACE || true
kubectl create secret generic azure-storage-secret \
  --from-literal=azurestorageaccountname=$STORAGE_ACCOUNT \
  --from-literal=azurestorageaccountkey=$STORAGE_KEY \
  -n $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

echo "Generating Helm values for Azure..."
mkdir -p helm
cat <<EOF > lgtm-stack/helm/values-lgtm.azure.yaml
loki:
  storage:
    type: azure
    azure:
      accountName: $STORAGE_ACCOUNT
      accountKey: $STORAGE_KEY
      containerName: lgtm-logs-${CONTAINER_SUFFIX}

tempo:
  storage:
    azure:
      accountName: $STORAGE_ACCOUNT
      accountKey: $STORAGE_KEY
      containerName: lgtm-traces-${CONTAINER_SUFFIX}

mimir:
  storage:
    azure:
      accountName: $STORAGE_ACCOUNT
      accountKey: $STORAGE_KEY
      containerName: lgtm-metrics-${CONTAINER_SUFFIX}

grafana:
  sidecar:
    dashboards:
      enabled: true
      label: grafana_dashboard
      labelValue: "1"
      searchNamespace: ALL
EOF

#!/bin/bash
set -e

TARGET="${1:-azure}"
NAMESPACE="${NAMESPACE:-monitoring}"

echo "Setting up Helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

echo "Deploying Prometheus Operator..."
helm upgrade --install prometheus-operator prometheus-community/kube-prometheus-stack \
  --namespace $NAMESPACE \
  --version 66.3.1 \
  -f lgtm-stack/helm/values-prometheus.yaml || true

echo "Deploying LGTM stack..."
VALUES_FILE="lgtm-stack/helm/values-lgtm.azure.yaml"
[[ "$TARGET" == "local" ]] && VALUES_FILE="lgtm-stack/helm/values-lgtm.local.yaml"

helm upgrade --install lgtm grafana/lgtm-distributed \
  --namespace $NAMESPACE \
  --version 2.1.0 \
  -f $VALUES_FILE

echo "Applying Grafana dashboards..."
kubectl apply -k https://github.com/dotdc/grafana-dashboards-kubernetes.git -n $NAMESPACE

kubectl apply -f lgmt--stack/manifests/promtail.docker.yaml

echo "LGTM stack deployed successfully to $TARGET!"

# echo "Grafana admin password:"
# kubectl get secret --namespace $NAMESPACE lgtm-grafana -o jsonpath="{.data.admin-password}" | base64 --decode
# echo ""


# To test loki integration:
# # Forward Loki port
# kubectl port-forward svc/lgtm-loki-distributor 3100:3100 -n monitoring

# # Send test log with timestamp and labels
# curl -XPOST http://localhost:3100/loki/api/v1/push -H "Content-Type: application/json" -d '{
#   "streams": [{
#     "stream": { "app": "test", "level": "info" },
#     "values": [[ "'$(date +%s)000000000'", "Test log message" ]]
#   }]
# }'