# 迭代版本保存与 GitHub 上传

## 推荐保存点

不要在每次文件保存时上传。FPGA 工程会产生大量尚未验证的 HDL 中间状态和 TD 构建文件。建议每完成一个可说明的功能，或每次 TD 验证通过后，保存一个迭代检查点。

## 一键保存命令

在工程根目录运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\complete-hx4s20c-hdmi-project\scripts\save_iteration.ps1 `
  -Message "feat: describe the completed change"
```

该命令会依次执行：

1. 运行结构检查和 BMP 资产检查；
2. 将当前工程变更加入 Git；
3. 创建本地提交；
4. 尝试推送到 `origin/main`。

稳定版本可以追加标签：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\complete-hx4s20c-hdmi-project\scripts\save_iteration.ps1 `
  -Message "feat: finish OSD and fade transition" -Tag v0.2
```

## GitHub 连接器回退

本机 Git HTTPS 推送受网络环境影响时，脚本仍会保留本地提交并返回退出码 `2`。此时在 Codex 中说“上传本次迭代到 GitHub”，Codex 应使用 GitHub 连接器把本地提交内容写入 `gezhe1012/lab_ex5_i2s` 的 `main`，然后读取远端提交确认上传成功。

## 提交约定

- `feat:` 新功能或赛题扩展要求
- `fix:` 缺陷修复
- `test:` 验证、仿真或板级测试
- `build:` TD 工程、IP 或约束变更
- `docs:` 说明文档和 skill 更新

`main` 保存可复现的稳定检查点；较大的新功能可先建立 `feature/<name>` 分支，验证通过后再合并到 `main`。

## 不进入普通版本历史的内容

`.gitignore` 已排除 TD 的 `_Runs`、日志和临时文件。源码、`.al` 工程、约束、IP 配置、测试图片、音频资源、验证脚本和项目 skill 会被保存。
