#
# Dockerfile to launch Claude Code
#
# There is an official devcontainer. You may use the official one instead of this Dockerfile.
#   https://github.com/anthropics/claude-code/blob/main/.devcontainer/Dockerfile
#
# ## Features of this Dockerfile
#
# - Various customizations
# - Not based on devcontainer; use by attaching VSCode to the container
# - Assumes host OS is Mac
#
# ## Preparation
#
# Uses ssh-agent. Please refer to the link and configure your host OS.
#   https://github.com/uraitakahito/hello-docker/blob/26a7813c90d0c02f321a28336536f0f5d152c93d/README.md#ssh-git-clone-from-github-inside-docker
#
# ## From Docker build to login
#
# Build the Docker image:
#
#   PROJECT=$(basename `pwd`) && docker image build --no-cache -t $PROJECT-image . --build-arg user_id=`id -u` --build-arg group_id=`id -g` --build-arg TZ=Asia/Tokyo
#
# Start the Docker container:
#
#   docker container run -d --rm --init -v $SSH_AUTH_SOCK:/ssh-agent -e SSH_AUTH_SOCK=/ssh-agent --env-file ~/.env --mount type=bind,src=`pwd`,dst=/app --name $PROJECT-container $PROJECT-image
#
# Log in to Docker:
#
#   fdshell /bin/zsh
#
# About fdshell:
#   https://github.com/uraitakahito/dotfiles/blob/37c4142038c658c468ade085cbc8883ba0ce1cc3/zsh/myzshrc#L93-L101
#
# ## Change socket permissions
#
# Change the socket permissions. This is not ideal, so let me know if there is a better way.
#
#   sudo chmod 777 $SSH_AUTH_SOCK
#
# ## Launch Claude
#
#   claude --dangerously-skip-permissions
#
# ## Connect from Visual Studio Code
#
# 1. Open **Command Palette (Shift + Command + p)**
# 2. Select **Dev Containers: Attach to Running Container**
# 3. Open the `/app` directory
#
# For details:
#   https://code.visualstudio.com/docs/devcontainers/attach-container#_attach-to-a-docker-container
#

# Debian 12.11
FROM debian:bookworm-20250721

ARG user_name=developer
ARG user_id
ARG group_id
ARG dotfiles_repository="https://github.com/uraitakahito/dotfiles.git"
ARG features_repository="https://github.com/uraitakahito/features.git"
ARG extra_utils_repository="https://github.com/uraitakahito/extra-utils.git"
# Refer to the following URL for Node.js versions:
#   https://nodejs.org/en/about/previous-releases
ARG node_version="24.4.0"

#
# Git
#
RUN apt-get update -qq && \
  apt-get install -y -qq --no-install-recommends \
    ca-certificates \
    git && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*

#
# clone features
#
RUN cd /usr/src && \
  git clone --depth 1 ${features_repository}

#
# Add user and install common utils.
#
RUN USERNAME=${user_name} \
    USERUID=${user_id} \
    USERGID=${group_id} \
    CONFIGUREZSHASDEFAULTSHELL=true \
    UPGRADEPACKAGES=false \
      /usr/src/features/src/common-utils/install.sh

#
# Install extra utils.
#
RUN cd /usr/src && \
  git clone --depth 1 ${extra_utils_repository} && \
  ADDEZA=true \
    /usr/src/extra-utils/utils/install.sh

COPY docker-entrypoint.sh /usr/local/bin/

#
# Install Node
#   https://github.com/uraitakahito/features/blob/develop/src/node/install.sh
#
RUN INSTALLYARNUSINGAPT=false \
    NVMVERSION="latest" \
    PNPM_VERSION="none" \
    USERNAME=${user_name} \
    VERSION=${node_version} \
      /usr/src/features/src/node/install.sh

#
# Install uv
# https://docs.astral.sh/uv/guides/integration/docker/#installing-uv
#
RUN curl --fail-early --silent --show-error --location https://astral.sh/uv/install.sh --output /tmp/uv-install.sh && \
  # Changing the install path
  # https://github.com/astral-sh/uv/blob/main/docs/configuration/installer.md#changing-the-install-path
  UV_INSTALL_DIR=/bin sh /tmp/uv-install.sh && \
  rm /tmp/uv-install.sh

USER ${user_name}

#
# dotfiles
#
RUN cd /home/${user_name} && \
  git clone --depth 1 ${dotfiles_repository} && \
  dotfiles/install.sh

#
# Claude Code
#
# Discussion about using nvm during Docker container build:
#   https://stackoverflow.com/questions/25899912/how-to-install-nvm-in-docker
ARG TZ
ENV TZ="$TZ"
ENV NVM_DIR=/usr/local/share/nvm
RUN bash -c "source $NVM_DIR/nvm.sh && \
             nvm use ${node_version} && \
             npm install -g @anthropic-ai/claude-code"

WORKDIR /app
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["tail", "-F", "/dev/null"]
