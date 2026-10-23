Feature: Admin inbox
  The inbox lists what waits on the owner: unread messages, pending webmentions and synced issues no one has seen.
  Each row offers what its kind takes, and the nav counts what waits.

  Scenario: A visitor who has not signed in is sent to sign in and sees no message
    Given the inbox holds:
      | kind    | title    |
      | message | A secret |
    When I visit "/admin/inbox"
    Then I am sent to sign in
    And I do not see "A secret"

  Scenario: The inbox lists each kind newest first, labeled with no icon
    Given I am signed in to the admin
    And the inbox holds:
      | kind       | title  | arrived |
      | issue      | Oldest | -120    |
      | message    | Middle | -60     |
      | webmention | Newest | 0       |
    Then the inbox shows the rows "Newest, Middle, Oldest"
    And the inbox screen's ".inbox-kind" read "webmention, message, issue"
    And the inbox screen has no ".inbox-kind i"

  Scenario: The inbox puts when each row arrived in a time tag
    Given I am signed in to the admin
    And the inbox holds:
      | kind       | title   | arrived              |
      | issue      | Issue   | 2026-09-07T17:30:00Z |
      | message    | Message | 2026-09-07T17:30:00Z |
      | webmention | Mention | 2026-09-07T17:30:00Z |
    When I visit "/admin/inbox"
    Then the inbox screen's ".inbox-meta time" carry "datetime" "2026-09-07T12:30:00-05:00, 2026-09-07T12:30:00-05:00, 2026-09-07T12:30:00-05:00"

  Scenario: The inbox counts its rows in the heading and on the nav's Inbox entry alone
    Given I am signed in to the admin
    And the inbox holds:
      | kind    | title   |
      | message | Message |
      | issue   | Issue   |
    When I visit "/admin/inbox"
    Then the inbox screen's ".page-head-sub" read "2 waiting"
    And the command palette's inbox entry counts "2 waiting"
    And the command palette's mail entry shows no count
    And the command palette's webmentions entry shows no count

  Scenario: The inbox lists only the newest 100 rows past its limit and still counts them all
    Given I am signed in to the admin
    And 101 more inbox messages arrived in the last minutes, titled "Message" and a number
    Then the inbox shows 100 rows, starting with "Message 1"
    And I do not see "Message 101"
    And the inbox screen's ".page-head-sub" read "101 waiting"

  Scenario Outline: The inbox keeps a woken <kind> ahead of newer ones past its limit
    Given I am signed in to the admin
    And the inbox holds:
      | kind   | title | arrived | snoozed |
      | <kind> | Woken | -600    | -1      |
    And 100 more inbox <kind>s arrived in the last minutes, titled "Newer" and a number
    Then the inbox shows 100 rows, starting with "Woken"

    Examples:
      | kind       |
      | message    |
      | webmention |
      | issue      |

  Scenario: The inbox and its nav count leave out what no longer waits
    Given I am signed in to the admin
    And the inbox holds:
      | kind       | title      | state    |
      | message    | Waits      |          |
      | message    | Read       | read     |
      | webmention | Approved   | approved |
      | webmention | Seen       | seen     |
      | issue      | Seen issue | seen     |
      | issue      | Done       | done     |
      | issue      | Canceled   | canceled |
      | task       | Sourceless |          |
    Then the inbox shows the rows "Waits"
    And the command palette's inbox entry counts "1 waiting"

  Scenario: The inbox says so when nothing waits and offers no bulk buttons
    Given I am signed in to the admin
    When I visit "/admin/inbox"
    Then the inbox screen's ".empty" read "Nothing waits on you."
    And the inbox screen has no "form[action='/admin/inbox/seen'] button[type=submit]"
    And the inbox screen has no "[data-dialog-open='inbox-snooze-all']"
    And the inbox screen has no "#inbox-snoozed"
    And the command palette's inbox entry shows no count

  Scenario: The inbox shows a synced issue's tags, linked to their summaries
    Given I am signed in to the admin
    And the inbox holds:
      | kind  | title  | tags        |
      | issue | Tagged | feeds, bugs |
    When I visit "/admin/inbox"
    Then the inbox screen's ".inbox-row .tag" read "#bugs, #feeds"
    And the inbox screen's ".inbox-row a.tag" carry "href" "/admin/tags/bugs, /admin/tags/feeds"

  Scenario Outline: The nav count drops by one when a <kind> is acted on
    Given I am signed in to the admin
    And the inbox holds:
      | id | kind       | title   |
      | 7  | message    | Message |
      | 8  | webmention | Mention |
      | 9  | issue      | Issue   |
    When I post the form to the admin "<path>"
    Then the command palette's inbox entry counts "2 waiting"

    Examples:
      | kind       | path                                         |
      | message    | /admin/inbox/messages/7/mark/read            |
      | webmention | /admin/inbox/webmentions/8/moderate/approved |
      | issue      | /admin/inbox/tasks/9/seen                    |

  Scenario: The nav count says nothing once nothing waits
    Given I am signed in to the admin
    And the inbox holds:
      | id | kind       | title   |
      | 7  | message    | Message |
      | 8  | webmention | Mention |
      | 9  | issue      | Issue   |
    When I post the form to the admin "/admin/inbox/messages/7/mark/read"
    And I post the form to the admin "/admin/inbox/webmentions/8/moderate/approved"
    And I post the form to the admin "/admin/inbox/tasks/9/seen"
    Then the command palette's inbox entry shows no count

  Scenario: A message reads out its body, only the start of a long one
    Given I am signed in to the admin
    And the inbox holds:
      | kind    | title      | body             | arrived |
      | message | A question | How?             | -60     |
      | message | Long       | [a × 500]TAIL    | 0       |
    When I visit "/admin/inbox"
    Then the inbox screen's ".msg-body" read "[a × 500], How?"
    And I do not see "TAIL"

  Scenario: A message offers a reply by mail that keeps the address from adding fields
    Given I am signed in to the admin
    And the inbox holds:
      | kind    | title      | reply_to               | arrived |
      | message | A question | ada@example.com        | -60     |
      | message | Sneaky     | ada?cc=eve@example.com | 0       |
    When I visit "/admin/inbox"
    Then the inbox screen's ".inbox-row a:has-text('Reply')" carry "href" "mailto:ada%3Fcc%3Deve@example.com?subject=Re%3A%20Sneaky, mailto:ada@example.com?subject=Re%3A%20A%20question"

  Scenario Outline: Marking a message <status> drops it with a toast
    Given I am signed in to the admin
    And the inbox holds:
      | id | kind    | title      |
      | 7  | message | A question |
    When I post the form to the admin "/admin/inbox/messages/7/mark/<status>"
    Then the admin post sends me to "/admin/inbox"
    When I follow the admin post
    Then the admin toast says "<toast>"
    And the database answers "<status>" for:
      """
      SELECT status FROM mail_threads WHERE id = 7
      """
    And the inbox shows no rows

    Examples:
      | status | toast          |
      | read   | Marked read    |
      | spam   | Marked as spam |

  Scenario: The inbox answers 404 to marking a message unread or one that is not there
    Given I am signed in to the admin
    And the inbox holds:
      | id | kind    | title      |
      | 7  | message | A question |
    When I post the form to the admin "/admin/inbox/messages/7/mark/unread"
    Then the admin post answers 404
    When I post the form to the admin "/admin/inbox/messages/0/mark/read"
    Then the admin post answers 404

  Scenario: The inbox refuses a forged CSRF token and leaves the message unread
    Given I am signed in to the admin
    And the inbox holds:
      | id | kind    | title      |
      | 7  | message | A question |
    When I post the form to the admin "/admin/inbox/messages/7/mark/read" with a forged CSRF token
    Then the admin post answers 403
    And the database answers "unread" for:
      """
      SELECT status FROM mail_threads WHERE id = 7
      """

  Scenario: A message offers a Make a task dialog that comes back to Waiting
    Given I am signed in to the admin
    And the inbox holds:
      | id | kind    | title      |
      | 7  | message | A question |
    When I visit "/admin/inbox"
    Then the inbox screen's "dialog#mail-task-7 input[name='task[title]']" carry "value" "A question"
    And the inbox screen's "dialog#mail-task-7 input[name='origin']" carry "value" "inbox"

  Scenario: Making a task from a message lands back on Waiting and trades the button for a link
    Given I am signed in to the admin
    And the inbox holds:
      | id | kind    | title      |
      | 7  | message | A question |
    When I post the form to the admin "/admin/mail/7/task" with:
      | origin      | inbox      |
      | task[title] | Answer Ada |
      | task[list]  | next       |
    Then the admin post sends me to "/admin/inbox"
    And the database answers "task, 1, mail_thread, 7" for:
      """
      SELECT left_kind, left_id, right_kind, right_id FROM record_links
      """
    When I visit "/admin/inbox"
    Then the inbox screen's "#message-7 a[href='/admin/tasks/1']" read "Task #1"
    And the inbox screen has no "dialog#mail-task-7"

  Scenario: A webmention names its type and post and shows its excerpt
    Given I am signed in to the admin
    And the inbox holds:
      | kind       | title | excerpt       |
      | webmention | Ada   | Lovely post.  |
    When I visit "/admin/inbox"
    Then I see "mention on /writing/mentioned-post"
    And the inbox screen's ".wm-excerpt.inbox-row-body" read "Lovely post."

  Scenario: A like says it carries no content
    Given I am signed in to the admin
    And the inbox holds:
      | kind       | title | state |
      | webmention | Ada   | like  |
    When I visit "/admin/inbox"
    Then the inbox screen's ".wm-excerpt.inbox-row-body.quiet" read "no content · like only"

  Scenario: A webmention draws its verdict buttons without icons, each posting to the inbox, with a note beside Spam
    Given I am signed in to the admin
    And the inbox holds:
      | id | kind       | title |
      | 8  | webmention | Ada   |
    When I visit "/admin/inbox"
    Then the inbox screen's "#webmention-8 form[action*='/moderate/'] button" read "Approve, Ignore, Spam"
    And the inbox screen has no "#webmention-8 button.bt:visible i"
    And the inbox screen's "#webmention-8 form[action*='/moderate/']" carry "action" "/admin/inbox/webmentions/8/moderate/approved, /admin/inbox/webmentions/8/moderate/ignored, /admin/inbox/webmentions/8/moderate/spam"
    And the inbox screen's "#webmention-8 form.wm-spam input[name=reason]" carry "placeholder" "Why spam? (optional)"

  Scenario: Approving a webmention from the inbox trusts its author
    Given I am signed in to the admin
    And the inbox holds:
      | id | kind       | title |
      | 8  | webmention | Ada   |
    When I post the form to the admin "/admin/inbox/webmentions/8/moderate/approved"
    Then the database answers "https://ada.example/about" for:
      """
      SELECT author_url FROM trusted_authors
      """

  Scenario Outline: Moderating a webmention <verdict> drops it with a toast
    Given I am signed in to the admin
    And the inbox holds:
      | id | kind       | title |
      | 8  | webmention | Ada   |
    When I post the form to the admin "/admin/inbox/webmentions/8/moderate/<verdict>"
    And I follow the admin post
    Then the admin toast says "<toast>"
    And the database answers "<verdict>" for:
      """
      SELECT status FROM webmentions WHERE id = 8
      """
    And the inbox shows no rows

    Examples:
      | verdict  | toast          |
      | approved | Approved       |
      | ignored  | Ignored        |
      | spam     | Marked as spam |

  Scenario: Marking a webmention spam keeps the reason
    Given I am signed in to the admin
    And the inbox holds:
      | id | kind       | title |
      | 8  | webmention | Ada   |
    When I post the form to the admin "/admin/inbox/webmentions/8/moderate/spam" with:
      | reason | Selling pills |
    Then the database answers "Selling pills" for:
      """
      SELECT spam_reason FROM webmentions WHERE status = 'spam'
      """

  Scenario: Marking a webmention spam keeps no reason when it holds only Unicode spaces
    Given I am signed in to the admin
    And the inbox holds:
      | id | kind       | title |
      | 8  | webmention | Ada   |
    When I post the form to the admin "/admin/inbox/webmentions/8/moderate/spam" with:
      | reason | \u3000\u00a0 |
    Then the admin post sends me to "/admin/inbox"
    And the database answers "none" for:
      """
      SELECT coalesce(spam_reason, 'none') FROM webmentions WHERE status = 'spam'
      """

  Scenario: The inbox answers 404 to setting a webmention back to pending or one that is not there
    Given I am signed in to the admin
    And the inbox holds:
      | id | kind       | title |
      | 8  | webmention | Ada   |
    When I post the form to the admin "/admin/inbox/webmentions/8/moderate/pending"
    Then the admin post answers 404
    When I post the form to the admin "/admin/inbox/webmentions/0/moderate/approved"
    Then the admin post answers 404

  Scenario: A synced issue offers the lists it is not on and Edit in place of a tag input
    Given I am signed in to the admin
    And the inbox holds:
      | id | kind  | title        |
      | 9  | issue | Fix the feed |
    When I visit "/admin/inbox"
    Then the inbox screen's ".inbox-row-acts button:visible" read "Today, Next, Someday, Seen, Snooze"
    And the inbox screen's "#issue-9 a:has-text('Edit')" carry "href" "/admin/tasks/9/edit?origin=inbox"
    And the inbox screen has no "[name=tags]"

  Scenario: Moving a synced issue drops it with a toast
    Given I am signed in to the admin
    And the inbox holds:
      | id | kind  | title        |
      | 9  | issue | Fix the feed |
    When I post the form to the admin "/admin/inbox/tasks/9/move/next"
    And I follow the admin post
    Then the admin toast says "Moved"
    And the database answers "next" for:
      """
      SELECT list FROM tasks WHERE id = 9
      """
    And the inbox shows no rows

  Scenario: Tagging a synced issue from the task form drops it and stays on the inbox
    Given I am signed in to the admin
    And the inbox holds:
      | id | kind  | title        |
      | 9  | issue | Fix the feed |
    When I post the form to the admin "/admin/tasks/9" with:
      | origin      | inbox        |
      | task[title] | Fix the feed |
      | task[tags]  | feeds, bugs  |
    Then the admin post sends me to "/admin/inbox"
    And the database answers "bugs, feeds" for:
      """
      SELECT string_agg(tags.name, ', ' ORDER BY tags.name) FROM task_tags JOIN tags ON tags.id = task_tags.tag_id
      """
    And the inbox shows no rows

  Scenario: A synced issue stays when the task form saves only a note
    Given I am signed in to the admin
    And the inbox holds:
      | id | kind  | title        |
      | 9  | issue | Fix the feed |
    When I post the form to the admin "/admin/tasks/9" with:
      | origin      | inbox             |
      | task[title] | Fix the feed      |
      | task[note]  | Look at the cache |
    Then the inbox shows the rows "Fix the feed"

  Scenario: Marking a synced issue seen drops it without moving it
    Given I am signed in to the admin
    And the inbox holds:
      | id | kind  | title        |
      | 9  | issue | Fix the feed |
    When I post the form to the admin "/admin/inbox/tasks/9/seen"
    And I follow the admin post
    Then the admin toast says "Marked seen"
    And the database answers "external" for:
      """
      SELECT list FROM tasks WHERE id = 9
      """
    And the inbox shows no rows

  Scenario: The inbox answers 404 for the old tag route, a task with no source and a task that is not there
    Given I am signed in to the admin
    And the inbox holds:
      | id | kind  | title        |
      | 9  | issue | Fix the feed |
      | 10 | task  | Sourceless   |
    When I post the form to the admin "/admin/inbox/tasks/9/tags" with:
      | tags | feeds |
    Then the admin post answers 404
    When I post the form to the admin "/admin/inbox/tasks/10/seen"
    Then the admin post answers 404
    When I post the form to the admin "/admin/inbox/tasks/0/move/next"
    Then the admin post answers 404
    When I post the form to the admin "/admin/inbox/tasks/0/seen"
    Then the admin post answers 404

  Scenario: Editing an issue's tags in the drawer stays on the inbox and drops the issue
    Given I am signed in to the admin
    And the inbox holds:
      | kind  | title        |
      | issue | Fix the feed |
    When I visit "/admin/inbox"
    And I edit the inbox issue "Fix the feed" in the drawer, setting "Tags" to "feeds"
    And I close the task drawer
    Then the browser stays on "/admin/inbox"
    And the inbox screen drops the row "Fix the feed"
    And the database answers "feeds" for:
      """
      SELECT tags.name FROM task_tags JOIN tags ON tags.id = task_tags.tag_id
      """

  Scenario: Editing only an issue's note in the drawer keeps the issue
    Given I am signed in to the admin
    And the inbox holds:
      | kind  | title        |
      | issue | Fix the feed |
    When I visit "/admin/inbox"
    And I edit the inbox issue "Fix the feed" in the drawer, setting "note" to "Look at the cache"
    And I close the task drawer
    Then the browser stays on "/admin/inbox"
    And the inbox screen shows the row "Fix the feed"

  Scenario: A long issue title keeps its buttons to its right, and below it on a phone
    Given I am signed in to the admin
    And the inbox holds:
      | kind  | title                                                                                                                                                                           |
      | issue | A synced issue with a title long enough to wrap onto a second line beside its buttons A synced issue with a title long enough to wrap onto a second line beside its buttons |
    When I visit "/admin/inbox"
    Then the inbox row's buttons sit to the right of its title
    When I use a phone
    Then the inbox row's buttons sit below its title

  Scenario Outline: The admin page <path> has no axe breaches
    Given I am signed in to the admin
    And the inbox holds:
      | kind       | title    | snoozed |
      | message    | Message  |         |
      | webmention | Mention  |         |
      | issue      | Issue    | 3600    |
    When I visit "<path>"
    Then the page has no axe breaches in light or dark

    Examples:
      | path               |
      | /admin/inbox       |
      | /admin/webmentions |
