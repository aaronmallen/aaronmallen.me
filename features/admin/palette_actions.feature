Feature: Admin palette actions
  The palette opens with a list of actions: forms to open, routes to post to, controls to click, and rows that act on
  the task on screen or on each task in progress.

  Background:
    Given I am signed in to the admin
    When I visit "/admin"

  Scenario: The actions ship in order, each where it leads
    Then the palette rows under "[aria-labelledby='command-palette-group-actions']" have the ids:
      | command-palette-create-task          |
      | command-palette-create-decision      |
      | command-palette-create-journal-entry |
      | command-palette-new-post             |
      | command-palette-new-social-post      |
      | command-palette-new-artifact         |
      | command-palette-plan-tomorrow        |
      | command-palette-import-commits       |
      | command-palette-sync-issues          |
      | command-palette-keyboard-shortcuts   |
      | command-palette-toggle-theme         |
      | command-palette-activate-maintenance |
      | command-palette-start-task           |
      | command-palette-complete-task        |
      | command-palette-pause-task           |
    And the admin markup lacks "[aria-labelledby='command-palette-group-actions'] .fa-plus"
    And the admin markup holds "#command-palette-create-task[data-palette-dialog='task-create'][data-palette-href='/admin/tasks/new'] .fa-list-check"
    And the admin markup holds "#command-palette-create-task[data-palette-text='create task, new task, add task']"
    And the admin markup holds "#command-palette-create-decision:not([data-palette-dialog])[data-palette-href='/admin/decisions/new'] .fa-scale-balanced"
    And the admin markup holds "#command-palette-create-decision .pal-r-label:text-is('Create decision')"
    And the admin markup holds "#command-palette-create-journal-entry[data-palette-dialog='journal-write'][data-palette-href='/admin/journal?write=1'] .fa-feather"
    And the admin markup holds "#command-palette-new-post[data-palette-href='/admin/posts/new']"
    And the admin markup holds "#command-palette-new-social-post[data-palette-href='/admin/social?write=1']"
    And the admin markup holds "#command-palette-new-artifact[data-palette-href='/admin/agents/artifacts/new']"
    And the admin markup holds "#command-palette-plan-tomorrow[data-palette-href='/admin/tasks?filter=upcoming']"
    And the admin markup holds "#command-palette-import-commits[data-palette-post][data-palette-href='/admin/commits/import']"
    And the admin markup holds "#command-palette-sync-issues[data-palette-post][data-palette-href='/admin/tasks/issues/sync']"
    And the admin markup holds "#command-palette-keyboard-shortcuts[data-palette-click='[data-key-help-open]'] .pal-r-key:text-is('?')"
    And the admin markup holds "#command-palette-toggle-theme[data-palette-click=\"[data-theme-choice][aria-pressed='false']\"]"
    And the admin markup holds "#command-palette-activate-maintenance[data-palette-post][data-palette-href='/admin/maintenance'][data-palette-confirm='Take the site down? Every request gets the maintenance page and jobs hold back.']"

  Scenario: The task actions post to the task on screen with the page's token
    Then the admin markup holds "#command-palette-start-task[data-palette-post][data-palette-needs='start']"
    And the admin markup holds "#command-palette-complete-task[data-palette-post][data-palette-needs='complete']"
    And the admin markup holds "#command-palette-pause-task[data-palette-post][data-palette-needs='pause']"
    And the palette carries the page's CSRF token

  Scenario: The tasks in progress fill complete and pause rows from the route that lists them
    Then the palette templates fetch from:
      | /admin/tasks/in-progress           |
      | /admin/tasks/in-progress?act=pause |
    And the palette templates draw the rows:
      | id                                          | label             | text                                       | sends | needs   |
      | command-palette-complete-task-in-progress   | Complete {title}  | complete {title}, finish task, mark done   | posts | no_task |
      | command-palette-pause-task-in-progress      | Pause {title}     | pause {title}, stop task, stop work        | posts | no_task |

  Scenario: The admin with the palette passes axe in light and dark
    Then the page has no axe breaches in light or dark
