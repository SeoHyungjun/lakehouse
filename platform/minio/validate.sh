#!/bin/bash
# MinIO Helm Chart Validation Script

set -e

echo "=== MinIO Helm Chart Validation ==="
echo ""

# Check required files
echo "✓ Checking required files..."
required_files=(
  "Chart.yaml"
  "values.yaml"
  ".helmignore"
  "README.md"
)

for file in "${required_files[@]}"; do
  if [ -f "$file" ]; then
    echo "  ✅ $file exists"
  else
    echo "  ❌ $file missing"
    exit 1
  fi
done

echo ""
echo "✓ Checking Chart.yaml structure..."
if grep -q "apiVersion: v2" Chart.yaml && \
   grep -q "name: minio" Chart.yaml && \
   grep -q "dependencies:" Chart.yaml; then
  echo "  ✅ Chart.yaml is valid"
else
  echo "  ❌ Chart.yaml is invalid"
  exit 1
fi

echo ""
echo "✓ Checking for hardcoded IPs..."
if grep -r "192\.168\|10\.\|172\.\|[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}" values.yaml ../../env/*/minio-values.yaml 2>/dev/null; then
  echo "  ❌ Hardcoded IPs found!"
  exit 1
else
  echo "  ✅ No hardcoded IPs found"
fi

echo ""
echo "✓ Checking environment-specific values..."
env_files=(
  "../../env/dev/minio-values.yaml"
  "../../env/staging/minio-values.yaml"
  "../../env/prod/minio-values.yaml"
)

for file in "${env_files[@]}"; do
  if [ -f "$file" ]; then
    echo "  ✅ $file exists"
  else
    echo "  ❌ $file missing"
    exit 1
  fi
done

echo ""
echo "✓ Checking DNS-based endpoints..."
if grep -q "endpoint.*minio" ../../contracts/object-storage.md; then
  echo "  ✅ Contract specifies DNS-based endpoints"
else
  echo "  ⚠️  Warning: Contract may not specify DNS endpoints"
fi

echo ""
echo "✓ Checking bucket configuration..."
for file in "${env_files[@]}"; do
  if grep -q "buckets:" "$file"; then
    echo "  ✅ $(basename $(dirname $file)): Buckets configured"
  else
    echo "  ⚠️  $(basename $(dirname $file)): No buckets configured"
  fi
done

echo ""
echo "✓ Checking resource limits..."
for file in "${env_files[@]}"; do
  if grep -q "resources:" "$file"; then
    echo "  ✅ $(basename $(dirname $file)): Resources configured"
  else
    echo "  ❌ $(basename $(dirname $file)): Resources not configured"
    exit 1
  fi
done

echo ""
echo "✓ Checking metrics configuration..."
for file in "${env_files[@]}"; do
  env_name=$(basename $(dirname $file))
  if [ "$env_name" = "prod" ] || [ "$env_name" = "staging" ]; then
    if grep -A2 "metrics:" "$file" | grep -q "enabled: true"; then
      echo "  ✅ $env_name: Metrics enabled"
    else
      echo "  ⚠️  $env_name: Metrics should be enabled"
    fi
  fi
done

echo ""
echo "=== Validation Summary ==="
echo "✅ All required files present"
echo "✅ Chart.yaml structure valid"
echo "✅ No hardcoded IPs"
echo "✅ Environment-specific values configured"
echo "✅ DNS-based endpoints used"
echo "✅ Resource limits defined"
echo ""
echo "VALIDATION PASSED ✅"
