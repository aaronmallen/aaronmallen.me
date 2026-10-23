Feature: Admin activity markdown
  A journal row sets the start of its markdown as one line of inline text, cut short with an ellipsis, and every
  other kind of row shows its name as plain text.

  Background:
    Given I am signed in to the admin

  Scenario: An activity journal row formats bold, italic and code
    Given the activity data holds:
      """
      insert into journal_entries (entry_date, entry_time, body, body_html)
        values (current_date, '09:00', 'a **bold**, _italic_ and `code` day', '<p>day</p>');
      """
    When I open the activity
    Then the activity page has ".activity-event-name strong" reading "bold"
    And the activity page has ".activity-event-name em" reading "italic"
    And the activity page has ".activity-event-name code" reading "code"

  Scenario: An activity journal row shows a link as its text
    Given the activity data holds:
      """
      insert into journal_entries (entry_date, entry_time, body, body_html)
        values (current_date, '09:00', 'read [the docs](https://example.com/docs) today', '<p>read</p>');
      """
    When I open the activity
    Then the activity rows read "read the docs today"
    And the activity page has no "a.activity-event a"

  Scenario: An activity journal row flattens a heading, a list and paragraphs into one line
    Given the activity data holds:
      """
      insert into journal_entries (entry_date, entry_time, body, body_html)
        values (current_date, '09:00', E'# Morning\n\n- one\n- two\n\nwalked\nthe dog\n\n> and rested', '<p>walked</p>');
      """
    When I open the activity
    Then the activity rows read "Morning one two walked the dog and rested"

  Scenario: An activity journal row cuts at the visible text and closes the mark it opened
    Given the activity data holds:
      """
      insert into journal_entries (entry_date, entry_time, body, body_html)
        values (current_date, '09:00', '**' || rtrim(repeat('bold ', 40)) || '**', '<p>bold</p>');
      """
    When I open the activity
    Then the first activity row's markup reads "<strong>bold bold bold bold bold bold bold bold bold bold bold bold bold bold bold bold bold bold bold bold bold bold bold bold</strong>…"

  Scenario: An activity journal row closes every mark it opened when the cut falls inside two
    Given the activity data holds:
      """
      insert into journal_entries (entry_date, entry_time, body, body_html)
        values (current_date, '09:00', '**bold _and ' || rtrim(repeat('long ', 30)) || '_**', '<p>bold</p>');
      """
    When I open the activity
    Then the first activity row's markup ends with "</em></strong>…"

  Scenario: An activity journal row leaves a link's address out of the count
    Given the activity data holds:
      """
      insert into journal_entries (entry_date, entry_time, body, body_html)
        values (current_date, '09:00', '[docs](https://example.com/' || repeat('a', 200) || ') walked', '<p>docs</p>');
      """
    When I open the activity
    Then the activity rows read "docs walked"

  Scenario: An activity journal row drops raw HTML
    Given the activity data holds:
      """
      insert into journal_entries (entry_date, entry_time, body, body_html)
        values (current_date, '09:00', 'a <script>alert(1)</script> <b>bold</b> <img src=x onerror=alert(2)> day', '<p>day</p>');
      """
    When I open the activity
    Then the activity page has no ".activity-event-name script, .activity-event-name b, .activity-event-name img"
    And the activity rows read "a alert(1) bold day"

  Scenario: An activity journal row escapes text that reads like HTML
    Given the activity data holds:
      """
      insert into journal_entries (entry_date, entry_time, body, body_html)
        values (current_date, '09:00', '`<b>not bold</b>`', '<p>not bold</p>');
      """
    When I open the activity
    Then the activity page has ".activity-event-name code" reading "<b>not bold</b>"

  Scenario: The activity leaves the markdown in other kinds of rows alone
    Given the activity data holds:
      """
      insert into commits (sha, repo, branch, message, commit_date, commit_time)
        values ('a1', 'aaronmallen/aaronmallen.me', 'main', 'add **the** view', current_date, '09:00');
      """
    When I open the activity
    Then the activity rows read "add **the** view"
    And the activity page has no ".activity-event-name strong"

  Scenario: The activity cuts a long name short with an ellipsis
    Given the activity data holds:
      """
      insert into journal_entries (entry_date, entry_time, body, body_html) values
        (current_date, '09:00', 'walked ' || repeat('the dog ', 40), '<p>walked</p>'),
        (current_date - 1, '09:00', '**ran** ' || repeat('far ', 400), '<p>ran</p>');
      """
    When I open the activity
    Then the first activity row runs to at most 121 characters
    And the first activity row on today ends with "…"
    And the activity page has ".activity-day:has(time[datetime='{today-1}']) .activity-event-name strong" reading "ran"
    And the first activity row on yesterday ends with "…"
