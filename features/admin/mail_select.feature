Feature: Admin mail select mode and layout
  Select mode ticks rows for the bulk bar, and the folders sit in a sidebar
  on a wide screen and in a select on a narrow one.

  Background:
    Given I am signed in to the admin
    And the mail threads:
      | subject | body           | minutes ago | status |
      | Newer   | The newer body | 0           |        |
      | Older   | The older body | 1           |        |
      | Junk    |                | 2           | spam   |

  Scenario: Select mode ticks rows and marks them read from the bar
    When I visit "/admin/mail"
    Then the mail Select toggle is off
    And the mail bulk bar hides until Select
    When I tick every mail row
    Then the mail bulk bar hints "drag to a folder or label"
    And the page has no axe breaches in light or dark
    When I click "Read" on the mail bulk bar
    Then the mail toast says "Marked 2 threads read"
    And the mail thread "Newer" is now read
    And the mail thread "Older" is now read

  Scenario: Picking a folder on the bulk bar moves the ticked rows at once
    When I visit "/admin/mail"
    And I tick every mail row
    Then the mail bulk bar has no Move button
    When I move the ticked mail to "Spam"
    Then the mail toast says "Moved 2 threads to Spam"

  Scenario: Ticks do not come back when the page reloads
    When I visit "/admin/mail"
    And I tick every mail row
    And I reload the mail page
    Then no mail row is ticked

  Scenario: Reading a thread picked from the list marks it read
    When I visit "/admin/mail"
    And I open the mail thread "Older"
    Then the mail row "Older" is open
    And the mail thread "Older" is now read
    And the mail thread "Newer" is now unread

  Scenario: The reader keeps Select on screen after it marks a thread read
    Given the mail threads:
      | subject |
      | Fresh   |
    When I visit the mail page "/admin/mail?thread=#[Fresh]"
    And I click "Mark read" in the mail reader
    Then the mail toast says "Marked read"
    And the mail Select toggle is off

  Scenario: The folders sit in a sidebar from 1180 pixels wide
    Given I use a mail screen 1180 pixels wide
    When I visit "/admin/mail"
    Then the mail folder sidebar shows and the folder select hides

  Scenario: The folders sit in a select below 1180 pixels wide
    Given I use a mail screen 1179 pixels wide
    When I visit "/admin/mail"
    Then the mail folder select shows and the sidebar hides
    And the page has no axe breaches in light or dark
    When I pick "Spam · 1" from the mail folder select
    Then the mail list shows "Junk"

  Scenario: Long account names and labels fit the folder list beside both panes
    Given I use a mail screen 1180 pixels wide
    And the mail account "aaron.allen.long.address@work.example.com"
    And the mail account "side.project.address@personal.example.org"
    And the mail threads:
      | subject   | account                                   | labels                                                                          |
      | From work | aaron.allen.long.address@work.example.com | receipts, travel, bills, school, family, newsletters-and-other-very-long-label-names |
      | From side | side.project.address@personal.example.org | receipts, travel, bills, school, family, newsletters-and-other-very-long-label-names |
      | Open      |                                           |                                                                                 |
    When I visit the mail page "/admin/mail?thread=#[Open]"
    Then the mail folders and both panes fit the screen

  Scenario: The bulk route reads, deletes and names a thread that is gone
    When I post to the mail route "/admin/mail/bulk" with:
      """
      act=read
      folder=inbox
      ids[]=#[Newer]
      ids[]=#[Older]
      """
    Then the mail answer goes to "/admin/mail?folder=inbox&show=all"
    And the mail thread "Newer" is now read
    And the mail thread "Older" is now read
    When I post to the mail route "/admin/mail/bulk" with:
      """
      act=delete
      folder=inbox
      ids[]=#[Newer]
      ids[]=#[Older]
      """
    Then the mail toast says "Deleted 2 threads forever"
    And the mail thread "Newer" is now gone
    And the mail thread "Older" is now gone
    When I post to the mail route "/admin/mail/bulk" with:
      """
      act=read
      ids[]=999999
      """
    Then the mail toast says "Nothing changed · thread #999999 is gone"
