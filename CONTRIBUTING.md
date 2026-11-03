# 参与贡献

感谢你愿意改进 DualWeChat。这个项目很小，保持简单、可靠、可审计比堆功能更重要。

## 提交之前

请确认：

- 在 macOS 12+ 上测试过，微信版本为 4.x；
- `bash -n setup.sh update.sh` 通过；
- `python3 -m py_compile generate_icon.py tools/build_assets.py` 通过；
- 如果改的是安装流程，在真实环境完整跑过一次 `./setup.sh`（不要只跑 `--check`）；
- 没有提交 `DualWeChat.app`、个人聊天记录、账号信息或任何密钥。

快速检查：

```bash
make check
```

## 项目结构

| 文件 | 作用 |
| --- | --- |
| `setup.sh` | 安装：复制、改 Bundle ID、换图标、重签名、刷新缓存 |
| `update.sh` | 版本检查与更新，调用 `setup.sh` 重建 |
| `generate_icon.py` | 从官方微信图标生成 10 套主题图标（.icns / .png） |
| `tools/build_assets.py` | 生成 README 用的 hero、主题墙和社交预览图 |
| `assets/` | 已生成的图片，README 直接引用 |

## 修改视觉素材

素材由脚本生成，不要手工覆盖 `assets/` 里的图片：

```bash
python3 tools/build_assets.py
```

脚本会读取本机 `/Applications/WeChat.app/Contents/Resources/AppIcon.icns`，用与安装时相同的算法渲染，因此 README 里的图标和用户实际得到的一致。

修改配色或排版时，请同时检查中英文两张图：

- `assets/hero.png` / `assets/hero-en.png`
- `assets/themes.png` / `assets/themes-en.png`
- `assets/social-preview.png`（GitHub 仓库设置 → Social preview 手动上传）

依赖：`pip3 install Pillow numpy`。

## 代码风格

- Shell：4 空格缩进，变量加引号，错误信息写清楚；新增参数要同步更新 `--help` 和 README。
- Python：保持零第三方依赖之外的简洁实现；图标渲染要确定性，避免每次生成不同结果。
- 文案：中文为主，英文同步；不要承诺“绝不封号”之类无法保证的结果。

## 提交信息

所有 commit message 统一使用英文，建议采用 `type: summary` 格式：

```text
feat: add --keep-icon
fix: refresh icon cache on macOS 26
docs: clarify Intel support
style: refine theme gallery layout
```

这样便于国际协作者检索，也让 changelog 更容易生成。

## Pull Request

请在 PR 描述里写清楚：

1. 改了什么、为什么改；
2. 测试环境（macOS 版本、芯片、微信版本）；
3. 如果是界面/素材变更，附上一张对比图；
4. 是否有破坏性变更（参数、默认值、文件结构）。

## Issue

提交 bug 前请先看 README 的「常见问题」和「故障排查」。附上：

```bash
./setup.sh --check
```

的输出，以及复现步骤和完整报错。请勿粘贴账号、手机号或聊天内容。

## License

提交的代码默认按本项目的 [CC BY-NC 4.0](LICENSE) 授权；商业使用需另行获得作者授权，详见 [COMMERCIAL.md](COMMERCIAL.md)。
