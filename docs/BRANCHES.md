# Branches

Every update ships the same way, so no branch is left behind main.

1. One branch per update. Open the pull request as soon as the branch is pushed.
2. When CI is green, **squash merge** into `main`. One commit per update keeps history short.
3. Delete the branch after the merge. The next update starts fresh from `main`.
4. If `main` moved while the branch was open, merge `main` into the branch before merging the pull request.

## Safety net

`scripts/branch-drift.sh` lists every remote branch that is behind `main` or has sat unmerged. The
**Branch drift** workflow runs it every morning and keeps one issue, labelled `branch-drift`, up to date.
The issue closes itself once every branch is merged or deleted.

```bash
git fetch --prune origin
scripts/branch-drift.sh            # table
scripts/branch-drift.sh --days 0   # include branches made today
```

## Repository settings that help

Set these once under Settings → General → Pull Requests, and Settings → Branches:

- Allow squash merging only. Turn off merge commits and rebase merging.
- Automatically delete head branches.
- Require branches to be up to date before merging, on the `main` rule.
