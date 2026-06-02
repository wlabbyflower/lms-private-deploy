# Moodle using Open edX through LTI

# Moodle 通过 LTI 使用 Open edX

English is shown first. Chinese follows each major instruction.

英文说明在前，中文说明跟随在每个主要步骤之后。

## Recommended roles / 推荐角色分工

Use Moodle as the learner entry point. Use Open edX Studio to author reusable courseware. Add selected Open edX units/components into Moodle as External Tool activities.

使用 Moodle 作为学习者入口。使用 Open edX Studio 制作可复用课件。把选定的 Open edX unit/component 添加到 Moodle，作为 External Tool 活动。

## Step 1: Create Open edX content / 第 1 步：创建 Open edX 内容

1. Open Studio: `http://studio.NEW_IP.sslip.io`
2. Create a course.
3. Add the content you want to expose: a subsection, a unit, or an individual component.
4. Publish the content.

中文步骤：

1. 打开 Studio：`http://studio.NEW_IP.sslip.io`
2. 创建课程。
3. 添加需要开放给 Moodle 的内容：subsection、unit 或单个 component。
4. 发布内容。

Open edX can expose subsections, units, or components through LTI. Sections are not supported.

Open edX 可以通过 LTI 暴露 subsection、unit 或 component，不支持直接暴露 section。

## Step 2: Create Moodle as an LTI consumer / 第 2 步：在 Open edX 注册 Moodle

1. Open the Open edX LMS admin: `http://openedx.NEW_IP.sslip.io/admin`
2. Log in as the Open edX superuser.
3. Go to `LTI Provider` -> `LTI Consumers` -> `Add`.
4. Use:
   - Consumer name: `moodle`
   - Consumer key: generate or set a stable value, for example `moodle-lti`
   - Consumer secret: generate a strong secret
   - Instance GUID: leave blank
5. Authentication choice:
   - Easiest: leave `Require user account` and `Use lti pii` unchecked. Learners launch smoothly and grade passback still maps to the Moodle learner.
   - Better identity mapping: enable `Use lti pii` and configure Moodle to share learner email.
   - Strict mapping: enable `Require user account` only if learners already have matching Open edX accounts and Moodle sends email.
6. Save and copy the Consumer Key and Consumer Secret.

中文步骤：

1. 打开 Open edX LMS 管理后台：`http://openedx.NEW_IP.sslip.io/admin`
2. 使用 Open edX 超级管理员登录。
3. 进入 `LTI Provider` -> `LTI Consumers` -> `Add`。
4. 填写：
   - Consumer name：`moodle`
   - Consumer key：生成或设置一个稳定值，例如 `moodle-lti`
   - Consumer secret：生成强密码
   - Instance GUID：留空
5. 身份策略：
   - 最简单：不勾选 `Require user account` 和 `Use lti pii`。学习者可以顺畅启动，成绩回传仍会映射到 Moodle 学习者。
   - 更好的身份映射：勾选 `Use lti pii`，并配置 Moodle 发送学习者 email。
   - 严格映射：只有两边已经存在匹配账号、且 Moodle 发送 email 时，才启用 `Require user account`。
6. 保存并复制 Consumer Key 和 Consumer Secret。

## Step 3: Build the Open edX LTI launch URL / 第 3 步：构造 Open edX LTI 启动 URL

The URL format is:

URL 格式：

```text
http://openedx.NEW_IP.sslip.io/lti_provider/courses/{course_id}/{usage_id}
```

Find `course_id` from the course URL. It looks like:

从课程 URL 中获取 `course_id`，格式类似：

```text
course-v1:ORG+COURSE+RUN
```

Find `usage_id`:

获取 `usage_id`：

- For a component or unit, open the courseware page as staff and use `Staff Debug Info`.
- Component usage ID is the `location` value.
- Unit usage ID is the `parent` value.
- For a subsection, copy it from the courseware URL. It usually contains `type@sequential`.

对应中文：

- 对于 component 或 unit，以 staff 身份打开课程页，查看 `Staff Debug Info`。
- component 的 usage ID 使用 `location` 值。
- unit 的 usage ID 使用 `parent` 值。
- subsection 通常可从 courseware URL 中复制，一般包含 `type@sequential`。

## Step 4: Add Open edX as a Moodle External Tool / 第 4 步：在 Moodle 添加 External Tool

1. Open Moodle: `http://moodle.NEW_IP.sslip.io:18081`
2. Go to `Site administration` -> `Plugins` -> `Activity modules` -> `External tool` -> `Manage tools`.
3. Choose `Configure a tool manually`.
4. Use:
   - Tool name: `Open edX`
   - Tool URL: the LTI launch URL from Step 3
   - LTI version: LTI 1.1
   - Consumer key: the Open edX consumer key
   - Shared secret: the Open edX consumer secret
   - Default launch container: `New window`
   - Share launcher's name: optional
   - Share launcher's email: enable if using Open edX `Use lti pii` or `Require user account`
   - Accept grades from the tool: enable if the Open edX content is graded
   - Configuration usage: show in activity chooser
5. Save.

中文步骤：

1. 打开 Moodle：`http://moodle.NEW_IP.sslip.io:18081`
2. 进入 `Site administration` -> `Plugins` -> `Activity modules` -> `External tool` -> `Manage tools`。
3. 选择 `Configure a tool manually`。
4. 填写：
   - Tool name：`Open edX`
   - Tool URL：第 3 步得到的 LTI 启动 URL
   - LTI version：LTI 1.1
   - Consumer key：Open edX 中配置的 consumer key
   - Shared secret：Open edX 中配置的 consumer secret
   - Default launch container：`New window`
   - Share launcher's name：可选
   - Share launcher's email：如果 Open edX 启用了 `Use lti pii` 或 `Require user account`，则启用
   - Accept grades from the tool：如果 Open edX 内容有成绩，则启用
   - Configuration usage：show in activity chooser
5. 保存。

## Step 5: Add the tool inside a Moodle course / 第 5 步：在 Moodle 课程中添加工具

1. Open a Moodle course.
2. Turn editing on.
3. Add an activity or resource.
4. Select the configured `Open edX` external tool.
5. Save and test as a learner.

中文步骤：

1. 打开一个 Moodle 课程。
2. 开启编辑模式。
3. 添加 activity 或 resource。
4. 选择已配置的 `Open edX` external tool。
5. 保存，并以学习者身份测试。

## Grade passback / 成绩回传

For best grade behavior, link directly to a graded Open edX problem component. Component scores are returned immediately. Unit/subsection links aggregate grades and may take around 15 minutes.

为了获得更稳定的成绩回传，建议直接链接到带成绩的 Open edX problem component。Component 分数会立即返回。Unit/subsection 链接会聚合成绩，可能需要约 15 分钟。

## HTTPS and iframe note / HTTPS 和 iframe 说明

This deployment starts on HTTP for testing. Moodle's LTI page warns that HTTPS is preferable and HTTP tools can show blank pages in some configurations. Keep `Default launch container` as `New window` during testing.

本部署默认使用 HTTP 便于测试。Moodle 的 LTI 页面会提示 HTTPS 更合适，HTTP 工具在某些配置中可能显示空白页。测试阶段建议把 `Default launch container` 保持为 `New window`。

For production, switch both systems to HTTPS and then iframe embedding can be considered.

生产环境请把两套系统都切换到 HTTPS，之后再考虑 iframe 嵌入。
