FROM ghcr.io/xtruder/nix-devcontainer:v1
ADD . /workspaces/srvc-hello/
RUN nix-shell --command 'echo done building nix dev environment' /workspaces/srvc-hello/shell.nix
