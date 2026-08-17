# AidLux 公开安装入口

这个仓库是 **公开** 的，只放引导脚本。真正的 OpenKore / ok-terminal 仍在私有仓库 [`kanppa/prontera_ok`](https://github.com/kanppa/prontera_ok)。

AidLux 终端里执行（必须用 `bash -c`，不要 `curl | bash`，否则无法交互登录）：

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ranmeizi/zhijia-mobile-installer/main/install.sh)"
```

脚本会：

1. 安装 `git` / `curl`（若缺失）
2. 钉死安装 GitHub CLI（`gh` 2.97.0，官方 linux-arm64/amd64 tarball + SHA256）
3. 运行 `gh auth login`：终端显示一次性代码，用手机浏览器打开 https://github.com/login/device 授权
4. `gh auth setup-git`，之后 `git pull` 不用再贴 PAT
5. 克隆私有仓库到 `$HOME/prontera_ok`
6. 执行仓库内 `deploy/aidlux.sh install --start`

不会自动 `lianji`。默认监听 `0.0.0.0:8787`。

自定义目录：

```bash
OK_REPO_DIR=$HOME/src/prontera_ok bash -c "$(curl -fsSL https://raw.githubusercontent.com/ranmeizi/zhijia-mobile-installer/main/install.sh)"
```
