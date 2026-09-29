# Issues

Issues live on GitHub in [`aaronmallen/aaronmallen.me`][repo]. Every skill that reads or files an issue works from
the commands below, through `gh`. The repository is public, so anything you file is public: keep hostnames,
secrets and details of the home network out of it.

Refer to an issue as `#12`. Linear keys such as `AA-213` belong to closed work from before the move, and stay as
plain text.

## Labels

Every issue carries one **type**, and only one:

| Type | For |
| --- | --- |
| `spec` | What we are building and how a reader knows it works. Work hangs off it as sub-issues. |
| `rfc` | A proposal that asks before anyone commits to it. |
| `bug`, `fix`, `regression` | Something broken. |
| `enhancement` | New behaviour. |
| `chore` | Upkeep, records and tooling. |
| `optimization` | The same behaviour, faster or cheaper. |
| `spike` | Time spent to answer a question, not to ship. |
| `release` | Cutting a version. |

Add one **area** label per slice or place the work touches: `activity`, `admin`, `analytics`, `contact`, `mcp`,
`posts`, `projects`, `public`, `record`, `social`, `suggestions`, `tags`, `tasks`, `build`, `tests`.

Add at most one **priority**:

| Label | Means |
| --- | --- |
| `p0` | Urgent. Drop everything. |
| `p1` | High. Other work waits on it. |
| `p2` | Medium. The body of the work. |
| `p3` | Low. Polish. |
| `p4` | Someday. |

**Status** labels track what the open or closed state cannot say: `in progress`, `needs review`, `blocked`, `on hold`
and `triage`.

## File an issue

Write the body to a file first, so the Markdown survives the shell.

```sh
gh issue create --title '<title>' --body-file <path> --assignee aaronmallen \
  --label enhancement --label tasks --label p2
```

It prints the issue's URL. The number is the last part of it. Always assign `aaronmallen`.

## Read an issue

```sh
gh issue view 12 --json number,title,body,labels,state
```

## Sub-issues

A sub-issue hangs off its parent through the API, not through a line in the body. The API wants the child's
internal `id`, which is not its number:

```sh
gh api -X POST repos/aaronmallen/aaronmallen.me/issues/<parent>/sub_issues \
  -F sub_issue_id="$(gh api repos/aaronmallen/aaronmallen.me/issues/<child> --jq .id)"
```

List a parent's sub-issues:

```sh
gh api repos/aaronmallen/aaronmallen.me/issues/<parent>/sub_issues \
  --jq '.[] | {number, title, state}'
```

## Blocked by

Order comes from these relations, not from issue numbers:

```sh
gh api -X POST repos/aaronmallen/aaronmallen.me/issues/<blocked>/dependencies/blocked_by \
  -F issue_id="$(gh api repos/aaronmallen/aaronmallen.me/issues/<blocker> --jq .id)"
gh api repos/aaronmallen/aaronmallen.me/issues/<blocked>/dependencies/blocked_by \
  --jq '.[] | {number, state}'
```

An issue with an open blocker also carries the `blocked` label. When you close an issue, take `blocked` off
every issue it blocked that has no other open blocker:

```sh
gh api repos/aaronmallen/aaronmallen.me/issues/<closed>/dependencies/blocking --jq '.[].number'
```

## Change state

```sh
gh issue edit 12 --add-label 'in progress'
gh issue close 12 --reason completed
gh issue close 12 --reason 'not planned'
gh issue reopen 12
```

Closing an issue takes `in progress` off it in the same breath: `gh issue edit 12 --remove-label 'in progress'`.

[repo]: https://github.com/aaronmallen/aaronmallen.me/issues
