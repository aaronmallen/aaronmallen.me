Feature: Admin mail writes to Gmail
  A change to a Gmail thread goes to Gmail first, and the mail screen keeps
  the change only once Gmail takes it.

  Background:
    Given I am signed in to the admin
    And the mail account "aaron@work.example"
    And the Google account "aaron@work.example" is connected with "openid gmail.modify"

  Scenario: A change to one thread goes to Gmail and here
    Given the mail threads:
      | subject   | account            | gmail id | starred | status | archived |
      | Archive   | aaron@work.example | t1       |         |        |          |
      | Star      | aaron@work.example | t2       |         |        |          |
      | Unstar    | aaron@work.example | t3       | yes     |        |          |
      | Read      | aaron@work.example | t4       |         |        |          |
      | Not spam  | aaron@work.example | t5       |         | spam   | yes      |
      | Snooze    | aaron@work.example | t6       |         |        |          |
      | Form star | contact form       |          |         |        |          |
    And Gmail takes changes to the mail threads "t1, t2, t3, t4, t5"
    When I post to the mail route "/admin/mail/#[Archive]/change/archive" with:
      """
      folder=inbox
      """
    Then Gmail received POST "/users/me/threads/t1/modify" holding '{"removeLabelIds":["INBOX"]}'
    And the mail thread "Archive" is now archived
    When I post to the mail route "/admin/mail/#[Star]/change/star"
    Then Gmail received POST "/users/me/threads/t2/modify" holding '{"addLabelIds":["STARRED"]}'
    And the mail thread "Star" is now starred
    When I post to the mail route "/admin/mail/#[Unstar]/change/unstar"
    Then Gmail received POST "/users/me/threads/t3/modify" holding '{"removeLabelIds":["STARRED"]}'
    And the mail thread "Unstar" is now unstarred
    When I post to the mail route "/admin/mail/#[Read]/change/read"
    Then Gmail received POST "/users/me/threads/t4/modify" holding '{"removeLabelIds":["UNREAD"]}'
    And the mail thread "Read" is now read
    When I post to the mail route "/admin/mail/#[Not spam]/change/read"
    Then Gmail received POST "/users/me/threads/t5/modify" holding '"addLabelIds":["INBOX"]'
    And Gmail received POST "/users/me/threads/t5/modify" holding '"removeLabelIds":["UNREAD","SPAM"]'
    And the mail thread "Not spam" is now read
    And the mail thread "Not spam" is now unarchived
    When I post to the mail route "/admin/mail/#[Form star]/change/star"
    Then the mail thread "Form star" is now starred
    When I post to the mail route "/admin/mail/#[Snooze]/snooze" with:
      """
      pick=%[a day from now]
      """
    And I visit the mail page "/admin/mail?account=@[aaron@work.example]"
    Then the mail list does not hold "Snooze"
    And the mail thread "Snooze" is now snoozed

  Scenario: A change Gmail refuses changes nothing here
    Given the mail threads:
      | subject | account            | gmail id | trashed |
      | Keep    | aaron@work.example | refused  |         |
      | Binned  | aaron@work.example | binned   | yes     |
    And Gmail refuses changes to the mail thread "refused"
    And Gmail refuses changes to the mail thread "binned"
    When I post to the mail route "/admin/mail/#[Keep]/change/archive" with:
      """
      folder=inbox
      """
    Then the mail toast says "Nothing changed · Gmail refused the change"
    And the mail thread "Keep" is now unarchived
    When I post to the mail route "/admin/mail/#[Binned]/delete" with:
      """
      folder=trash
      """
    Then the mail toast says "Nothing changed · Gmail refused the change"
    And the mail thread "Binned" is now kept
    When I post to the mail route "/admin/mail/#[Keep]/open"
    Then the mail answer has status 302
    And the mail thread "Keep" is now unread

  Scenario: Deleting a trashed Gmail thread forever deletes it in Gmail
    Given the mail threads:
      | subject | account            | gmail id | trashed | status |
      | Binned  | aaron@work.example | t1       | yes     |        |
      | Junk    | aaron@work.example | t2       |         | spam   |
    And Gmail takes changes to the mail threads "t1"
    When I visit the mail page "/admin/mail?folder=trash&thread=#[Binned]"
    Then the mail actions are "Restore, Delete forever"
    When I visit the mail page "/admin/mail?folder=spam&thread=#[Junk]"
    Then the mail actions are "Not spam, Delete forever"
    When I post to the mail route "/admin/mail/#[Binned]/delete" with:
      """
      folder=trash
      """
    Then Gmail got DELETE "/users/me/threads/t1" 1 time
    And the mail thread "Binned" is now gone

  Scenario: Trash in the reader moves a Gmail thread to trash as the menu does
    Given the mail threads:
      | subject | account            | gmail id |
      | Old     | aaron@work.example | t1       |
    And Gmail takes changes to the mail threads "t1"
    When I visit the mail page "/admin/mail?folder=inbox&show=all&thread=#[Old]"
    And I submit the mail reader form "Trash"
    Then the mail answer goes to "/admin/mail?folder=inbox&show=all"
    And Gmail received POST "/users/me/threads/t1/trash"
    And the mail thread "Old" is now trashed
    And the mail toast says "Moved 1 thread to Trash"

  Scenario: A thread whose From line had no address goes to spam and flags no sender
    Given the mail threads:
      | subject | account            | gmail id | reply to | status |
      | One     | aaron@work.example | t1       | none     |        |
      | Two     | aaron@work.example | t2       | none     |        |
      | Three   | aaron@work.example | t3       | none     |        |
      | Four    | aaron@work.example | t4       | none     | spam   |
    And Gmail takes changes to the mail threads "t1, t2, t3, t4"
    When I post to the mail route "/admin/mail/#[One]/change/spam"
    Then the mail thread "One" is now spam
    When I post to the mail route "/admin/mail/bulk" with:
      """
      act=move
      to=spam
      folder=inbox
      ids[]=#[Two]
      ids[]=#[Three]
      """
    Then the mail thread "Two" is now spam
    And the mail thread "Three" is now spam
    And no mail sender is flagged as spam
    When I post to the mail route "/admin/mail/#[Four]/change/read"
    Then the mail thread "Four" is now read

  Scenario: The bulk bar writes every ticked thread to Gmail
    Given the mail threads:
      | subject | account            | gmail id |
      | A1      | aaron@work.example | a1       |
      | A2      | aaron@work.example | a2       |
      | R1      | aaron@work.example | r1       |
      | R2      | aaron@work.example | r2       |
      | U1      | aaron@work.example | u1       |
      | U2      | aaron@work.example | u2       |
      | S1      | aaron@work.example | s1       |
      | S2      | aaron@work.example | s2       |
      | P1      | aaron@work.example | p1       |
      | P2      | aaron@work.example | p2       |
      | T1      | aaron@work.example | t1       |
      | T2      | aaron@work.example | t2       |
    And Gmail takes changes to the mail threads "a1, a2, r1, r2, u1, u2, s1, s2, p1, p2, t1, t2"
    When I post to the mail route "/admin/mail/bulk" with:
      """
      act=archive
      folder=inbox
      ids[]=#[A1]
      ids[]=#[A2]
      """
    Then the mail toast says "Archived 2 threads"
    And Gmail received POST "/users/me/threads/a1/modify" holding '{"removeLabelIds":["INBOX"]}'
    And Gmail received POST "/users/me/threads/a2/modify" holding '{"removeLabelIds":["INBOX"]}'
    And the mail thread "A1" is now archived
    And the mail thread "A2" is now archived
    When I post to the mail route "/admin/mail/bulk" with:
      """
      act=read
      folder=inbox
      ids[]=#[R1]
      ids[]=#[R2]
      """
    Then the mail toast says "Marked 2 threads read"
    And Gmail received POST "/users/me/threads/r1/modify" holding '{"removeLabelIds":["UNREAD"]}'
    And Gmail received POST "/users/me/threads/r2/modify" holding '{"removeLabelIds":["UNREAD"]}'
    And the mail thread "R1" is now read
    And the mail thread "R2" is now read
    When I post to the mail route "/admin/mail/bulk" with:
      """
      act=unread
      folder=inbox
      ids[]=#[U1]
      ids[]=#[U2]
      """
    Then the mail toast says "Moved 2 threads back to unread"
    And Gmail received POST "/users/me/threads/u1/modify" holding '{"addLabelIds":["UNREAD"]}'
    And Gmail received POST "/users/me/threads/u2/modify" holding '{"addLabelIds":["UNREAD"]}'
    And the mail thread "U2" is now unread
    When I post to the mail route "/admin/mail/bulk" with:
      """
      act=move
      to=star
      folder=inbox
      ids[]=#[S1]
      ids[]=#[S2]
      """
    Then the mail toast says "Starred 2 threads"
    And Gmail received POST "/users/me/threads/s1/modify" holding '{"addLabelIds":["STARRED"]}'
    And Gmail received POST "/users/me/threads/s2/modify" holding '{"addLabelIds":["STARRED"]}'
    And the mail thread "S1" is now starred
    And the mail thread "S2" is now starred
    When I post to the mail route "/admin/mail/bulk" with:
      """
      act=move
      to=spam
      folder=inbox
      ids[]=#[P1]
      ids[]=#[P2]
      """
    Then the mail toast says "Moved 2 threads to Spam"
    And Gmail received POST "/users/me/threads/p1/modify" holding '{"addLabelIds":["SPAM"],"removeLabelIds":["INBOX"]}'
    And Gmail received POST "/users/me/threads/p2/modify" holding '{"addLabelIds":["SPAM"],"removeLabelIds":["INBOX"]}'
    And the mail thread "P1" is now spam
    And the mail thread "P2" is now spam
    When I post to the mail route "/admin/mail/bulk" with:
      """
      act=trash
      folder=inbox
      ids[]=#[T1]
      ids[]=#[T2]
      """
    Then the mail toast says "Moved 2 threads to Trash"
    And Gmail received POST "/users/me/threads/t1/trash"
    And Gmail received POST "/users/me/threads/t2/trash"
    And the mail thread "T1" is now trashed
    And the mail thread "T2" is now trashed

  Scenario: The bulk bar refuses more than 100 threads before it writes to Gmail
    Given the mail threads:
      | subject | account            | gmail id |
      | First   | aaron@work.example | t1       |
    When I post 101 mail thread IDs to the bulk route with the act "read"
    Then the mail toast says "Tick 100 threads or fewer"
    And the mail thread "First" is now unread

  Scenario: Restoring a trashed thread puts it back in the inbox and wakes it
    Given the mail threads:
      | subject | account            | gmail id | trashed | archived | snoozed hours |
      | Back    | aaron@work.example | t3       | yes     | yes      | 1             |
    And Gmail takes changes to the mail threads "t3"
    When I post to the mail route "/admin/mail/bulk" with:
      """
      act=inbox
      folder=trash
      ids[]=#[Back]
      """
    Then Gmail received POST "/users/me/threads/t3/untrash"
    And Gmail received POST "/users/me/threads/t3/modify" holding '{"addLabelIds":["INBOX"],"removeLabelIds":["SPAM"]}'
    And the mail thread "Back" is now inboxed

  Scenario: A label from one account labels the threads it fits and skips the rest
    Given the mail threads:
      | subject   | account            | gmail id |
      | One       | aaron@work.example | t1       |
      | Two       | aaron@work.example | t2       |
      | From form | contact form       |          |
    And the mail label "Receipts" with the Gmail ID "Label_9" on "aaron@work.example"
    And Gmail takes changes to the mail threads "t1, t2"
    When I post to the mail route "/admin/mail/bulk" with:
      """
      act=label
      label=@[aaron@work.example]:Receipts
      folder=inbox
      ids[]=#[One]
      ids[]=#[Two]
      ids[]=#[From form]
      """
    Then the mail toast says "Labeled 2 threads #Receipts · 1 skipped (label is on another account)"
    And Gmail received POST "/users/me/threads/t1/modify" holding '{"addLabelIds":["Label_9"]}'
    And Gmail received POST "/users/me/threads/t2/modify" holding '{"addLabelIds":["Label_9"]}'
    And the mail thread "One" wears the label "Label_9"
    And the mail thread "Two" wears the label "Label_9"
    And the mail thread "From form" wears no label
    When I post to the mail route "/admin/mail/bulk" with:
      """
      act=label
      label=@[aaron@work.example]:Receipts
      folder=inbox
      ids[]=#[From form]
      """
    Then the mail toast says "#Receipts is on another account · nothing labeled"

  Scenario: Tags stay here, on contact form and Gmail threads alike
    Given the mail threads:
      | subject   | account            | gmail id |
      | From form | contact form       |          |
      | At work   | aaron@work.example | t4       |
    When I post to the mail route "/admin/mail/bulk" with:
      """
      act=label
      label=@[contact form]:billing
      folder=inbox
      ids[]=#[From form]
      """
    Then the mail thread "From form" has the tags "billing"
    When I post to the mail route "/admin/mail/bulk" with:
      """
      act=tag
      tag=later
      folder=inbox
      ids[]=#[At work]
      """
    Then the mail thread "At work" has the tags "later"

  Scenario: Deleting ticked threads forever deletes them in Gmail and here
    Given the mail threads:
      | subject | account            | gmail id |
      | One     | aaron@work.example | t1       |
      | Two     | aaron@work.example | t2       |
    And Gmail takes changes to the mail threads "t1, t2"
    When I post to the mail route "/admin/mail/bulk" with:
      """
      act=delete
      folder=inbox
      ids[]=#[One]
      ids[]=#[Two]
      """
    Then the mail toast says "Deleted 2 threads forever"
    And Gmail got DELETE "/users/me/threads/t1" 1 time
    And Gmail got DELETE "/users/me/threads/t2" 1 time
    And the mail thread "One" is now gone
    And the mail thread "Two" is now gone

  Scenario: A thread Gmail refuses to delete keeps every ticked thread
    Given the mail threads:
      | subject | account            | gmail id |
      | Refused | aaron@work.example | refused  |
      | One     | aaron@work.example | t1       |
      | Two     | aaron@work.example | t2       |
    And Gmail takes changes to the mail threads "t1, t2"
    And Gmail refuses changes to the mail thread "refused"
    When I post to the mail route "/admin/mail/bulk" with:
      """
      act=delete
      folder=inbox
      ids[]=#[Refused]
      ids[]=#[One]
      ids[]=#[Two]
      """
    Then the mail toast says "Nothing changed · Gmail refused thread ##[Refused] Refused"
    And the mail thread "Refused" is now kept
    And the mail thread "One" is now kept
    And the mail thread "Two" is now kept
    When I post to the mail route "/admin/mail/bulk" with:
      """
      act=delete
      folder=inbox
      ids[]=#[One]
      ids[]=#[Two]
      ids[]=#[Refused]
      """
    Then the mail thread "Refused" is now kept
    And the mail thread "One" is now kept
    And the mail thread "Two" is now kept

  Scenario: The bulk bar offers the folders and the labels each list can take
    Given the mail threads:
      | subject | account            | gmail id | trashed |
      | Binned  | aaron@work.example | t1       | yes     |
      | Fresh   | aaron@work.example | t2       |         |
    And the mail label "Receipts" on "aaron@work.example"
    When I visit "/admin/mail"
    Then the mail bulk bar acts are "archive, read, unread, move, label, trash"
    And the mail bulk bar moves to "star, spam"
    And the mail bulk bar labels with "Label…, #Receipts · aaron@work.example"
    When I visit "/admin/mail?folder=trash"
    Then the mail bulk bar acts are "inbox, delete"
