# Reviews

A review assesses the project at a specific revision. This folder holds reviews with findings awaiting an outcome. [Archive](Archive/) holds closed reviews. Track follow-up work in [work items](../Work/README.md) and the [Release Plan](../Documentation/Release%20Plan.md).

## Closing a Review

1. Record an outcome for each actionable finding. Use **fixed** with evidence, **declined** with Sam's reason, **superseded** with its replacement, **obsolete** with the reason it no longer applies, or **carried** with a link to its work item. Check the current revision before acting on an older finding.
2. For each carried finding, create a work item or add the review to the Sources of an existing item. Handle PR findings in the reviewed PR where possible.
3. Add an **Outcome** section below the title with the finding, outcome and evidence or destination. Preserve the rest of the review.
4. Move the closed review to [Archive](Archive/) and update references. For historical links that need to cite the original revision, use a permalink.

Close a PR's reviews in that PR. Close a full-project or document review in the PR that records its outcomes.
