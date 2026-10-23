Feature: Admin menus for the other rows with actions
  Comments, work sessions, sprints, commits, task rules, tokens, clients, services and the attention card carry a
  right-click menu too. Each holds the actions its row takes, asks before it deletes, and lands back on the page it
  opened on with the toast that action shows.

  Background:
    Given I am signed in to the admin

  Scenario Outline: A row menu answers 404 at <path>
    Then visiting "<path>" answers 404

    Examples:
      | path                                           |
      | /admin/tasks/0/comments/0/menu                 |
      | /admin/tasks/0/sessions/0/menu                 |
      | /admin/decisions/0/comments/0/menu             |
      | /admin/tasks/sprints/0/menu                    |
      | /admin/commits/0/menu                          |
      | /admin/tasks/rules/0/menu                      |
      | /admin/tokens/0/menu                           |
      | /admin/clients/0/menu                          |
      | /admin/services/nothing/menu                   |
      | /admin/attention/menu?kind=carried&record_id=0 |
      | /admin/attention/dead-jobs                     |
      | /admin/attention/dead-jobs/abc123/menu         |

  Scenario: A task comment's menu holds every action a comment takes, opens its edit form and asks before it deletes
    Given the database runs:
      """
      INSERT INTO tasks (title, list, position) VALUES ('Write the brief', 'next', 1);
      INSERT INTO task_comments (task_id, body) VALUES (1, E'Looks right\nmore');
      """
    When I visit "/admin/tasks/1/comments/1/menu?return_to=/admin/tasks/1"
    Then the menu head reads "Looks right"
    And the menu items read "Edit, Copy text, Delete comment"
    And the menu copies "Copy text" as "Looks right\nmore"
    And every menu form returns to "/admin/tasks/1"
    And the admin markup holds "a[data-dialog-open='task-comment-1'][href='/admin/tasks/1#task-comment-1']:has-text('Edit')"
    And the admin markup holds "form[action='/admin/tasks/1/comments/1/delete'] button[data-confirm-inline='Click again to delete']"

  Scenario: Deleting a task comment from its menu lands back on the page it opened on with its toast
    Given the menu screens hold "a task comment"
    When I post the form to the admin "/admin/tasks/1/comments/1/delete" with:
      | return_to | /admin/activity |
    Then the admin post sends me to "/admin/activity"
    When I follow the admin post
    Then the admin toast says "Comment deleted"

  Scenario: A synced comment's menu offers only the source and a copy
    Given the database runs:
      """
      INSERT INTO tasks (title, list, position) VALUES ('Write the brief', 'next', 1);
      INSERT INTO task_comments (task_id, body, provider, remote_id, author, url)
      VALUES (1, 'From GitHub', 'github', 'IC_1', 'octocat', 'https://github.com/aaronmallen/aaronmallen.me/issues/1#issuecomment-1');
      """
    When I visit "/admin/tasks/1/comments/1/menu"
    Then the menu items read "View on source, Copy text"

  Scenario: A comment menu answers 404 for a comment on another task
    Given the database runs:
      """
      INSERT INTO tasks (title, list, position) VALUES ('One', 'next', 1), ('Two', 'next', 2);
      INSERT INTO task_comments (task_id, body) VALUES (1, 'On one');
      """
    Then visiting "/admin/tasks/2/comments/1/menu" answers 404

  Scenario: A comment menu answers 404 for a session asked for as a comment
    Given the menu screens hold "a work session"
    Then visiting "/admin/tasks/1/comments/1/menu" answers 404

  Scenario: A session menu answers 404 for a comment asked for as a session
    Given the menu screens hold "a task comment"
    Then visiting "/admin/tasks/1/sessions/1/menu" answers 404

  Scenario: A comment menu answers 404 for a comment on another decision
    Given the database runs:
      """
      INSERT INTO decisions (title, problem) VALUES ('One', 'It came up'), ('Two', 'It came up');
      INSERT INTO decision_comments (decision_id, body) VALUES (1, 'On one');
      """
    Then visiting "/admin/decisions/2/comments/1/menu" answers 404

  Scenario: A decision comment's menu holds every action a comment takes
    Given the menu screens hold "a decision comment"
    When I visit "/admin/decisions/1/comments/1/menu"
    Then the menu items read "Edit, Copy text, Delete comment"
    And the admin markup holds "form[action='/admin/decisions/1/comments/1/delete']"

  Scenario: Deleting a decision comment from its menu lands back on the page it opened on with its toast
    Given the menu screens hold "a decision comment"
    When I post the form to the admin "/admin/decisions/1/comments/1/delete" with:
      | return_to | /admin/activity |
    Then the admin post sends me to "/admin/activity"
    When I follow the admin post
    Then the admin toast says "Comment deleted"

  Scenario: A closed work session's menu edits and deletes it
    Given the menu screens hold "a work session"
    When I visit "/admin/tasks/1/sessions/1/menu?return_to=/admin/activity"
    Then the menu items read "Edit, Delete session"
    And the admin markup holds "a[data-dialog-open='task-session-1']"
    And every menu form returns to "/admin/activity"

  Scenario: A running work session's menu only edits it
    Given the database runs:
      """
      INSERT INTO tasks (title, list, position) VALUES ('Write the brief', 'next', 1);
      INSERT INTO work_sessions (task_id, started_at) VALUES (1, now() - interval '1 hour');
      """
    When I visit "/admin/tasks/1/sessions/1/menu"
    Then the menu items read "Edit"

  Scenario: Deleting a work session from its menu lands back on the page it opened on with its toast
    Given the menu screens hold "a work session"
    When I post the form to the admin "/admin/tasks/1/sessions/1/delete" with:
      | return_to | /admin/activity |
    Then the admin post sends me to "/admin/activity"
    When I follow the admin post
    Then the admin toast says "Session deleted"

  Scenario: A sprint's menu opens it on the calendar and drops it on the second click
    Given the database runs:
      """
      INSERT INTO sprints (id, sprint_date) VALUES (90, '2026-10-20') ON CONFLICT DO NOTHING;
      """
    When I visit "/admin/tasks/sprints/90/menu"
    Then the menu head reads "Sprint · Oct 20, 2026"
    And the menu items read "Open on calendar, Drop sprint"
    And the admin markup holds "a[href='/admin/calendar?day=2026-10-20']:has-text('Open on calendar')"
    And the admin markup holds "form[action='/admin/tasks/sprints/90/delete'] button[data-confirm-inline='Click again to drop']"

  Scenario: A commit's menu opens it here and on GitHub and copies its SHA and subject
    Given the database runs:
      """
      INSERT INTO commits (sha, repo, branch, message, commit_date, commit_time)
      VALUES ('9f8e7d6000000000000000000000000000000000', 'aaronmallen/blog', 'main', E'add the view\n\nbody',
              current_date, '09:00');
      """
    When I visit "/admin/commits/1/menu"
    Then the menu items read "Open, View on GitHub, Copy SHA, Copy message"
    And the admin markup holds "a[href='https://github.com/aaronmallen/blog/commit/9f8e7d6000000000000000000000000000000000']:has-text('View on GitHub')"
    And the menu copies "Copy SHA" as "9f8e7d6000000000000000000000000000000000"
    And the menu copies "Copy message" as "add the view"
    And the admin markup holds 2 of "[data-copy]"

  Scenario: A task rule's menu opens its editor and deletes it in place
    Given the menu screens hold "a task rule"
    When I visit "/admin/tasks/rules/1/menu"
    Then the menu items read "Edit, Delete rule"
    And the admin markup holds "a[data-dialog-open='rule-1-edit']"
    And the admin markup holds "form[action='/admin/tasks/rules/1/delete'][data-morph]"

  Scenario: A token's menu revokes it on the second click
    Given the menu screens hold "a token"
    When I visit "/admin/tokens/1/menu"
    Then the menu items read "Revoke"
    And the admin markup holds "form[action='/admin/tokens/1/revoke'] button[data-confirm-inline='Click again to revoke']"

  Scenario: Revoking a token from its menu shows the toast it shows today
    Given the menu screens hold "a token"
    When I post the form to the admin "/admin/tokens/1/revoke"
    And I follow the admin post
    Then the admin toast says "Token revoked · the API refuses it now"

  Scenario: A client's menu opens its sign-ins and revokes it
    Given the menu screens hold "a client"
    When I visit "/admin/clients/1/menu"
    Then the menu head reads "Desk"
    And the menu items read "Sign-ins, Revoke"
    And the admin markup holds "form[action='/admin/clients/1/revoke']"

  Scenario: A service's menu shows its details, tests it in place and disconnects on the second click
    Given the services hold a linear connection labelled "Work"
    When I visit "/admin/services/1/menu"
    Then the menu items include "Details, Disconnect"
    And the admin markup holds "a[href='/admin/settings/services?selected=1#services']:has-text('Details')"
    And the admin markup holds "form[action='/admin/services/1/disconnect'] button[data-confirm-inline='Click again to disconnect']"
    And the admin markup holds "form[action='/admin/services/1/test'][data-morph]"

  Scenario: A carried task's attention menu opens, moves, cancels and snoozes it
    Given the menu screens hold "a carried task"
    When I visit "/admin/attention/menu?kind=carried&record_id=1"
    Then the menu head reads "Carried task"
    And the menu items read "Open, Move to Next, Cancel task, Snooze"
    And the admin markup holds "form[action='/admin/tasks/1/move/next'] input[type=hidden][name=origin][value=today]"
    And the admin markup holds "form[action='/admin/tasks/1/cancel'] button[data-confirm-inline='Click again to cancel']"
    And the admin markup holds "form[action='/admin/attention/snooze'] input[type=hidden][name=record_id][value='1']"

  Scenario: The journal row's attention menu writes and snoozes it
    Given the database runs:
      """
      INSERT INTO journal_entries (entry_date, entry_time, body, body_html)
      VALUES ((now() AT TIME ZONE 'America/Chicago')::date - 3, '09:00', 'Old news', '<p>Old news</p>');
      """
    When I visit "/admin/attention/menu?kind=journal"
    Then the menu items read "Write, Snooze"
    And the admin markup holds "form[action='/admin/attention/snooze']"
    And the admin markup lacks "form[action='/admin/attention/snooze'] input[type=hidden][name=record_id]"

  Scenario: Snoozing an attention row shows the toast it shows today
    Given the menu screens hold "a carried task"
    When I post the form to the admin "/admin/attention/snooze" with:
      | kind      | carried |
      | record_id | 1       |
    And I follow the admin post
    Then the admin toast says "Snoozed for a week"

  Scenario: The task page's comments and sessions carry menus
    Given the menu screens hold "a task comment"
    And the database runs:
      """
      INSERT INTO work_sessions (task_id, started_at, ended_at) VALUES (1, now() - interval '1 hour', now());
      """
    When I visit "/admin/tasks/1"
    Then the admin markup holds "[data-menu='/admin/tasks/1/comments/1/menu']"
    And the admin markup holds "[data-menu='/admin/tasks/1/sessions/1/menu']"

  Scenario: A token carries a menu
    Given the menu screens hold "a token"
    When I visit "/admin/settings/services"
    Then the admin markup holds "[data-menu='/admin/tokens/1/menu']"

  Scenario: A task rule carries a menu
    Given the menu screens hold "a task rule"
    When I visit "/admin/settings/tagging"
    Then the admin markup holds "[data-menu='/admin/tasks/rules/1/menu']"

  Scenario: An upcoming sprint carries a menu
    Given the menu screens hold "a sprint in two days"
    When I visit "/admin/tasks?filter=upcoming"
    Then the admin markup holds "[data-menu='/admin/tasks/sprints/90/menu']"

  Scenario: The Today attention card and commits carry menus
    Given the menu screens hold "a carried task"
    And the menu screens hold "a commit today"
    When I visit "/admin"
    Then the admin markup holds "[data-menu='/admin/attention/menu?kind=carried&record_id=1']"
    And the admin markup holds "[data-menu='/admin/commits/1/menu']"

  Scenario: Each record on the activity timeline carries its menu
    Given the menu screens hold "a commit today"
    And the menu screens hold "a journal entry"
    When I visit "/admin/activity"
    Then the admin markup holds "[data-menu='/admin/commits/1/menu']"
    And the admin markup holds "[data-menu='/admin/journal/1/menu']"

  Scenario: A social post on the calendar day carries its menu
    Given the database runs:
      """
      INSERT INTO social_posts (targets, status, posted_at)
      VALUES ('{mastodon,bluesky}', 'scheduled',
              ((now() AT TIME ZONE 'America/Chicago')::date + 1)::timestamp AT TIME ZONE 'America/Chicago');
      INSERT INTO social_post_parts (social_post_id, position, body) VALUES (1, 1, 'Out tomorrow.');
      """
    When I visit the admin calendar 1 day from today
    Then the admin markup holds "[data-menu='/admin/social/1/menu']"

  Scenario Outline: The screens with these menus pass axe at <path>
    Given the menu screens hold "<seed>"
    When I visit "<path>"
    Then the page has no axe breaches in light or dark

    Examples:
      | seed           | path                     |
      | a task comment | /admin/tasks/1           |
      | a token        | /admin/settings/services |
      | a task rule    | /admin/settings/tagging  |
      | a carried task | /admin                   |
      | a commit today | /admin/activity          |
