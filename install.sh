#!/usr/bin/env bash
# 公开一键入口：装 git/curl/perl/python、GitHub CLI 交互登录、克隆私有仓库，
# 再进入项目用 nvm 装 Node、pnpm install、构建并启动。
#
# 必须用 bash -c，不要 curl | bash（管道会占掉 stdin，无法登录）：
#
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/ranmeizi/zhijia-mobile-installer/main/install.sh)"
#
set -euo pipefail

DEFAULT_GH_VERSION="2.97.0"
DEFAULT_OK_REPO="kanppa/prontera_ok"
DEFAULT_OK_BRANCH="master"
DEFAULT_OK_REPO_DIR="${HOME}/prontera_ok"
DEFAULT_RUNTIME_DIR="${HOME}/.prontera-ok"

log() { printf '[aidlux] %s\n' "$*"; }
warn() { printf '[aidlux] 警告: %s\n' "$*" >&2; }
die() { printf '[aidlux] 错误: %s\n' "$*" >&2; exit 1; }

GH_VERSION="${GH_VERSION:-$DEFAULT_GH_VERSION}"
OK_REPO="${OK_REPO:-$DEFAULT_OK_REPO}"
OK_BRANCH="${OK_BRANCH:-$DEFAULT_OK_BRANCH}"
OK_REPO_DIR="${OK_REPO_DIR:-$DEFAULT_OK_REPO_DIR}"
OK_RUNTIME_DIR="${OK_RUNTIME_DIR:-$DEFAULT_RUNTIME_DIR}"

if [[ $OK_REPO == *openkore/openkore* ]]; then
  die "禁止从官方 openkore 远程克隆"
fi

if [[ ! -t 0 ]]; then
  die "检测到 curl | bash，无法交互登录 GitHub。请改用:
  bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/ranmeizi/zhijia-mobile-installer/main/install.sh)\""
fi

set_apt_cmd() {
  if [[ $(id -u) -eq 0 ]]; then
    APT_CMD=(apt-get)
  elif command -v sudo >/dev/null 2>&1; then
    APT_CMD=(sudo apt-get)
  else
    die "需要 root 或 sudo 才能安装系统包"
  fi
}

ensure_system_packages() {
  if command -v git >/dev/null 2>&1 && command -v curl >/dev/null 2>&1 && command -v perl >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
    log "系统已有 git / curl / perl / python3"
    return 0
  fi
  command -v apt-get >/dev/null 2>&1 || die "需要 apt-get 才能安装 git / curl / perl / python3"
  set_apt_cmd
  log "apt 安装 git / curl / perl / python3 / 编译链"
  "${APT_CMD[@]}" update -y
  "${APT_CMD[@]}" install -y --no-install-recommends \
    git curl ca-certificates xz-utils tar \
    build-essential make \
    python3 python3-dev \
    perl libperl-dev
  hash -r || true
  command -v git >/dev/null 2>&1 || die "找不到 git"
  command -v curl >/dev/null 2>&1 || die "找不到 curl"
  command -v perl >/dev/null 2>&1 || die "找不到 perl"
  command -v python3 >/dev/null 2>&1 || die "找不到 python3"
}

linux_gh_arch() {
  case "$(uname -m)" in
    aarch64 | arm64) printf 'arm64' ;;
    x86_64 | amd64) printf 'amd64' ;;
    armv6l | armv7l) printf 'armv6' ;;
    *) die "不支持的 CPU 架构: $(uname -m)" ;;
  esac
}

install_gh_linux() {
  local arch name dest current url tarball sums line
  arch="$(linux_gh_arch)"
  name="gh_${GH_VERSION}_linux_${arch}"
  dest="${OK_RUNTIME_DIR}/gh/${name}"
  current="${OK_RUNTIME_DIR}/gh/current"
  mkdir -p "${OK_RUNTIME_DIR}/gh" "${OK_RUNTIME_DIR}/tmp" "${OK_RUNTIME_DIR}/bin"
  if [[ -x $dest/bin/gh ]]; then
    ln -sfn "$dest" "$current"
    ln -sfn "$current/bin/gh" "${OK_RUNTIME_DIR}/bin/gh"
    return 0
  fi
  tarball="${OK_RUNTIME_DIR}/tmp/${name}.tar.gz"
  url="https://github.com/cli/cli/releases/download/v${GH_VERSION}/${name}.tar.gz"
  sums="https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_checksums.txt"
  log "下载 GitHub CLI v${GH_VERSION} (${arch})"
  curl -fL --retry 3 --retry-delay 2 -o "$tarball" "$url"
  curl -fL --retry 3 --retry-delay 2 -o "${OK_RUNTIME_DIR}/tmp/gh_checksums.txt" "$sums"
  line="$(grep "  ${name}.tar.gz$" "${OK_RUNTIME_DIR}/tmp/gh_checksums.txt" || true)"
  [[ -n $line ]] || die "checksums 中没有 ${name}.tar.gz"
  (
    cd "${OK_RUNTIME_DIR}/tmp"
    if command -v sha256sum >/dev/null 2>&1; then
      printf '%s\n' "$line" | sha256sum -c -
    else
      printf '%s\n' "$line" | shasum -a 256 -c -
    fi
  )
  rm -rf "$dest"
  tar -xzf "$tarball" -C "${OK_RUNTIME_DIR}/gh"
  ln -sfn "$dest" "$current"
  ln -sfn "$current/bin/gh" "${OK_RUNTIME_DIR}/bin/gh"
  rm -f "$tarball"
  [[ -x $current/bin/gh ]] || die "GitHub CLI 安装失败"
  log "GitHub CLI $($current/bin/gh --version | head -n1)"
}

ensure_gh() {
  export PATH="${OK_RUNTIME_DIR}/bin:${PATH}"
  if command -v gh >/dev/null 2>&1; then
    log "使用已有 gh: $(command -v gh)"
    return 0
  fi
  if [[ $(uname -s) != Linux ]]; then
    die "请先安装 GitHub CLI: https://cli.github.com/"
  fi
  install_gh_linux
  command -v gh >/dev/null 2>&1 || die "PATH 中没有 gh"
}

ensure_gh_login() {
  if gh auth status --hostname github.com >/dev/null 2>&1; then
    log "GitHub CLI 已登录"
    gh auth setup-git --hostname github.com >/dev/null
    return 0
  fi
  cat <<'EOF'

接下来用 GitHub CLI 交互登录（设备码，不必在这台机器上打开图形浏览器）：
  1. 终端会显示一次性代码
  2. 用手机浏览器打开 https://github.com/login/device
  3. 输入代码，授权访问私有仓库 kanppa/prontera_ok

EOF
  if [[ -z ${DISPLAY-} && -z ${WAYLAND_DISPLAY-} ]]; then
    export GH_BROWSER="${GH_BROWSER:-echo}"
  fi
  GH_FORCE_TTY=1 gh auth login \
    --hostname github.com \
    --git-protocol https \
    --web \
    --skip-ssh-key
  gh auth status --hostname github.com >/dev/null 2>&1 || die "GitHub 登录未完成"
  gh auth setup-git --hostname github.com
  log "GitHub CLI 登录完成，已配置 git 凭据"
}

clone_private_repo() {
  if [[ -f $OK_REPO_DIR/openkore.pl && -f $OK_REPO_DIR/deploy/aidlux.sh ]]; then
    log "使用已有仓库 $OK_REPO_DIR ，拉取最新"
    git -C "$OK_REPO_DIR" pull --ff-only || warn "git pull 失败，继续使用当前代码"
    return 0
  fi
  if [[ -e $OK_REPO_DIR ]]; then
    die "$OK_REPO_DIR 已存在但不是 prontera_ok 仓库"
  fi
  log "克隆私有仓库 ${OK_REPO} (${OK_BRANCH}) → ${OK_REPO_DIR}"
  gh repo clone "$OK_REPO" "$OK_REPO_DIR" -- --branch "$OK_BRANCH" --single-branch
  [[ -f $OK_REPO_DIR/deploy/aidlux.sh ]] || die "克隆结果缺少 deploy/aidlux.sh"
}

run_project_install() {
  [[ -f $OK_REPO_DIR/deploy/aidlux.sh ]] || die "找不到 $OK_REPO_DIR/deploy/aidlux.sh"
  log "进入 $OK_REPO_DIR ，安装 nvm / Node / pnpm 并构建 ok-terminal"
  bash "$OK_REPO_DIR/deploy/aidlux.sh" install --start
}

log "======== 1/4 系统包 git / curl / perl / python3 ========"
ensure_system_packages
log "======== 2/4 GitHub CLI ========"
ensure_gh
log "======== 3/4 登录并克隆私有仓库 ========"
ensure_gh_login
clone_private_repo
log "======== 4/4 进入项目：nvm / Node / pnpm install / 启动 ========"
run_project_install
log "一键安装结束"
