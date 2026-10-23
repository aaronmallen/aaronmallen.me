Feature: Admin journal saving
  The composer and the quick-write modal post a new entry to the journal. It lands on the chosen day, or today
  from the modal, at the time of saving, and a refused entry comes back with its errors and what was typed.

  Background:
    Given I am signed in to the admin

  Scenario: Saving files the entry under today at the time of saving and returns to the journal with the toast
    When I post the journal form to "/admin/journal" with:
      | entry[body]       | walked  |
      | entry[entry_date] | {today} |
    Then the journal post answers 302
    And the database answers "walked, true, true" for:
      """
      select body, entry_date = (now() at time zone 'America/Chicago')::date as today,
        abs(extract(epoch from entry_time - (now() at time zone 'America/Chicago')::time)) < 60
      from journal_entries
      """
    And the admin address is "/admin/journal"
    And the journal toast reads "Journal entry saved · private"
    And the journal entries on "{today}" read "walked"

  Scenario: Saving renders the body to HTML
    When I post the journal form to "/admin/journal" with:
      | entry[body]       | a *walk* |
      | entry[entry_date] | {today}  |
    Then the database answers "<p>a <em>walk</em></p>" for:
      """
      select trim(E'\n' from body_html) from journal_entries
      """

  Scenario: Saving files a backdated entry under the chosen date at the time of saving
    When I post the journal form to "/admin/journal" with:
      | entry[body]       | remembered  |
      | entry[entry_date] | {today-4}   |
    Then the database answers "remembered, true, true" for:
      """
      select body, entry_date = (now() at time zone 'America/Chicago')::date - 4 as day,
        abs(extract(epoch from entry_time - (now() at time zone 'America/Chicago')::time)) < 60
      from journal_entries
      """

  Scenario: Saving without an entry date files the entry under today
    When I post the journal form to "/admin/journal" with:
      | entry[body] | walked |
    Then the database answers "true" for:
      """
      select entry_date = (now() at time zone 'America/Chicago')::date from journal_entries
      """

  Scenario: Saving folds the tags to one case
    When I post the journal form to "/admin/journal" with:
      | entry[body]       | walked        |
      | entry[entry_date] | {today}       |
      | entry[tags]       | Ruby, health  |
    Then the database answers "health, ruby" for:
      """
      select string_agg(t.name, ', ' order by t.name) from journal_entry_tags jt join tags t on t.id = jt.tag_id
      """

  Scenario: Saving an entry with no tags gives it none
    When I post the journal form to "/admin/journal" with:
      | entry[body]       | walked  |
      | entry[entry_date] | {today} |
    Then the database answers "1, 0" for:
      """
      select (select count(*) from journal_entries) as entries, (select count(*) from journal_entry_tags) as tags
      """

  Scenario: A blank entry answers 422, saves nothing and shows the error by the textarea
    When I post the journal form to "/admin/journal" with:
      | entry[body]       | " \n " |
      | entry[entry_date] | {today} |
    Then the journal post answers 422
    And the database answers "0" for:
      """
      select count(*) from journal_entries
      """
    And the journal page shows "#journal-body-error.field-error" reading "Write something first."
    And the journal page holds "#journal-body[aria-invalid='true'][aria-describedby='journal-body-error']"

  Scenario: A future date is refused and what was typed stays
    When I post the journal form to "/admin/journal" with:
      | entry[body]       | tomorrow  |
      | entry[entry_date] | {today+1} |
    Then the journal post answers 422
    And the journal page shows "#journal-entry-date-error" reading "Pick today or an earlier day."
    And the journal field "Entry" holds "tomorrow"
    And the database answers "0" for:
      """
      select count(*) from journal_entries
      """

  Scenario: A date it can't read is refused
    When I post the journal form to "/admin/journal" with:
      | entry[body]       | walked     |
      | entry[entry_date] | 2026-02-30 |
    Then the journal page shows "#journal-entry-date-error" reading "Enter a date."

  Scenario: A tag it can't use is refused and what was typed stays
    When I post the journal form to "/admin/journal" with:
      | entry[body]       | walked  |
      | entry[entry_date] | {today} |
      | entry[tags]       | a/b     |
    Then the journal page shows "#journal-tags-error" reading "A tag is lowercase words joined by hyphens."
    And the journal field at "#journal-entry input[name='entry[tags]']" holds "a/b"
    And the database answers "0" for:
      """
      select count(*) from journal_entries
      """

  Scenario: A refused entry keeps the chosen date and titles the card with it
    When I post the journal form to "/admin/journal" with:
      | entry[body]       |            |
      | entry[entry_date] | 2026-09-03 |
    Then the journal field "Entry date" holds "2026-09-03"
    And the journal page shows "#journal-entry h2.card-title" reading "Thursday, September 3, 2026"

  Scenario: A save without a CSRF token is refused
    When I post the journal form to "/admin/journal" without a CSRF token, with:
      | entry[body] | walked |
    Then the journal post answers 403
    And the database answers "0" for:
      """
      select count(*) from journal_entries
      """

  Scenario: The modal files its entry under today with its tags, whatever date comes with it
    When I post the journal form to "/admin/journal" with:
      | modal             | 1            |
      | return_to         | /admin/posts |
      | entry[body]       | walked       |
      | entry[tags]       | health       |
      | entry[entry_date] | {today-4}    |
    Then the database answers "walked, true, health" for:
      """
      select e.body, e.entry_date = (now() at time zone 'America/Chicago')::date, t.name
      from journal_entries e join journal_entry_tags jt on jt.journal_entry_id = e.id join tags t on t.id = jt.tag_id
      """

  Scenario: The modal returns to the page it was opened on with the toast
    When I post the journal form to "/admin/journal" with:
      | modal       | 1            |
      | return_to   | /admin/posts |
      | entry[body] | walked       |
    Then the admin address is "/admin/posts"
    And the journal toast reads "Journal entry saved · private"

  Scenario: The modal returns to the journal when the return path leaves the admin
    When I post the journal form to "/admin/journal" with:
      | modal       | 1                         |
      | return_to   | https://example.com/admin |
      | entry[body] | walked                    |
    Then the journal post sends me to "/admin/journal"

  Scenario: A blank modal entry answers 422, saves nothing and reopens the modal with the error
    When I post the journal form to "/admin/journal" with:
      | modal       | 1            |
      | return_to   | /admin/posts |
      | entry[body] | "  "         |
    Then the journal post answers 422
    And the database answers "0" for:
      """
      select count(*) from journal_entries
      """
    And the journal page holds "dialog#journal-write[data-dialog-show]"
    And the journal page shows "dialog#journal-write #journal-write-body-error.field-error" reading "Write something first."
    And the journal page lacks "#journal-body-error"

  Scenario: A modal tag error shows in the modal and keeps what was typed
    When I post the journal form to "/admin/journal" with:
      | modal       | 1            |
      | return_to   | /admin/posts |
      | entry[body] | walked       |
      | entry[tags] | a/b          |
    Then the journal page holds "dialog#journal-write #journal-write-tags-error.field-error"
    And the journal page shows "dialog#journal-write #journal-write-body" reading "walked"
    And the journal page holds "dialog#journal-write #journal-write-tags[value='a/b'][aria-invalid='true']"
    And the journal page holds "dialog#journal-write input[name='return_to'][value='/admin/posts']"
