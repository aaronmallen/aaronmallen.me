Feature: Admin journal editing
  Edit swaps an entry's text for a form holding its markdown and tags. Saving keeps the entry's day and time, a
  refused edit reopens the form with its error, and Cancel puts the saved entry back.

  Background:
    Given I am signed in to the admin

  Scenario: An edit changes the body and keeps the date and time, then returns to the journal with the toast
    Given the journal holds:
      | body   | day       | time  |
      | before | {today-3} | 21:05 |
    When I post the journal form to "/admin/journal/1" with:
      | entry[body]       | after   |
      | entry[entry_date] | {today} |
      | entry[entry_time] | 08:00   |
    Then the database answers "after, true, 21:05:00" for:
      """
      select body, entry_date = (now() at time zone 'America/Chicago')::date - 3, entry_time from journal_entries
      """
    And the admin address is "/admin/journal"
    And the journal toast reads "Entry updated"

  Scenario: An edit renders the new body to HTML and folds the tags to one case
    Given the journal holds:
      | body   |
      | before |
    When I post the journal form to "/admin/journal/1" with:
      | entry[body] | a **bold** day |
      | entry[tags] | Ruby, Health   |
    Then the database answers "<p>a <strong>bold</strong> day</p>" for:
      """
      select trim(E'\n' from body_html) from journal_entries
      """
    And the database answers "health, ruby" for:
      """
      select string_agg(t.name, ', ' order by t.name) from journal_entry_tags jt join tags t on t.id = jt.tag_id
      """

  Scenario Outline: A blank edit of <body> answers 422 and keeps the old body
    Given the journal holds:
      | body   |
      | before |
    When I post the journal form to "/admin/journal/1" with:
      | entry[body] | <body> |
    Then the journal post answers 422
    And the database answers "before" for:
      """
      select body from journal_entries
      """

    Examples:
      | body       |
      | " "        |
      | ""         |
      | "\n\t "    |

  Scenario: A refused edit reopens the form with the textarea marked invalid and the error under it
    Given the journal holds:
      | body   |
      | before |
    When I post the journal form to "/admin/journal/1" with:
      | entry[body] | "  " |
    Then the journal page holds "form[action='/admin/journal/1']:not([hidden]) textarea#journal-edit-1-body[aria-invalid='true'][aria-describedby='journal-edit-1-body-error']"
    And the journal page shows "#journal-edit-1-body-error.field-error" reading "Write something first."
    And the journal page shows ".journal-entry-body[hidden]" reading "before"
    And the journal page lacks "#journal-body-error"

  Scenario: An edit without a CSRF token is refused
    Given the journal holds:
      | body   |
      | before |
    When I post the journal form to "/admin/journal/1" without a CSRF token, with:
      | entry[body] | after |
    Then the journal post answers 403
    And the database answers "before" for:
      """
      select body from journal_entries
      """

  Scenario: An edit on an older, searched page sends the page and the search with its forms
    Given the journal holds:
      | body        | day       |
      | newest walk | {today}   |
      | middle walk | {today-1} |
      | middle walk | {today-1} |
      | old walk    | {today-3} |
    When I open the journal page "/admin/journal?to={today-3}&q=walk"
    Then the journal edit template holds "input[type='hidden'][name='to'][value='{today-3}']"
    And the journal edit template holds "input[type='hidden'][name='q'][value='walk']"
    And the journal page holds "form[action='/admin/journal/4/delete'] input[type='hidden'][name='to'][value='{today-3}']"
    And the journal page holds "form[action='/admin/journal/4/delete'] input[type='hidden'][name='q'][value='walk']"
    When I visit "/admin/journal"
    Then the journal edit template lacks ".journal-edit input[name='to'], .journal-edit input[name='q']"

  Scenario: A refused edit on an older page reopens on its page with the error, what was typed and the search
    Given the journal holds:
      | body        | day       |
      | newest walk | {today}   |
      | old walk    | {today-3} |
    When I post the journal form to "/admin/journal/2" with:
      | entry[body] | old run   |
      | entry[tags] | a/b       |
      | to          | {today-3} |
      | q           | walk      |
    Then the journal post answers 422
    And the journal shows the days "{today-3}"
    And the journal page holds "form[action='/admin/journal/2']:not([hidden])"
    And the journal page shows "#journal-edit-2-tags-error" reading "A tag is lowercase words joined by hyphens."
    And the journal field at "form[action='/admin/journal/2'] [name='entry[body]']" holds "old run"
    And the journal field at "form[action='/admin/journal/2'] [name='entry[tags]']" holds "a/b"
    And the journal field at "#journal-search" holds "walk"

  Scenario: A blank edit on an older page keeps the search in the reopened page
    Given the journal holds:
      | body     | day       |
      | old walk | {today-3} |
    When I post the journal form to "/admin/journal/1" with:
      | entry[body] | "  "      |
      | to          | {today-3} |
      | q           | walk      |
    Then the journal field at "#journal-search" holds "walk"

  Scenario: A save or a delete on an older page returns to the page and the search
    Given the journal holds:
      | body     | day       |
      | old walk | {today-3} |
    When I post the journal form to "/admin/journal/1" with:
      | entry[body] | old run walk |
      | to          | {today-3}    |
      | q           | walk         |
    Then the journal post sends me to "/admin/journal?to={today-3}&q=walk"
    When I post the journal form to "/admin/journal/1/delete" with:
      | to | {today-3} |
      | q  | walk      |
    Then the journal post sends me to "/admin/journal?to={today-3}&q=walk"

  Scenario: Edit swaps the text for a focused textarea holding it and hides Edit and Delete
    Given the journal holds:
      | body   | day       | time  |
      | before | {today-2} | 21:05 |
    When I visit "/admin/journal"
    And I edit the journal entry "before"
    Then the journal entry's "Entry text" holds "before"
    And the journal entry lacks ".journal-entry-body"
    And the journal entry lacks "button:text-is('Edit'), button[aria-label='Edit']"
    And the journal entry lacks "button:text-is('Delete'), button[aria-label='Delete']"
    And the focused journal field is "entry[body]"
    And the journal page holds 1 of "form[data-journal-edit-form]"
    And the journal entry holds "textarea#journal-edit-1-body"
    When I write "  \n " in the journal entry's "Entry text"
    Then the journal entry has the button "Save" disabled

  Scenario: Saving an edit keeps the entry's day and time
    Given the journal holds:
      | body   | day       | time  |
      | before | {today-2} | 21:05 |
    When I visit "/admin/journal"
    And I edit the journal entry "before"
    And I write "after" in the journal entry's "Entry text"
    And I click "Save" in the journal entry
    Then the journal toast reads "Entry updated"
    And the journal entries on "{today-2}" read "after"
    And the database answers "21:05:00" for:
      """
      select entry_time from journal_entries
      """

  Scenario: Cancel puts the saved text back, and editing again holds it
    Given the journal holds:
      | body   |
      | before |
    When I visit "/admin/journal"
    And I edit the journal entry "before"
    And I write "changed my mind" in the journal entry's "Entry text"
    And I click "Cancel" in the journal entry
    Then the journal entry shows ".journal-entry-body" reading "before"
    And the journal entry lacks "textarea"
    And the database answers "before" for:
      """
      select body from journal_entries
      """
    When I click "Edit" in the journal entry
    Then the journal entry's "Entry text" holds "before"

  Scenario: An edit in progress survives a live update
    Given the journal holds:
      | body   | day       |
      | before | {today-2} |
    When I open "/admin/journal" and its live stream
    And I edit the journal entry "before"
    And I write "half typed" in the journal entry's "Entry text"
    And the journal holds:
      | body              |
      | written elsewhere |
    Then the journal page shows ".journal-entry-body:has-text('written elsewhere')" reading "written elsewhere"
    And the journal entry's "Entry text" holds "half typed"

  Scenario: Editing a tagged entry holds its tags and saves them with the new text
    Given the journal holds:
      | body   | tags       |
      | tagged | ruby, health |
    When I visit "/admin/journal"
    And I edit the journal entry "tagged"
    Then the journal entry holds 2 of ".tag-pick-chip"
    When I write "retagged" in the journal entry's "Entry text"
    And I click "Save" in the journal entry
    Then the journal toast reads "Entry updated"
    And the database answers "retagged, health, ruby" for:
      """
      select e.body, string_agg(t.name, ', ' order by t.name)
      from journal_entries e join journal_entry_tags jt on jt.journal_entry_id = e.id join tags t on t.id = jt.tag_id
      group by e.body
      """

  Scenario: Cancel puts the saved tags back, and saving after it keeps them
    Given the journal holds:
      | body   | tags |
      | tagged | ruby |
    When I visit "/admin/journal"
    And I edit the journal entry "tagged"
    And I remove a tag from the journal entry and add "lake"
    And I click "Cancel" in the journal entry
    And I click "Edit" in the journal entry
    Then the journal texts of ".journal-entry .tag-pick-chip" read "#ruby"
    And the journal field at ".journal-entry [data-tag-field-value]" holds "ruby"
    When I click "Save" in the journal entry
    Then the journal toast reads "Entry updated"
    And the database answers "ruby" for:
      """
      select string_agg(t.name, ', ' order by t.name) from journal_entry_tags jt join tags t on t.id = jt.tag_id
      """

  Scenario: Cancel hides an entry's links section
    Given a post "On racks" published an hour ago
    And the journal holds:
      | body            |
      | Packed the rack |
    And the journal entry "Packed the rack" links to the post "On racks"
    When I visit "/admin/journal"
    And I hover the journal entry "Packed the rack"
    And I click "Links" in the journal entry
    And I click "Cancel" in the journal entry
    Then the journal entry lacks ".record-links"

  Scenario: Cancelling an edit to a markdown entry shows it rendered and puts the source back
    When I post the journal form to "/admin/journal" with:
      | entry[body] | a **bold** day\n\n- one |
    And I edit the journal entry "bold"
    And I write "changed my mind" in the journal entry's "Entry text"
    And I click "Cancel" in the journal entry
    Then the journal entry shows ".journal-entry-body strong" reading "bold"
    And the journal entry shows ".journal-entry-body li" reading "one"
    When I click "Edit" in the journal entry
    Then the journal entry's "Entry text" holds "a **bold** day\n\n- one"

  Scenario: Previewing an edit shows the edited text and opens on Write with the saved text after Cancel
    Given the journal holds:
      | body   |
      | before |
    When I visit "/admin/journal"
    And I edit the journal entry "before"
    And I write "an *edited* entry" in the journal entry's "Entry text"
    And I switch the journal entry to "Preview"
    Then the journal entry preview shows "em" reading "edited"
    When I click "Cancel" in the journal entry
    And I click "Edit" in the journal entry
    Then the journal entry's "Entry text" holds "before"
    When I switch the journal entry to "Preview"
    Then the journal entry preview shows "p" reading "before"

  Scenario: Cancel clears a rejected edit's error
    Given the journal holds:
      | body   |
      | before |
    When I visit "/admin/journal"
    And I edit the journal entry "before"
    And I submit the journal entry's edit with " "
    Then the journal page shows ".field-error" reading "Write something first."
    When I click "Cancel" in the journal entry
    And I click "Edit" in the journal entry
    Then the journal entry's "Entry text" holds "before"
    And the journal entry lacks ".field-error"
