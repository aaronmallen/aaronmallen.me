Feature: Admin inbox row menus
  Task and webmention rows carry a right-click menu. In the inbox the task menu adds Snooze, and a webmention's menu
  offers every action it can still take and lands back on the page it opened on.

  Background:
    Given I am signed in to the admin

  Scenario: A task row in the inbox carries the task menu from the inbox
    Given the inbox holds:
      | id | kind  | title     |
      | 9  | issue | Triage me |
    When I visit "/admin/inbox"
    Then the inbox screen has "#issue-9[data-menu='/admin/tasks/9/menu?origin=inbox']"

  Scenario: The task menu from the inbox adds Snooze with the quick picks
    Given the inbox holds:
      | id | kind  | title     |
      | 9  | issue | Triage me |
    When I visit "/admin/tasks/9/menu?origin=inbox&return_to=/admin/inbox"
    Then the inbox screen's ".ctx-label" include "Open, Mark seen, Snooze, Tomorrow morning, Next week"
    And the forms "form[action='/admin/inbox/task/9/snooze']" post the quick picks for now

  Scenario: The task menu leaves Snooze out elsewhere
    Given the inbox holds:
      | id | kind  | title     |
      | 9  | issue | Triage me |
    When I visit "/admin/tasks/9/menu?origin=tasks"
    Then the inbox screen's ".ctx-label" leave out "Snooze"

  Scenario: The webmention menu answers 404 for a webmention that is gone
    Then visiting "/admin/webmentions/0/menu" answers 404

  Scenario: A webmention row carries its menu in the inbox and on the webmentions screen
    Given the inbox holds:
      | id | kind       | title |
      | 8  | webmention | Ada   |
    When I visit "/admin/inbox"
    Then the inbox screen has "#webmention-8[data-menu='/admin/webmentions/8/menu']"
    When I visit "/admin/webmentions"
    Then the inbox screen has "#webmention-8[data-menu='/admin/webmentions/8/menu']"

  Scenario: A pending webmention's menu holds every action, opens, copies and posts back by fetch
    Given the inbox holds:
      | id | kind       | title | source                    |
      | 8  | webmention | Ada   | https://example.com/reply |
    When I visit "/admin/webmentions/8/menu?return_to=/admin/webmentions?status=pending"
    Then the inbox screen's ".ctx-label" read "Open source, Approve, Ignore, Mark spam, Snooze, Later today, Tomorrow morning, Next week, Copy source link, Go to post"
    And the inbox screen has "a.ctx-item[href='https://example.com/reply'][target=_blank]"
    And the inbox screen has "[data-copy='https://example.com/reply']"
    And the inbox screen has "a.ctx-item[href='/admin/posts/1/edit']"
    And the inbox screen has no "[data-context-menu] form:not([data-morph])"
    And every "[data-context-menu] form input[name=return_to]" on the inbox screen carries "value" "/admin/webmentions?status=pending"

  Scenario: A moderated webmention's menu leaves out the status it holds and Snooze
    Given the inbox holds:
      | id | kind       | title | state    |
      | 8  | webmention | Ada   | approved |
    When I visit "/admin/webmentions/8/menu"
    Then the inbox screen's ".ctx-label" include "Ignore, Mark spam"
    And the inbox screen's ".ctx-label" leave out "Approve, Snooze"

  Scenario: A verdict from the webmention menu lands back on the page it opened on with its toast
    Given the inbox holds:
      | id | kind       | title |
      | 8  | webmention | Ada   |
    When I post the form to the admin "/admin/webmentions/8/approve" with:
      | return_to | /admin/inbox |
    Then the admin post sends me to "/admin/inbox"
    When I follow the admin post
    Then the admin toast says "Approved · now visible on the post"

  Scenario: A snooze from the webmention menu lands back on the page it opened on
    Given the inbox holds:
      | id | kind       | title |
      | 8  | webmention | Ada   |
    When I post the form to the admin "/admin/inbox/webmention/8/snooze" with:
      | pick      | 2030-01-08T08:00   |
      | return_to | /admin/webmentions |
    Then the admin post sends me to "/admin/webmentions"
