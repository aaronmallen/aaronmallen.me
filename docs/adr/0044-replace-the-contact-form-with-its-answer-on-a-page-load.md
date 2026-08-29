---
id: "0044"
title: Replace the contact form with its answer, on a page load
status: active
created: 2026-09-28
area: [assets, public]
issue: AA-668
tags: [contact, forms, javascript, redirect, throttle, validation]
---

# ADR 0044: Replace the contact form with its answer, on a page load

![Active][status]

## Context

The design for `/contact` holds the form and the confirmation in one document. The form carries `novalidate` and
no `action`, the confirmation follows it under `hidden`, both carry ids a script would grab, and the page ends with
a script tag for a `contact.js` the handoff never included. So the mock draws a page whose script checks the
fields, posts the form, hides it and shows the panel.

AA-384 had already decided the other way. A confirmation rendered in answer to a POST posts the message again on
a refresh, so `POST /contact` answers a stored message with a 302 to `/contact?sent=1`, and the page that follows
renders the confirmation. The record on guarding the contact form rules out a session, which is why the URL
carries the state. AA-511 asked which shape stands.

Two more states need a place, and the design draws neither: the 422 a bad entry gets and the 429 the
throttle gets.

## Decision

One slot under the heading holds one thing, and the server picks it.

| What happened | Status | URL | The slot holds |
| --- | --- | --- | --- |
| Nothing yet | 200 | `/contact` | the lede and the form |
| A message stored | 302, then 200 | `/contact?sent=1` | the sent panel |
| Entries refused | 422 | `/contact` | the lede and the form, holding what was typed, each bad field named |
| Sender throttled | 429 | `/contact` | the throttled panel |

`Public::UI::Views::Pages::Contact#outcome` renders one of the three branches, so a form and a panel never stand
together, and on the sent page the form is not in the document. The kicker, the heading and the block under the
slot stay on every one. The throttled panel copies the sent one in its own tone. A caught bot gets the same
redirect a sender gets, as AA-384 says.

Nothing on the page owns the submit. The form posts, and `Contact::Contracts::MessageContract` makes the only
ruling. Script on `/contact` keeps to three rules:

- The form carries no `novalidate`. The browser refuses a blank or badly typed field itself, from the `required`,
  `type` and `maxlength` the markup states.
- No script listens for a submit or posts the form.
- A script may change how the browser's refusal reads, not what it refuses. `app/assets/js/public/contact_errors.js`
  cancels the browser's bubble and shows the server's copy for that fault in the slot `ContactFieldError` renders
  under each field, and `message_count.js` counts characters. Neither holds a rule of its own.

## Alternatives

**Post with fetch and reveal the hidden panel**, which the mock's ids and its missing `contact.js` ask for. It holds
the sender's place on the page. The form still posts when the script breaks or never runs, so the server answers a
plain POST either way. The script buys a smoother send and leaves two paths to keep in step, two copies of the
error rendering, and nothing to link to.

**Take the design's `novalidate` and check the fields in script on submit**, as AA-516 first asked. It puts a
script in front of the post, which the rule above forbids, and it drops the checks the browser gives a reader with
no script for free.

**Leave the form under the panel on the sent page**, the way the mock stacks them. It hands the sender an empty
form under a thank you, which reads like the send did not take. The nav link gives a second message a cleaner
start.

**Keep the form in the document under `hidden`.** It matches the mock. It leaves fields in the page that nothing
will send, and it exists only for the reveal we are not writing.

## Consequences

One branch in one view answers every state, and a request spec reaches each one without a browser. A browser spec
runs the form with script off to prove it still posts and still refuses.

Anyone who loads `/contact?sent=1` sees a confirmation for a message nobody sent. AA-384 took that: the page makes
no claim about what is stored. AA-616 keeps the other states out of the URL, so `?throttled=1` shows the form.

Only the success path redirects. A refused or throttled sender stays on the answer to a POST, so refreshing it
posts again. The 422 keeps entries a redirect would drop, and the 429 has nothing worth carrying.

A throttled sender loses what they typed, because the refusal reads nothing back. Handing the text back invites the
retry the throttle exists to stop.

The browser and the contract disagree at the edges. The browser takes `ada@example` and the contract does not, so
that refusal lands on the server and renders in the same slot.

Nobody can link to a filled form or to an error. The day a public page needs a state the URL cannot carry, this
record runs out of room at the same moment the refusal of a session does.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
