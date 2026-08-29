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
MSG
jj new
```

A heredoc into `--stdin` keeps the wrapping you wrote. `jj new` then starts the next change.

## Split a change

Put the first commit's paths in their own change:

```sh
JJ_EDITOR=true jj split <paths>
```

Both halves come out with no description, so describe each one with `jj desc -r <revision> --stdin`. Set
`JJ_EDITOR`, or `jj split` opens an editor and waits forever.

## Read the change a decision produced

A record belongs in a commit sitting under the commits that carry the decision out:

```sh
jj log --no-pager -r '@::' -T 'change_id.short() ++ " " ++ description.first_line() ++ "\n"'
jj diff --no-pager -r <the commit below the record>
```

[Jujutsu]: https://jj-vcs.github.io/jj
