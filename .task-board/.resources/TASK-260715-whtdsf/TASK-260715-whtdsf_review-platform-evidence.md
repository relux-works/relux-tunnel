# TASK-260715-whtdsf revision 4 — independent platform evidence

Checked on 2026-08-30 against current official GitHub documentation.

- `issues: opened` is supported; for the `issues` event GitHub records `GITHUB_SHA` as the last commit on the default branch and `GITHUB_REF` as the default branch, and requires the workflow file on the default branch:
  https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#issues
- The Create an issue REST endpoint accepts GitHub App installation access tokens and requires only `Issues` repository permission (write):
  https://docs.github.com/en/rest/issues/issues#create-an-issue
- Events created with a GitHub App installation token can trigger workflows where `GITHUB_TOKEN` recursion suppression would not; GitHub explicitly recommends an App installation token or PAT for token-triggered events:
  https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow
- Workflow/job YAML adjusts `GITHUB_TOKEN` permissions after repository defaults, confirming the contract's refusal to treat repository defaults as a hard ceiling:
  https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#how-permissions-are-calculated-for-a-workflow-job
- GitHub-hosted runners have public Internet access by default, matching the contract's explicit PR egress capability:
  https://docs.github.com/en/enterprise-cloud@latest/actions/concepts/runners/private-networking#about-github-hosted-runners-networking
- GitHub documents a full commit SHA as the safest reusable-workflow reference:
  https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows

Conclusion: the revision 4 issue-plane release-request design and its stated token/network/reusable-workflow boundaries are supported by current primary documentation. The eventual production implementation must still prove the exact sender/App attribution, event capture, replay refusal, and permission denial cases listed in section 8 of the contract.
