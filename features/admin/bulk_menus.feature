Feature: Admin bulk menus
  With rows picked, the tasks, posts and webmentions screens open a bulk menu. It names how many rows it acts on and
  posts each action to the bulk route with every picked row and the list's place.

  Background:
    Given I am signed in to the admin

  Scenario Outline: The bulk menu answers 404 for <kind> with nothing picked
    Then visiting "/admin/<kind>/bulk/menu?ids[]=nope" answers 404

    Examples:
      | kind        |
      | tasks       |
      | posts       |
      | webmentions |

  Scenario: The tasks bulk menu names how many it acts on and holds every bulk action
    Given the database runs:
      """
      INSERT INTO tags (name, color, scope) VALUES ('home', 'mk-blue', 'private'), ('work', 'mk-blue', 'private'),
        ('ruby', 'mk-blue', 'public');
      INSERT INTO tasks (title, list, position) VALUES ('one', 'next', 1), ('two', 'next', 2), ('three', 'next', 3);
      INSERT INTO task_tags (task_id, tag_id) SELECT 1, id FROM tags WHERE name = 'work';
      """
    When I visit "/admin/tasks/bulk/menu?ids[]=1&ids[]=2&ids[]=3&filter=next&q=o&page=2"
    Then the menu head reads "3 tasks picked"
    And the menu items include "Complete, Move to, Add tag, Remove tag, Cancel, Delete, Clear selection"
    And the admin markup holds "form[action='/admin/tasks/bulk'] .ctx-item:has-text('Complete')"
    And the menu form for "Complete" holds the fields:
      | ids[]  | 1        |
      | ids[]  | 2        |
      | ids[]  | 3        |
      | act    | complete |
      | filter | next     |
      | q      | o        |
      | page   | 2        |
    And the menu form for "Someday" holds the fields:
      | act | move    |
      | to  | someday |
    And the menu form for "#home" under "Add tag" holds the fields:
      | act | tag  |
      | tag | home |
    And the menu form for "#work" under "Remove tag" holds the fields:
      | act | untag |
      | tag | work  |
    And the "Remove tag" submenu leaves out "#home"
    And the menu items leave out "#ruby"
    And the admin markup holds "button[data-confirm-inline='Click again to delete']:has-text('Delete')"
    And the admin markup holds "button[type=button][data-bulk-clear=task-bulk]:has-text('Clear selection')"

  Scenario: The posts bulk menu adds only public tags, holds no remove when no post has a tag, and deletes on a second click
    Given the database runs:
      """
      INSERT INTO tags (name, color, scope) VALUES ('ruby', 'mk-blue', 'public'), ('home', 'mk-blue', 'private');
      """
    And the menu screens hold "two drafts"
    When I visit "/admin/posts/bulk/menu?ids[]=1&ids[]=2&status=draft"
    Then the menu head reads "2 posts picked"
    And the menu form for "#ruby" holds the fields:
      | act    | tag   |
      | tag    | ruby  |
      | status | draft |
    And the menu items leave out "#home, Remove tag"
    And the menu form for "Delete" holds the fields:
      | ids[] | 1      |
      | ids[] | 2      |
      | act   | delete |
    And the admin markup holds "form:has(input[name=act][value=delete]) button[data-confirm-inline]"

  Scenario: The webmentions bulk menu offers each verdict the list has not reached
    Given the menu screens hold "two webmentions"
    When I visit "/admin/webmentions/bulk/menu?ids[]=1&ids[]=2&status=pending"
    Then the menu head reads "2 webmentions picked"
    And the menu items read "Approve, Ignore, Spam"
    And the menu form for "Approve" holds the fields:
      | ids[] | 1        |
      | ids[] | 2        |
      | act   | approved |

  Scenario: The webmentions bulk menu leaves out the verdict of the list it opened on
    Given the menu screens hold "two webmentions"
    When I visit "/admin/webmentions/bulk/menu?ids[]=1&ids[]=2&status=spam"
    Then the menu items read "Approve, Ignore"

  Scenario: The tasks bulk bar carries the menu with the list's place
    Given the menu screens hold "a task"
    When I visit "/admin/tasks?filter=next"
    Then the admin markup holds "form#task-bulk[data-bulk-menu='/admin/tasks/bulk/menu?filter=next']"

  Scenario: The posts bulk bar carries the menu
    Given the menu screens hold "two drafts"
    When I visit "/admin/posts"
    Then the admin markup holds "form#post-bulk[data-bulk-menu^='/admin/posts/bulk/menu']"

  Scenario: The webmentions bulk bar carries the menu
    Given the menu screens hold "two webmentions"
    When I visit "/admin/webmentions"
    Then the admin markup holds "form#webmention-bulk[data-bulk-menu^='/admin/webmentions/bulk/menu']"

  Scenario Outline: The screens with bulk menus pass axe at <path>
    Given the menu screens hold "<seed>"
    When I visit "<path>"
    Then the page has no axe breaches in light or dark

    Examples:
      | seed            | path                     |
      | a task          | /admin/tasks?filter=next |
      | two webmentions | /admin/webmentions       |
