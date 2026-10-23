Feature: Admin activity events
  Each kind of event shows on the activity timeline with its own name, sub-line and link.

  Background:
    Given I am signed in to the admin

  Scenario: The activity shows a completed task on the day it was finished
    Given the activity data holds:
      """
      insert into tasks (title, list, position, status, completed_at)
        values ('clear the gutters', 'next', 1, 'done', current_date - 1 + time '16:00');
      """
    When I open the activity
    Then the activity rows on yesterday read "clear the gutters"
    And the activity sub-lines read "done by me"

  Scenario: The activity leaves out canceled and open tasks and counts only the done ones
    Given the activity data holds:
      """
      insert into tasks (title, list, position, status, completed_at) values
        ('done one', 'next', 1, 'done', current_date + time '16:00'),
        ('canceled one', 'next', 2, 'canceled', current_date + time '16:00');
      insert into tasks (title, list, position) values ('still open', 'next', 3);
      """
    When I open the activity
    Then the activity rows read "done one"
    And the activity counts 1 for "Tasks"

  Scenario: The activity says who did each task
    Given the activity data holds:
      """
      insert into tasks (title, list, position, status, completed_at) values
        ('Mine', 'next', 1, 'done', current_date + time '16:00'),
        ('Shared', 'next', 2, 'done', current_date + time '15:00'),
        ('Sonnet''s', 'next', 3, 'done', current_date + time '14:00');
      insert into task_contributors (task_id, kind, agent, model) values
        (2, 'owner', null, null),
        (2, 'agent', 'claude-code', 'claude-opus-5-5'),
        (3, 'agent', 'claude-code', 'claude-sonnet-5');
      insert into journal_entries (entry_date, entry_time, body, body_html)
        values (current_date, '09:00', 'A note', '<p>A note</p>');
      """
    When I open the activity with "types[task]=1"
    Then the activity sub-lines read "done by me | done by me, claude-code on claude-opus-5-5 | done by claude-code on claude-sonnet-5"
    When I open the activity with "q=contributor:owner"
    Then the activity rows read "Mine | Shared"
    When I open the activity with "q=agent:claude-code"
    Then the activity rows read "Shared | Sonnet's"
    When I open the activity with "q=model:claude-sonnet-5"
    Then the activity rows read "Sonnet's"

  Scenario: The activity shows task comments, local and synced, open task or not
    Given the activity data holds:
      """
      insert into tasks (title, list, position) values ('clear the gutters', 'next', 1);
      insert into task_comments (task_id, body, created_at) values
        (1, 'bought a **ladder**', current_date + time '10:00'),
        (1, 'asked the neighbour', current_date - 1 + time '10:00');
      insert into task_comments (task_id, body, created_at, provider, remote_id, url, author)
        values (1, 'from the issue', current_date + time '09:00', 'github', 'IC_1', 'https://github.com/aaronmallen/aaronmallen.me/issues/1#issuecomment-1', 'octocat');
      """
    When I open the activity
    Then the activity rows on today read "bought a ladder | from the issue"
    And the activity rows on yesterday read "asked the neighbour"
    And the activity sub-lines read "on clear the gutters × 3"
    And the activity page has "a.activity-event[href='/admin/tasks/1#task-comment-1'][data-task-open]" reading "bought a ladder"
    And the activity page has ".activity-event-name.prose strong" reading "ladder"

  Scenario: The activity counts the task comments in the range
    Given the activity data holds:
      """
      insert into tasks (title, list, position) values ('clear the gutters', 'next', 1);
      insert into task_comments (task_id, body, created_at) values
        (1, 'one', current_date + time '10:00'),
        (1, 'old', current_date - 30 + time '10:00');
      insert into task_comments (task_id, body, created_at, provider, remote_id, url, author)
        values (1, 'two', current_date + time '10:00', 'github', 'IC_1', 'https://github.com/aaronmallen/aaronmallen.me/issues/1#issuecomment-1', 'octocat');
      """
    When I open the activity
    Then the activity counts 2 for "Comments"

  Scenario: The activity finds a task comment by its task's title and tags
    Given the activity data holds:
      """
      insert into tasks (title, list, position) values ('clear the gutters', 'next', 1), ('paint the fence', 'next', 2);
      insert into tags (name, color, scope) values ('home', 'mk-blue', 'private');
      insert into task_tags (task_id, tag_id) values (1, 1);
      insert into task_comments (task_id, body, created_at) values
        (1, 'bought a ladder', current_date + time '10:00'),
        (2, 'elsewhere', current_date + time '10:00');
      """
    When I open the activity with "q=gutters"
    Then the activity rows read "bought a ladder"
    When I open the activity with "q=tag:home"
    Then the activity rows read "bought a ladder"
    When I open the activity with "q=tag:work"
    Then the activity shows no rows

  Scenario: The activity drops the task comments when their type is unchecked
    Given the activity data holds:
      """
      insert into tasks (title, list, position) values ('clear the gutters', 'next', 1);
      insert into task_comments (task_id, body, created_at) values (1, 'bought a ladder', current_date + time '10:00');
      """
    When I open the activity with "types[comment]=0&types[task]=1"
    Then the activity shows no rows

  Scenario: The activity shows a closed work session on the day it started, named for its task
    Given the activity data holds:
      """
      insert into tasks (title, list, position, status) values ('clear the gutters', 'next', 1, 'in_progress');
      insert into work_sessions (task_id, started_at, ended_at) values
        (1, current_date - 1 + time '09:00', current_date - 1 + time '10:30'),
        (1, current_date - 3 + time '23:00', current_date - 2 + time '01:00');
      """
    When I open the activity
    Then the activity rows on yesterday read "clear the gutters"
    And the activity rows on 3 days ago read "clear the gutters"
    And the activity rows on 2 days ago read ""
    And the activity sub-lines read "worked 1h 30m | worked 2h 00m"
    And the activity page has "a.activity-event[href='/admin/tasks/1#task-session-1'][data-task-open]" reading "clear the gutters"

  Scenario: The activity shows a session on a done task beside the task
    Given the activity data holds:
      """
      insert into tasks (title, list, position, status, completed_at)
        values ('paint the fence', 'next', 1, 'done', current_date + time '16:00');
      insert into work_sessions (task_id, started_at, ended_at)
        values (1, current_date + time '09:00', current_date + time '10:00');
      """
    When I open the activity
    Then the activity sub-lines read "done by me | worked 1h 00m" in any order

  Scenario: The activity leaves out a work session that is still running
    Given the activity data holds:
      """
      insert into tasks (title, list, position, status) values ('clear the gutters', 'next', 1, 'in_progress');
      insert into work_sessions (task_id, started_at) values (1, current_date - 1 + time '09:00');
      """
    When I open the activity
    Then the activity shows no rows

  Scenario: The activity counts, finds and drops work sessions
    Given the activity data holds:
      """
      insert into tasks (title, list, position, status) values
        ('clear the gutters', 'next', 1, 'in_progress'),
        ('paint the fence', 'next', 2, 'in_progress');
      insert into tags (name, color, scope) values ('home', 'mk-blue', 'private');
      insert into task_tags (task_id, tag_id) values (1, 1);
      insert into work_sessions (task_id, started_at, ended_at) values
        (1, current_date + time '09:00', current_date + time '10:30'),
        (1, current_date + time '13:00', current_date + time '14:30'),
        (1, current_date - 30 + time '09:00', current_date - 30 + time '10:30'),
        (2, current_date + time '08:00', current_date + time '09:00');
      """
    When I open the activity
    Then the activity counts 3 for "Work sessions"
    When I open the activity with "q=tag:home"
    Then the activity rows read "clear the gutters × 2"
    When I open the activity with "types[comment]=1&types[session]=0"
    Then the activity shows no rows

  Scenario: The activity leaves a task's moves, tags and status changes out of the timeline
    Given the activity data holds:
      """
      insert into tasks (title, list, position) values ('clear the gutters', 'next', 1);
      insert into task_events (task_id, kind, occurred_at, from_list, to_list) values (1, 'moved', current_date + time '09:00', 'next', 'someday');
      insert into task_events (task_id, kind, occurred_at, tag_name) values
        (1, 'tagged', current_date + time '09:00', 'home'),
        (1, 'untagged', current_date + time '09:00', 'home');
      insert into task_events (task_id, kind, occurred_at, from_status, to_status) values (1, 'status_changed', current_date + time '09:00', 'open', 'in_progress');
      """
    When I open the activity
    Then the activity shows no rows

  Scenario: The activity shows every kind of decision event, each opening its decision
    Given the activity data holds:
      """
      insert into decisions (title, problem) values ('Pick a queue', 'Jobs need a home');
      insert into decision_options (decision_id, title) values (1, 'Sidekiq');
      insert into decision_events (decision_id, kind, option_id, note, reason, created_at) values
        (1, 'opened', null, null, null, current_date + time '10:00'),
        (1, 'option_added', 1, null, null, current_date + time '10:00'),
        (1, 'option_edited', 1, null, null, current_date + time '10:00'),
        (1, 'edited', null, 'Fixed a typo', null, current_date + time '10:00'),
        (1, 'resolved', 1, null, 'It already runs', current_date + time '10:00'),
        (1, 'dropped', null, null, 'Not worth it', current_date + time '10:00'),
        (1, 'reopened', null, null, 'Jobs pile up again', current_date + time '10:00');
      """
    When I open the activity
    Then the activity page has 7 of "a.activity-event[href='/admin/decisions/1'] .activity-event-name"
    And the activity rows read "Pick a queue × 7"
    And the activity sub-lines read "opened | option added · Sidekiq | option edited · Sidekiq | edited · Fixed a typo | resolved · It already runs | dropped · Not worth it | reopened · Jobs pile up again" in any order

  Scenario: The activity shows a decision comment's markdown, opening its decision
    Given the activity data holds:
      """
      insert into decisions (title, problem) values ('Pick a queue', 'Jobs need a home');
      insert into decision_comments (decision_id, body, created_at) values (1, 'Ask **ops** first', current_date + time '11:00');
      """
    When I open the activity
    Then the activity page has 1 of "a.activity-event[href='/admin/decisions/1'] .activity-event-name.prose strong"
    And the activity page has ".activity-event-name.prose strong" reading "ops"
    And the activity page has no "a.activity-event[data-task-open]"
    And the activity sub-lines read "on Pick a queue"

  Scenario: The activity counts, finds and drops decisions and their comments
    Given the activity data holds:
      """
      insert into decisions (title, problem) values ('Pick a queue', 'Jobs need a home'), ('Pick a host', 'Servers');
      insert into tags (name, color, scope) values ('infra', 'mk-blue', 'private');
      insert into decision_tags (decision_id, tag_id) values (1, 1);
      insert into decision_events (decision_id, kind, created_at) values
        (1, 'opened', current_date + time '10:00'),
        (2, 'opened', current_date + time '12:00');
      insert into decision_comments (decision_id, body, created_at) values (1, 'Ask ops first', current_date + time '11:00');
      """
    When I open the activity
    Then the activity counts 2 for "Decisions"
    And the activity counts 1 for "Decision comments"
    When I open the activity with "q=tag:infra"
    Then the activity rows read "Pick a queue | Ask ops first" in any order
    When I open the activity with "q=tag:work"
    Then the activity shows no rows
    When I open the activity with "types[decision]=0&types[decision_comment]=1"
    Then the activity rows read "Ask ops first"

  Scenario: The activity shows an opened and a merged row for a merged pull request
    Given the activity data holds:
      """
      insert into pull_requests (repo, number, title, url, ready_at, opened_at, merged_at)
        values ('aaronmallen/blog', 1, 'Add feeds', 'https://github.com/aaronmallen/blog/pull/1', current_date + time '09:00', current_date + time '09:00', current_date + time '10:00');
      """
    When I open the activity
    Then the activity sub-lines read "merged into aaronmallen/blog | opened in aaronmallen/blog"
    And the activity page has 2 of "a.activity-event[href='/admin/pull-requests/1']"
    And the activity page has 2 of "a.activity-event"
    When I open the activity with "types[pull_request_opened]=0&types[pull_request_merged]=1"
    Then the activity sub-lines read "merged into aaronmallen/blog"

  Scenario: The activity shows the rows of open, closed and never ready pull requests
    Given the activity data holds:
      """
      insert into pull_requests (repo, number, title, url, ready_at, opened_at, closed_at) values
        ('aaronmallen/blog', 1, 'Add feeds', 'https://github.com/aaronmallen/blog/pull/1', current_date + time '09:00', current_date + time '09:00', current_date + time '10:00'),
        ('aaronmallen/blog', 2, 'Add tags', 'https://github.com/aaronmallen/blog/pull/2', current_date + time '07:00', current_date + time '07:00', null),
        ('aaronmallen/blog', 3, 'Add maps', 'https://github.com/aaronmallen/blog/pull/3', null, current_date + time '06:00', current_date + time '10:00');
      """
    When I open the activity
    Then the activity sub-lines read "closed in aaronmallen/blog | opened in aaronmallen/blog | opened in aaronmallen/blog"
    And the activity rows read "Add feeds | Add feeds | Add tags"

  Scenario: The activity counts each kind of pull request row apart
    Given the activity data holds:
      """
      insert into pull_requests (repo, number, title, url, ready_at, opened_at, merged_at, closed_at) values
        ('aaronmallen/blog', 1, 'Add feeds', 'https://github.com/aaronmallen/blog/pull/1', current_date + time '09:00', current_date + time '09:00', current_date + time '10:00', null),
        ('aaronmallen/blog', 2, 'Add tags', 'https://github.com/aaronmallen/blog/pull/2', current_date + time '09:00', current_date + time '09:00', null, current_date + time '11:00');
      """
    When I open the activity
    Then the activity counts 2 for "Opened pull requests"
    And the activity counts 1 for "Merged pull requests"
    And the activity counts 1 for "Closed pull requests"

  Scenario: The activity lists workouts and gives a day its health figures
    Given the activity data holds:
      """
      insert into workouts (google_id, kind, started_at, minutes, device)
        values ('w1', 'STRENGTH_TRAINING', current_date + time '07:00', 65, 'Pixel Watch 3');
      insert into commits (sha, repo, branch, message, commit_date, commit_time)
        values ('a1', 'aaronmallen/aaronmallen.me', 'main', 'add the view', current_date - 1, '09:00');
      insert into health_days (day, minutes_asleep, hrv, resting_heart_rate, steps)
        values (current_date, 425, 47.6, 54, 8421);
      """
    When I open the activity
    Then the activity rows on today read "Strength Training"
    And the first activity sub-line reads "1h 05m · Pixel Watch 3"
    And the activity counts 1 for "Workouts"
    And the activity health on today reads "7h 05m asleep | hrv 48 · rhr 54 | 8,421 steps"
    And the activity page has no ".activity-day:has(time[datetime='{today-1}']) .activity-health"

  Scenario: The activity opens each kind of event on its own page
    Given the activity data holds:
      """
      insert into posts (title, slug, status, published_at, webmentions_enabled, body_html, read_time, word_count)
        values ('Hello', 'hello', 'published', current_date + time '09:00', true, '', 1, 1);
      insert into journal_entries (entry_date, entry_time, body, body_html)
        values (current_date - 1, '09:00', 'walked the dog', '<p>walked the dog</p>');
      insert into social_posts (targets, status, posted_at) values ('{mastodon}', 'posted', current_date + time '12:00');
      insert into social_post_parts (social_post_id, position, body) values (1, 1, 'out for a walk');
      insert into tasks (title, list, position, status, completed_at)
        values ('clear the gutters', 'next', 1, 'done', current_date + time '16:00');
      insert into webmentions (post_id, source_url, author_name, type, status, received_at)
        values (1, 'https://ada.example/note', 'Ada', 'mention', 'approved', current_date + time '08:00');
      insert into commits (sha, repo, branch, message, commit_date, commit_time)
        values ('a1', 'aaronmallen/aaronmallen.me', 'main', 'add the view' || chr(10) || chr(10) || 'with a body that says more', current_date, '09:30');
      """
    When I open the activity
    Then the activity page has "a.activity-event[href='/admin/posts/1/edit']" reading "Hello"
    And the activity page has "a.activity-event[href='/admin/journal?to={today-1}#day-{today-1}']" reading "walked the dog"
    And the activity page has "a.activity-event[href='/admin/social?filter=posted']"
    And the activity page has "a.activity-event[href='/admin/tasks/1'][data-task-open]" reading "clear the gutters"
    And the activity page has "a.activity-event[href='/admin/webmentions']" reading "Ada"
    And the activity page has "a.activity-event[href='/admin/commits/1']" reading "add the view"
    And the activity rows include "add the view"
    And the activity page has no ".activity-event-name" reading "with a body"

  Scenario: The activity opens a journal entry past the journal's first page on the page that holds it
    Given the activity data holds:
      """
      insert into journal_entries (entry_date, entry_time, body, body_html)
        select current_date - 1, '09:00', 'filler ' || n, '<p>filler</p>' from generate_series(1, 100) as n;
      insert into journal_entries (entry_date, entry_time, body, body_html)
        values (current_date - 3, '09:00', 'walked the dog', '<p>walked the dog</p>');
      """
    When I open the activity with "day={today-3}"
    And I follow the activity row "walked the dog"
    Then the page the activity row opened shows "walked the dog"

  Scenario: The activity counts a post's views
    Given the activity data holds:
      """
      insert into posts (title, slug, status, published_at, webmentions_enabled, body_html, read_time, word_count)
        values ('Hello', 'hello', 'published', current_date + time '09:00', false, '', 1, 1);
      insert into analytics_rollups (day) values (current_date);
      insert into analytics_rollup_paths (day, path, views, visitors, bounces) values (current_date, '/writing/hello', 12, 8, 2);
      """
    When I open the activity
    Then the activity sub-lines read "/writing/hello · published · 12 views"

  Scenario: The activity counts a post's one view
    Given the activity data holds:
      """
      insert into posts (title, slug, status, published_at, webmentions_enabled, body_html, read_time, word_count)
        values ('Hello', 'hello', 'published', current_date + time '09:00', false, '', 1, 1);
      insert into analytics_rollups (day) values (current_date);
      insert into analytics_rollup_paths (day, path, views, visitors, bounces) values (current_date, '/writing/hello', 1, 1, 1);
      """
    When I open the activity
    Then the activity sub-lines read "/writing/hello · published · 1 view"

  Scenario: The activity adds today's views to the rolled up days, counting each rolled day once
    Given the activity data holds:
      """
      insert into posts (title, slug, status, published_at, webmentions_enabled, body_html, read_time, word_count)
        values ('Hello', 'hello', 'published', current_date + time '09:00', false, '', 1, 1);
      insert into analytics_rollups (day) values (current_date - 1);
      insert into analytics_rollup_paths (day, path, views, visitors, bounces) values (current_date - 1, '/writing/hello', 12, 8, 2);
      insert into analytics_events (path, visitor_hash, address_hash, occurred_at)
        select '/writing/hello', repeat(to_hex(n), 64 / length(to_hex(n))), repeat(to_hex(n), 64 / length(to_hex(n))), at
        from (values (1, current_date - 1 + time '00:01'), (2, now()), (3, now())) as seen (n, at);
      """
    When I open the activity
    Then the activity sub-lines read "/writing/hello · published · 14 views"

  Scenario: The activity names the post a webmention is on, with its excerpt or without
    Given the activity data holds:
      """
      insert into posts (title, slug, status, published_at, webmentions_enabled, body_html, read_time, word_count)
        values ('Hello', 'hello', 'published', current_date - 1 + time '07:00', true, '', 1, 1);
      insert into webmentions (post_id, source_url, author_name, type, status, excerpt, received_at) values
        (1, 'https://ada.example/note', 'Ada', 'mention', 'approved', 'nice work', current_date + time '08:00'),
        (1, 'https://bea.example/note', 'Bea', 'mention', 'approved', null, current_date + time '07:00');
      """
    When I open the activity with "types[webmention]=1"
    Then the activity sub-lines read "on /writing/hello · nice work | on /writing/hello"

  Scenario: The activity shows only the approved webmentions
    Given the activity data holds:
      """
      insert into posts (title, slug, status, published_at, webmentions_enabled, body_html, read_time, word_count)
        values ('Hello', 'hello', 'published', current_date - 1 + time '07:00', true, '', 1, 1);
      insert into webmentions (post_id, source_url, author_name, type, status, excerpt, received_at) values
        (1, 'https://ada.example/note', 'Ada', 'mention', 'approved', 'Ada says hi', current_date + time '08:00'),
        (1, 'https://pending.example/note', 'Pending', 'mention', 'pending', 'Pending says hi', current_date + time '08:00'),
        (1, 'https://buy.example/note', 'Buy now', 'mention', 'spam', 'Buy now says hi', current_date + time '08:00'),
        (1, 'https://ignored.example/note', 'Ignored', 'mention', 'ignored', 'Ignored says hi', current_date + time '08:00');
      """
    When I open the activity with "types[webmention]=1"
    Then the activity rows read "Ada"
    When I open the activity
    Then the activity counts 1 for "Webmentions"
    When I open the activity with "q=pending says"
    Then the activity shows no rows
    When I open the activity with "q=buy now"
    Then the activity shows no rows
    When I open the activity with "q=ignored says"
    Then the activity shows no rows

  Scenario: The activity shows a social post's photos in part and position order with their alt text
    Given the activity data holds:
      """
      insert into photos (key, width, height, byte_size) values
        ('00000000000000000000000000000001.jpg', 640, 480, 1024),
        ('00000000000000000000000000000002.jpg', 640, 480, 1024),
        ('00000000000000000000000000000003.jpg', 640, 480, 1024);
      insert into social_posts (targets, status, posted_at) values ('{mastodon}', 'posted', current_date + time '12:00');
      insert into social_post_parts (social_post_id, position, body) values (1, 1, 'one'), (1, 2, 'two');
      insert into social_post_photos (social_post_part_id, position, photo_key, alt_text) values
        (2, 1, '00000000000000000000000000000003.jpg', 'A bird'),
        (1, 2, '00000000000000000000000000000001.jpg', 'A cat'),
        (1, 1, '00000000000000000000000000000002.jpg', 'A dog');
      """
    When I open the activity
    Then the activity photos read "/media/00000000000000000000000000000002.jpg A dog | /media/00000000000000000000000000000001.jpg A cat | /media/00000000000000000000000000000003.jpg A bird"

  Scenario: The activity shows no photos for a social post without any or on other kinds
    Given the activity data holds:
      """
      insert into social_posts (targets, status, posted_at) values ('{mastodon}', 'posted', current_date + time '12:00');
      insert into social_post_parts (social_post_id, position, body) values (1, 1, 'one'), (1, 2, 'two');
      insert into journal_entries (entry_date, entry_time, body, body_html)
        values (current_date, '09:00', 'walked the dog', '<p>walked the dog</p>');
      """
    When I open the activity
    Then the activity rows read "one | walked the dog"
    And the activity page has no ".activity-event .sq-photos"

  Scenario: The activity leaves out what has yet to happen
    Given the activity data holds:
      """
      insert into posts (title, slug, status, published_at, webmentions_enabled, body_html, read_time, word_count) values
        ('Half done', 'half-done', 'draft', null, false, '', 1, 1),
        ('Soon', 'soon', 'scheduled', now() + interval '1 day', false, '', 1, 1);
      insert into social_posts (targets, status, posted_at) values
        ('{mastodon}', 'draft', null),
        ('{mastodon}', 'scheduled', now() + interval '1 day');
      insert into social_post_parts (social_post_id, position, body) values (1, 1, 'draft note'), (2, 1, 'scheduled note');
      """
    When I open the activity
    Then the activity shows no rows
    When I open the activity with "to={today+7}"
    Then the activity shows no rows

  Scenario: The activity reads a post's day in Chicago
    Given the activity data holds:
      """
      insert into posts (title, slug, status, published_at, webmentions_enabled, body_html, read_time, word_count) values
        ('Late', 'late', 'published', current_date - 1 + time '23:59', false, '', 1, 1),
        ('Early', 'early', 'published', (current_date + time '00:30') at time zone 'UTC', false, '', 1, 1);
      """
    When I open the activity
    Then the activity rows on yesterday read "Late | Early"
