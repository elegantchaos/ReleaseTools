# Work Items

Each open item has a file here and an entry in the [Release Plan](../Documentation/Release%20Plan.md). Aim for a piece of work that can be finished, reviewed and verified in one PR. Split larger plans as their delivery work is scoped.

## The File

Name the file `<ID> <Title>.md`. Use an area prefix and number as a stable ID. Start the document with the ID and title, then record:

- **Status** as Started, Planned, Proposed or Parked. Mark work Proposed when its release is still open. In a parked item's notes, give the reason and where to resume.
- **Release** as a named release, Later or Unassigned.
- **Depends on** with links to prerequisite items, or “nothing”.
- **Sources** with links to the reviews, plans, decisions or journal entries that led to the item.

Give the item a **Finish Condition** that can be checked. Add **Notes** for delivery details or open questions. Link to the design or implementation document that owns any larger plan.

## Lifecycle

1. Create the item and add it to the Release Plan in the same PR.
2. Update the item and plan in the PR that starts, parks or resumes the work.
3. In the PR that finishes the work, add an **Outcome** with the PR and validation evidence, remove the Status line, move the file to [Done](Done/), remove its row from the Release Plan and fix links to it.

When findings describe the same work, add each review to the item's Sources.
