# Self-Hosted GitHub Actions Runner Setup

The Pi control plane node runs a self-hosted runner registered to the `moongooseorg` org.
Deploy jobs run here; build jobs run on GitHub-hosted runners.

---

## Step 1 — Install Helm

```bash
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

Verify:

```bash
helm version
```

---

## Step 2 — Create a dedicated runner user

```bash
sudo useradd --system --shell /bin/bash --create-home github-runner
```

---

## Step 3 — Download and configure the runner

Switch to the runner user and create the runner directory:

```bash
sudo -u github-runner bash
mkdir -p /opt/github-runner/actions-runner && cd /opt/github-runner/actions-runner
```

Go to **GitHub → moongooseorg org → Settings → Actions → Runners → New self-hosted runner**,
select **Linux** and **ARM64**, then paste the three commands GitHub provides (curl download,
shasum validation, tar extract).

Then run the `config.sh` command from the same page, appending `--unattended`:

```bash
./config.sh --url https://github.com/moongooseorg --token <TOKEN_FROM_GITHUB> --unattended
```

The token expires after 1 hour. Do not commit it.

When done, exit back to your normal user:

```bash
exit
```

---

## Step 4 — Install as a systemd service

Switch to root, then cd into the runner directory and run the service commands:

```bash
sudo su
cd /opt/github-runner/actions-runner
./svc.sh install github-runner
./svc.sh start
```

Verify it's running:

```bash
./svc.sh status
```

Then exit root:

```bash
exit
```

The runner should appear as **online** at:
**GitHub → moongooseorg org → Settings → Actions → Runners**

---

## Step 5 — Give the runner kubeconfig access

k3s writes its kubeconfig as root. Copy it to the runner user and set `KUBECONFIG` via
a systemd service override so `helm` and `kubectl` work in deploy jobs.

> **Note:** Setting `KUBECONFIG` in `~/.profile` is not sufficient — systemd services
> do not source shell profiles.

```bash
sudo mkdir -p /home/github-runner/.kube
sudo cp /etc/rancher/k3s/k3s.yaml /home/github-runner/.kube/config
sudo chown -R github-runner:github-runner /home/github-runner/.kube
sudo chmod 600 /home/github-runner/.kube/config
```

Then add `KUBECONFIG` to the systemd service environment:

```bash
sudo systemctl edit actions.runner.moongooseorg.*
```

Add the following and save:

```ini
[Service]
Environment="KUBECONFIG=/home/github-runner/.kube/config"
```

Reload and restart the service:

```bash
sudo systemctl daemon-reload
sudo systemctl restart actions.runner.moongooseorg.*
```

Test it:

```bash
sudo -u github-runner bash -l -c 'kubectl get nodes'
```

---

## Day-to-day operations

All `svc.sh` commands must be run from within the runner directory as root:

```bash
sudo su
cd /opt/github-runner/actions-runner
```

| Task | Command |
|---|---|
| Check status | `./svc.sh status` |
| Stop | `./svc.sh stop` |
| Start | `./svc.sh start` |
| View logs | `journalctl -u actions.runner.moongooseorg.main -f` |

---

## Kubeconfig refresh

If the k3s cluster is reinitialized, the kubeconfig changes and deploys will fail.
Refresh it with:

```bash
sudo cp /etc/rancher/k3s/k3s.yaml /home/github-runner/.kube/config
sudo chown github-runner:github-runner /home/github-runner/.kube/config
sudo chmod 600 /home/github-runner/.kube/config
sudo systemctl restart actions.runner.moongooseorg.*
```

---

## Workspace cleanup

Cancelled or errored jobs can leave stale directories under `_work/`. A systemd
timer runs nightly to prune any workspace subdirectories older than 24 hours.

The unit files are in `systemd/` in this repo. To install on the Pi, first copy
them from your dev machine:

```bash
scp systemd/runner-workspace-cleanup.{service,timer} <pi-user>@<pi-host>:/tmp/
```

Then SSH in and move them into place:

```bash
ssh <pi-user>@<pi-host>
sudo mv /tmp/runner-workspace-cleanup.{service,timer} /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now runner-workspace-cleanup.timer
```

Verify it's scheduled:

```bash
systemctl list-timers runner-workspace-cleanup.timer
```

To trigger a manual run:

```bash
sudo systemctl start runner-workspace-cleanup.service
journalctl -u runner-workspace-cleanup.service
```

---

## Updating the runner

GitHub will notify you in the runner settings when an update is available.
To update, stop the runner and re-run setup from Step 3 using a new registration token.
