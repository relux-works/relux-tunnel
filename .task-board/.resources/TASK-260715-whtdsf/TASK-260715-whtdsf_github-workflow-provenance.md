# TASK-260715-whtdsf — GitHub release-request trust evidence (rework 6)

Checked: 2026-08-30

## Corrected platform boundary

- `issues: opened` runs the workflow at the last protected-default-branch
  commit/ref and requires the workflow file on the default branch.
- A fine-grained GitHub App installation token needs only `Issues: write` to
  create the request issue.
- The rejected `repository_dispatch` design needed `Contents: write`; that same
  permission also authorizes GitHub Release/asset and Git-ref mutation APIs, so
  a documented endpoint convention could not constrain a stolen token.
- The request issue and sender claims remain untrusted. Trusted workflow code
  binds the captured event payload digest, verifies the expected App sender,
  issue/template/request identity, candidate ancestry, trusted workflow/policy
  digests, fresh check evidence, and an absent intended tag.

Official sources:

- https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#issues
- https://docs.github.com/en/rest/issues/issues#create-an-issue
- https://docs.github.com/en/rest/repos/repos#create-a-repository-dispatch-event
- https://docs.github.com/en/rest/releases/releases
- https://docs.github.com/en/rest/releases/assets
- https://docs.github.com/en/rest/git/refs

## Result

The short-lived requester App is scoped to `Issues: write`, not Contents. A
compromise can create/edit/close/reopen/label/spam request issues and comments,
but cannot mutate Contents, Git refs, GitHub Releases/assets, Actions/workflows,
protected environments, or secrets. The release workflow never refetches
mutable issue text as authority. Tag/push, `repository_dispatch`, selectable-ref
dispatch, and candidate-controlled upstream workflow completion are not release
entry points.

