Feature: Admin activity search
  The Contains box narrows the activity to events whose text matches, and reads tag:, repo:, contributor:, agent:
  and model: terms as filters.

  Background:
    Given I am signed in to the admin

  Scenario: The activity search hint names the terms, and each term keeps what it names
    Given the activity data holds:
      """
      insert into commits (sha, repo, branch, message, commit_date, commit_time) values
        ('a1', 'aaronmallen/one', 'main', 'in one', current_date, '09:00'),
        ('a2', 'aaronmallen/two', 'main', 'in two', current_date, '09:00');
      insert into journal_entries (entry_date, entry_time, body, body_html) values (current_date, '09:00', 'read the docs', '<p>read the docs</p>');
      insert into tags (name, color, scope) values ('ruby', 'mk-blue', 'private');
      insert into journal_entry_tags (journal_entry_id, tag_id) values (1, 1);
      insert into tasks (title, list, position, status, completed_at) values ('Agent''s', 'next', 1, 'done', current_date + time '14:00');
      insert into task_contributors (task_id, kind, agent, model) values (1, 'agent', 'claude-code', 'claude-opus-5-5');
      """
    When I open the activity
    Then the activity page has "#activity-q-hint" reading "Add tag:ruby for one tag, repo:owner/name for one repo's commits and pull requests, or contributor:owner, agent:claude-code or model:claude-opus-5-5 for tasks by who did them."
    When I open the activity with "q=tag:ruby"
    Then the activity rows read "read the docs"
    When I open the activity with "q=repo:aaronmallen/one"
    Then the activity rows include "in one"
    And the activity rows leave out "in two"
    When I open the activity with "q=contributor:agent"
    Then the activity rows read "Agent's"
    When I open the activity with "q=agent:claude-code"
    Then the activity rows read "Agent's"
    When I open the activity with "q=model:claude-opus-5-5"
    Then the activity rows read "Agent's"

  Scenario: The activity search by repo keeps that repo's commits and leaves the other types alone
    Given the activity data holds:
      """
      insert into commits (sha, repo, branch, message, commit_date, commit_time) values
        ('a1', 'aaronmallen/one', 'main', 'in one', current_date, '09:00'),
        ('a2', 'aaronmallen/two', 'main', 'in two', current_date, '09:00');
      insert into journal_entries (entry_date, entry_time, body, body_html) values (current_date, '08:00', 'walked the dog', '<p>walked the dog</p>');
      """
    When I open the activity with "q=repo:aaronmallen/one"
    Then the activity rows read "in one | walked the dog"
    And the activity counts 1 for "Commits"
    And the activity counts 1 for "Journal"
    And the activity search box holds "repo:aaronmallen/one"

  Scenario: The activity search by repo keeps the commits of every repo named
    Given the activity data holds:
      """
      insert into commits (sha, repo, branch, message, commit_date, commit_time) values
        ('a1', 'aaronmallen/one', 'main', 'in one', current_date, '09:00'),
        ('a2', 'aaronmallen/two', 'main', 'in two', current_date, '09:00');
      insert into journal_entries (entry_date, entry_time, body, body_html) values (current_date, '08:00', 'walked the dog', '<p>walked the dog</p>');
      """
    When I open the activity with "q=repo:aaronmallen/one repo:aaronmallen/two"
    Then the activity rows include "in one | in two | walked the dog"

  Scenario: The activity search by repo drops the pull requests of every other repo
    Given the activity data holds:
      """
      insert into pull_requests (repo, number, title, url, ready_at, opened_at) values
        ('aaronmallen/one', 1, 'pr in one', 'https://github.com/aaronmallen/one/pull/1', now(), now()),
        ('aaronmallen/two', 1, 'pr in two', 'https://github.com/aaronmallen/two/pull/1', now(), now());
      """
    When I open the activity with "q=repo:aaronmallen/one"
    Then the activity rows read "pr in one"

  Scenario: The activity search by repo ignores case and the owner
    Given the activity data holds:
      """
      insert into commits (sha, repo, branch, message, commit_date, commit_time)
        values ('a1', 'aaronmallen/one', 'main', 'in one', current_date, '09:00');
      """
    When I open the activity with "q=repo:AaronMallen/One"
    Then the activity rows read "in one"
    When I open the activity with "q=repo:one"
    Then the activity rows read "in one"
    When I open the activity with "q=repo:aaronmallen"
    Then the activity shows no rows

  Scenario: The activity search by repo shows no commit for a repo that has none, and no error
    Given the activity data holds:
      """
      insert into commits (sha, repo, branch, message, commit_date, commit_time)
        values ('a1', 'aaronmallen/one', 'main', 'in one', current_date, '09:00');
      insert into journal_entries (entry_date, entry_time, body, body_html) values (current_date, '08:00', 'walked the dog', '<p>walked the dog</p>');
      """
    When I open the activity with "q=repo:aaronmallen/gone"
    Then the activity rows read "walked the dog"

  Scenario: The activity search by repo searches the words beside the repo as text
    Given the activity data holds:
      """
      insert into commits (sha, repo, branch, message, commit_date, commit_time) values
        ('a1', 'aaronmallen/one', 'main', 'in one', current_date, '09:00'),
        ('a2', 'aaronmallen/two', 'main', 'in two', current_date, '09:00');
      insert into journal_entries (entry_date, entry_time, body, body_html) values (current_date, '08:00', 'walked the dog', '<p>walked the dog</p>');
      """
    When I open the activity with "q=repo:aaronmallen/one in"
    Then the activity rows read "in one"

  Scenario: The activity contains box matches names and sub-lines, ignoring case, and narrows the counts
    Given the activity data holds:
      """
      insert into commits (sha, repo, branch, message, commit_date, commit_time) values
        ('a1', 'aaronmallen/aaronmallen.me', 'main', 'add the Activities view', current_date, '09:00'),
        ('a2', 'aaronmallen/aaronmallen.me', 'main', 'nothing to see', current_date, '09:00');
      insert into posts (title, slug, status, published_at, webmentions_enabled, body_html, read_time, word_count)
        values ('Hello', 'on-views', 'published', current_date + time '09:00', false, '', 1, 1);
      """
    When I open the activity with "q=ACTIVITIES"
    Then the activity rows read "add the Activities view"
    And the activity search box holds "ACTIVITIES"
    And the activity counts 1 for "Commits"
    When I open the activity with "q=On-Views"
    Then the activity rows read "Hello"

  Scenario: The activity contains box matches a commit body the row never shows
    Given the activity data holds:
      """
      insert into commits (sha, repo, branch, message, commit_date, commit_time) values
        ('a1', 'aaronmallen/aaronmallen.me', 'main', 'tidy the imports' || chr(10) || chr(10) || 'the lockfile drifted', current_date, '09:00'),
        ('a2', 'aaronmallen/aaronmallen.me', 'main', 'nothing to see', current_date, '09:00');
      """
    When I open the activity with "q=lockfile"
    Then the activity rows read "tidy the imports"

  Scenario: The activity contains box matches journal text past what the row reads
    Given the activity data holds:
      """
      insert into journal_entries (entry_date, entry_time, body, body_html)
        values (current_date, '09:00', 'walked ' || repeat('the dog ', 200) || 'then rested', '<p>walked</p>');
      insert into commits (sha, repo, branch, message, commit_date, commit_time)
        values ('a1', 'aaronmallen/aaronmallen.me', 'main', 'nothing to see', current_date, '09:00');
      """
    When I open the activity with "q=rested"
    Then the activity shows 1 rows
    And the first activity row starts with "walked the dog"

  Scenario: The activity contains box takes a percent sign as text, not a wildcard
    Given the activity data holds:
      """
      insert into commits (sha, repo, branch, message, commit_date, commit_time) values
        ('a1', 'aaronmallen/aaronmallen.me', 'main', '100% done', current_date, '09:00'),
        ('a2', 'aaronmallen/aaronmallen.me', 'main', 'nothing to see', current_date, '09:00');
      """
    When I open the activity with "q=0%25%20d"
    Then the activity rows read "100% done"

  Scenario: The activity search by tag keeps the entries carrying the tag and nothing else
    Given the activity data holds:
      """
      insert into journal_entries (entry_date, entry_time, body, body_html) values
        (current_date, '09:00', 'walked the dog', '<p>walked the dog</p>'),
        (current_date, '09:00', 'read the docs', '<p>read the docs</p>');
      insert into tags (name, color, scope) values ('health', 'mk-blue', 'private'), ('ruby', 'mk-blue', 'private');
      insert into journal_entry_tags (journal_entry_id, tag_id) values (1, 1), (2, 2);
      insert into commits (sha, repo, branch, message, commit_date, commit_time)
        values ('a1', 'aaronmallen/aaronmallen.me', 'main', 'ruby: add the view', current_date, '09:00');
      """
    When I open the activity with "q=tag:ruby"
    Then the activity rows read "read the docs"
    And the activity counts 1 for "Journal"
    And the activity counts 0 for "Commits"
    And the activity search box holds "tag:ruby"
    When I open the activity with "q=tag:RUBY"
    Then the activity rows read "read the docs"
    When I open the activity with "q=tag:rust"
    Then the activity shows no rows

  Scenario: The activity search by tag asks for both tags when the query names two
    Given the activity data holds:
      """
      insert into journal_entries (entry_date, entry_time, body, body_html) values
        (current_date, '09:00', 'read the docs', '<p>read the docs</p>'),
        (current_date, '09:00', 'wrote the post', '<p>wrote the post</p>');
      insert into tags (name, color, scope) values ('ruby', 'mk-blue', 'private'), ('writing', 'mk-blue', 'private');
      insert into journal_entry_tags (journal_entry_id, tag_id) values (1, 1), (2, 1), (2, 2);
      """
    When I open the activity with "q=tag:ruby tag:writing"
    Then the activity rows read "wrote the post"

  Scenario: The activity search by tag searches the words beside the tag as text
    Given the activity data holds:
      """
      insert into journal_entries (entry_date, entry_time, body, body_html) values
        (current_date, '09:00', 'read the docs', '<p>read the docs</p>'),
        (current_date, '09:00', 'read the news', '<p>read the news</p>');
      insert into tags (name, color, scope) values ('ruby', 'mk-blue', 'private');
      insert into journal_entry_tags (journal_entry_id, tag_id) values (1, 1), (2, 1);
      """
    When I open the activity with "q=tag:ruby docs"
    Then the activity rows read "read the docs"

  Scenario: The activity search by tag finds and counts the completed tasks carrying the tag
    Given the activity data holds:
      """
      insert into journal_entries (entry_date, entry_time, body, body_html) values (current_date, '09:00', 'read the docs', '<p>read the docs</p>');
      insert into tags (name, color, scope) values ('ruby', 'mk-blue', 'private'), ('home', 'mk-blue', 'private');
      insert into journal_entry_tags (journal_entry_id, tag_id) values (1, 1);
      insert into tasks (title, list, position, status, completed_at) values
        ('clear the gutters', 'next', 1, 'done', current_date + time '16:00'),
        ('paint the fence', 'next', 2, 'done', current_date + time '16:00');
      insert into task_tags (task_id, tag_id) values (1, 1), (2, 2);
      """
    When I open the activity with "q=tag:ruby"
    Then the activity rows read "clear the gutters | read the docs" in any order
    And the activity counts 1 for "Tasks"
