# TNE AI dev/workspace image — the single definition shared by local dev and
# (Phase 2) the cloud IDE workspace pod. NOT based on lib/Dockerfile.base, which
# is a legacy PX4/drone image; this is the AI toolchain that `make ai` expects.
# syntax=docker/dockerfile:1
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-c"]

# Base toolchain: build essentials, git(+lfs), make, gh CLI, python, node.
RUN apt-get update -y && apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg lsb-release \
        git git-lfs make sudo unzip vim jq \
        build-essential \
        python3 python3-venv python3-dev \
        postgresql-client redis-tools \
    && git lfs install --system \
    # GitHub CLI (official apt repo)
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
    # Node.js 20 (NodeSource)
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get update -y && apt-get install -y --no-install-recommends gh nodejs \
    && rm -rf /var/lib/apt/lists/*

# Non-root dev user with passwordless sudo (Linux defaults 1000:1000; override
# UID/GID at build to match the host for clean bind-mount permissions).
ARG USER=dev
ARG UID=1000
ARG GID=1000
RUN groupadd -g "$GID" "$USER" 2>/dev/null || true \
    && useradd -m -u "$UID" -g "$GID" -s /bin/bash "$USER" \
    && echo "$USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-"$USER"
USER $USER
WORKDIR /home/$USER

# uv (Python 3.12 toolchain manager used across the repos) + pinned Python.
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
ENV PATH="/home/${USER}/.local/bin:${PATH}"
RUN uv python install 3.12

CMD ["sleep", "infinity"]
