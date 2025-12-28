#!/bin/bash
# Lakehouse Platform Validation Script
#
# This script validates the Lakehouse platform deployment.
#
# Usage:
#   ./scripts/validate.sh [environment]
#
# Arguments:
#   environment - Target environment: dev, staging, or prod (default: dev)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ENVIRONMENT="${1:-dev}"
ARGOCD_NAMESPACE="argocd"
PLATFORM_NAMESPACE="lakehouse-platform"

PASS=0
FAIL=0
WARN=0

# Logging functions
pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASS++))
}

fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAIL++))
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARN++))
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Print banner
echo ""
echo "=========================================="
echo "  Lakehouse Platform Validation"
echo "=========================================="
echo ""
echo "Environment: ${ENVIRONMENT}"
echo ""

# Check cluster connection
echo "1. Cluster Connection"
echo "---------------------"
if kubectl cluster-info &> /dev/null; then
    pass "Kubernetes cluster is accessible"
else
    fail "Cannot connect to Kubernetes cluster"
fi
echo ""

# Check ArgoCD
echo "2. ArgoCD"
echo "---------"
if kubectl get namespace "${ARGOCD_NAMESPACE}" &> /dev/null; then
    pass "ArgoCD namespace exists"
    
    # Check ArgoCD server
    if kubectl get deployment argocd-server -n "${ARGOCD_NAMESPACE}" &> /dev/null; then
        pass "ArgoCD server deployment exists"
        
        # Check if server is ready
        READY=$(kubectl get deployment argocd-server -n "${ARGOCD_NAMESPACE}" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        if [ "${READY}" -gt 0 ]; then
            pass "ArgoCD server is ready (${READY} replicas)"
        else
            fail "ArgoCD server is not ready"
        fi
    else
        fail "ArgoCD server deployment not found"
    fi
    
    # Check ArgoCD controller
    if kubectl get deployment argocd-application-controller -n "${ARGOCD_NAMESPACE}" &> /dev/null; then
        pass "ArgoCD application controller exists"
    else
        fail "ArgoCD application controller not found"
    fi
else
    fail "ArgoCD namespace not found"
fi
echo ""

# Check ArgoCD Applications
echo "3. ArgoCD Applications"
echo "----------------------"
if kubectl get applications -n "${ARGOCD_NAMESPACE}" &> /dev/null; then
    APP_COUNT=$(kubectl get applications -n "${ARGOCD_NAMESPACE}" --no-headers 2>/dev/null | wc -l | tr -d ' ')
    pass "Found ${APP_COUNT} ArgoCD applications"
    
    # Check each expected application
    for app in minio iceberg-catalog trino airflow observability; do
        if kubectl get application "${app}" -n "${ARGOCD_NAMESPACE}" &> /dev/null; then
            STATUS=$(kubectl get application "${app}" -n "${ARGOCD_NAMESPACE}" -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
            HEALTH=$(kubectl get application "${app}" -n "${ARGOCD_NAMESPACE}" -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
            
            if [ "${STATUS}" = "Synced" ] && [ "${HEALTH}" = "Healthy" ]; then
                pass "${app}: Synced and Healthy"
            elif [ "${STATUS}" = "Synced" ]; then
                warn "${app}: Synced but ${HEALTH}"
            else
                warn "${app}: ${STATUS}, ${HEALTH}"
            fi
        else
            fail "${app} application not found"
        fi
    done
else
    fail "No ArgoCD applications found"
fi
echo ""

# Check Platform Namespace
echo "4. Platform Namespace"
echo "---------------------"
if kubectl get namespace "${PLATFORM_NAMESPACE}" &> /dev/null; then
    pass "Platform namespace exists"
    
    # Check pods
    POD_COUNT=$(kubectl get pods -n "${PLATFORM_NAMESPACE}" --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [ "${POD_COUNT}" -gt 0 ]; then
        pass "Found ${POD_COUNT} pods in platform namespace"
        
        # Check running pods
        RUNNING=$(kubectl get pods -n "${PLATFORM_NAMESPACE}" --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ')
        if [ "${RUNNING}" -gt 0 ]; then
            pass "${RUNNING} pods are running"
        else
            warn "No pods are running"
        fi
    else
        warn "No pods found in platform namespace"
    fi
else
    fail "Platform namespace not found"
fi
echo ""

# Check Platform Components
echo "5. Platform Components"
echo "----------------------"

# Check MinIO
if kubectl get deployment minio -n "${PLATFORM_NAMESPACE}" &> /dev/null; then
    pass "MinIO deployment exists"
else
    warn "MinIO deployment not found"
fi

# Check Iceberg Catalog
if kubectl get deployment iceberg-catalog -n "${PLATFORM_NAMESPACE}" &> /dev/null; then
    pass "Iceberg Catalog deployment exists"
else
    warn "Iceberg Catalog deployment not found"
fi

# Check Trino
if kubectl get deployment trino-coordinator -n "${PLATFORM_NAMESPACE}" &> /dev/null; then
    pass "Trino coordinator deployment exists"
else
    warn "Trino coordinator deployment not found"
fi

# Check Airflow
if kubectl get deployment airflow-webserver -n "${PLATFORM_NAMESPACE}" &> /dev/null; then
    pass "Airflow webserver deployment exists"
else
    warn "Airflow webserver deployment not found"
fi

# Check Observability
if kubectl get deployment observability-grafana -n "${PLATFORM_NAMESPACE}" &> /dev/null; then
    pass "Grafana deployment exists"
else
    warn "Grafana deployment not found"
fi

if kubectl get statefulset prometheus-observability-kube-prometheus-prometheus -n "${PLATFORM_NAMESPACE}" &> /dev/null; then
    pass "Prometheus statefulset exists"
else
    warn "Prometheus statefulset not found"
fi
echo ""

# Summary
echo "=========================================="
echo "Validation Summary"
echo "=========================================="
echo -e "${GREEN}Passed:${NC} ${PASS}"
echo -e "${YELLOW}Warnings:${NC} ${WARN}"
echo -e "${RED}Failed:${NC} ${FAIL}"
echo ""

if [ ${FAIL} -eq 0 ]; then
    echo -e "${GREEN}✓ Platform validation passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Platform validation failed.${NC}"
    echo "Please review the failures above."
    exit 1
fi
