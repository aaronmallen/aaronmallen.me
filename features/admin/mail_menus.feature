Feature: Admin mail menus
  A right click on a mail row opens a menu of what the thread can do, and a
  right click with rows ticked opens one for every ticked thread.

  Background:
    Given I am signed in to the admin

  Scenario: Each row and the bulk bar hang their menu with the list's place
    Given the mail threads:
      | subject |
      | Hello   |
    When I visit "/admin/mail?folder=inbox&show=unread"
    Then the mail row "Hello" hangs its menu on "/admin/mail/#[Hello]/menu?folder=inbox&show=unread"
    And the mail bulk bar hangs its menu on "/admin/mail/bulk/menu?folder=inbox&show=unread"
    When I visit "/admin/inbox"
    Then the inbox row for the mail thread "Hello" hangs its menu on "/admin/mail/#[Hello]/menu?origin=inbox"
    And the page has no axe breaches in light or dark
    And the mail page "/admin/mail/0/menu" answers with status 404
    And the mail page "/admin/mail/bulk/menu?ids[]=nope" answers with status 404

  Scenario: The menu of an unread thread in the inbox holds every action it takes
    Given the mail account "aaron@work.example"
    And the mail label "billing" on "aaron@work.example"
    And the mail threads:
      | subject       | account            | from | reply to    | labels |
      | Release notes | aaron@work.example | Sean | sean@ex.com | ops    |
    When I fetch the mail menu "/admin/mail/#[Release notes]/menu?folder=inbox&page=2&return_to=%2Fadmin%2Fmail%3Fpage%3D2"
    Then the mail menu is headed "Sean · Release notes"
    And the mail menu holds "Open, Reply, Mark read, Star, Archive, Snooze, Later today, Tomorrow morning, Next week, Move to, Archive, Spam, Trash, Label, #billing, #ops, Make a task, Copy address, Delete"
    And the mail menu item "Mark read" posts to "/admin/mail/bulk" with "ids[]=#[Release notes]&act=read&folder=inbox&page=2"
    And the mail menu item "Mark read" sends no "return_to"
    And the mail menu item "Tomorrow morning" under "Snooze" posts to "/admin/inbox/message/#[Release notes]/snooze" with "return_to=/admin/mail?page=2&pick=%[tomorrow at 08:00]"
    And the mail menu item "#billing" under "Label" posts to "/admin/mail/bulk" with "act=label&label=@[aaron@work.example]:billing"
    And the mail menu shows "#ops" under "Label" ticked and fixed
    And the mail menu item "Make a task" opens the task dialog of "Release notes"
    And the mail menu copies "sean@ex.com"
    And the mail menu item "Reply" links to a page starting "/admin/mail?folder=inbox&show=all&page=2&thread=#[Release notes]#"
    And the mail menu item "Delete" asks "Click again to delete" first

  Scenario: The menu fits what the thread is
    Given the mail account "aaron@work.example"
    And the mail threads:
      | subject  | account            | status | starred | snoozed hours | archived | trashed |
      | Sleepy   | contact form       | read   | yes     | 1             |          |         |
      | Filed    | contact form       |        |         |               | yes      |         |
      | Binned   | contact form       |        |         |               |          | yes     |
      | From you | contact form       |        |         |               |          |         |
      | At work  | aaron@work.example |        |         |               |          |         |
    And the task "Reply to Filed" links the mail thread "Filed"
    When I fetch the mail menu "/admin/mail/#[Sleepy]/menu"
    Then the mail menu includes "Mark unread, Unstar, Wake now"
    And the mail menu leaves out "Snooze"
    When I fetch the mail menu "/admin/mail/#[Filed]/menu"
    Then the mail menu includes "Move to Inbox, Open task #1"
    And the mail menu leaves out "Make a task"
    When I fetch the mail menu "/admin/mail/#[Binned]/menu"
    Then the mail menu leaves out "Reply"
    And the mail menu item "Delete forever" posts to "/admin/mail/bulk" with "act=delete"
    And the mail menu item "Delete forever" asks "Click again · can't undo" first
    When I fetch the mail menu "/admin/mail/#[From you]/menu"
    Then the mail menu offers a new label field under "Label" that posts "act=tag"
    When I fetch the mail menu "/admin/mail/#[At work]/menu"
    Then the mail menu offers a new label field under "Label" that posts "act=tag"

  Scenario: Actions from a menu opened in the inbox land back on the inbox
    Given the mail threads:
      | subject | starred | snoozed hours |
      | Ping    |         |               |
      | Pinned  | yes     |               |
      | Sleepy  |         | 1             |
    When I fetch the mail menu "/admin/mail/#[Ping]/menu?origin=inbox&return_to=%2Fadmin%2Finbox"
    Then the mail menu item "Mark read" posts to "/admin/mail/bulk" with "return_to=/admin/inbox"
    When I post to the mail route "/admin/mail/bulk" with:
      """
      ids[]=#[Ping]
      act=star
      return_to=/admin/inbox
      """
    Then the mail answer goes to "/admin/inbox"
    And the mail toast says "Starred 1 thread"
    When I post to the mail route "/admin/mail/bulk" with:
      """
      ids[]=#[Pinned]
      act=unstar
      folder=inbox
      """
    Then the mail toast says "Unstarred 1 thread"
    And the mail thread "Pinned" is now unstarred
    When I post to the mail route "/admin/mail/#[Sleepy]/wake" with:
      """
      return_to=/admin/mail?folder=snoozed
      """
    Then the mail answer goes to "/admin/mail?folder=snoozed"

  Scenario: The bulk menu acts on every picked thread
    Given the mail account "aaron@work.example"
    And the mail label "ops" on "aaron@work.example"
    And the mail threads:
      | subject | account            | minutes ago |
      | one     | aaron@work.example | 0           |
      | two     | aaron@work.example | 1           |
    When I fetch the mail menu "/admin/mail/bulk/menu?ids[]=#[one]&ids[]=#[two]&folder=inbox&page=2"
    Then the mail menu is headed "2 threads picked"
    And the mail menu holds "Archive 2, Mark read, Mark unread, Star, Snooze, Later today, Tomorrow morning, Next week, Move to, Archive, Spam, Trash, Label, #ops, Delete 2"
    And the mail menu item "Archive 2" posts to "/admin/mail/bulk" with "act=archive&folder=inbox&page=2"
    And the mail menu item "Archive 2" posts the IDs of "one, two"
    And the mail menu item "#ops" under "Label" posts to "/admin/mail/bulk" with "act=label&label=@[aaron@work.example]:ops"
    And the mail menu item "Next week" under "Snooze" posts to "/admin/mail/bulk/snooze" with "folder=inbox"
    And the mail menu item "Delete 2" asks "Click again to delete" first

  Scenario: The bulk menu in the trash restores or deletes forever
    Given the mail threads:
      | subject | trashed |
      | One     | yes     |
      | Two     | yes     |
    When I fetch the mail menu "/admin/mail/bulk/menu?ids[]=#[One]&ids[]=#[Two]&folder=trash"
    Then the mail menu holds "Restore 2, Delete 2 forever"

  Scenario: Snoozing picked threads needs a time after now
    Given the mail threads:
      | subject |
      | One     |
      | Two     |
    When I post to the mail route "/admin/mail/bulk/snooze" with:
      """
      ids[]=#[One]
      ids[]=#[Two]
      pick=2020-01-01T08:00
      folder=inbox
      """
    Then the mail toast says "Nothing changed · a snooze ends after now"
    And the mail thread "One" is now awake
    When I post to the mail route "/admin/mail/bulk/snooze" with:
      """
      ids[]=#[One]
      ids[]=#[Two]
      pick=soon
      folder=inbox
      """
    Then the mail toast says "Nothing changed · a snooze ends after now"
    And the mail thread "Two" is now awake
    When I post to the mail route "/admin/mail/bulk/snooze" with:
      """
      ids[]=#[One]
      ids[]=#[Two]
      pick=%[tomorrow at 08:00]
      folder=inbox
      """
    Then the mail toast says "Snoozed 2 threads until %[tomorrow as a date]"
    And the mail thread "One" now snoozes until "%[tomorrow at 08:00]"
    And the mail thread "Two" now snoozes until "%[tomorrow at 08:00]"

  Scenario: A thread's menu stars it in place
    Given the mail threads:
      | subject | minutes ago |
      | Newer   | 0           |
      | Older   | 1           |
    When I visit "/admin/mail"
    And I mark the mail page
    And I open the mail menu on "Older"
    Then the page has no axe breaches in light or dark
    When I pick "Star" from the mail menu
    Then the mail toast says "Starred 1 thread"
    And 1 mail row wears a star
    And the mail page has not reloaded

  Scenario: A thread's menu asks for a second click before it deletes
    Given the mail threads:
      | subject | minutes ago |
      | Newer   | 0           |
      | Older   | 1           |
    When I visit "/admin/mail"
    And I open the mail menu on "Older"
    And I pick "Delete" from the mail menu
    Then the mail thread "Older" is now kept
    When I pick "Click again to delete" from the mail menu
    Then the mail toast says "Moved 1 thread to Trash"
    And the mail list does not hold "Older"

  Scenario: The bulk menu acts on every ticked thread
    Given the mail threads:
      | subject | minutes ago |
      | Newer   | 0           |
      | Older   | 1           |
    When I visit "/admin/mail"
    And I tick every mail row
    And I open the mail menu on "Newer"
    And I pick "Mark read" from the mail menu
    Then the mail toast says "Marked 2 threads read"
    And the mail thread "Newer" is now read
    And the mail thread "Older" is now read

  Scenario: A mail row's menu in the inbox archives the thread
    Given the mail threads:
      | subject | minutes ago |
      | Newer   | 0           |
      | Older   | 1           |
    When I visit "/admin/inbox"
    And I open the mail menu on the inbox row "Older"
    And I pick "Archive" from the mail menu
    Then the mail toast says "Archived 1 thread"
    And the mail page address is "/admin/inbox"
