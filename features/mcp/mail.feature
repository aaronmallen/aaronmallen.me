Feature: Mail tools over MCP
  A client with the mail scope lists, reads and marks mail threads, makes tasks from them and saves
  Gmail drafts. A client without it sees no mail anywhere.

  Background:
    Given I am signed in to the admin

  Scenario: list_mail_threads lists the threads in a range of whole days, newest first
    Given the mail threads:
      | subject     |
      | Three days  |
      | Yesterday   |
      | Late        |
      | Just today  |
      | Too early   |
    And the mail thread "Three days" arrived "3 days ago at 09:00"
    And the mail thread "Yesterday" arrived "1 day ago at 09:00"
    And the mail thread "Late" arrived "yesterday at 23:59"
    And the mail thread "Just today" arrived "today at 00:00"
    And the mail thread "Too early" arrived "3 days ago at 23:59"
    And an MCP client connects with the scopes "read write mail" and I approve it
    When I call the MCP mail tool "list_mail_threads" with:
      """
      {"from": "<today-6>", "to": "<today>"}
      """
    Then the MCP answer lists the mail threads "Just today, Late, Yesterday, Too early, Three days"
    When I call the MCP mail tool "list_mail_threads" with:
      """
      {"from": "<today-2>", "to": "<today-1>"}
      """
    Then the MCP answer lists the mail threads "Late, Yesterday"

  Scenario: list_mail_threads says what the admin list shows
    Given the mail threads:
      | subject | status | reply to             | tags            |
      | Hello   | read   | someone@example.com  | urgent, billing |
    And the mail thread "Hello" arrived "2026-01-05T09:00:00Z"
    And the mail thread "Hello" snoozes until "2099-01-02T03:00:00Z"
    And an MCP client connects with the scopes "read write mail" and I approve it
    When I call the MCP mail tool "list_mail_threads" with:
      """
      {}
      """
    Then the MCP answer's "mail_threads.0" reads:
      """
      {"id": #[Hello], "account": "Contact form", "subject": "Hello", "reply_to": "someone@example.com", "status": "read",
        "tags": ["billing", "urgent"], "received_at": "2026-01-05T09:00:00Z", "snoozed_until": "2099-01-02T03:00:00Z"}
      """
    And the MCP answer marks "mail_threads.0.subject" as untrusted
    And the MCP answer marks "mail_threads.0.reply_to" as untrusted

  Scenario: list_mail_threads narrows to a status and counts every status in the range
    Given the mail threads:
      | subject    | status |
      | Fresh      | unread |
      | New spam   | spam   |
      | Old spam   | spam   |
      | Ancient    | read   |
    And the mail thread "New spam" arrived "1 day ago at 09:00"
    And the mail thread "Old spam" arrived "30 days ago at 09:00"
    And the mail thread "Ancient" arrived "900 days ago at 09:00"
    And an MCP client connects with the scopes "read write mail" and I approve it
    When I call the MCP mail tool "list_mail_threads" with:
      """
      {"from": "<today-6>", "to": "<today>", "status": "spam"}
      """
    Then the MCP answer lists the mail threads "New spam"
    And the MCP answer's "counts" is "{\"unread\":1,\"read\":0,\"spam\":1}"
    When I call the MCP mail tool "list_mail_threads" with:
      """
      {}
      """
    Then the MCP answer lists the mail threads "Fresh, New spam, Old spam, Ancient"
    And the MCP answer's "from" is "null"
    And the MCP answer's "to" is "null"
    And the MCP answer's "counts" is "{\"unread\":1,\"read\":1,\"spam\":2}"
    When I call the MCP mail tool "list_mail_threads" with:
      """
      {"to": "<today-31>"}
      """
    Then the MCP answer lists the mail threads "Ancient"

  Scenario: list_mail_threads pages through every thread in one status
    Given 102 old spam mail threads
    And the mail threads:
      | subject |
      | Fresh   |
    And an MCP client connects with the scopes "read write mail" and I approve it
    When I call the MCP mail tool "list_mail_threads" with:
      """
      {"status": "spam", "page": 1}
      """
    Then the MCP answer lists 100 mail threads, all spam
    When I call the MCP mail tool "list_mail_threads" with:
      """
      {"status": "spam", "page": 2}
      """
    Then the MCP answer lists the mail threads "Old spam 101, Old spam 102"

  Scenario: list_mail_threads refuses a status the admin lacks and a range that runs backwards
    Given an MCP client connects with the scopes "read write mail" and I approve it
    When I call the MCP mail tool "list_mail_threads" with:
      """
      {"from": "<today>", "to": "<today>", "status": "archived"}
      """
    Then the MCP answer holds "/status"
    When I call the MCP mail tool "list_mail_threads" with:
      """
      {"from": "<today>", "to": "<today-1>"}
      """
    Then the MCP answer says "from comes after to"

  Scenario: read_mail_thread reads the thread and its first message and keeps the visitor hash back
    Given the mail threads:
      | subject | body             | reply to      | tags    |
      | Hi      | I liked the post | a@example.com | billing |
    And the mail thread "Hi" snoozes until "2099-01-02T03:00:00Z"
    And an MCP client connects with the scopes "read write mail" and I approve it
    When I call the MCP mail tool "read_mail_thread" with:
      """
      {"id": #[Hi]}
      """
    Then the MCP answer's "account" is "\"Contact form\""
    And the MCP answer's "status" is "\"unread\""
    And the MCP answer's "tags" is "[\"billing\"]"
    And the MCP answer's "snoozed_until" is "\"2099-01-02T03:00:00Z\""
    And the MCP answer's "messages.0.body" is "\"I liked the post\""
    And the MCP answer's "messages.0.reply_to" is "\"a@example.com\""
    And the MCP answer marks "subject" as untrusted
    And the MCP answer marks "messages.0.body" as untrusted
    And the MCP answer's "" has the keys "account, id, messages, received_at, snoozed_until, status, subject, tags"
    And the MCP answer's "messages.0" has the keys "body, id, received_at, reply_to, subject"

  Scenario: read_mail_thread reads every message in a Gmail thread, oldest first
    Given the mail account "aaron@work.example"
    And the mail threads:
      | subject | account            | body  |
      | Plans   | aaron@work.example | First |
    And the mail thread "Plans" has a later message saying "Second"
    And an MCP client connects with the scopes "read write mail" and I approve it
    When I call the MCP mail tool "read_mail_thread" with:
      """
      {"id": #[Plans]}
      """
    Then the MCP answer's "account" is "\"aaron@work.example\""
    And the MCP answer's "messages.0.body" is "\"First\""
    And the MCP answer's "messages.1.body" is "\"Second\""
    When I call the MCP mail tool "read_mail_thread" with:
      """
      {"id": 999999}
      """
    Then the MCP answer says "no mail thread has the ID 999999"

  Scenario: mark_mail_thread marks a thread and refuses what it does not know
    Given the mail threads:
      | subject | status |
      | Hello   | unread |
      | Offer   | read   |
    And an MCP client connects with the scopes "read write mail" and I approve it
    When I call the MCP mail tool "mark_mail_thread" with:
      """
      {"id": #[Hello], "status": "read"}
      """
    Then the mail thread "Hello" is now read
    When I call the MCP mail tool "mark_mail_thread" with:
      """
      {"id": #[Offer], "status": "spam"}
      """
    Then the MCP answer reads:
      """
      {"id": #[Offer], "status": "spam"}
      """
    When I call the MCP mail tool "mark_mail_thread" with:
      """
      {"id": 999999, "status": "read"}
      """
    Then the MCP answer says "no mail thread has the ID 999999"
    When I call the MCP mail tool "mark_mail_thread" with:
      """
      {"id": #[Hello], "status": "archived"}
      """
    Then the MCP answer holds "/status"
    And the mail thread "Hello" is now read

  Scenario: make_mail_task makes a task on the list it names, linked to the thread
    Given the mail threads:
      | subject         |
      | Lunch on Friday |
    And an MCP client connects with the scopes "read write mail" and I approve it
    When I call the MCP mail tool "make_mail_task" with:
      """
      {"id": #[Lunch on Friday], "title": "Book lunch", "list": "someday", "archive": false}
      """
    Then the MCP answer's "title" is "\"Book lunch\""
    And the MCP answer's "list" is "\"someday\""
    And the MCP answer's "archived" is "false"
    And the mail thread "Lunch on Friday" is linked to the task "Book lunch"
    And the mail thread "Lunch on Friday" is now unarchived
    When I call the MCP mail tool "make_mail_task" with:
      """
      {"id": #[Lunch on Friday], "title": "Again"}
      """
    Then the MCP answer says "mail thread 1 already has a task"
    And no task is called "Again"

  Scenario: make_mail_task puts the task on next and archives the thread by default
    Given the mail threads:
      | subject         |
      | Lunch on Friday |
    And an MCP client connects with the scopes "read write mail" and I approve it
    When I call the MCP mail tool "make_mail_task" with:
      """
      {"id": #[Lunch on Friday], "title": " "}
      """
    Then the MCP answer says "title: write the task down first"
    And no record is linked to the mail thread "Lunch on Friday"
    When I call the MCP mail tool "make_mail_task" with:
      """
      {"id": 999999, "title": "Book lunch"}
      """
    Then the MCP answer says "no mail thread has the ID 999999"
    When I call the MCP mail tool "make_mail_task" with:
      """
      {"id": #[Lunch on Friday], "title": "Book lunch"}
      """
    Then the MCP answer's "list" is "\"next\""
    And the MCP answer's "archived" is "true"
    And the mail thread "Lunch on Friday" is now archived

  Scenario: make_mail_task keeps the task when Gmail refuses to archive the thread
    Given the Google account "aaron@work.example" is connected with "openid gmail.modify"
    And the mail account "aaron@work.example"
    And the mail threads:
      | subject | account            | gmail id |
      | Reply   | aaron@work.example | refused  |
    And Gmail refuses changes to the mail thread "refused"
    And an MCP client connects with the scopes "read write mail" and I approve it
    When I call the MCP mail tool "make_mail_task" with:
      """
      {"id": #[Reply], "title": "Reply"}
      """
    Then the MCP answer's "archived" is "false"
    And the mail thread "Reply" is linked to the task "Reply"
    And the mail thread "Reply" is now unarchived

  Scenario: save_mail_draft saves a Gmail draft and files it in Drafts
    Given the Google account "aaron@work.example" is connected with "openid gmail.modify gmail.send"
    And the mail account "aaron@work.example"
    And Gmail answers POST "/users/me/drafts" with:
      """
      {"id": "r1", "message": {"id": "d1", "threadId": "t5"}}
      """
    And Gmail answers PUT "/users/me/drafts/r1" with:
      """
      {"id": "r1", "message": {"id": "d1", "threadId": "t5"}}
      """
    And Gmail holds the thread "t5" with the messages:
      | id | labels | from               | subject |
      | d1 | DRAFT  | aaron@work.example | Plans   |
    And Gmail serves each message of the thread "t5" alone
    And an MCP client connects with the scopes "read write mail" and I approve it
    When I call the MCP mail tool "save_mail_draft" with:
      """
      {"from": "aaron@work.example", "to": "ada@example.com", "subject": "Plans", "body": "Soon"}
      """
    Then the MCP answer reads:
      """
      {"draft": "r1"}
      """
    And Gmail received a draft holding "From: aaron@work.example"
    And Gmail received a draft holding "To: ada@example.com"
    And Gmail received a draft holding "Subject: Plans"
    And the Gmail thread "t5" reads:
      | draft | true |
    When I call the MCP mail tool "save_mail_draft" with:
      """
      {"from": "aaron@work.example", "to": "ada@example.com", "subject": "Plans", "body": "Later", "draft": "r1"}
      """
    Then Gmail received PUT "/users/me/drafts/r1"

  Scenario: save_mail_draft refuses an account that cannot send and says when Gmail refuses
    Given the Google account "aaron@work.example" is connected with "openid gmail.modify gmail.send"
    And the mail account "aaron@work.example"
    And the mail account "aaron@home.example"
    And Gmail answers POST "/users/me/drafts" with status 500
    And an MCP client connects with the scopes "read write mail" and I approve it
    When I call the MCP mail tool "save_mail_draft" with:
      """
      {"from": "aaron@home.example", "to": "ada@example.com", "subject": "Plans", "body": "Soon"}
      """
    Then the MCP answer holds "names no account that can send"
    When I call the MCP mail tool "save_mail_draft" with:
      """
      {"from": "aaron@work.example", "to": "ada@example.com", "subject": "Plans", "body": "Soon"}
      """
    Then the MCP answer says "Gmail would not save the draft; try again"

  Scenario: A client without the mail scope finds no mail in search, activity or attention
    Given the mail threads:
      | subject           | minutes ago |
      | Zeppelin sighting | 10          |
    And the task "Track the zeppelin"
    And an MCP client connects with the scopes "read write delete" and I approve it
    When I call the MCP mail tool "search" with:
      """
      {"query": "zeppelin"}
      """
    Then the MCP answer's "results" lists the kinds "task"
    When I call the MCP mail tool "search" with:
      """
      {"query": "zeppelin", "kind": "message"}
      """
    Then the MCP answer is an error saying "message rows need the mail scope"
    When I call the MCP mail tool "read_activity" with:
      """
      {"from": "<today>", "to": "<today>"}
      """
    Then the MCP answer does not hold "Zeppelin sighting"
    When I call the MCP mail tool "summarize_activity" with:
      """
      {"from": "<today>", "to": "<today>"}
      """
    Then the MCP answer does not hold "Zeppelin sighting"
    When I call the MCP tool "list_attention"
    Then the MCP answer does not hold "Zeppelin sighting"

  Scenario: A client without the mail scope sees no mail in the inbox and may not change it there
    Given the mail threads:
      | subject           | minutes ago |
      | Zeppelin sighting | 10          |
    And a post "Engines" published an hour ago
    And a webmention on the post "Engines"
    And an MCP client connects with the scopes "read write delete" and I approve it
    When I call the MCP tool "list_inbox"
    Then the MCP answer's "inbox" lists the kinds "webmention"
    When I call the MCP mail tool "clear_inbox" with:
      """
      {"messages": [#[Zeppelin sighting]]}
      """
    Then the MCP answer says "message rows need the mail scope"
    When I call the MCP mail tool "snooze_inbox" with:
      """
      {"messages": [#[Zeppelin sighting]], "snoozed_until": "2099-01-02T03:00:00Z"}
      """
    Then the MCP answer says "message rows need the mail scope"
    When I call the MCP mail tool "snooze_inbox_row" with:
      """
      {"kind": "message", "id": #[Zeppelin sighting], "snoozed_until": "2099-01-02T03:00:00Z"}
      """
    Then the MCP answer says "message rows need the mail scope"
    And the mail thread "Zeppelin sighting" reads:
      | status        | unread |
      | snoozed_until | none   |
    Given the mail thread "Zeppelin sighting" snoozes until "2099-01-02T03:00:00Z"
    When I call the MCP mail tool "wake_inbox_row" with:
      """
      {"kind": "message", "id": #[Zeppelin sighting]}
      """
    Then the MCP answer says "message rows need the mail scope"
    And the mail thread "Zeppelin sighting" is now snoozed

  Scenario: A client without the mail scope may not link a mail thread and sees no linked one
    Given the mail threads:
      | subject           |
      | Zeppelin sighting |
    And a post "Engines" published an hour ago
    And a post "Airships" published an hour ago
    And the post "Airships" is linked to the mail thread "Zeppelin sighting"
    And an MCP client connects with the scopes "read write delete" and I approve it
    When I call the MCP mail tool "link_records" with:
      """
      {"kind": "post", "id": 1, "other_kind": "mail_thread", "other_id": #[Zeppelin sighting]}
      """
    Then the MCP answer says "this endpoint needs a token with the mail scope"
    When I call the MCP mail tool "list_links" with:
      """
      {"kind": "post", "id": 2}
      """
    Then the MCP answer's "links" is "{}"

  Scenario: A client with the mail scope finds, lists, links and clears mail
    Given the mail threads:
      | subject           | minutes ago |
      | Zeppelin sighting | 10          |
    And the task "Track the zeppelin"
    And a post "Engines" published an hour ago
    And an MCP client connects with the scopes "read write mail" and I approve it
    When I call the MCP mail tool "search" with:
      """
      {"query": "zeppelin"}
      """
    Then the MCP answer's "results" lists the kinds "message, task"
    When I call the MCP tool "list_inbox"
    Then the MCP answer's "inbox" lists the kinds "message"
    When I call the MCP mail tool "link_records" with:
      """
      {"kind": "post", "id": 1, "other_kind": "mail_thread", "other_id": #[Zeppelin sighting]}
      """
    Then the MCP answer marks "links.mail_thread.0.title" as untrusted
    And the MCP answer's "links.mail_thread.0.title" is "\"Zeppelin sighting\""
    When I call the MCP mail tool "unlink_records" with:
      """
      {"kind": "mail_thread", "id": #[Zeppelin sighting], "other_kind": "post", "other_id": 1}
      """
    Then no record is linked to the mail thread "Zeppelin sighting"
    When I call the MCP mail tool "clear_inbox" with:
      """
      {"messages": [#[Zeppelin sighting]]}
      """
    Then the mail thread "Zeppelin sighting" is now read
