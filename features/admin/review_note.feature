Feature: Admin review note
  The review screen keeps one private note for each week and each month. The note lives apart from the journal, so
  saving it writes no entry and leaves the owner's own entries alone.

  Background:
    Given I am signed in to the admin

  Scenario: The box starts empty and posts the week's last day as a plain form with its token
    When I visit "/admin/review?day=2026-09-16"
    Then the review shows "#review-notes form#review-note-form[method='post'][action='/admin/review/note']"
    And the review's "#review-note-form textarea[name='note[body]']" holds ""
    And the review's "#review-note-form input[type='hidden'][name='day']" holds "2026-09-20"
    And the review shows "#review-note-form input[type='hidden'][name='_csrf_token']"
    And the review shows "#review-note-form button[type='submit']" reading "Save note"

  Scenario: A month's box names the month's last day
    When I visit "/admin/review?period=month&day=2026-09-16"
    Then the review's "#review-note-form input[type='hidden'][name='period']" holds "month"
    And the review's "#review-note-form input[type='hidden'][name='day']" holds "2026-09-30"

  Scenario: Saving a note keeps it for the week, writes no journal entry and returns with the toast
    When I visit "/admin/review?day=2026-09-16"
    And I fill the review note with "good week"
    And I click the button "Save note"
    Then the review page is at "/admin/review?day=2026-09-20"
    And the review shows "[data-toast] .toast" reading "Review note saved · private"
    And the database answers "week, 2026-09-14, good week" for:
      """
      select period, to_char(starts_on, 'YYYY-MM-DD'), body from review_notes
      """
    And the database answers "0" for:
      """
      select count(*) from journal_entries
      """

  Scenario: A month's note lands on the month and returns to the month
    When I post the review note "good month" for the month ending "2026-09-30"
    Then the review page is at "/admin/review?period=month&day=2026-09-30"
    And the database answers "month, 2026-09-01, good month" for:
      """
      select period, to_char(starts_on, 'YYYY-MM-DD'), body from review_notes
      """

  Scenario: The box shows the saved note and offers to update it, and a second save replaces the first
    When I post the review note "good week" for the day "2026-09-20"
    And I visit "/admin/review?day=2026-09-16"
    Then the review's "#review-notes textarea[name='note[body]']" holds "good week"
    And the review shows "#review-notes button[type='submit']" reading "Update note"
    When I post the review note "great week" for the day "2026-09-20"
    Then the database answers "great week" for:
      """
      select body from review_notes
      """

  Scenario: Saving a note leaves an entry on the same day alone
    Given the review has a journal entry on "2026-09-20" reading "walked the dog"
    When I post the review note "good week" for the day "2026-09-20"
    Then the database answers "walked the dog" for:
      """
      select body from journal_entries
      """

  Scenario: In a month that ends on a Sunday, the week and the month each keep their own note
    When I post the review note "good month" for the month ending "2026-05-31"
    And I post the review note "good week" for the day "2026-05-31"
    And I post the review note "great week" for the day "2026-05-31"
    Then the database answers "great week | good month" for:
      """
      select string_agg(body, ' | ' order by body desc) from review_notes
      """
    When I visit "/admin/review?day=2026-05-31"
    Then the review's "#review-notes textarea[name='note[body]']" holds "great week"
    When I post the review note "great month" for the month ending "2026-05-31"
    Then the database answers "great week | great month" for:
      """
      select string_agg(body, ' | ' order by period) from review_notes
      """
    When I visit "/admin/review?period=month&day=2026-05-31"
    Then the review's "#review-notes textarea[name='note[body]']" holds "great month"

  Scenario: In a month that ends on a Sunday, the month starts empty when only the week has a note
    When I post the review note "good week" for the day "2026-05-31"
    And I visit "/admin/review?period=month&day=2026-05-31"
    Then the review's "#review-notes textarea[name='note[body]']" holds ""

  Scenario: An entry tagged review on the week's last day stays out of the box and as I wrote it
    Given the review has a journal entry on "2026-09-20" reading "my own review" tagged "review"
    When I visit "/admin/review?day=2026-09-20"
    Then the review's "#review-notes textarea[name='note[body]']" holds ""
    When I post the review note "good week" for the day "2026-09-20"
    And I post the review note "great week" for the day "2026-09-20"
    Then the database answers "1, my own review" for:
      """
      select id, body from journal_entries
      """
    And the database answers "great week" for:
      """
      select body from review_notes where period = 'week' and starts_on = '2026-09-14'
      """

  Scenario: The note stays out of the journal and the activity feed
    When I post the review note "good week" for the day "2026-09-20"
    And I visit "/admin/journal?to=2026-09-20"
    Then the review shows no ".journal-entry-body" reading "good week"
    When I visit "/admin/activity?to=2026-09-20"
    Then the review shows no ".activity-event-name" reading "good week"

  Scenario: A week whose only writing is its note counts no entries and no words
    Given an MCP client connected with the scopes "read"
    When I post the review note "one two three four" for the day "2026-09-20"
    And I visit "/admin/review?day=2026-09-20"
    Then the review's "#review-journal .review-stat" reads "0 entries · 0 words · 0 days written"
    When I call the MCP tool "read_review" with:
      """
      {"day": "2026-09-20"}
      """
    Then the answer's "journal.entries" is:
      """
      []
      """
    And the answer's "journal.words" is "0"

  Scenario: A note for the week under way keeps to the week and leaves the journal, calendar and attention alone
    Given an API token
    And the database runs:
      """
      insert into journal_entries (entry_date, entry_time, body, body_html)
      values ((now() at time zone 'America/Chicago')::date - 5, '09:00', 'Old', '<p>Old</p>');
      """
    When I call the API with "GET /api/v1/attention"
    Then the answer matches:
      """
      {"attention": [{"kind": "journal", "record_id": null, "days": 5}]}
      """
    When I post the review note "halfway" for this week
    Then the review database holds this week's note "halfway"
    And the review database holds no journal entry after today
    And the review's calendar API marks only the journal's own days this week
    When I call the API with "GET /api/v1/attention"
    Then the answer matches:
      """
      {"attention": [{"kind": "journal", "record_id": null, "days": 5}]}
      """

  Scenario: A blank note answers 422, saves nothing and says why beside the box on the same week
    When I post the review note " \n " for the day "2026-09-20"
    Then the review note post answers 422
    And the database answers "0, 0" for:
      """
      select (select count(*) from review_notes) as notes, (select count(*) from journal_entries) as entries
      """
    And the review's "#review-notes #review-note-body-error.field-error" reads "Write something first."
    And the review shows "#review-notes #review-note-body[aria-invalid='true'][aria-describedby='review-note-body-error']"
    And the review shows ".page-head-sub" reading "Sep 14 → Sep 20, 2026"

  Scenario: A blank note leaves a saved note as it was
    When I post the review note "good week" for the day "2026-09-20"
    And I post the review note "  " for the day "2026-09-20"
    Then the review note post answers 422
    And the database answers "good week" for:
      """
      select body from review_notes
      """

  Scenario: A day it cannot read answers 400 and saves nothing
    When I post the review note "good week" for the day "2026-13-40"
    Then the review note post answers 400
    And the database answers "0" for:
      """
      select count(*) from review_notes
      """

  Scenario Outline: The review pages have no axe breaches in light or dark
    When I visit "<path>"
    Then the page has no axe breaches in light or dark

    Examples:
      | path                                     |
      | /admin/review?day=2026-09-16             |
      | /admin/review?period=month&day=2026-09-16 |
