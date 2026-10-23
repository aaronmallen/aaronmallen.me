Feature: Admin mail drag
  A mail row dragged onto a folder or a label moves the thread there, by
  mouse or by a held touch.

  Background:
    Given I am signed in to the admin
    And the mail threads:
      | subject | minutes ago |
      | Newer   | 0           |
      | Older   | 1           |

  Scenario: A row dropped on a folder moves the thread and redraws the list in place
    When I visit "/admin/mail"
    And I mark the mail page
    And I drag the mail row "Older" onto the folder "Spam"
    Then the mail toast says "Moved 1 thread to Spam"
    And the mail list does not hold "Older"
    And the mail thread "Older" is now spam
    And the mail page has not reloaded

  Scenario: A row dragged by a held touch moves the thread
    When I visit "/admin/mail"
    And I drag the mail row "Older" by touch onto the folder "All mail"
    Then the mail toast says "Archived 1 thread"
    And the mail thread "Older" is now archived

  Scenario: A tap on a row opens the thread
    When I visit "/admin/mail"
    And I tap the mail row "Older"
    Then the mail row "Older" is open

  Scenario: A swipe that does not hold first starts no drag
    When I visit "/admin/mail"
    And I swipe the mail row "Older" toward the folder "All mail" without holding first
    Then no mail row drags

  Scenario: A swipe scrolls a list taller than the screen
    Given 30 older mail threads
    And I use a mail screen 1280 pixels wide and 500 tall
    When I visit "/admin/mail"
    And I swipe up the mail list
    Then the mail list has scrolled

  Scenario: Dragging a ticked row moves every ticked thread
    When I visit "/admin/mail"
    And I tick every mail row
    And I drag the mail row "Older" onto the folder "Trash"
    Then the mail toast says "Moved 2 threads to Trash"
    And the mail thread "Newer" is now trashed
    And the mail thread "Older" is now trashed

  Scenario: A drag shows the ghost, the targets and the faded rows
    When I visit "/admin/mail"
    And I tick every mail row
    And I drag the mail row "Older" over the folder "Spam" and hold it there
    Then the mail drag shows "2 threads" over 2 faded rows with "Spam" lit among 5 targets

  Scenario: Below 1180 pixels wide no folder shows, so no drag starts
    Given I use a mail screen 1179 pixels wide
    When I visit "/admin/mail"
    And I press and hold the mail row "Older"
    Then no mail row drags

  Scenario: A label from another account labels nothing
    Given I use a mail screen 1280 pixels wide
    And the mail account "work@example.com"
    And the mail label "Receipts" on "work@example.com"
    When I visit "/admin/mail"
    And I drag the mail row "Older" onto the folder "Receipts"
    Then the mail toast says "#Receipts is on another account · nothing labeled"
