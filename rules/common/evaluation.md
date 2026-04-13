# Evaluation Standards

## Agent Output Quality Rubric

Every agent deliverable must meet these minimum standards:

| Dimension | Min Score | What to Check |
|-----------|-----------|---------------|
| **Correctness** | 8/10 | Implements what was specified. No hallucinated features. |
| **Completeness** | 7/10 | All items from checklist done. No TODO/placeholder/stub left. |
| **Code Quality** | 7/10 | Functions <50 lines. Files <800 lines. No duplication >3 lines. |
| **Test Coverage** | 8/10 | >=80% coverage. Unit + integration tests present. |
| **Security** | 9/10 | No hardcoded secrets. Inputs validated. Auth correct. |
| **Performance** | 7/10 | No N+1. Indexes on query patterns. Pagination on lists. |

**Total minimum**: 7.0 weighted average to approve.

## Self-Evaluation Before Reporting Done

Every agent MUST ask itself before claiming done:

1. Did I implement ALL items from the task, not just the easy ones?
2. Are there any TODO comments or placeholder values I left behind?
3. Did I run the verification commands and see them pass?
4. Would I approve this code if I were reviewing it?
5. Did I write my learnings to agent-memory?

If any answer is "no" — you are NOT done. Keep working.

## Measuring Improvement Across Sessions

Track in gotchas.md:
- How many iterations to get tests passing? (fewer = improving)
- How many reviewer findings per PR? (fewer = improving)
- How many self-healing loop cycles needed? (fewer = improving)
