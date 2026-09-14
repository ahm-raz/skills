# 17 — Common Failure Modes

> Most software fails because of how capable people work, not because they lack knowledge: they code before understanding, skip foundations, accumulate unmanaged debt, and rely on memory instead of mechanisms. This file catalogs twenty-one failure modes with symptoms, root causes, realistic examples, compounding costs, how experts avoid each one, and a concrete guardrail. It closes with how failure modes feed each other and a diagnostic checklist.

---

## Table of Contents

1. [Why Capable People Still Build Bad Systems](#1-why-capable-people-still-build-bad-systems)
2. [How to Read Each Failure Mode](#2-how-to-read-each-failure-mode)
3. [Failure Modes: Thinking & Understanding](#3-failure-modes-thinking--understanding)
   - 3.1 Coding before understanding
   - 3.2 Building features without validating foundations
4. [Failure Modes: Architecture & Design](#4-failure-modes-architecture--design)
   - 4.1 No architecture
   - 4.2 Overengineering
   - 4.3 Underengineering
   - 4.4 Weak boundaries
   - 4.5 Copy-paste architecture
   - 4.6 Framework-driven architecture
   - 4.7 Too many abstractions
   - 4.8 Too many dependencies
5. [Failure Modes: Quality, Performance & Security](#5-failure-modes-quality-performance--security)
   - 5.1 Premature optimization
   - 5.2 No testing strategy
   - 5.3 No observability
   - 5.4 No failure planning
   - 5.5 Security as an afterthought
   - 5.6 No quality gates
6. [Failure Modes: Knowledge & Decisions](#6-failure-modes-knowledge--decisions)
   - 6.1 No documentation
   - 6.2 No decision records
   - 6.3 Technical debt accumulation
7. [Failure Modes: Work Management](#7-failure-modes-work-management)
   - 7.1 Context switching
   - 7.2 Too much WIP
8. [How Failure Modes Compound](#8-how-failure-modes-compound)
9. [Amateur vs Professional vs Expert: Relationship to Failure](#9-amateur-vs-professional-vs-expert-relationship-to-failure)
10. [Diagnostic Checklist](#10-diagnostic-checklist)
11. [Key Takeaways](#key-takeaways)
12. [Self-Assessment Checklist](#self-assessment-checklist)

Related: [03-how-experts-design.md](03-how-experts-design.md), [04-architectural-decision-making.md](04-architectural-decision-making.md), [05-quality-engineering.md](05-quality-engineering.md), [07-designing-for-failure.md](07-designing-for-failure.md), [08-security-engineering.md](08-security-engineering.md), [10-knowledge-into-systems.md](10-knowledge-into-systems.md), [11-solo-developer-multiple-projects.md](11-solo-developer-multiple-projects.md), [14-expert-development-loop.md](14-expert-development-loop.md), [16-maturity-model.md](16-maturity-model.md).

---

## 1. Why Capable People Still Build Bad Systems

### What

A *failure mode* is a recurring pattern of working that reliably produces poor software outcomes, whatever the individual's technical ability.

### Why it matters

Technical skill is necessary but not sufficient. The same engineer can produce excellent or terrible systems depending on:
- **Incentives:** visible feature output gets rewarded, invisible foundations don't.
- **Feedback delay:** most failure modes cost nothing today and a lot in six months, so the cause-effect link is invisible.
- **Cognitive biases:** optimism about timelines, the availability heuristic ("last project used microservices"), sunk cost, the IKEA effect (overvaluing what you built).
- **Social pressure:** "we don't have time for design," "just ship it," fear of looking slow.
- **Missing mechanisms:** relying on memory and discipline, which fail under stress.

### How experts think about it

Experts don't believe they're immune to these failure modes. They assume they *will* fall into them under pressure and build **guardrails** that catch them: checklists, templates, CI gates, WIP limits, review protocols, decision records.

```text
Amateur:       "I know better than to do that."
Professional:  "I try hard not to do that."
Expert:        "I've built something that stops me from doing that when I'm tired and rushed."
```

### Common Mistake

Reading a list of failure modes, agreeing with all of them, and changing nothing structural. Awareness alone rarely changes behavior under deadline pressure.

---

## 2. How to Read Each Failure Mode

Each entry follows this structure:

| Field | Meaning |
|---|---|
| **What** | Definition |
| **Symptoms** | How to recognize it in a codebase, team, or your own habits |
| **Root cause** | Why it happens, often psychological or organizational rather than technical |
| **Example** | A realistic scenario |
| **Cost over time** | How the damage grows |
| **How experts avoid it** | Mindset and practice |
| **Guardrail** | A concrete mechanism (check, template, rule, automation) |
| **Expert Mental Model** | The internal heuristic |
| **Common Mistake** | The wrong fix people usually apply |

<!-- CONTINUE -->
