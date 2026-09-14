# Manifest: W15 Enterprise UI

Scope: React + Next.js (TypeScript) per TAXONOMY scope note (2026-09-15). All 20 assigned slugs written, plus 2 added slugs: `report-builder-ui` and `resource-scheduling-and-timeline-views`. All files use the exact template headings (27 H2 sections, verified in order), 243–344 lines each, and cross-link only to TAXONOMY slugs or the two added slugs.

Added slugs (not in TAXONOMY.md; please register):
- `report-builder-ui` — saved reports/views: column picker, group-by, aggregations, filter builder, scheduled exports, sharing/permissions, server-side query preview. Distinct from dashboard-design (W14) and advanced-filtering-ui.
- `resource-scheduling-and-timeline-views` — resource/timeline/Gantt views: time axis x resource rows, drag/resize with keyboard alternatives, server-side conflict detection, timezones, two-axis virtualization. Distinct from date-pickers-and-calendars (W07).

Key version/status findings (verified 2026-09-15):
- **TanStack Table is v9 (9.2.4).** Code uses `useTable` + `tableFeatures()`, not v8's `useReactTable`. Other skills written against v8 need review.
- AG Grid 36.1.0 (Aug 2026): `AgGridProvider` module registration is recommended since v35.1.
- Library versions: nuqs 2.10.1; @refinedev/core 5.0.12; react-admin 5.15.3; @dnd-kit/react 0.5.0 (pre-1.0); ExcelJS 4.4.0; react-grid-layout 2.2.4.
- Shopify Polaris React is deprecated in favor of Polaris web components (launched 2025-10-01).

## Skills

| Slug | Title | Category | Framework | Quality | Status | Primary Source (URL) |
|---|---|---|---|---|---|---|
| admin-panel-architecture | Admin Panel Architecture | Enterprise UI | React, Next.js | A | Active | https://nextjs.org/docs/app/guides/data-security |
| enterprise-data-tables | Enterprise Data Tables | Enterprise UI | React, Next.js | A | Active | https://www.nngroup.com/articles/data-tables/ |
| data-grids-ag-grid | Data Grids with AG Grid (and Alternatives) | Enterprise UI | React, Next.js | A | Active | https://www.ag-grid.com/react-data-grid/licensing/ |
| advanced-filtering-ui | Advanced Filtering UI | Enterprise UI | React, Next.js | A | Active | https://design.gitlab.com/patterns/filtering |
| bulk-actions | Bulk Actions | Enterprise UI | React, Next.js | A | Active | https://nextjs.org/docs/app/guides/data-security |
| role-based-ui-and-permissions | Role-Based UI and Permissions | Enterprise UI | React, Next.js | A | Active | https://github.com/stalniy/casl/tree/master/packages/casl-react |
| audit-log-interfaces | Audit Log Interfaces | Enterprise UI | React, Next.js | B | Active | https://nextjs.org/docs/app/guides/data-security |
| workflow-and-approval-ui | Workflow and Approval UI | Enterprise UI | React, Next.js | B | Active | https://nextjs.org/docs/app/guides/data-security |
| erp-ui-patterns | ERP UI Patterns | Enterprise UI | React, Next.js | B | Active | https://www.sap.com/design-system/fiori-design-web/page-types/floorplan-overview |
| crm-ui-patterns | CRM UI Patterns | Enterprise UI | React, Next.js | B | Active | https://nextjs.org/docs/app/guides/data-security |
| wms-and-logistics-ui-patterns | WMS and Logistics UI Patterns | Enterprise UI | React, Next.js | C | Active | https://nextjs.org/docs/app/guides/data-security |
| multi-tenant-ui | Multi-Tenant UI | Enterprise UI | React, Next.js | B | Active | https://nextjs.org/docs/app/guides/data-security |
| keyboard-power-user-ui | Keyboard Power-User UI | Enterprise UI | React, Next.js | A | Active | https://www.w3.org/WAI/ARIA/apg/patterns/grid/ |
| dense-form-screens | Dense Form Screens | Enterprise UI | React, Next.js | B | Active | https://nextjs.org/docs/app/guides/data-security |
| master-detail-layouts | Master-Detail Layouts | Enterprise UI | React, Next.js | B | Active | https://www.nngroup.com/articles/data-tables/ |
| data-import-export-ui | Data Import & Export UI | Enterprise UI | React, Next.js | A | Active | https://www.papaparse.com/docs |
| realtime-collaboration-ui | Realtime Collaboration UI | Enterprise UI | React, Next.js | B | Active | https://liveblocks.io/docs/get-started/nextjs |
| responsive-dashboard-layouts | Responsive Dashboard Layouts | Enterprise UI | React, Next.js | B | Active | https://nextjs.org/docs/app/guides/data-security |
| kanban-boards | Kanban Boards | Enterprise UI | React, Next.js | A | Active | https://github.com/clauderic/dnd-kit |
| refine-and-react-admin-frameworks | refine and react-admin Frameworks | Enterprise UI | React, Next.js | A | Active | https://refine.dev/docs/routing/integrations/next-js/ |
| report-builder-ui (added) | Report Builder UI | Enterprise UI | React, Next.js | B | Active | https://www.nngroup.com/articles/complex-application-design/ |
| resource-scheduling-and-timeline-views (added) | Resource Scheduling & Timeline Views | Enterprise UI | React, Next.js | B | Active | https://fullcalendar.io/pricing |

## Sources

| Source | URL | Type | What Was Extracted | Why It Matters | Quality | Last Verified |
|---|---|---|---|---|---|---|
| Next.js: Data security guide (docs v16.3.5) | https://nextjs.org/docs/app/guides/data-security | Official | Data Access Layer with `server-only`; minimal return objects (DTOs); Server Actions are reachable by direct POST, so re-check authentication and authorization in every action; per-record ownership (IDOR) checks; minimal return values; taint APIs; closure encryption; allowedOrigins; audit checklist; proxy.ts | Security boundary for all admin CRUD and permission skills | High | 2026-09-15 |
| AG Grid licensing | https://www.ag-grid.com/react-data-grid/licensing/ | Official | Community MIT vs Enterprise EULA; Enterprise-only features; trial | License selection | High | 2026-09-15 |
| AG Grid releases | https://github.com/ag-grid/ag-grid/releases | Official | 36.1.0 (2026-08-05) | Version accuracy | High | 2026-09-15 |
| AG Grid modules | https://www.ag-grid.com/react-data-grid/modules/ | Official | ModuleRegistry, AgGridProvider (v35.1+), AllCommunity/AllEnterprise modules, cherry-picking | Bundle size, setup | High | 2026-09-15 |
| AG Grid SSRM datasource | https://www.ag-grid.com/react-data-grid/server-side-model-datasource/ | Official | getRows request (startRow/endRow/sortModel/filterModel/groupKeys), success/fail | Server API contract | High | 2026-09-15 |
| AG Grid theming parameters | https://www.ag-grid.com/react-data-grid/theming-parameters/ | Official | themeQuartz.withParams (spacing, rowHeight, headerHeight, fontSize) | Density modes | High | 2026-09-15 |
| TanStack Table v9 docs (GitHub) | https://github.com/TanStack/table/tree/main/docs | Official | useTable, tableFeatures, row models in features, manual* modes, rowCount, controlled state/atoms, table.Subscribe, table.FlexRender, v8→v9 migration | Correct current API (v9.2.4) | High | 2026-09-15 |
| @tanstack/react-table on npm | https://www.npmjs.com/package/@tanstack/react-table | Official | Latest 9.2.4, react >=18 | Version accuracy | High | 2026-09-15 |
| MUI X licensing | https://mui.com/x/introduction/licensing/ | Official | Community/Pro/Premium feature split; LicenseInfo.setLicenseKey | Grid tier selection | High | 2026-09-15 |
| MUI X Data Grid server-side data | https://mui.com/x/react-data-grid/server-side-data/ | Official | dataSource.getRows → {rows,rowCount}; auto server modes; cache TTL | Alternative server contract | High | 2026-09-15 |
| Glide Data Grid | https://grid.glideapps.com/ | Open Source | MIT, canvas, millions of rows, streaming updates | High-volume alternative | Medium | 2026-09-15 |
| nuqs server-side docs | https://nuqs.dev/docs/server-side | Official | 2.10.1; createLoader, createSearchParamsCache, parsers; loaders don't validate | URL-synced filters/sort/pagination | High | 2026-09-15 |
| refine general concepts | https://refine.dev/docs/guides-concepts/general-concepts/ | Official | Providers (data/auth/accessControl/router), getList params shape, useCan/CanAccess | Framework comparison | High | 2026-09-15 |
| refine Next.js router | https://refine.dev/docs/routing/integrations/next-js/ | Official | @refinedev/nextjs-router, client-only Refine, authProviderServer, limitations | App Router integration | High | 2026-09-15 |
| refine releases / npm | https://github.com/refinedev/refine/releases | Official | @refinedev/core 5.0.12, React Query v5 peer | Version accuracy | High | 2026-09-15 |
| react-admin README + Next.js doc + npm | https://github.com/marmelab/react-admin | Open Source | MIT + Enterprise Edition; data providers; 5.15.3; client-only via dynamic ssr:false; catch-all proxy route | Framework comparison | High | 2026-09-15 |
| @casl/react README | https://github.com/stalniy/casl/tree/master/packages/casl-react | Open Source | Can props, useAbility, render-function children, passThrough | UI permission gating | High | 2026-09-15 |
| OpenFGA check docs | https://openfga.dev/docs/getting-started/perform-check | Official | ReBAC check, batchCheck, SDK client config | Fine-grained authorization | High | 2026-09-15 |
| Permit.io docs | https://docs.permit.io/ | Official | RBAC/ABAC/ReBAC, PDP, permit.check, CASL-based frontend SDK | Managed authorization option | Medium | 2026-09-15 |
| NN/g: Data tables | https://www.nngroup.com/articles/data-tables/ | Community (research) | Four user tasks, frozen headers, column control, nonmodal edit panels | Table/master-detail UX | High | 2026-09-15 |
| NN/g: Complex application design | https://www.nngroup.com/articles/complex-application-design/ | Community (research) | 8 guidelines for expert apps | Power-user and report-builder UX | High | 2026-09-15 |
| W3C ARIA APG grid pattern | https://www.w3.org/WAI/ARIA/apg/patterns/grid/ | Official | Grid keyboard model, roving tabindex, aria-rowcount/rowindex, table vs grid | Accessibility of grids/shortcuts | High | 2026-09-15 |
| Elastic EUI Data Grid | https://eui.elastic.co/docs/components/tabular-content/data-grid/ | Official | Density, column selector, sort popover, fullscreen, control columns | Toolbar anatomy reference | Medium | 2026-09-15 |
| Carbon DataTable (React source docs) | https://github.com/carbon-design-system/carbon/tree/main/packages/react/src/components/DataTable | Official | TableToolbar, TableBatchActions, search, selection, expansion | Bulk-action bar anatomy | Medium | 2026-09-15 |
| GitLab Pajamas filtering | https://design.gitlab.com/patterns/filtering | Official | Search vs filter; complexity levels 1–5 → component choice | Filter UI selection | Medium | 2026-09-15 |
| Shopify Polaris React README | https://github.com/Shopify/polaris-react | Official | Deprecated; Polaris web components launched 2025-10-01 | Status of index-table reference | High | 2026-09-15 |
| UI5 Web Components for React README | https://github.com/SAP/ui5-webcomponents-react | Official | Fiori-compliant React; Next.js caveats | ERP/Fiori implementation option | Medium | 2026-09-15 |
| SAP fundamental-styles README | https://github.com/SAP/fundamental-styles | Official | Fiori themes (Quartz, Horizon) | ERP context | Low | 2026-09-15 |
| Papa Parse docs | https://www.papaparse.com/docs | Open Source | header, dynamicTyping, worker, step/chunk, unparse, escapeFormulae | CSV import/export + CSV injection | High | 2026-09-15 |
| SheetJS repository notice | https://github.com/SheetJS/sheetjs | Open Source | Apache-2.0 CE; moved to git.sheetjs.com; cdn.sheetjs.com distribution | Licensing/install correctness | High | 2026-09-15 |
| ExcelJS on npm | https://www.npmjs.com/package/exceljs | Open Source | 4.4.0, MIT | Export library option | Medium | 2026-09-15 |
| react-spreadsheet-import README | https://github.com/UgnisSoftware/react-spreadsheet-import | Open Source | Import steps, field/validation schema, MIT, Chakra UI dependency | Import wizard | Medium | 2026-09-15 |
| dnd-kit repo + README | https://github.com/clauderic/dnd-kit | Open Source | MIT, active (pushed 2026-09-12), core/sortable, keyboard sensor, announcements | Kanban DnD | High | 2026-09-15 |
| @dnd-kit/react on npm | https://www.npmjs.com/package/@dnd-kit/react | Open Source | 0.5.0 pre-1.0, React 18/19 | Next-gen API status | Medium | 2026-09-15 |
| Atlassian Pragmatic drag and drop | https://atlassian.design/components/pragmatic-drag-and-drop/about | Official | Framework-agnostic, accessibility guidelines section | Kanban alternative | Medium | 2026-09-15 |
| Liveblocks Next.js get-started | https://liveblocks.io/docs/get-started/nextjs | Official | Providers, useStorage/useMutation/useOthers/useMyPresence | Collaboration setup | High | 2026-09-15 |
| Liveblocks access-token auth (Next.js) | https://liveblocks.io/docs/authentication/access-token/nextjs | Official | Route handler with prepareSession/allow/authorize | Server-enforced room permissions | High | 2026-09-15 |
| Yjs docs | https://docs.yjs.dev/ | Open Source | Shared types, providers, editor bindings | CRDT collaboration | Medium | 2026-09-15 |
| PartyKit docs | https://docs.partykit.io/ | Official | Party.Server, PartySocket, y-partykit | Self-hosted realtime option | Medium | 2026-09-15 |
| Cloudflare acquires PartyKit | https://blog.cloudflare.com/cloudflare-acquires-partykit/ | Official | Announced 2024-04-05; built on Durable Objects | Project status | High | 2026-09-15 |
| react-grid-layout on npm | https://www.npmjs.com/package/react-grid-layout | Open Source | 2.2.4, MIT | Customizable dashboards | Medium | 2026-09-15 |
| FullCalendar pricing | https://fullcalendar.io/pricing | Official | Standard MIT; timeline/resource views Premium; v7.1.0 | Scheduling licensing | High | 2026-09-15 |

## Duplicates

| Topic | Canonical Source | Alternates Merged | Merged Into Slug |
|---|---|---|---|
| Server-side table state (pagination/sort/filter) | TanStack Table v9 client-side-vs-server-side guide + nuqs server-side docs | AG Grid SSRM datasource, MUI X dataSource | enterprise-data-tables (contract), data-grids-ag-grid (grid-specific adapters) |
| Server-side authorization for admin mutations | Next.js data-security guide | refine authProviderServer, react-admin authProvider | role-based-ui-and-permissions (canonical); referenced by admin-panel-architecture, bulk-actions, workflow-and-approval-ui |
| UI permission gating | @casl/react | Permit.io frontend SDK (CASL-based), refine useCan/CanAccess | role-based-ui-and-permissions |
| Batch/bulk action bar anatomy | Carbon TableBatchActions | Polaris index table promoted bulk actions (deprecated React lib), NN/g batch actions | bulk-actions |
| Grid keyboard model | W3C APG grid pattern | EUI data grid keyboard, AG Grid keyboard | keyboard-power-user-ui (global shortcuts), enterprise-data-tables (in-grid navigation) |
| CSV/XLSX import and export | Papa Parse docs | SheetJS CE, ExcelJS, react-spreadsheet-import | data-import-export-ui |
| Drag-and-drop boards | dnd-kit | Pragmatic drag and drop, @dnd-kit/react 0.5.0 | kanban-boards (generic DnD stays in W06 drag-and-drop) |
| Floorplans (list report / object page / flexible column layout) | SAP Fiori floorplan overview (403 — from general knowledge) | UI5 Web Components for React, NN/g master-detail guidance | erp-ui-patterns (floorplans), master-detail-layouts (layout mechanics) |

## Gaps

- **SAP Fiori pages returned HTTP 403.** Floorplan anatomy in erp-ui-patterns and master-detail-layouts comes from general knowledge and is flagged "verify against current Fiori guidelines".
- **Salesforce Lightning Design System and Microsoft Fluent 2 pages could not be read.** The empty page and 404 affect CRM record-page concepts (path, highlights panel, related lists) and density/size guidance. Both are unverified.
- **Carbon data table row heights (xs–xl) not verified.** Density values in the table skills are illustrative.
- **The AG Grid Enterprise license-key API name was not confirmed.** Skills say "see Enterprise install docs".
- **TanStack Table v9 details still unverified:** the exact row-selection feature export name and `createColumnHelper` generics. v8 code elsewhere in the library (e.g. W02 tanstack-table) should be checked against v9.
- **refine v5 pagination field name (`current` vs `currentPage`) unconfirmed.**
- **CASL `subject()` helper and database-adapter APIs unconfirmed.**
- **Liveblocks hook names `useStatus`/`useUpdateMyPresence` not re-verified.** Also unconfirmed: y-partykit's current packaging (README 404) and the MUI X Scheduler tier.
- **No authoritative design-system source for audit log UIs or impersonation UX, or for WMS/handheld scanning UIs** (hence wms-and-logistics-ui-patterns at C). BarcodeDetector / `navigator.vibrate` support needs device testing.
- **WCAG 2.1.4 and 2.5.7 Understanding pages not re-fetched.** Criteria cited from standard knowledge.
- **No community agent skills/rules for React admin dashboards were reviewed** (WebSearch quota constraint).
- **No code examples were compiled or type-checked.**
