Feature: Admin mail list and reader
  The mail screen lists threads from each Gmail account and the contact form,
  sorts them into folders and labels, and reads one thread beside the list.

  Scenario: Mail sends a visitor who has not signed in to sign in
    When I visit "/admin/mail"
    Then I am sent to sign in
    When I visit "/admin/mail/settings"
    Then I am sent to sign in
    And the mail page "/admin/mail/1/menu" answers with status 302

  Scenario: The mail page lists threads from every account newest first
    Given I am signed in to the admin
    And the mail account "aaron@work.example"
    And the mail threads:
      | subject       | account            | minutes ago |
      | From work     | aaron@work.example | 1           |
      | From the form | contact form       | 0           |
    When I visit "/admin/mail"
    Then the mail list shows "From the form, From work"
    And the mail account picker offers "All accounts · 2, aaron@work.example · 1, Contact form · 1"
    And the mail head says "2 unread across 1 Gmail account and the contact form"
    And the mail row "From work" shows "aaron@work.example"
    And the page has no axe breaches in light or dark
    When I pick the mail account "aaron@work.example"
    Then the mail list shows "From work"
    And the mail row "From work" has no account chip
    And the mail page "/admin/mail?page=2" answers with status 404
    And the mail page "/admin/messages" answers with status 404

  Scenario: An empty folder says so
    Given I am signed in to the admin
    When I visit "/admin/mail?folder=sent"
    Then the mail list says "Sent is empty."

  Scenario: Each folder holds its own threads and counts them on the sidebar
    Given I am signed in to the admin
    And the mail account "aaron@work.example"
    And the mail threads:
      | subject    | account            | category | starred | archived | status | snoozed hours | draft | trashed | sent |
      | Plain      | aaron@work.example |          |         |          |        |               |       |         |      |
      | Primary    | aaron@work.example | personal |         |          |        |               |       |         |      |
      | Newsletter | aaron@work.example | updates  |         |          |        |               |       |         |      |
      | Kept       | aaron@work.example |          | yes     | yes      | read   |               |       |         |      |
      | Later      | aaron@work.example |          |         |          |        | 1             |       |         |      |
      | Filed      | aaron@work.example |          |         | yes      |        |               |       |         |      |
      | Unsent     | aaron@work.example |          |         |          |        |               | yes   |         |      |
      | Junk       | aaron@work.example |          |         |          | spam   |               |       |         |      |
      | Binned     | aaron@work.example |          | yes     |          |        |               |       | yes     |      |
      | Replied    | aaron@work.example |          |         | yes      | read   |               |       |         | yes  |
    When I visit "/admin/mail"
    Then the mail list holds "Plain, Primary"
    And the mail folders count:
      | Inbox   | 2 |
      | Updates | 1 |
      | Snoozed | 1 |
      | Drafts  | 1 |
      | Spam    | 1 |
      | Starred |   |
    When I open the mail folder "Updates"
    Then the mail list holds "Newsletter"
    When I open the mail folder "Starred"
    Then the mail list holds "Kept"
    When I open the mail folder "Snoozed"
    Then the mail list holds "Later"
    When I open the mail folder "Sent"
    Then the mail list holds "Replied"
    When I open the mail folder "Drafts"
    Then the mail list holds "Unsent"
    And the mail folder select picks "drafts"
    And the mail folder select offers the folders "inbox, updates, starred, snoozed, sent, drafts, all, spam, trash"
    When I open the mail folder "All mail"
    Then the mail list holds "Plain, Primary, Newsletter, Kept, Later, Filed, Replied"
    When I open the mail folder "Spam"
    Then the mail list holds "Junk"
    And the mail folder "Spam" is open
    When I open the mail folder "Trash"
    Then the mail list holds "Binned"
    When I visit "/admin/mail?folder=junk"
    Then the mail list holds "Plain, Primary"

  Scenario: Gmail labels and contact form tags list as labels
    Given I am signed in to the admin
    And the mail account "aaron@work.example"
    And the mail threads:
      | subject          | account            | status | labels   | tags    |
      | Plan it          | aaron@work.example |        | planning |         |
      | Plan it again    | aaron@work.example | read   | planning |         |
      | Planned junk     | aaron@work.example | spam   | planning |         |
      | Billing question | contact form       |        |          | billing |
      | Unlabeled        | aaron@work.example |        |          |         |
    When I visit "/admin/mail"
    Then the mail sidebar groups the labels:
      | aaron@work.example | planning1 |
      | Contact form       | billing1  |
    And the mail folder select offers the labels "#planning · aaron@work.example, #billing · Contact form"
    And the mail row "Plan it" shows "#planning"
    When I visit "/admin/mail?folder=label:planning"
    Then the mail list holds "Plan it, Plan it again"
    And the mail row "Plan it" does not show "#planning"
    When I visit "/admin/mail?folder=label:billing"
    Then the mail list shows "Billing question"
    When I visit the mail page "/admin/mail?account=@[aaron@work.example]"
    Then the mail sidebar lists the labels "planning"

  Scenario: The unread switch and the search narrow the list
    Given I am signed in to the admin
    And the mail account "aaron@work.example"
    And the mail threads:
      | subject         | account            | status | body       | from         | reply to            | tags    |
      | Invoice overdue | aaron@work.example |        | please pay | Ada Lovelace | ada@engines.example |         |
      | Lighthouse      | aaron@work.example | read   | a question |              |                     |         |
      | Tagged          | contact form       | read   |            |              |                     | billing |
    When I visit "/admin/mail?show=unread"
    Then the mail list shows "Invoice overdue"
    When I visit "/admin/mail?show=unread&folder=label:billing"
    Then the mail list says "Nothing unread in #billing."
    When I visit "/admin/mail?search=ighthou"
    Then the mail list shows "Lighthouse"
    When I visit "/admin/mail?search=leas"
    Then the mail list shows "Invoice overdue"
    When I visit "/admin/mail?search=ovelac"
    Then the mail list shows "Invoice overdue"
    When I visit "/admin/mail?search=engines.ex"
    Then the mail list shows "Invoice overdue"
    When I visit "/admin/mail?search=illin"
    Then the mail list shows "Tagged"
    When I visit "/admin/mail?search=zebra"
    Then the mail list says "No mail matches."
    When I visit "/admin/mail?search=invoice&show=unread"
    Then the mail search holds "invoice" and shows "unread"

  Scenario: A row names the sender, counts the messages and previews the latest one
    Given I am signed in to the admin
    And the mail account "aaron@work.example"
    And the mail threads:
      | subject       | account            | from         | body  | starred | snoozed hours | minutes ago |
      | Release notes | aaron@work.example | Sean Collins | First | yes     | 24            | 1           |
    And the mail thread "Release notes" has the messages:
      | from         | body        |
      | Sean Collins | Latest word |
    When I visit "/admin/mail?folder=snoozed"
    Then the mail row "Release notes" is from "Sean Collins"
    And the mail row "Release notes" reads "Release notes · 2"
    And the mail row "Release notes" wears a star
    And the mail row "Release notes" is dimmed
    And the mail row "Release notes" shows "wakes"
    And the mail row "Release notes" previews "Latest word"
    And the page has no axe breaches in light or dark

  Scenario: A row previews the latest message that is not a draft
    Given I am signed in to the admin
    And the mail threads:
      | subject | body  | minutes ago |
      | Notes   | First | 2           |
    And the mail thread "Notes" has the messages:
      | body        | minutes ago | draft |
      | Latest word | 1           |       |
      | Unsent      | -1          | yes   |
    When I visit "/admin/mail"
    Then the mail row "Notes" previews "Latest word"

  Scenario: A row previews only the start of a long message
    Given I am signed in to the admin
    And the mail threads:
      | subject | body  |
      | Long    | First |
    And the mail thread "Long" has a newer message of 500 letters and a tail
    When I visit "/admin/mail"
    Then the mail row "Long" previews the first 500 letters alone

  Scenario: A draft row says who it goes to
    Given I am signed in to the admin
    And the mail account "aaron@work.example"
    And the mail threads:
      | subject     | account            | draft | reply to       |
      | Reply later | aaron@work.example | yes   | jo@example.com |
    When I visit "/admin/mail?folder=drafts"
    Then the mail row "Reply later" is from "Draft to jo@example.com"

  Scenario: A row marks mail that waits in Waiting and the reader says why
    Given I am signed in to the admin
    And the mail account "aaron@work.example"
    And the mail threads:
      | subject  | account            | status | snoozed hours |
      | Hi there | contact form       |        |               |
      | Quiet    | aaron@work.example | read   |               |
      | Later    | contact form       |        | 24            |
    When I visit "/admin/mail"
    Then the mail row "Hi there" waits in Waiting
    And the mail row "Quiet" has no why chip
    When I visit the mail page "/admin/mail?thread=#[Hi there]"
    Then the mail reader says why it waits: "contact form"
    When I visit "/admin/mail?folder=snoozed"
    Then the mail row "Later" has no why chip
