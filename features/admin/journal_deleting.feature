Feature: Admin journal deleting
  Delete asks first, then removes the entry, updates the counts and returns to the journal, or to the day and
  search it was on. It works with scripts off too.

  Background:
    Given I am signed in to the admin

  Scenario: Deleting an entry removes it and returns to the journal with the toast
    Given the journal holds:
      | body    |
      | one two |
    When I post the journal form to "/admin/journal/1/delete"
    Then the database answers "0" for:
      """
      select count(*) from journal_entries
      """
    And the admin address is "/admin/journal"
    And the journal toast reads "Entry deleted"

  Scenario: Deleting an entry updates the counts and the streak
    Given the journal holds:
      | body    | day       |
      | one two | {today}   |
      | three   | {today-1} |
    When I post the journal form to "/admin/journal/1/delete"
    Then the journal page shows ".page-head-sub" holding "1 entry · 1 word"
    And the journal page shows ".page-head-sub" holding "wrote on 1 of the last 30 days"

  Scenario: Deleting an entry that is gone answers 404
    Given the journal holds:
      | body    |
      | one two |
    When I post the journal form to "/admin/journal/2/delete"
    Then the journal post answers 404
    And the database answers "1" for:
      """
      select count(*) from journal_entries
      """

  Scenario: A delete without a CSRF token is refused
    Given the journal holds:
      | body    |
      | one two |
    When I post the journal form to "/admin/journal/1/delete" without a CSRF token, with:
      | q | |
    Then the journal post answers 403
    And the database answers "1" for:
      """
      select count(*) from journal_entries
      """

  Scenario: The Delete button deletes with scripts off
    Given the journal holds:
      | body    |
      | one two |
    When I delete the journal entry "one two" with scripts off
    Then the scripts-off journal page showed the toast "Entry deleted"
    And the database answers "0" for:
      """
      select count(*) from journal_entries
      """

  Scenario: Delete asks with the confirmation text and keeps the entry when I decline
    Given the journal holds:
      | body    | day       |
      | keep me | {today}   |
      | drop me | {today-1} |
    When I visit "/admin/journal"
    And I ask to delete the journal entry "drop me"
    Then the journal page shows "[data-confirm-ask] [data-confirm-message]" reading "Delete this entry? You can't undo this."
    When I decline the confirm
    Then the journal page lacks ".toast"
    And the journal page holds ".journal-entry-body:has-text('drop me')"

  Scenario: Delete removes the entry and updates the counts once I confirm
    Given the journal holds:
      | body    | day       |
      | keep me | {today}   |
      | drop me | {today-1} |
    When I visit "/admin/journal"
    And I ask to delete the journal entry "drop me"
    And I accept the journal confirm
    Then the journal toast reads "Entry deleted"
    And the journal page lacks ".journal-entry-body:has-text('drop me')"
    And the journal page shows ".page-head-sub" holding "1 entry · 2 words"
    And the journal page shows ".page-head-sub" holding "wrote on 1 of the last 30 days"

  Scenario: Deleting from a searched day comes back to that day and search
    Given the journal holds:
      | body      | day       |
      | keep walk | {today}   |
      | drop walk | {today-1} |
      | stay walk | {today-1} |
    When I open the journal page "/admin/journal?to={today-1}&q=walk"
    And I ask to delete the journal entry "drop walk"
    And I accept the journal confirm
    Then the journal toast reads "Entry deleted"
    And the journal address is "/admin/journal?to={today-1}&q=walk"
    And the journal field at "#journal-search" holds "walk"
