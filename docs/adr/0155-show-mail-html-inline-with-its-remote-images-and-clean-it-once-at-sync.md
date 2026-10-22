---
id: "0155"
title: Show mail HTML inline with its remote images, and clean it once at sync
status: active
created: 2026-10-12
area:
  - admin
  - lib
  - mail
issue: "#1157"
amended:
  - "#1392"
  - "#1499"
  - "#1602"
tags:
  - mail
  - gmail
  - html
  - sanitize
  - images
  - privacy
  - csp
  - reader
---

# ADR 0155: Show mail HTML inline with its remote images, and clean it once at sync

![Active][status]

## Context

[ADR 0150][0150] mirrors Gmail into the `mail` slice. `Mail::GmailThread` in `lib/mail/gmail_thread.rb` stores each
message's HTML part in `html_body`, cleaned by Sanitize's relaxed config less the `style` element, which drops
scripts, event handlers and `javascript:` links. The admin reader in `slices/admin/ui/components/mail/reader.rb`
shows only the plain `body`, so links, lists and images are lost.

Spec #1156 has the reader show the HTML. Mail comes from anyone, and an image loads from wherever its `src` points,
so showing one tells the sender the owner opened the mail, from where, and when. [ADR 0108][0108] turns remote images
in imported markdown into links for that reason. Hanami's default content security policy, which the admin keeps,
lets an image load from any `https` host.

## Decision

**The reader puts a message's `html_body` straight into the page**, in a div styled like the design's rich body. A
message with no HTML, such as a contact form one, shows its plain `body` as it does now.

**Remote images load as they come.** ADR 0108's swap does not run on mail.

**HTML is cleaned once, at sync, by `Mail::GmailThread`.** The reader trusts what the row holds and does not clean it
again. Any change to what mail may carry goes in that class.

**Mail keeps no `class` or `id` attributes.** The admin stylesheet ships classes that set `position: fixed`, so a
class on mail markup could lay it over the admin as the `position` property once could, and an `id` could clash
with one the admin scripts look up. Cleaning drops both, as `Markdown::Note` does. Queue
`Mail::Jobs::RecleanMailHtml` once after this ships, so stored mail loses them too.

**Mail paints only inside its own box.** `.mail-rich` sets `contain: paint` and `overflow: clip`, so a negative
margin or any other trick cannot paint mail over the admin chrome. Cleaning also drops `transform`, `translate`,
`rotate` and `scale`, which move a block without moving its box. Queue `Mail::Jobs::RecleanMailHtml` once after this
ships, so stored mail loses them too.

**Clean stored mail again whenever the Sanitize config or gem changes.** Gmail mail keeps no raw HTML, so
`Mail::Jobs::RecleanMailHtml` fetches each stored Gmail thread again, a page at a time, and rewrites each message's
`html_body` through `Mail::GmailThread`. It leaves a thread Gmail no longer has as it is and logs how many it left.
Queue it by hand, once, after the change ships.

## Alternatives

**A sandboxed iframe.** It walls mail markup off from the admin, but the document inside takes none of the admin's
styles, so mail would not read like the design's rich body. The owner picked an inline div in #1156.

**Block remote images, or show them as links like ADR 0108.** Either keeps the sender from learning the mail was
read, and either leaves most HTML mail a page of gaps or links. The owner picked showing them in #1156.

**Clean again at render time.** It would guard against a row cleaned under a looser config, at the cost of a
second pass on every page. #1156 rules it out.

## Consequences

The mail screen reads like the mail. In return, opening a message tells its sender, and any tracker it carries, that
the owner read it, along with the owner's address and the time.

Mail markup sits in the admin's document. It carries no `class` or `id`, so the admin's CSS reaches it only
through element selectors, and mail that leans on its own classes loses that styling.

The sync is the only guard. A change to the Sanitize config reaches old rows only after they sync again or the
clean job runs, and a bug there puts whatever it lets through straight into the admin. The job cannot reach a
thread Gmail has dropped, or contact form mail, which keeps no HTML.

An image on plain `http` does not load, since the content security policy allows only `https`.

[0108]: 0108-show-remote-images-in-imported-markdown-as-links.md
[0150]: 0150-mirror-gmail-and-contact-messages-in-a-mail-slice.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
