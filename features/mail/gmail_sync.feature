Feature: Gmail sync
  The Gmail sync job follows each connected account's Gmail history and stores what changed:
  threads, messages, labels and the signature. It records a failure where the admin reads it.

  Background:
    Given the Google account "aaron@example.com" is connected with "openid gmail.modify"
    And Gmail is quiet at history "100" for "aaron@example.com"

  Scenario: A first sync follows Gmail from where it is now, stores its labels and backfills its mail
    Given Gmail has the label "Label_1" named "Receipts"
    And Gmail gives "aaron@example.com" the signature "<div>Aaron<script>alert(1)</script></div>"
    When the Gmail sync runs
    Then the mail account "aaron@example.com" follows the history "100"
    And the Gmail labels are "Label_1: Receipts"
    And the mail account "aaron@example.com" has the signature "<div>Aaron</div>"
    And Gmail received GET "/users/me/threads" 1 time
    And the mail sync records no failure

  Scenario: The sync clears the signature once Gmail has none
    Given Gmail gives "aaron@example.com" the signature "<b>Old</b>"
    When the Gmail sync runs
    And Gmail gives "aaron@example.com" the signature ""
    And an hour passes for the Gmail account "aaron@example.com"
    And the Gmail sync runs
    Then the mail account "aaron@example.com" has no signature

  Scenario: The sync stores new mail with its state, sender, bodies and labels
    Given the Gmail account "aaron@example.com" has synced to history "100"
    And the mail sync failed before with "gmail_failed"
    And Gmail has the label "Label_1" named "Receipts"
    And Gmail holds the thread "t1" with the messages:
      | id | labels                                      | at                   |
      | m1 | INBOX UNREAD STARRED CATEGORY_UPDATES Label_1 | 2026-01-05T09:00:00Z |
    And Gmail history moves to "250" with the threads "t1, t1"
    When the Gmail sync runs
    Then the Gmail thread "t1" reads:
      | subject     | Engines                  |
      | status      | unread                   |
      | starred     | true                     |
      | archived    | false                    |
      | trashed     | false                    |
      | sent        | false                    |
      | important   | false                    |
      | category    | updates                  |
      | received_at | 2026-01-05T09:00:00.000Z |
    And the Gmail thread "t1" has the messages:
      | gmail_id | subject | reply_to        | from_name    | body        | html_body          | visitor_hash | received_at              |
      | m1       | Engines | ada@example.com | Ada Lovelace | Hello there | <p>Hello there</p> | none         | 2026-01-05T09:00:00.000Z |
    And the Gmail thread "t1" wears the labels "Receipts"
    And the mail account "aaron@example.com" follows the history "250"
    And the mail sync records no failure

  Scenario: A change in Gmail keeps the snooze and tags on a stored thread
    Given the Gmail account "aaron@example.com" has synced to history "100"
    And Gmail holds the thread "t1" with the messages:
      | id |
      | m1 |
    And Gmail history moves to "200" with the threads "t1"
    And the Gmail sync runs
    And the mail thread "Engines" snoozes until "2099-01-02T03:00:00Z"
    And the mail thread "Engines" carries the tag "people"
    And Gmail holds the thread "t1" with the messages:
      | id | labels |
      | m1 | INBOX  |
    And Gmail history moves to "300" with the threads "t1"
    When the Gmail sync runs
    Then the Gmail thread "t1" reads:
      | status        | read                     |
      | snoozed_until | 2099-01-02T03:00:00.000Z |
    And the mail thread "Engines" has the tags "people"

  Scenario: The sync leaves labels and the signature alone within the hour and refreshes them after
    Given the Gmail account "aaron@example.com" has synced to history "100"
    And Gmail has the label "Label_1" named "Receipts"
    And Gmail gives "aaron@example.com" the signature "<b>New</b>"
    When the Gmail sync runs
    Then Gmail received GET "/users/me/labels" 0 times
    And the Gmail labels are ""
    And the mail account "aaron@example.com" has no signature
    When an hour passes for the Gmail account "aaron@example.com"
    And the Gmail sync runs
    Then the Gmail labels are "Label_1: Receipts"
    And the mail account "aaron@example.com" has the signature "<b>New</b>"

  Scenario Outline: The sync takes a thread's state from its messages' labels: <case>
    Given the Gmail account "aaron@example.com" has synced to history "100"
    And Gmail holds the thread "t1" with the messages:
      | id |
      | m1 |
      | m2 |
    And Gmail history moves to "200" with the threads "t1"
    And the Gmail sync runs
    And Gmail holds the thread "t1" with the messages:
      | id | labels   |
      | m1 | <first>  |
      | m2 | <second> |
    And Gmail history moves to "300" with the threads "t1"
    When the Gmail sync runs
    Then the Gmail thread "t1" reads:
      | status         | <status>    |
      | marked_spam_at | <spam mark> |
      | archived       | <archived>  |
      | starred        | <starred>   |
      | trashed        | <trashed>   |
      | draft          | <draft>     |
      | sent           | <sent>      |
      | important      | <important> |

    Examples:
      | case                                                     | first                 | second            | status | spam mark | archived | starred | trashed | draft | sent  | important |
      | a read, unstarred thread out of the inbox is archived    | CATEGORY_PERSONAL     | CATEGORY_PERSONAL | read   | none      | true     | false   | false   | false | false | false     |
      | a thread in spam is marked spam                          | SPAM                  | SPAM              | spam   | set       | true     | false   | false   | false | false | false     |
      | a thread Gmail calls important is important              | INBOX IMPORTANT       | INBOX             | read   | none      | false    | false   | false | false | false | true      |
      | a draft is filed in drafts                               | DRAFT                 | DRAFT             | read   | none      | true     | false   | false   | true  | false | false     |
      | a thread in the trash is trashed                         | TRASH                 | TRASH             | read   | none      | true     | false   | true    | false | false | false     |
      | a sent thread stays sent                                 | SENT                  | SENT              | read   | none      | true     | false   | false   | false | true  | false     |
      | a reply brings a trashed thread back to the inbox unread | TRASH                 | INBOX UNREAD      | unread | none      | false    | false   | false   | false | false | false     |
      | one message out of spam keeps the thread out of spam     | SPAM                  | INBOX             | read   | none      | false    | false   | false   | false | false | false     |
      | every message in trash, drafts and spam files it there   | TRASH DRAFT SPAM      | TRASH DRAFT SPAM  | spam   | set       | true     | false   | true    | true  | false | false     |
      | any one message sets inbox, unread, starred, sent and important | INBOX UNREAD STARRED | SENT IMPORTANT | unread | none   | false    | true    | false   | false | true  | true      |

  Scenario: The sync keeps a thread in the inbox while a reply to it is a draft
    Given the Gmail account "aaron@example.com" has synced to history "100"
    And Gmail holds the thread "t1" with the messages:
      | id | labels |
      | m1 | INBOX  |
      | m2 | DRAFT  |
    And Gmail history moves to "200" with the threads "t1"
    When the Gmail sync runs
    Then the Gmail thread "t1" reads:
      | archived | false |
      | draft    | false |
    And the Gmail thread "t1" has the messages:
      | gmail_id | draft |
      | m1       | false |
      | m2       | true  |

  Scenario: The sync drops a message and then a thread that Gmail deleted
    Given the Gmail account "aaron@example.com" has synced to history "100"
    And Gmail holds the thread "t1" with the messages:
      | id |
      | m1 |
      | m2 |
    And Gmail history moves to "200" with the threads "t1"
    And the Gmail sync runs
    And Gmail holds the thread "t1" with the messages:
      | id | labels |
      | m1 | INBOX  |
    And Gmail history moves to "300" with the threads "t1"
    When the Gmail sync runs
    Then the Gmail thread "t1" has the messages:
      | gmail_id |
      | m1       |
    Given Gmail answers GET "/users/me/threads/t1" with status 404
    And Gmail history moves to "400" with the threads "t1"
    When the Gmail sync runs
    Then the Gmail threads are ""

  Scenario: A change to labels alone takes the state from Gmail without fetching the thread in full
    Given the Gmail account "aaron@example.com" has synced to history "100"
    And Gmail has the label "Label_1" named "Receipts"
    And Gmail holds the thread "t1" with the messages:
      | id |
      | m1 |
      | m2 |
    And Gmail history moves to "200" with the threads "t1"
    And the Gmail sync runs
    And Gmail holds the thread "t1" with the messages:
      | id | labels          | subject | text         |
      | m1 | STARRED Label_1 | Looms   | Changed body |
      | m2 | IMPORTANT       | Looms   | Changed body |
    And Gmail history moves to "300" with the labels "STARRED Label_1" added on the thread "t1"
    When the Gmail sync runs
    Then Gmail received GET "/users/me/threads/t1" 2 times
    And the Gmail thread "t1" reads:
      | subject   | Engines |
      | status    | read    |
      | starred   | true    |
      | archived  | true    |
      | important | true    |
    And the Gmail thread "t1" wears the labels "Receipts"
    And the Gmail thread "t1" has the messages:
      | gmail_id | body        |
      | m1       | Hello there |
      | m2       | Hello there |
    Given Gmail holds the thread "t1" with the messages:
      | id | labels |
      | m1 | INBOX  |
      | m2 | INBOX  |
    And Gmail history moves to "400" with the labels "STARRED Label_1" removed on the thread "t1"
    When the Gmail sync runs
    Then the Gmail thread "t1" reads:
      | starred | false |
    And the Gmail thread "t1" wears the labels ""

  Scenario: A change to labels alone moves a thread to spam or the trash
    Given the Gmail account "aaron@example.com" has synced to history "100"
    And Gmail holds the thread "t1" with the messages:
      | id |
      | m1 |
      | m2 |
    And Gmail history moves to "200" with the threads "t1"
    And the Gmail sync runs
    And Gmail holds the thread "t1" with the messages:
      | id | labels     |
      | m1 | SPAM TRASH |
      | m2 | SPAM TRASH |
    And Gmail history moves to "300" with the labels "SPAM TRASH" added on the thread "t1"
    When the Gmail sync runs
    Then Gmail received GET "/users/me/threads/t1" 2 times
    And the Gmail thread "t1" reads:
      | status         | spam |
      | trashed        | true |
      | marked_spam_at | set  |

  Scenario: A change to labels alone fetches the thread in full when its messages differ from the stored ones
    Given the Gmail account "aaron@example.com" has synced to history "100"
    And Gmail holds the thread "t1" with the messages:
      | id |
      | m1 |
      | m2 |
    And Gmail history moves to "200" with the threads "t1"
    And the Gmail sync runs
    And Gmail holds the thread "t1" with the messages:
      | id | labels |
      | m1 | INBOX  |
    And Gmail history moves to "300" with the labels "INBOX" added on the thread "t1"
    When the Gmail sync runs
    Then Gmail received GET "/users/me/threads/t1" 3 times
    And the Gmail thread "t1" has the messages:
      | gmail_id |
      | m1       |

  Scenario: A change to labels alone fetches in full a thread it has not stored
    Given the Gmail account "aaron@example.com" has synced to history "100"
    And Gmail holds the thread "t1" with the messages:
      | id | labels |
      | m1 | INBOX  |
      | m2 | INBOX  |
    And Gmail history moves to "300" with the labels "INBOX" added on the thread "t1"
    When the Gmail sync runs
    Then Gmail received GET "/users/me/threads/t1" 2 times
    And the Gmail threads are "t1"

  Scenario: A message leaving a thread fetches the thread in full at once
    Given the Gmail account "aaron@example.com" has synced to history "100"
    And Gmail holds the thread "t1" with the messages:
      | id |
      | m1 |
      | m2 |
    And Gmail history moves to "200" with the threads "t1"
    And the Gmail sync runs
    And Gmail holds the thread "t1" with the messages:
      | id | labels | text         |
      | m1 | INBOX  | Changed body |
      | m2 | INBOX  | Changed body |
    And Gmail history moves to "300" with a message deleted from the thread "t1"
    When the Gmail sync runs
    Then Gmail received GET "/users/me/threads/t1" 2 times
    And the Gmail thread "t1" has the messages:
      | gmail_id | body         |
      | m1       | Changed body |
      | m2       | Changed body |

  Scenario Outline: The sync cleans a stored HTML body: <case>
    Given the Gmail account "aaron@example.com" has synced to history "100"
    And Gmail holds the thread "t1" with the messages:
      | id | html   |
      | m1 | <html> |
    And Gmail history moves to "200" with the threads "t1"
    When the Gmail sync runs
    Then the Gmail thread "t1" has the messages:
      | html_body | body   |
      | <clean>   | <text> |

    Examples:
      | case                                     | html                                                                                                                   | clean                                                                                  | text           |
      | it strips script                         | <p onclick="steal()">Hi</p><script>steal()</script><a href="javascript:steal()">x</a><style>*{}</style>                 | <p>Hi</p><a>x</a>                                                                      | Hi x           |
      | it keeps the text without its entities   | <p>Tom &amp; Jerry&nbsp;&lt;3</p>                                                                                      | <p>Tom &amp; Jerry&nbsp;&lt;3</p>                                                      | Tom & Jerry <3 |
      | it keeps the styling but not position    | <div style="position: fixed; z-index: 9999; top: 0; color: red"><img src="https://example.com/a.png">Hi</div>          | <div style="  top: 0; color: red"><img src="https://example.com/a.png">Hi</div>       | Hi             |
      | it drops moves out of its box            | <div style="transform: translateY(-90vh); translate: 0 -50vh; rotate: 1deg; scale: 2; color: red">Hi</div>             | <div style="    color: red">Hi</div>                                                   | Hi             |
      | it drops class and id                    | <div class="fixed inset-0 z-50" id="main"><p class="x">Hi</p></div>                                                    | <div><p>Hi</p></div>                                                                   | Hi             |

  Scenario: The sync reads a body in the charset its part names
    Given the Gmail account "aaron@example.com" has synced to history "100"
    And Gmail holds the thread "t1" with the messages:
      | id | text      | charset    |
      | m1 | Café | ISO-8859-1 |
    And Gmail history moves to "200" with the threads "t1"
    When the Gmail sync runs
    Then the Gmail thread "t1" has the messages:
      | body      |
      | Café |

  Scenario: The sync skips attachments as bodies and keeps out an address it cannot reply to
    Given the Gmail account "aaron@example.com" has synced to history "100"
    And Gmail holds the thread "t1" with the messages:
      | id | attachment       | from           | subject |
      | m1 | a.txt\|text/plain | root@localhost |         |
    And Gmail history moves to "200" with the threads "t1"
    When the Gmail sync runs
    Then the Gmail thread "t1" has the messages:
      | body | reply_to | subject      |
      | none | none     | (no subject) |

  Scenario: The sync stores attachment names without NUL and skips a name of only whitespace
    Given the Gmail account "aaron@example.com" has synced to history "100"
    And Gmail holds the thread "t1" with the messages:
      | id | text   | attachment                         |
      | m1 | Report |   　\|application/pdf |
      | m2 | Report | a\u0000b.pdf\|application/\u0000pdf |
    And Gmail history moves to "200" with the threads "t1"
    When the Gmail sync runs
    Then the Gmail thread "t1" has the messages:
      | gmail_id | body   |
      | m1       | Report |
      | m2       | Report |
    And the Gmail attachments are "ab.pdf application/pdf"
    And the mail sync records no failure

  Scenario: The sync treats a subject, sender name and body of only Unicode whitespace as blank
    Given the Gmail account "aaron@example.com" has synced to history "100"
    And Gmail holds the thread "t1" with the messages:
      | id | text        | from                          | subject      |
      | m1 |   \n |   <ada@example.com> | 　  |
    And Gmail history moves to "200" with the threads "t1"
    When the Gmail sync runs
    Then the Gmail thread "t1" has the messages:
      | body | from_name | subject      |
      | none | none      | (no subject) |
    And the Gmail thread "t1" reads:
      | subject | (no subject) |
    And the mail sync records no failure

  Scenario: The sync cuts a body too long to search at a fixed length
    Given the Gmail account "aaron@example.com" has synced to history "100"
    And Gmail holds the thread "t1" with a plain body of 150000 words
    And Gmail history moves to "200" with the threads "t1"
    When the Gmail sync runs
    Then the Gmail thread "t1" keeps a body of 100000 letters
    And the mail sync records no failure

  Scenario: The sync starts over when Gmail no longer holds the history it left off at
    Given the Gmail account "aaron@example.com" has synced to history "100"
    And Gmail is at history "900"
    And Gmail no longer holds the history
    When the Gmail sync runs
    Then the mail account "aaron@example.com" follows the history "900"
    And Gmail received GET "/users/me/threads" 1 time

  Scenario: A failed run keeps its place, records the failure and catches up on the next run
    Given the Gmail account "aaron@example.com" has synced to history "150"
    And Gmail holds the thread "t1" with the messages:
      | id |
      | m1 |
    And Gmail history moves to "250" with the threads "t1"
    And Gmail answers GET "/users/me/threads/t1" with status 503
    When the Gmail sync runs
    Then the mail sync records the failure "gmail_failed" saying "Google answered 503"
    And the mail account "aaron@example.com" follows the history "150"
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read"
    When I call the MCP tool "read_sync_state"
    Then the MCP answer holds "Google answered 503"
    Given Gmail holds the thread "t1" with the messages:
      | id |
      | m1 |
    When the Gmail sync runs
    Then the Gmail thread "t1" reads:
      | subject | Engines |
    And the mail account "aaron@example.com" follows the history "250"
    And the mail sync records no failure

  Scenario: A run Gmail rate limits keeps its place and records the failure
    Given the Gmail account "aaron@example.com" has synced to history "150"
    And Gmail history moves to "250" with the threads "t1"
    And Gmail rate limits GET "/users/me/threads/t1" with status 403
    When the Gmail sync runs
    Then the mail account "aaron@example.com" follows the history "150"
    And the mail sync records the failure "gmail_failed" saying "Google answered 403"

  Scenario: A catch-up Gmail rate limits partway keeps what it stored and a second run finishes it
    Given the Gmail account "aaron@example.com" has synced to history "150"
    And Gmail holds the thread "t1" with the messages:
      | id |
      | m1 |
    And Gmail holds the thread "t2" with the messages:
      | id |
      | m2 |
    And Gmail holds the thread "t3" with the messages:
      | id |
      | m3 |
    And Gmail history moves to "250" with the threads "t1, t2, t3"
    And Gmail rate limits GET "/users/me/threads/t2" with status 403
    When the Gmail sync runs
    Then the Gmail threads are "t1"
    And the mail account "aaron@example.com" follows the history "248"
    And the mail sync records the failure "gmail_failed" saying "Google answered 403"
    Given Gmail holds the thread "t2" with the messages:
      | id |
      | m2 |
    When the Gmail sync runs
    Then the Gmail threads are "t1, t2, t3"
    And the mail account "aaron@example.com" follows the history "250"
    And the mail sync records no failure

  Scenario: The sync sends the admin no notice when Gmail has nothing new
    Given the Gmail account "aaron@example.com" has synced to history "100"
    And Gmail history moves to "300" with the threads ""
    When the Gmail sync runs to history "300" while I listen for admin notices
    Then the admin hears no notice

  Scenario: A run steps aside while another run holds the lock
    Given the mail sync failed before with "rate_limited"
    When the Gmail sync runs while another run holds the lock
    Then Gmail received GET "/users/me/profile" 0 times
    And Gmail received GET "/users/me/history" 0 times
    And the mail sync still records the failure "rate_limited" once

  Scenario: The sync syncs only the accounts that granted Gmail and still syncs past a revoked one
    Given the Google account "health@example.com" is connected with "googlehealth.sleep.readonly"
    And the Google account "aa@example.com" is connected with "openid gmail.modify"
    And the Google connection for "aa@example.com" is revoked
    When the Gmail sync runs
    Then only "aaron@example.com" has a mail account from Gmail
    And the mail account "aaron@example.com" follows the history "100"
    And the mail sync records no failure

  Scenario: The sync still syncs the next account when one fails, and records the failure
    Given the Google account "aa@example.com" is connected with "openid gmail.modify"
    And the Google token for "aa@example.com" has run out
    And Google OAuth answers POST "/token" with status 503
    When the Gmail sync runs
    Then the mail account "aaron@example.com" follows the history "100"
    And the mail sync records the failure "gmail_failed" saying "Google answered 503"

  Scenario: A run that crashes records the crash where the admin reads it
    Given Gmail answers GET "/users/me/profile" with:
      """
      {}
      """
    When the Gmail sync runs
    Then the mail sync records the failure "crashed" saying "key not found: \"history_id\""

  Scenario: The sync stores both names when labels swap or take a name another gave up
    Given the Gmail account "aaron@example.com" has synced to history "100"
    And Gmail has the labels "Label_1: Receipts, Label_2: Travel"
    And an hour passes for the Gmail account "aaron@example.com"
    And the Gmail sync runs
    And Gmail has the labels "Label_1: Travel, Label_2: Receipts"
    And an hour passes for the Gmail account "aaron@example.com"
    When the Gmail sync runs
    Then the Gmail labels are "Label_1: Travel, Label_2: Receipts"
    Given Gmail has the labels "Label_1: Receipts, Label_2: Trips"
    And an hour passes for the Gmail account "aaron@example.com"
    When the Gmail sync runs
    Then the Gmail labels are "Label_1: Receipts, Label_2: Trips"
    And the mail sync records no failure

  Scenario: The sync still refuses two labels with one name
    Given the Gmail account "aaron@example.com" has synced to history "100"
    And Gmail has the labels "Label_1: Travel, Label_2: Travel"
    And an hour passes for the Gmail account "aaron@example.com"
    When the Gmail sync runs
    Then the Gmail labels are ""
    And the mail sync still records the failure "crashed" once

  Scenario: A thread that has not changed leaves every row alone
    Given the Gmail account "aaron@example.com" has synced to history "100"
    And Gmail has the label "Label_1" named "Receipts"
    And Gmail holds the thread "t1" with the messages:
      | id | labels               | text  | attachment             | at                   |
      | m1 | INBOX UNREAD Label_1 | Hello | 2.pdf\|application/pdf | 2026-01-05T09:00:00Z |
      | m2 | INBOX UNREAD         | Hello | 2.pdf\|application/pdf | 2026-01-05T09:00:00Z |
    And Gmail history moves to "200" with the threads "t1"
    And the Gmail sync runs
    And Gmail history moves to "300" with the threads "t1"
    When the Gmail sync runs to history "300" while I listen for admin notices
    Then the admin hears no notice

  Scenario: A changed thread updates only what changed and adds a message that arrived
    Given the Gmail account "aaron@example.com" has synced to history "100"
    And Gmail has the label "Label_1" named "Receipts"
    And Gmail holds the thread "t1" with the messages:
      | id | labels               | at                   |
      | m1 | INBOX UNREAD Label_1 | 2026-01-05T09:00:00Z |
      | m2 | INBOX UNREAD         | 2026-01-05T09:00:00Z |
    And Gmail history moves to "200" with the threads "t1"
    And the Gmail sync runs
    And I note when the Gmail message "m2" last changed
    And Gmail holds the thread "t1" with the messages:
      | id | labels       | subject | at                   |
      | m1 | INBOX UNREAD | Looms   | 2026-01-05T09:00:00Z |
      | m2 | INBOX UNREAD | Engines | 2026-01-05T09:00:00Z |
      | m3 | INBOX UNREAD | Engines | 2026-01-05T10:00:00Z |
    And Gmail history moves to "300" with the threads "t1"
    When the Gmail sync runs
    Then the Gmail thread "t1" has the messages:
      | gmail_id | subject |
      | m1       | Looms   |
      | m2       | Engines |
      | m3       | Engines |
    And the Gmail message "m2" has not changed since
    And the Gmail thread "t1" wears the labels ""
