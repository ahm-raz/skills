# Ant Design (antd)

## Summary
Ant Design (`antd` 6.6.4, MIT, Ant Group) is an enterprise-grade React component library with 60+ dense, data-heavy components: Table, Form, Tree, Cascader, Transfer, DatePicker, Upload. It uses the CSS-in-JS engine `@ant-design/cssinjs`, a design-token theme system (`ConfigProvider theme`), and in v6 pure CSS variables by default. v6 requires React 18+, drops IE, adds semantic `classNames`/`styles` for component internals, and is a smooth upgrade from v5 without a compatibility package.

## Category
UI Libraries

## Subcategories
Enterprise UI, design tokens, ConfigProvider, CSS variables, semantic classNames/styles, Form, Table, Next.js registry, v5 to v6 migration, ProComponents

## Problem It Solves
Enterprise back-office apps need many complex, consistent, i18n-ready components (tables with sorting, filtering and pagination, forms with validation and dependencies, trees, transfers). Ant Design ships them together with a token-based theming model.

## When To Use
- Admin consoles, ERP/CRM, and internal tools with dense data entry and tables.
- Teams needing broad built-in locales (Chinese, English and many others) and date handling.
- Organizations already in the Ant ecosystem (ProComponents, Ant Design Pro, AntV charts).

## When Not To Use
- Brand-driven consumer products where Ant's visual language is hard to escape.
- Tailwind-first design systems (possible with CSS layers, but two systems).
- Performance-sensitive public pages. CSS-in-JS plus large components add JS and hydration cost.

## Core Principles
1. **Tokens drive everything**: seed tokens (`colorPrimary`, `borderRadius`) derive map/alias tokens, and component tokens (`components.Button.*`) override per component.
2. **Algorithms**: `theme.defaultAlgorithm`, `theme.darkAlgorithm`, `theme.compactAlgorithm`, composable.
3. **CSS variables by default in v6**: lighter theme switching and shared styles across themes.
4. **Semantic DOM customization**: `classNames={{ body: "..." }}` and `styles={{ header: {...} }}` target internal parts instead of fragile selectors.
5. **Form as a state engine**: `Form` + `Form.Item name rules`, `Form.useForm()`, `dependencies`, `shouldUpdate`.

## Best Practices
- Theme via `ConfigProvider theme={{ token, components, algorithm }}` at the root. Nest ConfigProviders for local overrides.
- Use semantic `classNames`/`styles` (v6) instead of `.ant-*` descendant selectors.
- Use `App` component (`<App>`) + `App.useApp()` for `message`, `notification` and `modal`, so they inherit context (theme, locale). Avoid static `message.success`.
- For large tables, enable `virtual` on Table with fixed `scroll={{ y }}` and stable `rowKey`.
- In v6, use the unified size enum `'large' | 'medium' | 'small'` and renamed props (`Alert title`, `Button iconPlacement`, `styles.body` instead of `bodyStyle`).
- Keep `@ant-design/icons` at 6.x with antd 6.
- Use the Ant Design CLI's deprecated-API detection when upgrading (see the migration guide).

## Implementation Guidance
```bash
pnpm add antd @ant-design/icons
pnpm add @ant-design/nextjs-registry   # Next.js App Router style extraction
```
```tsx
// app/layout.tsx
import { AntdRegistry } from "@ant-design/nextjs-registry";
import { ConfigProvider, App } from "antd";

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <AntdRegistry>
          <ConfigProvider theme={{ token: { colorPrimary: "#1f6feb", borderRadius: 8 }, cssVar: {} /* default in v6 */ }}>
            <App>{children}</App>
          </ConfigProvider>
        </AntdRegistry>
      </body>
    </html>
  );
}
```
(The `cssVar` key is shown for clarity; v6 enables CSS variables by default. Verify the option shape in the v6 theme docs.)

**v5 to v6 checklist**
| Area | Change |
|---|---|
| React | 18+ only |
| Browsers | Modern only; CSS variables default |
| Alert | `message` becomes `title`; `closeText` becomes `closable.closeIcon` |
| Button | `iconPosition` becomes `iconPlacement` |
| Modal/Drawer | `bodyStyle` etc. become `styles.body` |
| Select/Cascader | dropdown* props become popup* |
| Sizes | `default`/`middle` become `medium` |
| DOM | Internal structure optimized, so re-check custom CSS |
| Overlays | Mask blur off by default (6.3.0) |
The v5 React 19 patch package is not needed on v6.

## Recommended Workflow
1. Define seed tokens and algorithm (light/dark/compact) and component tokens.
2. Set up the registry (Next.js) and the `App` context wrapper.
3. Build forms with `Form.useForm`, typed via `Form<Values>` generics, and colocated rules.
4. Build tables with server-driven pagination/sorting (`onChange` handler) and `rowKey`.
5. Upgrade: run the CLI checks, fix renamed props, re-test custom CSS.

## Patterns
- **Typed form**: `const [form] = Form.useForm<Values>(); <Form<Values> form={form} onFinish={...}>`.
- **Server-side table**: control `pagination`, `sorter` and `filters` from URL state and fetch on `onChange`.
- **Dark mode switch**: `algorithm: isDark ? theme.darkAlgorithm : theme.defaultAlgorithm`.
- **Component token override**: `components: { Table: { headerBg: "#fafafa", rowHoverBg: "#f5f7ff" } }`.

## Anti-Patterns
- **Static `message`/`Modal.confirm` calls**: they don't read ConfigProvider context. Use `App.useApp()`.
- **Overriding `.ant-*` internals**: brittle across v6 DOM changes. Use `classNames`/`styles` or tokens.
- **Uncontrolled giant Tables without `virtual` or pagination**: slow INP.
- **Missing `rowKey`**: selection and expansion bugs and React key warnings.
- **Using v4/v5 prop names in v6** (`bodyStyle`, `dropdownClassName`, `size="middle"`).

## Accessibility
- Reasonable keyboard support and ARIA for most components. Complex widgets (Cascader, Transfer, TreeSelect) have historically weaker screen-reader UX than React Aria. Audit them with real screen readers.
- Ensure `Form.Item label` associates with inputs (use `name` and `htmlFor` behavior). Don't rely on placeholders.
- Check contrast of the default secondary text and disabled states against WCAG 1.4.3.
- Add `aria-label` to icon-only buttons.

## Responsive Design
- `Grid` (`Row`/`Col` with `xs..xxl`), `Grid.useBreakpoint()`, responsive `Descriptions`/`Table` column `responsive` arrays.
- `compactAlgorithm` for dense desktop layouts. Drawers for mobile filters.
- Table horizontal scroll (`scroll={{ x: "max-content" }}`) on small screens.

## Performance
- Large library, so import only what you use (ESM tree-shaking). Icons are per-icon imports.
- v6 CSS variables reduce theme-switch cost and duplicate styles across themes.
- Heavy components (Table, DatePicker) hydrate as client components. Lazy-load rarely used screens.
- Static style extraction via the Next.js registry prevents FOUC but still ships the runtime.

## Security
- `Upload`: validate file types and size server-side. `beforeUpload` is client-only.
- Avoid rendering user HTML in `Table` `render` functions without sanitization.
- MIT. Large corporate-backed project. Watch transitive `rc-*` / `@rc-component/*` dependency advisories.

## Testing
- Testing Library role queries. Some antd widgets render custom roles, so use `getByRole("combobox")` for Select.
- Mock `window.matchMedia` in jsdom (used by responsive observers).
- Form tests: fill fields, submit, assert `onFinish` payload and `Form.Item` error text.

## Tooling
- `antd` 6.6.4, `@ant-design/icons` 6.x, `@ant-design/nextjs-registry`, `@ant-design/cssinjs`.
- ProComponents / Ant Design Pro (check v6 compatibility of each package before upgrading).
- AntV (charts) as the companion visualization suite.

## Framework Notes
- **Next.js App Router**: wrap in `AntdRegistry` in the root layout so styles are extracted during SSR. antd components are client components (they use context), so compose them inside `"use client"` files when using hooks such as `Form.useForm`/`App.useApp`. Server Components can pass data down.
- **React (Vite SPA)**: `ConfigProvider` + `App` at root. No registry required.
- React 18/19 supported. React 19 is recommended by the team.

## AI Agent Guidance
- DO read the installed `antd` major before writing props. v6 renamed several props.
- DO use `App.useApp()` for feedback components and `classNames`/`styles` for internal styling.
- DON'T add `@ant-design/v5-patch-for-react-19` to v6 projects.
- Verify before done: no deprecation warnings in the console, SSR without FOUC in Next.js, table `rowKey` set, form validation messages visible and associated.

## Examples
```tsx
"use client";
import { App, Button, Form, Input, Select } from "antd";

type Values = { name: string; role: "admin" | "member" };

export function InviteForm({ onInvite }: { onInvite: (v: Values) => Promise<void> }) {
  const [form] = Form.useForm<Values>();
  const { message } = App.useApp();

  return (
    <Form<Values>
      form={form}
      layout="vertical"
      initialValues={{ role: "member" }}
      onFinish={async (v) => { await onInvite(v); message.success("Invitation sent"); form.resetFields(); }}
    >
      <Form.Item label="Name" name="name" rules={[{ required: true, message: "Name is required" }]}>
        <Input autoComplete="name" />
      </Form.Item>
      <Form.Item label="Role" name="role">
        <Select options={[{ value: "admin", label: "Admin" }, { value: "member", label: "Member" }]} />
      </Form.Item>
      <Button type="primary" htmlType="submit">Invite</Button>
    </Form>
  );
}
```

## Related Skills
- [enterprise-data-tables](../enterprise-data-tables/Skill.md): Table patterns
- [dense-form-screens](../dense-form-screens/Skill.md): Form-heavy UIs
- [admin-panel-architecture](../admin-panel-architecture/Skill.md): typical use case
- [refine-and-react-admin-frameworks](../refine-and-react-admin-frameworks/Skill.md): Refine uses antd
- [css-in-js-and-zero-runtime](../css-in-js-and-zero-runtime/Skill.md): cssinjs trade-offs
- [design-token-architecture](../design-token-architecture/Skill.md): token tiers
- [ui-library-selection-guide](../ui-library-selection-guide/Skill.md): comparisons

## Sources
- [From v5 to v6](https://ant.design/docs/react/migration-v6/): Official. Requirements, renamed props, sizes, CLI
- [Ant Design 6.0 is here (issue #55804)](https://github.com/ant-design/ant-design/issues/55804): Open Source. Release goals
- [Ant Design 6.0 (Medium)](https://medium.com/ant-design/ant-design-6-0-is-here-0f5b2803e6a0): Official blog. CSS variables default, React 18+
- [CSS in v6](https://ant-design.antgroup.com/docs/blog/css-tricks): Official. Styling approach
- [antd registry metadata](https://registry.npmjs.org/antd/latest): Official. Version 6.6.4, peers

## License / Usage Notes
antd is MIT. Ant Design Pro/ProComponents are MIT as well; check each package. Summarized content; examples are original.

## Quality Tier
A: official migration guide and version verified; v6 accessibility of complex widgets is not independently audited here.

## Status
Active

## Last Verified
2026-09-15
