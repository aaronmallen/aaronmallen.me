Feature: Admin row menus in the browser
  A right click on a journal, decision, file, link or tag row opens its menu, and its actions work in place.

  Background:
    Given I am signed in to the admin

  Scenario: Ticking a tag in a journal entry's menu tags it in place, and unticking takes it off
    Given the record menus have the journal entry "shipped it" tagged home
    And the database runs:
      """
      delete from journal_entry_tags
      """
    When I visit "/admin/journal?to=2026-10-01"
    And I open the record menu on ".journal-entry time"
    And I point at "Tags" in the record menu
    And I pick "#home" in the record menu
    Then the record page has ".toast" reading "Tagged home"
    And the record page has ".journal-entry .tag" reading "#home"
    And the record page stayed
    When I open the record menu on ".journal-entry time"
    And I point at "Tags" in the record menu
    And I pick "#home" in the record menu
    Then the record page has ".toast" reading "Took home off"
    And the record page has no ".journal-entry .tag:has-text('#home')"
    And the database soon answers "0" for:
      """
      select count(*) from journal_entry_tags
      """

  Scenario: Copying a journal entry's text from its menu says so
    Given the record menus have the journal entry "shipped it" tagged home
    When I visit "/admin/journal?to=2026-10-01"
    And I watch the record clipboard
    And I open the record menu on ".journal-entry time"
    And I pick "Copy text" in the record menu
    Then the record page has ".toast" reading "Entry copied"
    And the record clipboard holds "shipped it"

  Scenario: Deleting a journal entry from its menu asks for a second click, then deletes it in place
    Given the record menus have the journal entry "shipped it" tagged home
    When I visit "/admin/journal?to=2026-10-01"
    And I open the record menu on ".journal-entry time"
    And I pick "Delete entry" in the record menu
    Then the record menu offers "Click again · can't undo"
    When I pick "Click again · can't undo" in the record menu
    Then the record page has ".toast" reading "Entry deleted"
    And the record page has no ".journal-entry"
    And the record page stayed

  Scenario: Dropping a decision from its menu opens the reason form in a dialog and shows the blank reason error
    Given a record link decision titled "Pick a queue"
    When I visit "/admin/decisions"
    And I open the record menu on ".decision-meta"
    And I pick "Drop…" in the record menu
    Then the record page has "dialog#decision-1-drop [name='decision[reason]']"
    When I click "Drop" in the record dialog "dialog#decision-1-drop"
    Then the record page has "dialog#decision-1-drop .field-error" reading "Say why."
    And the database answers "open" for:
      """
      select status from decisions
      """
    When I fill "decision[reason]" in the record dialog "dialog#decision-1-drop" with "moot"
    And I click "Drop" in the record dialog "dialog#decision-1-drop"
    Then the record page has ".toast" reading "Dropped"

  Scenario: Dropping a decision from its menu with a reason drops it in place
    Given a record link decision titled "Pick a queue"
    When I visit "/admin/decisions"
    And I open the record menu on ".decision-meta"
    And I pick "Drop…" in the record menu
    And I fill "decision[reason]" in the record dialog "dialog#decision-1-drop" with "moot"
    And I click "Drop" in the record dialog "dialog#decision-1-drop"
    Then the record page has ".toast" reading "Dropped"
    And the record page has no ".decision-row:has-text('Pick a queue')"
    And the record page stayed

  Scenario: A file's menu opens its details and copies its link with a toast
    Given the record menus have the file "deck.pdf" of the type "application/pdf" at "deck"
    When I visit "/admin/files"
    And I watch the record clipboard
    And I open the record menu on ".file-card-meta"
    And I pick "Copy link" in the record menu
    Then the record page has ".toast" reading "Link copied"
    And the record clipboard starts with "http://shares.localhost/"
    When I open the record menu on ".file-card-meta"
    And I pick "Details" in the record menu
    Then the record page has "dialog.file-drawer[open]"

  Scenario: Deleting a link from its menu deletes it in place on the second click
    Given the record menus have the short link "talk-now" to "https://example.com/talk"
    When I visit "/admin/links"
    And I open the record menu on ".link-row-meta"
    And I pick "Delete link" in the record menu
    And I pick "Click again · it will 404" in the record menu
    Then the record page has ".toast" reading "Link deleted"
    And the record page has no ".link-row"
    And the record page stayed

  Scenario: A right click on a row's title link keeps the browser's own menu
    Given the record menus have the short link "talk-now" to "https://example.com/talk"
    When I visit "/admin/links"
    And I right click ".link-row-title a" on the record page
    Then no record menu opens

  Scenario: Recolouring a tag from its menu recolours it in place
    Given the record menus have the private tag "home" coloured "mk-blue"
    When I visit "/admin/settings/tagging?scope=private"
    And I open the record menu on ".tag-uses"
    And I point at "Colour" in the record menu
    And I pick "Pink" in the record menu
    Then the record page has ".toast" reading "Tag recoloured"
    And the record page has ".tag-row .tag-name .tag.pink" reading "#home"
    And the record page has no ".tag-row .tag-name .tag.blue"
    And the database soon answers "mk-pink" for:
      """
      select color from tags where scope = 'private'
      """
    And the record page stayed
