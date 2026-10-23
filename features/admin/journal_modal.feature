Feature: Admin journal modal
  The w key opens a quick-write modal on any admin page. It counts words, saves today's entry with its tags on
  Save or Ctrl+Enter and returns to the page, and keeps what was typed when a save fails.

  Background:
    Given I am signed in to the admin
    When I visit "/admin/posts"
    And I press the keys "w"

  Scenario: The modal opens on today with the cursor in the entry
    Then the journal modal's head names today
    And the journal page holds "dialog#journal-write [data-markdown-editor] textarea#journal-write-body[name='entry[body]']"
    And the journal page holds "#journal-write-body:focus"

  Scenario: The modal counts words and enables Save once there is text
    Then the journal button "Save" is disabled
    When I write "one two three" in the journal field "#journal-write-body"
    Then the journal page shows "dialog#journal-write [data-journal-words]" reading "3 words"
    And the journal button "Save" is enabled

  Scenario: Saving files today's entry with its tags and returns to the page
    When I write "walked to the lake" in the journal field "#journal-write-body"
    And I write "health" in the journal field "#journal-write-tags-search"
    And I click "Save" in the journal modal
    Then the journal toast reads "Journal entry saved · private"
    And the admin address is "/admin/posts"
    And the database answers "walked to the lake, true, health" for:
      """
      select e.body, e.entry_date = (now() at time zone 'America/Chicago')::date, string_agg(t.name, ', ')
      from journal_entries e join journal_entry_tags jt on jt.journal_entry_id = e.id join tags t on t.id = jt.tag_id
      group by e.id
      """

  Scenario: Ctrl+Enter saves what was typed in the editor
    When I type "walked" into the journal page
    And I press "Control+Enter"
    Then the journal toast reads "Journal entry saved · private"
    And the database answers "walked" for:
      """
      select body from journal_entries
      """

  Scenario: A failed save shows its errors in the modal and keeps what was typed
    When I write "walked" in the journal field "#journal-write-body"
    And I write "a/b" in the journal field "#journal-write-tags-search"
    And I click "Save" in the journal modal
    Then the journal page holds "dialog#journal-write[open] #journal-write-tags-error.field-error"
    And the journal field at "#journal-write-body" holds "walked"
    And the database answers "0" for:
      """
      select count(*) from journal_entries
      """
