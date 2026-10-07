---
description: Commit changes to the repository.
name: commit
---

# Commit

The caller may name an issue, say whether this is the issue's last commit, and name a spec the commit closes. With
no issue, the commit names none.

## 1. Read the changes

Read the working change the way [`.claude/vcs.md`][vcs] describes. Work out what landed and why. If a change does
not explain itself, ask before writing the message.

## 2. Write the message

```text
<scope>: <subject>

<body>

<keywords>
```

Wrap the whole message at 72 characters.

The scope names the part of the project that changed. A change inside one slice, in `slices/<name>` or the
`lib/<name>` it owns, takes the slice name: `posts`, `admin`, `mcp`. Code outside any one slice takes one of `app`,
`assets`, `claude`, `config`, `db`, `lib`, `scripts`, `spec`, and a change that spans several slices takes `app`.

The subject names the code that landed, not what it does for a user. Write `app: add the post view and layout`,
not `app: make posts look right`. Developers read the log to find where a change went in.

The body is prose in paragraphs. Say what the change does, then say why each decision that is not obvious
went the way it did. It is not a bulleted changelog. Leave the body out only when the subject tells the whole
story.

The keywords name the issue, as [`.claude/issues.md`][issues] says under "Reference an issue". The last commit
for an issue, or its only one, ends with `Closes #<issue>`. Any commit before it ends with `See #<issue>`. When
the caller names a spec, add `Closes #<spec>` on the next line. With no issue, leave the paragraph out.

Add no `Co-Authored-By` trailer. An agent credits itself on the issue's task instead, as `/implement` says.

## 3. Commit

Record the change the way [`.claude/vcs.md`][vcs] describes, and pass the message you wrote without rewrapping it.

## 4. One change per commit

If the working copy holds unrelated work, split it before you describe anything. [`.claude/vcs.md`][vcs] says how.
Describe each half on its own. When the halves share an issue, only the one on top closes it, and the one
under it says `See`.

[issues]: .claude/issues.md
[vcs]: .claude/vcs.md
