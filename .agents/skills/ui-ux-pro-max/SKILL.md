---
name: ui-ux-pro-max
description: "UI/UX 设计智能。67 种样式、96 种配色方案、57 种字体搭配、25 种图表类型、13 种技术栈（React、Next.js、Vue、Svelte、SwiftUI、React Native、Flutter、Tailwind、shadcn/ui）。操作：规划、构建、创建、设计、实施、审查、修复、改进、优化、增强、重构、检查 UI/UX 代码。项目类型：网站、落地页、仪表盘、管理面板、电子商务、SaaS、作品集、博客、移动应用、.html、.tsx、.vue、.svelte。元素：按钮、模态框、导航栏、侧边栏、卡片、表格、表单、图表。样式：玻璃拟态、粘土拟态、极简主义、稚拙主义、新拟态、宾果网格、深色模式、响应式设计、写实风格、扁平设计。主题：配色方案、无障碍访问、动画、布局、字体排版、字体搭配、间距、悬停、阴影、渐变。集成：shadcn/ui MCP 用于组件搜索和示例。"
---
# UI/UX Pro Max - 设计智能

Web 和移动应用程序的综合设计指南。包含 67 种样式、96 种配色方案、57 种字体搭配、99 条 UX 指南以及 13 种技术栈的 25 种图表类型。支持优先级的可搜索数据库。

## 适用场景

在以下情况下参考这些指南：
- 设计新的 UI 组件或页面
- 选择配色方案和字体排版
- 审查代码的 UX 问题
- 构建落地页或仪表盘
- 实现无障碍访问要求

## 按优先级分类的规则

| 优先级 | 类别 | 影响程度 | 领域 |
|----------|----------|--------|--------|
| 1 | 无障碍访问 | 关键 | `ux` |
| 2 | 触控与交互 | 关键 | `ux` |
| 3 | 性能 | 高 | `ux` |
| 4 | 布局与响应式 | 高 | `ux` |
| 5 | 字体排版与颜色 | 中等 | `typography`、`color` |
| 6 | 动画 | 中等 | `ux` |
| 7 | 样式选择 | 中等 | `style`、`product` |
| 8 | 图表与数据 | 低 | `chart` |

## 快速参考

### 1. 无障碍访问（关键）

- `color-contrast` - 正文最小 4.5:1 对比度
- `focus-states` - 可交互元素的焦点环可见
- `alt-text` - 有意义图片的描述性 alt 文本
- `aria-labels` - 图标按钮的 aria-label
- `keyboard-nav` - Tab 顺序与视觉顺序一致
- `form-labels` - 使用带 for 属性的 label

### 2. 触控与交互（关键）

- `touch-target-size` - 最小 44x44px 触控目标
- `hover-vs-tap` - 主要交互使用点击/tap
- `loading-buttons` - 异步操作期间禁用按钮
- `error-feedback` - 在问题附近显示清晰的错误信息
- `cursor-pointer` - 为可点击元素添加 cursor-pointer

### 3. 性能（高）

- `image-optimization` - 使用 WebP、srcset、懒加载
- `reduced-motion` - 检查 prefers-reduced-motion
- `content-jumping` - 为异步内容预留空间

### 4. 布局与响应式（高）

- `viewport-meta` - width=device-width initial-scale=1
- `readable-font-size` - 移动端正文最小 16px
- `horizontal-scroll` - 确保内容适应视口宽度
- `z-index-management` - 定义 z-index 层级（10、20、30、50）

### 5. 字体排版与颜色（中等）

- `line-height` - 正文使用 1.5-1.75
- `line-length` - 每行限制 65-75 个字符
- `font-pairing` - 标题/正文字体个性匹配

### 6. 动画（中等）

- `duration-timing` - 微交互使用 150-300ms
- `transform-performance` - 使用 transform/opacity，而非 width/height
- `loading-states` - 骨架屏或加载动画

### 7. 样式选择（中等）

- `style-match` - 样式匹配产品类型
- `consistency` - 所有页面使用相同样式
- `no-emoji-icons` - 使用 SVG 图标，而非 emoji

### 8. 图表与数据（低）

- `chart-type` - 图表类型匹配数据类型
- `color-guidance` - 使用无障碍配色方案
- `data-table` - 提供表格替代方案以实现无障碍访问

## 使用方法

使用以下 CLI 工具搜索特定领域。

---


## 前置条件

检查 Python 是否已安装：

```bash
python3 --version || python --version
```

如果 Python 未安装，请根据用户操作系统安装：

**macOS:**
```bash
brew install python3
```

**Ubuntu/Debian:**
```bash
sudo apt update && sudo apt install python3
```

**Windows:**
```powershell
winget install Python.Python.3.12
```

---

## 如何使用此技能

当用户请求 UI/UX 工作（设计、构建、创建、实施、审查、修复、改进）时，请遵循此工作流程：

### 步骤 1：分析用户需求

从用户请求中提取关键信息：
- **产品类型**：SaaS、电子商务、作品集、仪表盘、落地页等
- **风格关键词**：极简、活泼、专业、优雅、深色模式等
- **行业**：医疗健康、金融科技、游戏、教育等
- **技术栈**：React、Vue、Next.js，或默认使用 `html-tailwind`

### 步骤 2：生成设计系统（必需）

**始终使用 `--design-system` 开始**，以获取带有推理的全面建议：

```bash
python3 skills/ui-ux-pro-max/scripts/search.py "<product_type> <industry> <keywords>" --design-system [-p "Project Name"]
```

此命令：
1. 并行搜索 5 个领域（product、style、color、landing、typography）
2. 应用 `ui-reasoning.csv` 中的推理规则选择最佳匹配
3. 返回完整设计系统：模式、样式、颜色、字体排版、效果
4. 包含需要避免的反模式

**示例：**
```bash
python3 skills/ui-ux-pro-max/scripts/search.py "beauty spa wellness service" --design-system -p "Serenity Spa"
```

### 步骤 2b：持久化设计系统（主文件 + 覆盖模式）

要保存设计系统以便跨会话进行层级检索，请添加 `--persist`：

```bash
python3 skills/ui-ux-pro-max/scripts/search.py "<query>" --design-system --persist -p "Project Name"
```

这将创建：
- `design-system/MASTER.md` — 包含所有设计规则的全局真理来源
- `design-system/pages/` — 页面特定覆盖的文件夹

**带有页面特定覆盖：**
```bash
python3 skills/ui-ux-pro-max/scripts/search.py "<query>" --design-system --persist -p "Project Name" --page "dashboard"
```

这还将创建：
- `design-system/pages/dashboard.md` — 页面特定偏离主文件的规则

**层级检索工作方式：**
1. 构建特定页面时（例如 "Checkout"），首先检查 `design-system/pages/checkout.md`
2. 如果页面文件存在，其规则**覆盖**主文件
3. 如果不存在，则仅使用 `design-system/MASTER.md`

### 步骤 3：补充详细搜索（按需）

获取设计系统后，使用领域搜索获取更多细节：

```bash
python3 skills/ui-ux-pro-max/scripts/search.py "<keyword>" --domain <domain> [-n <max_results>]
```

**何时使用详细搜索：**

| 需求 | 领域 | 示例 |
|------|--------|---------|
| 更多样式选项 | `style` | `--domain style "glassmorphism dark"` |
| 图表建议 | `chart` | `--domain chart "real-time dashboard"` |
| UX 最佳实践 | `ux` | `--domain ux "animation accessibility"` |
| 替代字体 | `typography` | `--domain typography "elegant luxury"` |
| 落地页结构 | `landing` | `--domain landing "hero social-proof"` |

### 步骤 4：技术栈指南（默认：html-tailwind）

获取特定实现的最佳实践。如果用户未指定技术栈，**默认为 `html-tailwind`**。

```bash
python3 skills/ui-ux-pro-max/scripts/search.py "<keyword>" --stack html-tailwind
```

可用技术栈：`html-tailwind`、`react`、`nextjs`、`vue`、`svelte`、`swiftui`、`react-native`、`flutter`、`shadcn`、`jetpack-compose`

---

## 搜索参考

### 可用领域

| 领域 | 用途 | 示例关键词 |
|--------|---------|----------------|
| `product` | 产品类型建议 | SaaS、电子商务、作品集、医疗健康、美妆、服务 |
| `style` | UI 样式、颜色、效果 | glassmorphism、极简主义、深色模式、稚拙主义 |
| `typography` | 字体搭配、Google Fonts | 优雅、活泼、专业、现代 |
| `color` | 按产品类型的配色方案 | saas、ecommerce、healthcare、beauty、fintech、service |
| `landing` | 页面结构、CTA 策略 | hero、hero-centric、testimonial、pricing、social-proof |
| `chart` | 图表类型、库建议 | trend、comparison、timeline、funnel、pie |
| `ux` | 最佳实践、反模式 | animation、accessibility、z-index、loading |
| `react` | React/Next.js 性能 | waterfall、bundle、suspense、memo、rerender、cache |
| `web` | Web 接口指南 | aria、focus、keyboard、semantic、virtualize |
| `prompt` | AI 提示、CSS 关键词 | （样式名称） |

### 可用技术栈

| 技术栈 | 重点 |
|-------|-------|
| `html-tailwind` | Tailwind 工具类、响应式、无障碍（默认） |
| `react` | 状态、hooks、性能、模式 |
| `nextjs` | SSR、路由、图片、API 路由 |
| `vue` | Composition API、Pinia、Vue Router |
| `svelte` | Runes、stores、SvelteKit |
| `swiftui` | Views、State、Navigation、Animation |
| `react-native` | 组件、Navigation、Lists |
| `flutter` | Widgets、State、Layout、Theming |
| `shadcn` | shadcn/ui 组件、主题化、表单、模式 |
| `jetpack-compose` | Composables、Modifiers、State Hoisting、Recomposition |

---

## 示例工作流程

**用户请求：** "为专业皮肤护理服务制作落地页"

### 步骤 1：分析需求
- 产品类型：美妆/Spa 服务
- 风格关键词：优雅、专业、柔和
- 行业：美妆/健康
- 技术栈：html-tailwind（默认）

### 步骤 2：生成设计系统（必需）

```bash
python3 skills/ui-ux-pro-max/scripts/search.py "beauty spa wellness service elegant" --design-system -p "Serenity Spa"
```

**输出：** 包含模式、样式、颜色、字体排版、效果和反模式的完整设计系统。

### 步骤 3：补充详细搜索（按需）

```bash
# 获取动画和无障碍访问的 UX 指南
python3 skills/ui-ux-pro-max/scripts/search.py "animation accessibility" --domain ux

# 如有需要，获取替代字体选项
python3 skills/ui-ux-pro-max/scripts/search.py "elegant luxury serif" --domain typography
```

### 步骤 4：技术栈指南

```bash
python3 skills/ui-ux-pro-max/scripts/search.py "layout responsive form" --stack html-tailwind
```

**然后：** 综合设计系统 + 详细搜索并实现设计。

---

## 输出格式

`--design-system` 标志支持两种输出格式：

```bash
# ASCII 框（默认）- 最佳终端显示
python3 skills/ui-ux-pro-max/scripts/search.py "fintech crypto" --design-system

# Markdown - 最佳文档格式
python3 skills/ui-ux-pro-max/scripts/search.py "fintech crypto" --design-system -f markdown
```

---

## 更好结果的技巧

1. **关键词要具体** - "healthcare SaaS dashboard" > "app"
2. **多次搜索** - 不同关键词揭示不同见解
3. **组合领域** - Style + Typography + Color = 完整设计系统
4. **始终检查 UX** - 搜索 "animation"、"z-index"、"accessibility" 了解常见问题
5. **使用技术栈标志** - 获取特定实现的最佳实践
6. **迭代** - 如果第一次搜索不匹配，尝试不同的关键词

---

## 专业 UI 的常见规则

这些是常被忽视的会使 UI 看起来不专业的问题：

### 图标与视觉元素

| 规则 | 应该 | 不应该 |
|------|----|----- |
| **不使用 emoji 图标** | 使用 SVG 图标（Heroicons、Lucide、Simple Icons） | 使用 🎨 🚀 ⚙️ 等 emoji 作为 UI 图标 |
| **稳定的悬停状态** | 悬停时使用颜色/透明度过渡 | 使用会改变布局的缩放变换 |
| **正确的品牌 logo** | 从 Simple Icons 研究官方 SVG | 猜测或使用错误的 logo 路径 |
| **一致的图标尺寸** | 使用固定 viewBox（24x24）配合 w-6 h-6 | 随机混合不同图标尺寸 |

### 交互与光标

| 规则 | 应该 | 不应该 |
|------|----|----- |
| **Cursor pointer** | 为所有可点击/悬停卡片添加 `cursor-pointer` | 可交互元素保留默认光标 |
| **悬停反馈** | 提供视觉反馈（颜色、阴影、边框） | 不指示元素可交互 |
| **平滑过渡** | 使用 `transition-colors duration-200` | 即时状态变化或太慢（>500ms） |

### 浅色/深色模式对比

| 规则 | 应该 | 不应该 |
|------|----|----- |
| **浅色模式玻璃卡片** | 使用 `bg-white/80` 或更高不透明度 | 使用 `bg-white/10`（太透明） |
| **浅色模式文本对比** | 文本使用 `#0F172A`（slate-900） | 正文使用 `#94A3B8`（slate-400） |
| **浅色模式次要文本** | 最小使用 `#475569`（slate-600） | 使用 gray-400 或更浅 |
| **边框可见性** | 浅色模式使用 `border-gray-200` | 使用 `border-white/10`（不可见） |

### 布局与间距

| 规则 | 应该 | 不应该 |
|------|----|----- |
| **浮动导航栏** | 添加 `top-4 left-4 right-4` 间距 | 导航栏贴附 `top-0 left-0 right-0` |
| **内容内边距** | 考虑固定导航栏高度 | 让内容隐藏在固定元素后面 |
| **一致的 max-width** | 使用相同的 `max-w-6xl` 或 `max-w-7xl` | 混合不同的容器宽度 |

---

## 交付前检查清单

交付 UI 代码前，验证以下项目：

### 视觉质量
- [ ] 不使用 emoji 作为图标（改用 SVG）
- [ ] 所有图标来自一致的图标集（Heroicons/Lucide）
- [ ] 品牌 logo 正确（已从 Simple Icons 验证）
- [ ] 悬停状态不会导致布局偏移
- [ ] 直接使用主题颜色（bg-primary）而非 var() 包装器

### 交互
- [ ] 所有可点击元素都有 `cursor-pointer`
- [ ] 悬停状态提供清晰的视觉反馈
- [ ] 过渡平滑（150-300ms）
- [ ] 键盘导航的焦点状态可见

### 浅色/深色模式
- [ ] 浅色模式文本有足够对比度（最小 4.5:1）
- [ ] 玻璃/透明元素在浅色模式下可见
- [ ] 两种模式下边框都可见
- [ ] 交付前测试两种模式

### 布局
- [ ] 浮动元素与边缘有适当间距
- [ ] 没有内容隐藏在固定导航栏后面
- [ ] 在 375px、768px、1024px、1440px 下响应式
- [ ] 移动端无水平滚动

### 无障碍访问
- [ ] 所有图片都有 alt 文本
- [ ] 表单输入有标签
- [ ] 颜色不是唯一的指示器
- [ ] 尊重 `prefers-reduced-motion`
