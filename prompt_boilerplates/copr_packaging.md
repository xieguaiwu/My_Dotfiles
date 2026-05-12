---
name: copr-packaging
version: 1.0.0
description: 将项目打包为RPM并上传到COPR仓库
triggers:
  - "copr打包"
  - "RPM打包"
  - "上传copr"
  - "fedora打包"
inputs:
  - name: project_path
    description: 项目目录路径
    required: true
  - name: github_repo
    description: GitHub仓库地址
    required: true
  - name: email
    description: 邮箱(用于changelog)
    required: true
  - name: github_user
    description: GitHub用户名
    required: true
  - name: maintainer
    description: 维护者名称
    required: false
  - name: version
    description: 版本号
    required: false
    default: "1.0.0"
tools:
  - read
  - write
  - bash
  - glob
---

# COPR 打包

请深入分析这个问题，提供详细的推理过程，考虑多种可能的方案并比较优劣。

---

## 前置要求

### 用户需提供的信息
1. **项目路径**: 本地项目目录位置
2. **GitHub 仓库地址**: `https://github.com/xieguaiwu/仓库名`
3. **个人信息**:
   - 邮箱 (用于 changelog)
   - GitHub 用户名
   - 昵称/姓名 (可选)
4. **版本号**: 首次发布通常为 `1.0.0`

### 环境要求
- Fedora / RHEL / CentOS 系统
- 已安装 `copr-cli` 并配置好 token
- 已安装 `rpmbuild`
- 已通过 `gh auth login` 登录 GitHub CLI

---

## Prompt 模板

### 基础 Prompt

```
请将 @[项目目录]/ 打包为 RPM 并上传到 dnf copr。
GitHub 仓库地址: https://github.com/[用户名]/[仓库名]
使用 [邮箱] 作为邮箱，[GitHub用户名] 作为 GitHub 用户名，[昵称] 作为 maintainer 名字。
版本号: [版本号]
```

### 完整示例

```
请将 @GameOfLife/ 打包为 RPM 并上传到 dnf copr。
GitHub 仓库地址: https://github.com/xieguaiwu/Game_Of_Life
使用 xieguaiwu@163.com 作为邮箱，xieguaiwu 作为 GitHub 用户名，xgw 作为 maintainer 名字。
版本号: 1.0.0
```

---

## AI 执行流程

### 1. 项目分析
AI 会自动:
- 读取项目源代码和 README
- 识别项目类型 (C/C++/Python 等)
- 确定依赖项
- 检查许可证

### 2. 创建 Spec 文件
AI 会生成 `packaging/fedora/[项目名].spec`，包含:
- 基本信息 (Name, Version, Release, Summary)
- 许可证和 URL
- 构建依赖和运行依赖
- `%prep`, `%build`, `%install` 脚本
- `%files` 列表
- `%changelog`

### 3. 创建 GitHub Release
- 创建 git tag `v[版本号]`
- 发布 GitHub Release
- 可选: 上传 RPM 包作为 assets

### 4. 构建 SRPM
- 下载源码 tarball
- 运行 `rpmbuild -bs` 生成 SRPM

### 5. 创建 COPR 项目并构建
```bash
copr create [用户名]/[项目名] --chroot fedora-42-x86_64 --description "..." --instructions "..."
copr build [用户名]/[项目名] [SRPM路径]
```

### 6. 更新文档
- 在 README.md 添加 COPR 安装说明
- 推送到 GitHub

---

## Spec 文件模板

### C/C++ 项目

```spec
Name:           [包名]
Version:        [版本号]
Release:        1%{?dist}
Summary:        [简短描述]

License:        [MIT/GPL/BSD/etc]
URL:            https://github.com/[用户名]/[仓库名]
Source0:        %{url}/archive/v%{version}.tar.gz#/%{name}-%{version}.tar.gz

BuildRequires:  gcc
# 或 BuildRequires: gcc-c++  (C++项目)
Requires:       glibc

%description
[详细描述]

%prep
%setup -q -n [仓库名]-%{version}

%build
gcc %{optflags} -o [输出文件] [源文件.c]
# 或 g++ %{optflags} -o [输出文件] [源文件.cpp]

%install
rm -rf %{buildroot}
install -Dm755 [可执行文件] %{buildroot}%{_bindir}/[可执行文件]
install -Dm644 LICENSE %{buildroot}%{_defaultlicensedir}/%{name}/LICENSE
install -Dm644 README.md %{buildroot}%{_defaultdocdir}/%{name}/README.md

%files
%license LICENSE
%doc README.md
%{_bindir}/[可执行文件]

%changelog
* [日期] [姓名] <[邮箱]> - [版本号]-1
- Initial package
```

### Python 项目

```spec
Name:           [包名]
Version:        [版本号]
Release:        1%{?dist}
Summary:        [简短描述]

License:        [许可证]
URL:            https://github.com/[用户名]/[仓库名]
Source0:        %{url}/archive/v%{version}.tar.gz#/%{name}-%{version}.tar.gz

BuildRequires:  python3-devel
BuildRequires:  python3-setuptools
Requires:       python3

%description
[详细描述]

%prep
%setup -q -n [仓库名]-%{version}

%build
%py3_build

%install
%py3_install

%files
%license LICENSE
%doc README.md
%{python3_sitelib}/[包名]*
```

---

## 注意事项

### 1. GitHub Tarball 目录命名
GitHub 生成的 tarball 目录格式为 `[仓库名]-[版本号]`，不是 `[包名]-[版本号]`。

**解决方法**: 在 `%prep` 中指定目录名
```spec
%setup -q -n [仓库名]-%{version}
```

### 2. Source0 格式
使用 `#/` 重命名下载的文件:
```spec
Source0: %{url}/archive/v%{version}.tar.gz#/%{name}-%{version}.tar.gz
```

### 3. 许可证
确保项目根目录有 `LICENSE` 文件，常见许可证:
- MIT → `License: MIT`
- GPL-3.0 → `License: GPL-3.0-or-later`
- Apache-2.0 → `License: Apache-2.0`

### 4. COPR 支持的 chroot
查看可用 chroot:
```bash
copr list-chroots
```
常用:
- `fedora-42-x86_64`
- `fedora-41-x86_64`
- `rhel-9-x86_64`

### 5. 日期格式警告
changelog 日期必须是实际日期，否则会有警告 (但不影响构建):
```spec
* Mon Mar 17 2026 xgw <xieguaiwu@163.com> - 1.0.0-1
```

### 6. 多文件项目
如果项目有多个源文件，需要在 `%build` 中正确编译:
```spec
%build
gcc %{optflags} -o myapp main.c utils.c parser.c
```

### 7. 文件写入安全

使用 `write` 前必须用 `glob` 或 `read` 确认目标 spec 文件或 README 是否已存在。若文件已存在，优先用 `edit` 追加/修改，而非直接 `write` 覆写。确需覆写须先告知用户。

### 8. 数据文件
如果项目包含示例文件、配置文件等:
```spec
%install
install -Dm644 example.conf %{buildroot}%{_sysconfdir}/myapp.conf
install -Dm644 examples/*.txt %{buildroot}%{_defaultdocdir}/%{name}/examples/

%files
%config(noreplace) %{_sysconfdir}/myapp.conf
%doc examples/
```

---

## 常见错误排查

### 错误: 下载失败
```
error: File not found: .../v1.0.0.tar.gz
```
**原因**: GitHub Release 未创建或 tag 不存在
**解决**: 先创建 Release `gh release create v1.0.0`

### 错误: %setup 目录不存在
```
error: File not found: .../mypackage-1.0.0
```
**原因**: tarball 解压目录名与 spec 不匹配
**解决**: 使用 `%setup -q -n [实际目录名]`

### 错误: COPR chroot 无效
```
Error: chroots: 'fedora-40-x86_64' are not valid choices
```
**原因**: 该 Fedora 版本已 EOL 或 COPR 不支持
**解决**: 使用 `copr list-chroots` 查看可用选项

### 错误: copr-cli 未配置
```
Error: No configuration file found
```
**解决**: 访问 https://copr.fedorainfracloud.org/api/ 获取 token，写入 `~/.config/copr`

---

## 完整 Prompt 示例集

### 场景 1: 简单 C 项目

```
请将 @bullet_note/ (github repo: https://github.com/xieguaiwu/Smoking_Note) 打包为rpm并上传到dnf copr
```

### 场景 2: 提供完整信息

```
请将 @myproject/ 打包为 RPM 并上传到 COPR。

项目信息:
- GitHub: https://github.com/username/myproject
- 邮箱: user@example.com
- GitHub 用户名: username
- 昵称: John
- 版本: 1.0.0
- 描述: 一个简单的命令行工具
```

### 场景 3: 仅创建 Spec 文件

```
请为 @myproject/ 创建 COPR 打包所需的 RPM spec 文件。
GitHub 仓库: https://github.com/username/myproject
```

### 场景 4: 更新已发布项目

```
请将 myproject 更新到版本 1.1.0 并重新构建 COPR 包。
GitHub: https://github.com/username/myproject
```

---

## 后续维护

### 更新版本
1. 修改 spec 文件中的 `Version`
2. 增加 `Release` 或重置为 `1`
3. 添加新的 changelog 条目
4. 更新 sha256sum (如果有)
5. 创建新 GitHub Release
6. 重新构建 SRPM 并上传

### 添加新 chroot
```bash
copr modify [用户名]/[项目名] --chroot fedora-43-x86_64
copr build [用户名]/[项目名] [SRPM]
```

---

## 参考链接

- COPR 文档: https://docs.pagure.org/copr.copr/
- Fedora 打包指南: https://docs.fedoraproject.org/en-US/Packaging_Guidelines/
- RPM Spec 语法: https://rpm-software-management.github.io/rpm/manual/spec.html
- GitHub CLI: https://cli.github.com/manual/
