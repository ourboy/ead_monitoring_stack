
# ead_monitoring_stack

This repository is used to deploy the **LGTM stack** onto **Azure Kubernetes Service (AKS)**.

## Overview

This project leverages the [LGTM stack](https://github.com/daviaraujocc/lgtm-stack) , which provides comprehensive system visibility. The stack helps monitor, troubleshoot, and optimize their applications effectively. It includes:

- **Loki**: Log aggregation system [https://grafana.com/oss/loki/](https://grafana.com/oss/loki/)
- **Grafana**: Interface & dashboards [https://grafana.com/oss/grafana/](https://grafana.com/oss/grafana/)
- **Tempo**: Distributed tracing storage and management [https://grafana.com/oss/tempo/](https://grafana.com/oss/tempo/)
- **Mimir**: Long-term metrics storage for Prometheus [https://grafana.com/oss/mimir/](https://grafana.com/oss/mimir/)

Additionally, a number of prebuilt Grafana dashboards are installed, courtesy of [dotdc/grafana-dashboards-kubernetes](https://github.com/dotdc/grafana-dashboards-kubernetes):

> This repository contains a modern set of Grafana dashboards for Kubernetes, inspired by many other dashboards from `kubernetes-mixin` and [grafana.com](https://grafana.com).

---

## Prerequisites

To enable resource deployment and manage access permissions in Azure, you must create a **Service Principal**. This identity is used by the deployment scripts.

### Create a Service Principal

```bash
az ad sp create-for-rbac --name "ead-monitoring" --role "Contributor" --scopes /subscriptions/<your-subscription-id>
```

### Configuration
Before running the deployment script (deploy-lgmt-azure.sh), update the deploy-lgmt-azure.sh script with the following environment variables and your Azure-specific values:
```bash
export RESOURCE_GROUP="<your-resource-group>"
export STORAGE_ACCOUNT="<your-storage-account-name>"
export CLUSTER_NAME="<your-aks-cluster-name>"
export LOCATION="East US"
export NAMESPACE="monitoring"

```