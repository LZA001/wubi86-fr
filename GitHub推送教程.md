# GitHub 推送教程 —— 五笔 86・拼音输入法

本教程把「五笔 86・拼音输入法」源码推送到 GitHub。**联系人数据（人名 + 邮箱）已全部移除**，安装包已重新打包为干净版。



***

## 一、推送前准备



1. **GitHub 账号**：没有先去 [https://github.com](https://github.com) 注册。

2. **Git 已安装**：本机已装（git 2.53.0）。其他电脑如未装：[https://git-scm.com/download/win](https://git-scm.com/download/win) 一路 Next。

3. **确认安装包干净**（已完成）：

* 词库已无任何联系人条目（fr\_data 206,145 条 / 五笔码表 140,341 词 / 拼音术语 614 词）

* 安装说明.md、install.ps1 已删除联系人章节

* zip 与安装包目录已用隐私扫描确认无 `@wietc`、人名、邮箱残留



***

## 二、在 GitHub 网页端新建仓库（1 分钟）



1. 登录 GitHub → 右上角 **+** → **New repository**

2. 填写：

* **Repository name**：`wubi86-fr`（或你喜欢的名字）

* **Description**：`Rime 五笔86+拼音输入方案，候选带中法对照注释（法语）`

* **Public / Private**：选 **Public**（要公开分享）或 **Private**（仅自己）

* ⚠️ **不要勾选** "Add a README file"、"Add .gitignore"、"Add a license"（保持空仓库，避免冲突）

1. 点 **Create repository**

2. 创建后页面会显示仓库地址，记下 HTTPS 地址，形如：

   `https://github.com/你的用户名/wubi86-fr.git`



***

## 三、本地初始化并推送

> ⚠️ 本项目所在目录位于 
>
> `C:\Users\Administrator`
>
>  主仓库内，
>
> **必须在项目目录里单独&#x20;**
>
> `git init`
>
> （嵌套仓库完全合法，互不影响）。切勿在 
>
> `C:\Users\Administrator`
>
>  直接 add/push（会把整个用户目录推上去）。

在&#x2A;*项目根目录** `C:\Users\Administrator\Doubao\chats\2026-10-08\new-chat\五笔86拼音输入法\` 打开 PowerShell（在文件夹地址栏输入 `powershell` 回车），依次执行：

### 第 1 步：配置身份（仅首次）



```
git config --global user.name "你的GitHub用户名"
git config --global user.email "你的GitHub注册邮箱"
```

### 第 2 步：初始化仓库



```
git init
git branch -M main
```

### 第 3 步：写 .gitignore（排除调试脚本与安装包）

把下面内容保存为项目根下的 `.gitignore` 文件（记事本新建，文件名就是 `.gitignore`）：



```
# 开发工具与调试脚本（含联系人测试样例，不推送）
tools/

# 安装包（zip 建议走 GitHub Releases，见第五节）
*.zip
五笔86拼音输入法-安装包/
```

### 第 4 步：暂存并提交



```
git add .
git commit -m "五笔86·拼音输入法：五笔+拼音双通道，候选带中法对照注释"
```

> 想先看看会提交哪些文件：
>
> `git status`
>
> 。确认列表里只有 13 个方案文件 + 安装说明.md + .gitignore，
>
> **没有 tools/**
>
> 。

### 第 5 步：关联远程仓库并推送



```
git remote add origin https://github.com/你的用户名/wubi86-fr.git
git push -u origin main
```

### 第 6 步：认证（首次 push）

弹出 GitHub 登录框时：



* **方式一（推荐，HTTPS + Token）**：

1. 先到 GitHub 生成 Token：头像 → **Settings** → 左下角 **Developer settings** → **Personal access tokens** → **Tokens (classic)** → **Generate new token (classic)**

2. 勾选 **repo** 权限，有效期选 90 天，点生成

3. 复制 token（形如 `ghp_xxxx`）

4. 回 push 窗口：**用户名**填你的 GitHub 用户名，**密码**粘贴 token（不是登录密码）

* **方式二（SSH）**：教程见 [https://docs.github.com/zh/authentication/connecting-to-github-with-ssh](https://docs.github.com/zh/authentication/connecting-to-github-with-ssh)

push 成功会显示 `branch 'main' set up to track ...`，到 GitHub 网页刷新即可看到文件。



***

## 四、以后更新代码

改了任何文件后，在项目目录执行：



```
git add .
git commit -m "更新说明"
git push
```



***

## 五、把安装包发到 GitHub Releases（可选，推荐）

zip（5.1MB）不适合放仓库，建议走 **Releases** 附件，别人下载解压即用：



1. GitHub 仓库页 → 右侧 **Releases** → **Create a new release**

2. Tag 填 `v1.0.0`，标题填 `五笔86·拼音输入法 1.0`

3. 把 `五笔86拼音输入法-安装包.zip` 拖进 **Attach binaries** 上传

4. 点 **Publish release**

5. 发布后其他人点 Releases → 下载 zip 即可（附一句：需先装小狼毫，双击 一键安装.bat）



***

## 六、推送前隐私复核清单（本项目已全部通过）



| 检查项              | 状态                                           |
| ---------------- | -------------------------------------------- |
| 词库内无联系人（人名 / 邮箱） | ✅ fr\_data 206,145 / 码表 140,341 / 术语 614     |
| 安装说明 / 脚本无邮箱样例   | ✅ 已删除联系人章节                                   |
| tools 调试脚本不推送    | ✅ .gitignore 排除                              |
| CSV 源文件不在项目内     | ✅ 在 `e:\Users\Administrator\Documents\`，不会推送 |
| 安装包 zip 不占仓库     | ✅ 走 Releases                                 |

## 七、常见问题



* **push 报 "fatal: remote origin already exists"**：说明之前配置过，先 `git remote remove origin` 再重新 add。

* **push 报 "error: src refspec main does not match any"**：说明没有 commit 成功，检查 `git status` 是否有暂存内容，先 commit。

* **push 报认证失败**：Token 过期或权限不足，重新生成并勾选 repo。

* **想把 tools/ 也推上去**：删除 .gitignore 里的 `tools/` 行，但**必须先清理** tools 下测试脚本中的真实邮箱 / 人名样例（如 test\_contacts\_*.py、verify\_contacts*.py、debug\_commit\*.py、regression\_test.py 中的 `bikeqi@wietc.com`、毕可岐 等字样），或直接删掉这些联系人相关脚本再推。