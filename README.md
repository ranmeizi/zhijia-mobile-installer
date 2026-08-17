# AidLux 公开安装入口

这个仓库是 **公开** 的，只放引导脚本。真正的 OpenKore / ok-terminal 仍在私有仓库 [`kanppa/prontera_ok`](https://github.com/kanppa/prontera_ok)。

AidLux 终端里执行（必须用 `bash -c`，不要 `curl | bash`，否则无法交互登录）：

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ranmeizi/zhijia-mobile-installer/main/install.sh)"
```

脚本会：

1. apt 安装 `git` / `curl` / `perl` / `python3` 和编译链
2. 钉死安装 GitHub CLI（`gh` 2.97.0）
3. `gh auth login` 设备码登录，克隆私有仓库 `kanppa/prontera_ok`
4. **进入项目**执行 `deploy/aidlux.sh install --start`：nvm + Node 22、pnpm、`tools/ok_terminal` 的 `pnpm install && pnpm build`，并启动控制台


不会自动 `lianji`。默认监听 `0.0.0.0:8787`。

自定义目录：

```bash
OK_REPO_DIR=$HOME/src/prontera_ok bash -c "$(curl -fsSL https://raw.githubusercontent.com/ranmeizi/zhijia-mobile-installer/main/install.sh)"
```
