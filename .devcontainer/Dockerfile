FROM swift:5.8-jammy

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive  \
    && apt-get -y install --no-install-recommends curl ca-certificates \
    && bash -c "$(curl -fsSL "https://raw.githubusercontent.com/microsoft/vscode-dev-containers/main/script-library/common-debian.sh")" -- "true" "${USERNAME}" "${USER_UID}" "${USER_GID}" "true" "false" \
    && chsh --shell /bin/zsh ${USERNAME} \
    && bash -c "$(curl -fsSL "https://raw.githubusercontent.com/microsoft/vscode-dev-containers/main/script-library/docker-in-docker-debian.sh")" -- "true" "${USERNAME}" "true" "latest" "v2" \
    && apt-get clean -y && rm -rf /var/lib/apt/lists/*

USER ${USERNAME}

WORKDIR /workspaces
