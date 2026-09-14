# Accessibility Legal Compliance

## Summary
An engineer's map of the major digital accessibility laws and standards as of September 2026, and what each means for a React/Next.js product team:
- EU: European Accessibility Act (EAA, enforceable since 28 June 2025), EN 301 549, Web Accessibility Directive
- US: ADA Title II web rule, ADA Title III litigation, Section 508, Section 504 (HHS)
- UK: Equality Act and Public Sector Bodies Regulations
- Canada: ACA and AODA

Also covers conformance documentation (ACR/VPAT, accessibility statements). This is not legal advice; confirm obligations with counsel.

## Category
Accessibility

## Subcategories
European Accessibility Act, EN 301 549, Web Accessibility Directive, ADA Title II, ADA Title III, Section 508, Section 504, UK PSBAR, AODA, Accessible Canada Act, VPAT/ACR, accessibility statements

## Problem It Solves
Teams don't know which WCAG version and level they must meet, by when, or what documentation to produce. They either over-rotate on vendor fear marketing (overlays), or ignore enforceable obligations that now carry penalties, procurement exclusion and lawsuits.

## When To Use
- Scoping accessibility requirements for a product, market launch, or procurement bid.
- Answering "which standard do we target?" (short answer: WCAG 2.2 AA covers all the major regimes).
- Preparing an ACR/VPAT or accessibility statement.
- Prioritising remediation against deadlines.

## When Not To Use
- Not a substitute for a lawyer, especially for exemption claims (microenterprise, disproportionate burden), sector-specific rules, or active litigation.
- Don't use legal minimums as the product quality bar. Usability for disabled users matters beyond compliance.

## Core Principles
1. **Target WCAG 2.2 Level AA.** It is a superset of 2.0 and 2.1 AA (except obsolete 4.1.1), so it satisfies every regime below and future-proofs against EN 301 549 v4.1.1.
2. **Standards vs laws.** Laws (EAA, ADA) set obligations; standards (EN 301 549, WCAG) define technical conformance.
3. **Document conformance honestly.** Inaccurate ACRs and statements create liability.
4. **Overlays don't create compliance.** Regulators and courts look at actual accessibility, and overlay use has itself been cited in complaints.
5. **Accessibility is continuous.** Laws require maintaining conformance, not a one-time audit.
6. **Third-party components and content** you choose to embed are generally your responsibility.

## Best Practices
- Maintain a compliance register: markets, applicable laws, standard and version, deadlines, owner, evidence links.
- Include accessibility acceptance criteria in procurement of UI libraries, chat widgets, payment iframes, video players and CMSs. Request ACRs and verify them.
- Publish and maintain an accessibility statement with a feedback mechanism, and respond to feedback within stated timelines.
- Keep audit evidence: dated test reports, AT/browser matrix, remediation tickets.
- Train designers, developers, QA and content authors. Many laws expect organisational measures.

## Implementation Guidance

### Regime summary (verify current status before relying on it)
| Jurisdiction / law | Who | Technical standard | Key dates / status (as of 2026-09-15) |
|---|---|---|---|
| **EU – European Accessibility Act** (Directive (EU) 2019/882, national transpositions) | Private-sector products and services for EU consumers: e-commerce, consumer banking, e-books, electronic communications, passenger transport services (websites, apps, ticketing), audiovisual media access services, self-service terminals | EN 301 549 (harmonised: v3.2.1, which references WCAG 2.1 AA) | Applies since **28 June 2025**. Transitional periods for services using products already in use (to 2030) and self-service terminals (up to 20 years). Microenterprises providing services (<10 staff and ≤€2M turnover/balance sheet) exempt. Penalties set per member state. Service providers must describe how they meet requirements (accessibility information) |
| **EN 301 549 v4.1.1** | Standard used for EAA and WAD presumption of conformity | Adopts **WCAG 2.2** (adds the six new A/AA SCs, drops 4.1.1, strengthens user-preference requirements, adds an EAA annex) | Published **September 2026**. **Not yet cited in the Official Journal**, so v3.2.1 remains the legal reference until citation. Prepare now |
| **EU – Web Accessibility Directive** (2016/2102) | Public-sector websites and apps | EN 301 549 (WCAG 2.1 AA) | In force; requires accessibility statements and a feedback mechanism; periodic monitoring |
| **US – ADA Title II web rule** (DOJ, 28 CFR part 35 subpart H) | State and local governments (incl. public universities, courts, transit) | **WCAG 2.1 AA** (web and mobile apps) | Original 2026/2027 dates **extended by April 2026 interim final rule**: **26 April 2027** (population ≥50,000), **26 April 2028** (smaller entities, special districts). Exceptions: archived content, preexisting conventional documents, third-party content, individualised password-protected documents, preexisting social media posts |
| **US – Section 504 (HHS rule)** | Recipients of HHS federal funding (healthcare, human services) | WCAG 2.1 AA | 2024 rule; compliance date for larger recipients (15+ employees) was May 2026. Check current enforcement guidance |
| **US – ADA Title III** | Public accommodations (private businesses) | No regulation specifying WCAG; courts and DOJ settlements commonly reference WCAG 2.1/2.2 AA | Active private litigation (thousands of web accessibility suits per year, heavily e-commerce); state laws (e.g., California Unruh Act) add damages exposure |
| **US – Section 508** (Rehabilitation Act; 2017 Refresh) | Federal agencies' ICT, and vendors selling to them | **WCAG 2.0 AA** (incorporated by reference) | In force; ACR/VPAT expected in procurement |
| **UK – Equality Act 2010** | Service providers | "Reasonable adjustments"; WCAG AA is the practical benchmark | In force |
| **UK – Public Sector Bodies Accessibility Regulations 2018** | Public-sector sites and apps | WCAG 2.2 AA (monitoring since Oct 2024) | Accessibility statement required; GDS monitoring |
| **Canada – Accessible Canada Act** | Federally regulated entities | CAN/ASC–EN 301 549 | Planning and progress report obligations |
| **Ontario – AODA** | Public sector and organisations with 50+ employees | WCAG 2.0 AA | In force |

### Conformance documentation
- **ACR (Accessibility Conformance Report)** using the ITI **VPAT®** template: editions for WCAG, Section 508, EU (EN 301 549) and INT (all). For each criterion record Supports / Partially Supports / Does Not Support / Not Applicable, with remarks. Base it on a documented evaluation (see accessibility-audit-process) and date it.
- **Accessibility statement**: conformance status (full/partial/non), known limitations with workarounds and timelines, contact/feedback channel, enforcement procedure (EU/UK public sector), date of last review. The W3C WAI statement generator provides a structure; EU public-sector statements follow the Commission's model.
- **EAA service information**: in general terms and conditions or equivalent, describe how the service meets accessibility requirements. Many teams publish this as an accessibility statement page linked from the footer.

### Engineering translation
| Obligation | Engineering deliverable |
|---|---|
| WCAG 2.2 AA conformance | Design-system components meeting AA; automated gates; manual audits per release train |
| Accessibility statement/info | `app/accessibility/page.tsx` with a dated statement; footer link on every page (consistent help, 3.2.6) |
| Feedback mechanism | Accessible contact form or email link; triage workflow with SLAs |
| Procurement ACR | ACR per product version, stored with release artifacts |
| Documents (PDFs) | Tagged PDFs meeting PDF/UA, or HTML equivalents |
| Mobile apps | Same standard (WCAG 2.1/2.2 AA via WCAG2ICT); React Native out of scope here |
| Third-party widgets | Vendor ACR review plus testing; contract clauses for remediation |

## Recommended Workflow
1. Identify markets and sectors, then list the applicable regimes (table above) with counsel.
2. Set the technical target: WCAG 2.2 AA (plus EN 301 549 non-web clauses if applicable, e.g., real-time text, video player features).
3. Baseline audit of key flows and templates.
4. Remediation plan prioritised by user impact and legal deadline; publish the statement with known issues.
5. Shift left: design review, lint and automated CI, component acceptance criteria.
6. Periodic re-audit (at least annually and on major releases). Update the ACR and statement with dates.
7. Monitor changes: EN 301 549 v4.1.1 OJEU citation, Section 508 updates, Title II guidance, WCAG 3 progress.

## Patterns
- **Compliance register** as a markdown table or GRC tool entry per product.
- **"Known issues" section** in the statement, generated from tagged tickets (`a11y`, `known-issue`).
- **Release checklist** with an ACR update gate for major versions.
- **Vendor intake questionnaire**: ACR date, evaluation method, AT tested, remediation SLAs.

## Anti-Patterns
- **Installing an overlay to "become compliant".** Doesn't fix underlying code; has faced FTC action for deceptive claims (accessiBe settlement, 2025) and continued litigation. Remediate the source.
- **Targeting WCAG 2.0 or 2.1 only because "that's what the law says".** Rework later. Target 2.2 AA.
- **ACRs claiming "Supports" everywhere without an evaluation.** Misrepresentation risk. Base them on audits and include remarks.
- **Treating the EAA as "EU only" when you sell to EU consumers from abroad.** It applies to services offered in the EU market.
- **Assuming PDFs, emails, and third-party checkout iframes are out of scope.** Often in scope. Inventory them.
- **Waiting for WCAG 3.** Years away. Comply with 2.2 now.

## Accessibility
- The technical substance is WCAG 2.2 A/AA (see wcag-2-2-compliance). EN 301 549 adds non-web ICT clauses (e.g., caption/audio description player controls in clause 7, documentation and support services in clause 12).

## Responsive Design
- Laws cover mobile web and native apps equally. The ADA Title II rule explicitly covers mobile apps. Test reflow and touch criteria (1.4.10, 2.5.x).

## Performance
- No direct legal performance requirement. But timeouts (2.2.1) and heavy pages that break AT usability can surface in complaints.

## Security
- Accessible authentication (3.3.8) is part of WCAG 2.2 and EN 301 549 v4.1.1. Coordinate CAPTCHA and MFA choices with security.
- Accessibility feedback channels must handle personal data (disability information) under GDPR and privacy policies.

## Testing
- Evidence-grade testing: documented methodology (WCAG-EM), scope and sample, AT/browser matrix, dated results, retest records.
- Section 508 federal context: the DHS Trusted Tester process is the recognised manual test methodology.

## Tooling
- ITI VPAT® template (WCAG, 508, EU, INT editions).
- W3C WCAG-EM Report Tool; W3C Accessibility Statement Generator.
- Accessibility Insights Assessment; axe Monitor/Level Access/Siteimprove (commercial monitoring).
- PAC (PDF Accessibility Checker) for PDF/UA.

## Framework Notes
- **Next.js.**
  - Add `app/accessibility/page.tsx` (statement) and footer link.
  - Server-render legal content for robustness.
  - Keep a `docs/acr/` folder versioned with releases.
  - Use `metadata` for titles (2.4.2).
- **React (Vite SPA).** Same deliverables. Ensure the statement page is reachable without JS where possible (static prerender), since some users and AT configurations struggle with heavy SPAs.

## AI Agent Guidance
- Do: default all work to WCAG 2.2 AA; state the applicable legal standard versions when asked, with dates and the "verify with counsel" caveat.
- Do: generate accessibility statement and ACR templates, filling only verified results. Mark unverified criteria "Not evaluated".
- Don't: provide legal conclusions about exemptions, recommend overlays, or claim compliance without audit evidence.
- Don't: present outdated deadlines. The ADA Title II dates are now April 2027/2028, and EN 301 549 v4.1.1 is published but not yet cited.
- Verify before done: dates and versions cross-checked against the Sources below; statement includes feedback contact and review date.

## Examples
```tsx
// app/accessibility/page.tsx (skeleton)
export const metadata = { title: 'Accessibility statement' };

export default function AccessibilityStatement() {
  return (
    <article>
      <h1>Accessibility statement for Acme Store</h1>
      <p>Last reviewed: <time dateTime="2026-09-15">15 September 2026</time></p>
      <h2>Conformance status</h2>
      <p>Acme Store is <strong>partially conformant</strong> with WCAG 2.2 Level AA. Partially conformant means some content does not yet fully conform.</p>
      <h2>Known limitations</h2>
      <ul>
        <li>Order history charts lack a data table alternative. Workaround: download CSV. Fix planned by 30 November 2026.</li>
      </ul>
      <h2>How we tested</h2>
      <p>Automated testing with axe-core; manual testing with NVDA 2026.x + Chrome, JAWS 2026 + Chrome, VoiceOver on macOS and iOS Safari.</p>
      <h2>Feedback</h2>
      <p>Contact <a href="mailto:accessibility@acme.example">accessibility@acme.example</a>. We respond within 5 business days.</p>
      <h2>Enforcement</h2>
      <p>If you are not satisfied with our response, you can contact your national enforcement body.</p>
    </article>
  );
}
```

## Related Skills
- [wcag-2-2-compliance](../wcag-2-2-compliance/Skill.md) — technical requirements
- [accessibility-audit-process](../accessibility-audit-process/Skill.md) — evidence and ACR production
- [automated-accessibility-testing](../automated-accessibility-testing/Skill.md) — continuous compliance
- [ecommerce-ux-patterns](../ecommerce-ux-patterns/Skill.md) — EAA-scoped products
- [fintech-ui-patterns](../fintech-ui-patterns/Skill.md) — banking services under EAA
- [healthcare-ui-patterns](../healthcare-ui-patterns/Skill.md) — Section 504/HHS context
- [ethical-design-and-dark-patterns](../ethical-design-and-dark-patterns/Skill.md) — overlapping consumer protection

## Sources
- [AccessibleEU: EN 301 549 v4.1.1 published (Sept 2026)](https://accessible-eu-centre.ec.europa.eu/content-corner/news/european-accessibility-standard-en-301-549-has-been-updated-2026-09-07_en) — Official (EU) — WCAG 2.2 adoption, not yet cited in OJEU
- [Directive (EU) 2019/882 (European Accessibility Act)](https://eur-lex.europa.eu/eli/dir/2019/882/oj) — Official — scope, dates, microenterprise exemption
- [ADA.gov: Web Rule First Steps](https://www.ada.gov/resources/web-rule-first-steps/) — Official (US DOJ) — WCAG 2.1 AA, extended dates, exceptions
- [Federal Register: Extension of Title II compliance dates (April 2026)](https://www.federalregister.gov/documents/2026/04/20/2026-07663/extension-of-compliance-dates-for-nondiscrimination-on-the-basis-of-disability-accessibility-of-web) — Official — interim final rule
- [Section508.gov: Laws and Policies](https://www.section508.gov/manage/laws-and-policies/) — Official (US GSA) — WCAG 2.0 incorporation
- [GOV.UK: Understanding accessibility requirements for public sector bodies](https://www.gov.uk/guidance/accessibility-requirements-for-public-sector-websites-and-apps) — Official (UK) — WCAG 2.2 monitoring, statements
- [Jackson Lewis: DOJ extends Title II; HHS May 2026 deadline](https://www.jacksonlewis.com/insights/doj-extends-public-entities-compliance-deadline-ada-related-website-accessibility-hhss-may-2026-deadline-still-looms) — Community (law firm) — Section 504 HHS context
- [ITI VPAT](https://www.itic.org/policy/accessibility/vpat) — Official (industry) — ACR template editions
- [W3C Accessibility Statement Generator](https://www.w3.org/WAI/planning/statements/) — Official — statement structure

## License / Usage Notes
Summaries of public legal texts and official guidance. Not legal advice. The VPAT® mark belongs to ITI.

## Quality Tier
A — primary official sources verified to Sept 2026. Legal specifics (national EAA transpositions, HHS enforcement, Title III case law) change often and need counsel review.

## Status
Active

## Last Verified
2026-09-15
