Feature: Admin activity in the browser
  The activity filters redraw the timeline in place and keep the address in step, and a task's rows open the task
  panel over the page.

  Background:
    Given I am signed in to the admin

  Scenario: The activity opens a comment's task in the panel over Activity
    Given the activity data holds:
      """
      insert into tasks (title, list, position, status) values ('clear the gutters', 'next', 1, 'in_progress');
      insert into task_comments (task_id, body, created_at)
        select 1, 'note ' || n || chr(10) || chr(10) || repeat('Long line. ', 40), current_date + time '08:00' + n * interval '1 minute'
        from generate_series(0, 11) as n;
      """
    When I open the activity
    And I open the activity row "note 11" in the task panel
    Then the activity address matches "/admin/activity$"
    And the task panel over the activity shows the task "clear the gutters" with "#task-comment-12" in view

  Scenario: Unchecking an activity type redraws the timeline in place and keeps it in the address
    Given the activity data holds:
      """
      insert into posts (title, slug, status, published_at, webmentions_enabled, body_html, read_time, word_count)
        values ('A published post', 'a-published-post', 'published', current_date + time '09:00', false, '', 1, 1);
      insert into commits (sha, repo, branch, message, commit_date, commit_time)
        values ('a1', 'aaronmallen/aaronmallen.me', 'main', 'add the view', current_date, '09:00');
      """
    When I visit "/admin"
    And I open the activity
    And I mark the activity page
    And I toggle the activity type "Blog posts"
    Then the activity rows read "add the view"
    And the activity address matches "/admin/activity\?.*types%5Bpost%5D=0"
    And the activity page stayed
    When I reload the activity
    Then the activity page has "input[type='checkbox'][name='types[post]']:not(:checked)"
    And the activity page has 1 of ".activity-event"

  Scenario: Unchecking an activity type saves the filtered query in a view
    Given the activity data holds:
      """
      insert into posts (title, slug, status, published_at, webmentions_enabled, body_html, read_time, word_count)
        values ('A published post', 'a-published-post', 'published', current_date + time '09:00', false, '', 1, 1);
      insert into commits (sha, repo, branch, message, commit_date, commit_time)
        values ('a1', 'aaronmallen/aaronmallen.me', 'main', 'add the view', current_date, '09:00');
      """
    When I open the activity
    And I toggle the activity type "Blog posts"
    And the activity rows read "add the view"
    And I save the activity filters as the view "No posts"
    Then the activity page has ".saved-view-link[href*='types%5Bpost%5D=0']" reading "No posts"

  Scenario: The activity filters by the text typed in place
    Given the activity data holds:
      """
      insert into commits (sha, repo, branch, message, commit_date, commit_time)
        values ('a1', 'aaronmallen/aaronmallen.me', 'main', 'add the view', current_date, '09:00');
      """
    When I open the activity
    And I mark the activity page
    And I search the activity for "view" in place
    Then the activity address matches "q=view"
    And the activity page stayed

  Scenario: Going back after three activity filters leaves the page
    Given the activity data holds:
      """
      insert into posts (title, slug, status, published_at, webmentions_enabled, body_html, read_time, word_count)
        values ('A published post', 'a-published-post', 'published', current_date + time '09:00', false, '', 1, 1);
      insert into commits (sha, repo, branch, message, commit_date, commit_time)
        values ('a1', 'aaronmallen/aaronmallen.me', 'main', 'add the view', current_date, '09:00');
      """
    When I visit "/admin"
    And I open the activity
    And I toggle the activity type "Blog posts"
    And the activity address matches "post%5D=0"
    And I toggle the activity type "Commits"
    And the activity address matches "commit%5D=0"
    And I toggle the activity type "Blog posts"
    And the activity address matches "post%5D=1"
    And I go back from the activity
    Then the activity address matches "/admin$"

  Scenario Outline: The activity pages have no axe breaches at <path>
    Given the activity data holds:
      """
      insert into commits (sha, repo, branch, message, commit_date, commit_time)
        values ('a1', 'aaronmallen/aaronmallen.me', 'main', 'add the view', current_date, '09:00');
      insert into journal_entries (entry_date, entry_time, body, body_html)
        values (current_date, '09:00', 'walked the dog', '<p>walked the dog</p>');
      """
    When I visit "<path>"
    Then the page has no axe breaches in light or dark

    Examples:
      | path            |
      | /admin/activity |
      | /admin/journal  |
