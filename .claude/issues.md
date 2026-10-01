# Issues

Issues live on GitHub in [`aaronmallen/aaronmallen.me`][repo]. Every skill that reads or files an issue works from
the commands below, through `gh`. The repository is public, so anything you file is public: [redact](#redact) it
first.

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

## Redact

Before you file, swap each of these for `[redacted]`:

- hostnames
- secrets and tokens
- details of the home network, IP addresses among them
- device names
- email addresses
- other people's names

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

Read an issue's parent spec. It answers 404 when the issue has none:

```sh
gh api repos/aaronmallen/aaronmallen.me/issues/<child>/parent --jq .number
```

## Blocked by

Order comes from these relations, not from issue numbers:

```sh
gh api -X POST repos/aaronmallen/aaronmallen.me/issues/<blocked>/dependencies/blocked_by \
  -F issue_id="$(gh api repos/aaronmallen/aaronmallen.me/issues/<blocker> --jq .id)"
gh api repos/aaronmallen/aaronmallen.me/issues/<blocked>/dependencies/blocked_by \
  --jq '.[] | {number, state, labels: [.labels[].name]}'
```

An issue with an open blocker also carries the `blocked` label. A blocker in `needs review` counts as done,
since its commit closes it on the next push. When you finish an issue, take `blocked` off every issue it blocked
whose other blockers are all closed or in `needs review`:

```sh
gh api repos/aaronmallen/aaronmallen.me/issues/<finished>/dependencies/blocking --jq '.[].number'
```

## Change state

```sh
gh issue edit 12 --add-label 'in progress'
gh issue edit 12 --remove-label 'in progress' --add-label 'needs review'
gh issue close 12 --reason 'not planned'
gh issue reopen 12
```

Finished work does not close by hand. Its commit says `Closes #12`, and GitHub closes the issue when the owner
pushes. Until then the issue sits open in `needs review`. GitHub leaves that label on a closed issue, so take it
off once the issue closes: `gh issue edit 12 --remove-label 'needs review'`.

## Reference an issue

A commit names the issue it works on in a paragraph of its own at the end of the message:

| Line | When |
| --- | --- |
| `See #12` | A commit that leaves more of #12 to do. |
| `Closes #12` | The last commit for #12, or the only one. |
| `Closes #9` | The last commit of a spec's last open sub-issue, on the line after the issue's own. |

Use only `See` and `Closes`. GitHub closes an issue on any of its keywords (`Fixes`, `Resolves` and the rest), so a
stray one closes work that is not done. One issue gets one `Closes`, on its last commit. A commit for no issue has
no line.

[repo]: https://github.com/aaronmallen/aaronmallen.me/issues
