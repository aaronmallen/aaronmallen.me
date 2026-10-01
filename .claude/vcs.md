# Version control

This project uses [Jujutsu]. Every skill that touches version control works from the commands below.

## Read the working change

`jj diff` with no arguments is the working copy against its parent, which is the work in flight.

```sh
jj diff
jj diff --name-only
jj log -r @ --no-graph
```

## Read the current revision

```sh
jj log -r @ --no-graph -T 'commit_id.short()'
```

## Record a change

```sh
jj desc --stdin <<'MSG'
app: add the post view and layout

The body goes here, already wrapped.

Closes #12
MSG
jj new
```

A heredoc into `--stdin` keeps the wrapping you wrote. `jj new` then starts the next change. The last paragraph
names the issue, as [`.claude/issues.md`][issues] says under "Reference an issue".

## Split a change

Put the first commit's paths in their own change:

```sh
JJ_EDITOR=true jj split <paths>
```

Both halves come out with no description, so describe each one with `jj desc -r <revision> --stdin`. Set
`JJ_EDITOR`, or `jj split` opens an editor and waits forever.

## Work in parallel workspaces

Each agent that runs beside others gets a workspace of its own, in a sibling directory outside the repo. Never put
one under a dot directory: RuboCop's `**/` globs skip it, and lint passes when it should not.

```sh
jj workspace add ../aaronmallen.me-ws/<n> --name ws<n> -r <base>
```

Copy `.env` into it with `DATABASE_NAME=blog_ws<n>` on the end, so its tests run against their own database, and
run `mise trust -q .config/mise.toml` inside it. A workspace has no `.git`, so `gh` there needs
`-R aaronmallen/aaronmallen.me`.

## Linearize workspaces

When every agent in a wave is done, put their commits in one line on the tip, one workspace at a time:

```sh
jj rebase -b 'ws<n>@-' -d <tip>
jj workspace forget ws<n>
```

The last commit you rebased is the next `<tip>`. Delete the workspace's directory once it is forgotten. If its
empty working-copy commit is still in `jj log`, abandon it.

Rebasing keeps each message as it was. Before you go on, read the descriptions on the line:

```sh
jj log --no-pager -r '<base>..<tip>' -T 'change_id.short() ++ " " ++ description ++ "\n"'
```

Each issue gets one `Closes #<n>`, on its last commit, and its earlier commits say `See #<n>`. A spec gets one
`Closes #<spec>`, on the last commit of its last sub-issue. Fix a description that breaks this with
`jj desc -r <revision> --stdin`.

## Read the change a decision produced

A record belongs in a commit sitting under the commits that carry the decision out:

```sh
jj log --no-pager -r '@::' -T 'change_id.short() ++ " " ++ description.first_line() ++ "\n"'
jj diff --no-pager -r <the commit below the record>
```

[issues]: .claude/issues.md
[Jujutsu]: https://jj-vcs.github.io/jj
