#!/bin/bash
# Bare-Metal Installation Script for Sample Service
# Installs and configures the Sample Service to run on bare-metal (no container)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/opt/lakehouse/sample-service"
SERVICE_USER="lakehouse"
SERVICE_FILE="/etc/systemd/system/sample-service.service"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Print banner
print_banner() {
    echo ""
    echo "=========================================="
    echo "  Sample Service Bare-Metal Installation"
    echo "=========================================="
    echo ""
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 is not installed"
        exit 1
    fi
    PYTHON_VERSION=$(python3 --version)
    log_success "Python: ${PYTHON_VERSION}"
    
    # Check pip
    if ! command -v pip3 &> /dev/null; then
        log_error "pip3 is not installed"
        exit 1
    fi
    log_success "pip3 is available"
    
    echo ""
}

# Create service user
create_user() {
    log_info "Creating service user..."
    
    if id "${SERVICE_USER}" &>/dev/null; then
        log_warn "User ${SERVICE_USER} already exists"
    else
        useradd -r -s /bin/false -d "${INSTALL_DIR}" "${SERVICE_USER}"
        log_success "Created user ${SERVICE_USER}"
    fi
    
    echo ""
}

# Create installation directory
create_install_dir() {
    log_info "Creating installation directory..."
    
    mkdir -p "${INSTALL_DIR}"
    log_success "Created ${INSTALL_DIR}"
    
    echo ""
}

# Copy application files
copy_files() {
    log_info "Copying application files..."
    
    # Copy Python application
    cp "${SCRIPT_DIR}/app.py" "${INSTALL_DIR}/"
    log_success "Copied app.py"
    
    # Copy requirements
    cp "${SCRIPT_DIR}/requirements.txt" "${INSTALL_DIR}/"
    log_success "Copied requirements.txt"
    
    # Set ownership
    chown -R "${SERVICE_USER}:${SERVICE_USER}" "${INSTALL_DIR}"
    log_success "Set ownership to ${SERVICE_USER}"
    
    echo ""
}

# Install Python dependencies
install_dependencies() {
    log_info "Installing Python dependencies..."
    
    pip3 install -r "${INSTALL_DIR}/requirements.txt"
    log_success "Dependencies installed"
    
    echo ""
}

# Install systemd service
install_service() {
    log_info "Installing systemd service..."
    
    # Copy service file
    cp "${SCRIPT_DIR}/sample-service.service" "${SERVICE_FILE}"
    log_success "Copied service file to ${SERVICE_FILE}"
    
    # Reload systemd
    systemctl daemon-reload
    log_success "Reloaded systemd"
    
    # Enable service
    systemctl enable sample-service
    log_success "Enabled sample-service"
    
    echo ""
}

# Configure service
configure_service() {
    log_info "Configuring service..."
    
    # Prompt for configuration
    read -p "Trino endpoint [http://trino.lakehouse.local:8080]: " TRINO_ENDPOINT
    TRINO_ENDPOINT=${TRINO_ENDPOINT:-http://trino.lakehouse.local:8080}
    
    read -p "S3 endpoint [http://minio.lakehouse.local:9000]: " S3_ENDPOINT
    S3_ENDPOINT=${S3_ENDPOINT:-http://minio.lakehouse.local:9000}
    
    read -p "Iceberg Catalog URI [http://iceberg-catalog.lakehouse.local:8181]: " ICEBERG_URI
    ICEBERG_URI=${ICEBERG_URI:-http://iceberg-catalog.lakehouse.local:8181}
    
    # Update service file
    sed -i "s|Environment=\"TRINO_ENDPOINT=.*\"|Environment=\"TRINO_ENDPOINT=${TRINO_ENDPOINT}\"|" "${SERVICE_FILE}"
    sed -i "s|Environment=\"S3_ENDPOINT=.*\"|Environment=\"S3_ENDPOINT=${S3_ENDPOINT}\"|" "${SERVICE_FILE}"
    sed -i "s|Environment=\"ICEBERG_CATALOG_URI=.*\"|Environment=\"ICEBERG_CATALOG_URI=${ICEBERG_URI}\"|" "${SERVICE_FILE}"
    
    # Reload systemd
    systemctl daemon-reload
    
    log_success "Service configured"
    echo ""
}

# Start service
start_service() {
    log_info "Starting service..."
    
    systemctl start sample-service
    sleep 2
    
    # Check status
    if systemctl is-active --quiet sample-service; then
        log_success "Service started successfully"
    else
        log_error "Service failed to start"
        systemctl status sample-service
        exit 1
    fi
    
    echo ""
}

# Verify installation
verify_installation() {
    log_info "Verifying installation..."
    
    # Check service status
    if systemctl is-active --quiet sample-service; then
        log_success "Service is running"
    else
        log_error "Service is not running"
        exit 1
    fi
    
    # Check health endpoint
    sleep 2
    if curl -f http://localhost:8080/health &> /dev/null; then
        log_success "Health endpoint responding"
    else
        log_warn "Health endpoint not responding (may need time to start)"
    fi
    
    echo ""
}

# Print next steps
print_next_steps() {
    echo ""
    echo "=========================================="
    echo "  Installation Complete!"
    echo "=========================================="
    echo ""
    echo "Service installed and running as systemd service"
    echo ""
    echo "Useful commands:"
    echo "  sudo systemctl status sample-service   # Check status"
    echo "  sudo systemctl stop sample-service     # Stop service"
    echo "  sudo systemctl start sample-service    # Start service"
    echo "  sudo systemctl restart sample-service  # Restart service"
    echo "  sudo journalctl -u sample-service -f   # View logs"
    echo ""
    echo "Test endpoints:"
    echo "  curl http://localhost:8080/health      # Health check"
    echo "  curl http://localhost:8080/ready       # Readiness check"
    echo "  curl http://localhost:8080/metrics     # Metrics"
    echo ""
    echo "=========================================="
    echo ""
}

# Main execution
main() {
    print_banner
    check_root
    check_prerequisites
    create_user
    create_install_dir
    copy_files
    install_dependencies
    install_service
    configure_service
    start_service
    verify_installation
    print_next_steps
    
    log_success "Installation completed successfully!"
}

# Run main function
main "$@"
