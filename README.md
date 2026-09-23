# 33-206 公共采购与 AA（独立部署版 · 室友不用注册）

纯静态网页 + Supabase 免费后端，不依赖 Claude。室友点开你发的链接就能用，不注册、不登录：
链接里带一个「宿舍口令」，网页第一次打开时记住它，之后每次请求都凭这个口令读写数据；没有口令的人（包括看到了代码仓库的人）什么也读不到、写不了。

```
index.html            网页本身（清单 / 账单 / 结算 / 统计）
config.js             ← 只需要改这个文件：填 Supabase 地址和 anon key
manifest.webmanifest  让手机可以"添加到主屏幕"当 App 用
icon-*.png            App 图标
supabase/schema.sql   建表 + 口令 + 权限 + 照片桶，在 Supabase 里运行一次
supabase/seed.sql     可选，把原 Excel 里的 4 个名字和 7 件物品导进去
```

整个过程约 10 分钟，全部免费。

## 一、建后端（Supabase）

1. 打开 https://supabase.com 注册并 **New project**（区域选离你们近的，比如 West US）。设一个数据库密码，之后基本用不到。
2. 左侧 **SQL Editor → New query**，把 `supabase/schema.sql` 整个粘进去，点 **Run**。
   下方结果区会显示一行 **宿舍口令**（8 位随机字母数字），记下来。
3. （可选）同样方法运行 `supabase/seed.sql`，导入原来的名单和 7 件物品。
4. 左侧 **Project Settings → API**，复制 **Project URL** 和 **anon public** key，填进 `config.js`：

```js
window.DORM_CONFIG = {
  supabaseUrl: 'https://xxxxxxxx.supabase.co',
  supabaseAnonKey: 'eyJhbGciOi……',
};
```

anon key 设计上就是公开的，放在前端没问题；数据安全靠"必须带口令"的行级策略保证，口令只存在数据库里和室友的手机里，不在代码里。**service_role key 绝对不要放进前端。**

## 二、部署前端（二选一）

### GitHub Pages
1. GitHub 新建一个 **Public** 仓库（Pages 免费额度只对公开仓库开放；仓库公开没关系，口令不在里面）。
2. 把这个文件夹里的所有文件上传到仓库根目录（网页版 **Add file → Upload files** 直接拖进去；`supabase` 文件夹不上传也行）。
3. 仓库 **Settings → Pages → Build and deployment**：Source 选 **Deploy from a branch**，Branch 选 `main` / `/ (root)`，Save。
4. 一两分钟后页面上会显示网址，形如 `https://你的用户名.github.io/仓库名/`。

### Vercel
1. 在 https://vercel.com/new 里导入 GitHub 仓库（可以是私有仓库），或者直接拖拽上传这个文件夹。
2. Framework Preset 选 **Other**，其余不用改，Deploy，得到 `https://xxx.vercel.app`。

以后改 `config.js` 或换版本，重新上传文件即可。

## 三、第一次使用 & 邀请室友

1. 你自己打开 `https://你的网址/#code=宿舍口令`（把口令接在 `#code=` 后面）。网页会记住口令并把它从地址栏里去掉。
2. 右上角 ⚙ 设置：确认室友名单、货币符号，选好"这台设备上我是"。
3. 设置里有 **邀请室友的链接**，点「复制链接」发到宿舍群。室友点开即用，什么都不用填。
4. 手机上"添加到主屏幕"（iOS 用 Safari 分享菜单，Android 用 Chrome 菜单），就像 App 一样有图标、全屏打开。

## 四、需要知道的几件事

- **拿到邀请链接的人就有全部读写权限**，所以链接只发给室友。有人搬走要换口令：SQL Editor 里运行
  `update private.room_secret set code = '新口令' where id = 1;`，然后重新发邀请链接；旧口令的设备会提示重新输入。
- 同步方式是每 10 秒自动刷新一次（切回页面时立即刷新），室友的改动最多 10 秒后出现；自己的操作立即可见。
- **Supabase 免费项目一周没人访问会暂停**（数据不丢），去控制台点一下 Restore 就恢复。4 个人正常在用一般不会触发。
- 小票照片桶是"公开可看"：拿到某张图完整链接的人可以看到那张图（链接是随机的，猜不到）；上传限 5 MB 的图片。
- 备份/导出：Supabase 控制台 **Table Editor** 里任意表都能导出 CSV。
- 换室友名单：设置里改即可；旧账单上的旧名字不会自动改，结算页会提醒。
- 多人同时操作以"后写入者为准"，正常使用不会冲突。
- 这套代码只对接了 Supabase；LeanCloud 的权限方式不同，需要另写适配层。
