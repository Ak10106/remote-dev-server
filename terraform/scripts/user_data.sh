#!/bin/bash
set -e

# Log all output
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "========================================"
echo "Starting Remote Dev Server Setup"
echo "========================================"

# ============================================
# System Update
# ============================================
echo "[1/8] Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get upgrade -y

# ============================================
# Install Prerequisites
# ============================================
echo "[2/8] Installing prerequisites..."
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    unzip \
    jq \
    git \
    vim \
    htop \
    build-essential

# ============================================
# Install Docker
# ============================================
echo "[3/8] Installing Docker..."
# Add Docker's official GPG key
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Set up the Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add ubuntu user to docker group
usermod -aG docker ubuntu

# Start and enable Docker
systemctl start docker
systemctl enable docker

echo "Docker version: $(docker --version)"
echo "Docker Compose version: $(docker compose version)"

# ============================================
# Install AWS CLI v2
# ============================================
echo "[4/8] Installing AWS CLI v2..."
cd /tmp
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

echo "AWS CLI version: $(aws --version)"

# ============================================
# Install Node.js 22
# ============================================
echo "[5/8] Installing Node.js 22..."
# Remove any existing Node.js from Ubuntu repos
apt-get remove -y nodejs npm libnode* 2>/dev/null || true
apt-get autoremove -y

# Install Node.js 22 from NodeSource
curl -fsSL https://deb.nodesource.com/setup_22.x -o /tmp/nodesource_setup.sh
bash /tmp/nodesource_setup.sh
apt-get install -y nodejs

# Verify installation
node --version
npm --version
echo "Node.js version: $(node --version)"
echo "npm version: $(npm --version)"

# ============================================
# Install Claude Code CLI
# ============================================
echo "[5b/8] Installing Claude Code CLI..."
npm install -g @anthropic-ai/claude-code
echo "Claude Code CLI installed"

# ============================================
# Setup Application Directories
# ============================================
echo "[6/8] Setting up application directories..."

# Create workspace directory
mkdir -p /home/ubuntu/workspace
mkdir -p /home/ubuntu/.config/code-server
mkdir -p /home/ubuntu/claude-code-ui
mkdir -p /home/ubuntu/.claude-code-ui-config

# Set ownership
chown -R ubuntu:ubuntu /home/ubuntu/workspace
chown -R ubuntu:ubuntu /home/ubuntu/.config
chown -R ubuntu:ubuntu /home/ubuntu/claude-code-ui
chown -R ubuntu:ubuntu /home/ubuntu/.claude-code-ui-config

# ============================================
# Create Docker Compose File
# ============================================
echo "[7/8] Creating Docker Compose configuration..."

# Set environment variables
export VSCODE_PASSWORD="${vscode_password}"
export VSCODE_AUTH_TYPE="${vscode_auth_type}"
export AWS_REGION="${aws_region}"

# Create .env file for Docker Compose
cat > /home/ubuntu/.env <<'EOF'
VSCODE_PASSWORD=${vscode_password}
VSCODE_AUTH_TYPE=${vscode_auth_type}
AWS_REGION=${aws_region}
EOF

chown ubuntu:ubuntu /home/ubuntu/.env

# Copy Docker Compose file
cat > /home/ubuntu/docker-compose.yml <<'DOCKER_COMPOSE'
${docker_compose_content}
DOCKER_COMPOSE

chown ubuntu:ubuntu /home/ubuntu/docker-compose.yml

# ============================================
# Start Docker Services
# ============================================
echo "[8/8] Starting Docker services..."

cd /home/ubuntu
sudo -u ubuntu docker compose up -d

echo "Waiting for services to start..."
sleep 10

# Check service status
echo "Service status:"
docker compose ps

# ============================================
# Configure CloudWatch Logs (Optional)
# ============================================
if [ "${enable_cloudwatch_logs}" = "true" ]; then
    echo "Configuring CloudWatch Logs..."

    # Install CloudWatch Agent
    wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
    dpkg -i -E ./amazon-cloudwatch-agent.deb
    rm amazon-cloudwatch-agent.deb

    # Create CloudWatch config
    cat > /opt/aws/amazon-cloudwatch-agent/etc/config.json <<'CW_CONFIG'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/user-data.log",
            "log_group_name": "/aws/ec2/${project_name}",
            "log_stream_name": "{instance_id}/user-data.log"
          },
          {
            "file_path": "/var/log/cloud-init-output.log",
            "log_group_name": "/aws/ec2/${project_name}",
            "log_stream_name": "{instance_id}/cloud-init-output.log"
          }
        ]
      }
    }
  }
}
CW_CONFIG

    # Start CloudWatch Agent
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
        -a fetch-config \
        -m ec2 \
        -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json \
        -s

    echo "CloudWatch Logs configured"
fi

# ============================================
# System Information
# ============================================
echo ""
echo "========================================"
echo "Setup Complete!"
echo "========================================"
echo ""
echo "System Information:"
echo "  - Hostname: $(hostname)"
echo "  - Private IP: $(hostname -I | awk '{print $1}')"
echo "  - Docker: $(docker --version)"
echo "  - AWS CLI: $(aws --version)"
echo ""
echo "Running Services:"
docker compose ps
echo ""
echo "Access URLs (via ALB):"
echo "  - Claude Code UI: https://${domain_name}"
echo "  - VS Code Server: https://${domain_name}/vscode"
echo ""
echo "SSH Access (via SSM):"
echo "  aws ssm start-session --target $(ec2-metadata --instance-id | cut -d ' ' -f 2) --region ${aws_region}"
echo ""
echo "Logs:"
echo "  - User Data: tail -f /var/log/user-data.log"
echo "  - Cloud Init: tail -f /var/log/cloud-init-output.log"
echo "  - Code Server: docker logs code-server"
echo "  - Claude UI: docker logs claude-code-ui"
echo ""
echo "========================================"
