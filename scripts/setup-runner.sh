#!/usr/bin/env bash
set -euo pipefail

# Self-hosted GitHub Actions runner setup for the Pi control plane node.
# Reference: docs/runner-setup.md

# ---------------------------------------------------------------------------
# Step 1 — Create a dedicated runner user
# ---------------------------------------------------------------------------
echo "==> Step 1: Creating runner user..."
if id "github-runner" &>/dev/null; then
    echo "    User 'github-runner' already exists, skipping."
else
    sudo useradd --system --shell /bin/bash --create-home github-runner
    echo "    User 'github-runner' created."
fi

# ---------------------------------------------------------------------------
# Step 2 — Download and configure the runner (manual GitHub steps)
# ---------------------------------------------------------------------------
echo ""
echo "==> Step 2: Creating runner directory..."
sudo mkdir -p /opt/github-runner/actions-runner
sudo chown -R github-runner:github-runner /opt/github-runner

echo ""
echo "============================================================"
echo "  MANUAL STEP REQUIRED — GitHub runner registration"
echo "============================================================"
echo ""
echo "  1. Go to: GitHub → moongooseorg org → Settings → Actions"
echo "             → Runners → New self-hosted runner"
echo "  2. Select Linux / ARM64."
echo "  3. Run the following to switch to the runner user:"
echo ""
echo "     sudo -u github-runner bash"
echo "     cd /opt/github-runner/actions-runner"
echo ""
echo "  4. Paste the curl download, shasum validation, and tar"
echo "     extract commands shown on the GitHub page."
echo "  5. Then run config.sh with --unattended:"
echo ""
echo "     ./config.sh --url https://github.com/moongooseorg --token <TOKEN_FROM_GITHUB> --unattended"
echo ""
echo "  6. Type 'exit' to return to your normal user."
echo ""
echo "  Note: the registration token expires after 1 hour."
echo ""
echo "  Press Enter when you have completed the above steps..."
read -r < /dev/tty

# ---------------------------------------------------------------------------
# Step 3 — Install as a systemd service
# ---------------------------------------------------------------------------
echo ""
echo "==> Step 3: Installing and starting the runner service..."
cd /opt/github-runner/actions-runner
sudo ./svc.sh install github-runner
sudo ./svc.sh start


# ---------------------------------------------------------------------------
# Step 4 — Give the runner kubeconfig access
# ---------------------------------------------------------------------------
echo ""
echo "==> Step 4: Copying kubeconfig for runner user..."
sudo mkdir -p /home/github-runner/.kube
sudo cp /etc/rancher/k3s/k3s.yaml /home/github-runner/.kube/config
sudo chown -R github-runner:github-runner /home/github-runner/.kube
sudo chmod 600 /home/github-runner/.kube/config

echo "    Writing systemd service override for KUBECONFIG..."
sudo systemctl edit actions.runner.moongooseorg.* --force <<'EOF'
[Service]
Environment="KUBECONFIG=/home/github-runner/.kube/config"
EOF

sudo systemctl daemon-reload
sudo systemctl restart actions.runner.moongooseorg.*
echo "    Service restarted with KUBECONFIG set."

# ---------------------------------------------------------------------------
# Step 5 — Install nightly workspace cleanup timer
# ---------------------------------------------------------------------------
echo ""
echo "==> Step 5: Installing workspace cleanup systemd units..."

sudo tee /etc/systemd/system/runner-workspace-cleanup.service > /dev/null <<'EOF'
[Unit]
Description=Clean up stale GitHub Actions workspaces

[Service]
Type=oneshot
User=github-runner
ExecStart=find /opt/github-runner/actions-runner/_work -mindepth 2 -maxdepth 2 -type d -mtime +1 -exec rm -rf {} +
EOF

sudo tee /etc/systemd/system/runner-workspace-cleanup.timer > /dev/null <<'EOF'
[Unit]
Description=Nightly GitHub Actions workspace cleanup

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now runner-workspace-cleanup.timer

echo "    Timer status:"
systemctl list-timers runner-workspace-cleanup.timer

# ---------------------------------------------------------------------------
echo ""
echo "==> Setup complete."
echo "    Verify the runner is online at:"
echo "    GitHub → moongooseorg org → Settings → Actions → Runners"
