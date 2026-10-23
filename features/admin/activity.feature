Feature: Admin activity
  The activity page lays every kind of event out on one timeline, a day at a time, with filters for the range,
  the types and the text.

  Background:
    Given I am signed in to the admin

  Scenario: The empty activity page lays out its heading, filters and empty state
    When I open the activity
    Then the activity page has ".screen-tab[aria-current='page']" reading "activity"
    And the activity page has "#command-palette-activity i.fa-timeline"
    And the activity page has ".page-head h1" reading "Activity"
    And the activity page has ".activity-bar + .card"
    And the activity page has 14 of ".activity-types[role='group'][aria-label='Include'] label.activity-type"
    And the activity page has "#activity-q[aria-describedby='activity-q-hint']"
    And the activity page has "p#activity-q-hint"
    And the activity names the range from 6 days ago to today
    And the activity page has ".page-head-sub" reading "0 events across 0 days"
    And the activity page has ".empty" reading "Nothing in this range with these filters"
    And the activity page has 14 of ".activity-type input[type='checkbox'][checked]"
    And the activity page has "form[method='get'][action='/admin/activity'][data-autosubmit]"

  Scenario: The activity timeline groups days and orders events newest first
    Given the activity data holds:
      """
      insert into posts (title, slug, status, published_at, webmentions_enabled, body_html, read_time, word_count)
        values ('Hello', 'hello', 'published', current_date + time '09:00', false, '', 1, 1);
      insert into journal_entries (entry_date, entry_time, body, body_html)
        values (current_date - 1, '21:15', 'walked the dog', '<p>walked the dog</p>');
      insert into commits (sha, repo, branch, message, commit_date, commit_time)
        values ('a1', 'aaronmallen/aaronmallen.me', 'main', 'add the view', current_date, '08:00');
      """
    When I open the activity
    Then the activity days read "today | yesterday"
    And the activity rows on today read "Hello | add the view"
    And the activity rows on yesterday read "walked the dog"
    And the activity page has ".day-note" reading "Today · 2"
    And the activity page has ".day-note" reading "Yesterday · 1"
    And the activity page has 2 of ".activity-bar + .card .day-head.sunk"
    And the activity page has ".activity-event-time" reading "08:00"
    And the activity page has ".page-head-sub" reading "3 events across 2 days"
    And the activity page has ".activity-event-name.prose" reading "walked the dog"
    And the activity page has no ".activity-event-name.prose" reading "add the view"

  Scenario: The activity names a commit by its repo, short sha and lines
    Given the activity data holds:
      """
      insert into commits (sha, repo, branch, message, commit_date, commit_time, additions, deletions)
        values ('9f8e7d6000000000000000000000000000000000', 'aaronmallen/blog', 'main', 'add the view', current_date - 1, '09:00', 3, 1);
      """
    When I open the activity
    Then the activity sub-lines read "aaronmallen/blog · 9f8e7d6 · +3/−1"

  Scenario: The activity heads a day older than yesterday with how long ago it was
    Given the activity data holds:
      """
      insert into commits (sha, repo, branch, message, commit_date, commit_time)
        values ('a1', 'aaronmallen/aaronmallen.me', 'main', 'add the view', current_date - 3, '09:00');
      """
    When I open the activity
    Then the activity page has ".day-note" reading "3 days ago · 1"

  Scenario: The activity range holds the last 7 days by default
    Given the activity data holds:
      """
      insert into commits (sha, repo, branch, message, commit_date, commit_time) values
        ('a1', 'aaronmallen/aaronmallen.me', 'main', 'older', current_date - 20, '09:00'),
        ('a2', 'aaronmallen/aaronmallen.me', 'main', 'newer', current_date, '09:00');
      """
    When I open the activity
    Then the activity rows read "newer"
    And the activity page has "#activity-from[max='{today}']"
    And the activity page has "#activity-to[min='{today-6}']"
    And the activity page has no "#activity-from[min]"

  Scenario: The activity range reaches back to a From that is given
    Given the activity data holds:
      """
      insert into commits (sha, repo, branch, message, commit_date, commit_time) values
        ('a1', 'aaronmallen/aaronmallen.me', 'main', 'older', current_date - 20, '09:00'),
        ('a2', 'aaronmallen/aaronmallen.me', 'main', 'newer', current_date, '09:00');
      """
    When I open the activity with "from={today-30}&to={today}"
    Then the activity rows read "newer | older"

  Scenario: The activity range pulls a From after To back to To
    When I open the activity with "from={today+5}&to={today}"
    Then the activity page has "#activity-from[value='{today}']"

  Scenario Outline: The activity range falls back to the default From for <from>
    When I open the activity with "from=<from>"
    Then the activity page has "#activity-from[value='{today-6}']"

    Examples:
      | from           |
      | soon           |
      | 99999999-01-01 |
      | -4800-01-01    |

  Scenario Outline: The activity range falls back to today for a To of <to>
    When I open the activity with "to=<to>"
    Then the activity page has "#activity-to[value='{today}']"

    Examples:
      | to             |
      | 99999999-01-01 |
      | -4800-01-01    |

  Scenario: The activity presets mark 7d by default and set the dates through their links
    When I open the activity
    Then the activity page has "nav.seg[aria-label='Range'] a.seg-option.current[aria-current='page']" reading "7d"
    And the activity page has "a.seg-option[href^='/admin/activity?from={today-89}&to={today}']" reading "90d"

  Scenario: The activity presets mark 30d when the dates match it
    When I open the activity with "from={today-29}&to={today}"
    Then the activity page has ".seg-option.current" reading "30d"

  Scenario: The activity presets mark nothing for dates that match no preset
    When I open the activity with "from={today-3}&to={today}"
    Then the activity page has no ".seg-option.current"

  Scenario: The activity presets keep the other filters in their links
    When I open the activity with "q=repo:aaronmallen/one views"
    Then the activity page has ".seg-option[href*='q=repo%3Aaaronmallen%2Fone+views']" reading "30d"

  Scenario: The activity drops and still counts the events of an unchecked type
    Given the activity data holds:
      """
      insert into posts (title, slug, status, published_at, webmentions_enabled, body_html, read_time, word_count)
        values ('Hello', 'hello', 'published', current_date + time '09:00', false, '', 1, 1);
      insert into commits (sha, repo, branch, message, commit_date, commit_time)
        values ('a1', 'aaronmallen/aaronmallen.me', 'main', 'add the view', current_date, '09:00');
      """
    When I open the activity with "types[commit]=1&types[journal]=1&types[post]=0&types[social]=1&types[task]=1&types[webmention]=1"
    Then the activity rows read "add the view"
    And the activity page has ".activity-type:has(.fa-file-lines) input[type='checkbox']:not([checked])"
    And the activity counts 1 for "Blog posts"

  Scenario: The activity shows nothing when no type is checked
    Given the activity data holds:
      """
      insert into commits (sha, repo, branch, message, commit_date, commit_time)
        values ('a1', 'aaronmallen/aaronmallen.me', 'main', 'add the view', current_date, '09:00');
      """
    When I open the activity with "types[commit]=0&types[journal]=0&types[post]=0&types[social]=0&types[task]=0&types[webmention]=0"
    Then the activity page has ".empty"

  Scenario: The activity counts each checked type and zero for a type with nothing in range
    Given the activity data holds:
      """
      insert into posts (title, slug, status, published_at, webmentions_enabled, body_html, read_time, word_count)
        values ('Hello', 'hello', 'published', current_date + time '09:00', false, '', 1, 1);
      insert into commits (sha, repo, branch, message, commit_date, commit_time)
        values ('a1', 'aaronmallen/aaronmallen.me', 'main', 'add the view', current_date, '09:00');
      """
    When I open the activity
    Then the activity counts 1 for "Commits"
    And the activity counts 0 for "Journal"

  Scenario: The activity leaves out projects, sprints and suggestions
    Given the activity data holds:
      """
      insert into posts (title, slug, status, published_at, webmentions_enabled, body_html, read_time, word_count)
        values ('Hello', 'hello', 'published', current_date + time '09:00', false, '', 1, 1);
      insert into commits (sha, repo, branch, message, commit_date, commit_time)
        values ('a1', 'aaronmallen/aaronmallen.me', 'main', 'add the view', current_date, '09:00');
      insert into projects (name, key, visibility) values ('blog', 'BLOG', 'private');
      insert into sprints (sprint_date) values (current_date);
      """
    When I open the activity
    Then the activity rows read "Hello | add the view" in any order
    And the activity page has no "input[name='types[project]'], input[name='types[sprint]'], input[name='types[suggestion]']"
    And the activity page has "input[type='checkbox'][name='types[post]']:not([role])"
