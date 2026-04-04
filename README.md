# k3s-infrastructure

## Setup GitHub Actions Runner

Run the setup script directly from GitHub:

```bash
curl -fsSL https://raw.githubusercontent.com/moongooseorg/k3s-infrastructure/main/scripts/setup-runner.sh | bash
```

This sets up a self-hosted GitHub Actions runner on the Pi control plane node. The script will pause midway and prompt you to complete the runner registration on GitHub before continuing.
