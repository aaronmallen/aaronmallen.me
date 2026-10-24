Feature: Task contributors
  The task editor credits me, an agent on a model, or both, and the task page lists who did the work.

  Background:
    Given I am signed in to the admin
    And the tasks:
      | title           |
      | Ship the editor |

  Scenario: The editor checks me on a task with no contributors and offers fields for an agent
    When I visit "/admin/tasks/{task:Ship the editor}/edit"
    Then the page box "#task-{task:Ship the editor}-form input[type=checkbox][name='task[contributors][owner]']" is ticked
    And the page has no "#task-{task:Ship the editor}-form input[name$='[keep]']"
    And the page field "#task-{task:Ship the editor}-form [name='task[contributors][agents][new][agent]']" holds ""
    And the page field "#task-{task:Ship the editor}-form [name='task[contributors][agents][new][model]']" holds ""
    And the page has no axe breaches in light or dark
    When I visit "/admin/tasks/new"
    Then the page has no "[name^='task[contributors]']"

  Scenario: The editor lists each agent with its model, checked
    Given the task_contributors table holds the rows:
      | task_id                | kind  | agent       | model           |
      | {task:Ship the editor} | agent | claude-code | claude-opus-5-5 |
    When I visit "/admin/tasks/{task:Ship the editor}/edit"
    Then the page box "input[type=checkbox][name='task[contributors][agents][0][keep]']" is ticked
    And the page part ":has(> input[name='task[contributors][agents][0][keep]'])" holds "claude-code on claude-opus-5-5"
    And the page box "input[type=checkbox][name='task[contributors][owner]']" is not ticked

  Scenario: Saving adds an agent beside me, and the page and the editor show both
    When I visit "/admin/tasks/{task:Ship the editor}/edit"
    And I set the page field "[name='task[contributors][agents][new][agent]']" to "claude-code"
    And I set the page field "[name='task[contributors][agents][new][model]']" to "claude-opus-5-5"
    And I click "Save"
    Then the toast says "Task saved"
    And the task_contributors rows are:
      | kind  | agent       | model           |
      | owner | none        | none            |
      | agent | claude-code | claude-opus-5-5 |
    When I visit "/admin/tasks/{task:Ship the editor}"
    Then the page parts ".task-fact:has(dt:text-is('Contributors')) .pill" read "Me | claude-code on claude-opus-5-5"
    When I visit "/admin/tasks/{task:Ship the editor}/edit"
    Then the page box "input[type=checkbox][name='task[contributors][owner]']" is ticked
    And the page box "input[type=checkbox][name='task[contributors][agents][0][keep]']" is ticked

  Scenario: Saving adds an agent alone when I take myself off
    When I visit "/admin/tasks/{task:Ship the editor}/edit"
    And I untick the page box "input[type=checkbox][name='task[contributors][owner]']"
    And I set the page field "[name='task[contributors][agents][new][agent]']" to " claude-code "
    And I set the page field "[name='task[contributors][agents][new][model]']" to "claude-sonnet-5"
    And I click "Save"
    Then the toast says "Task saved"
    And the task_contributors rows are:
      | kind  | agent       | model           |
      | agent | claude-code | claude-sonnet-5 |

  Scenario: Saving adds me to a task an agent did, and drops a contributor I uncheck
    Given the task_contributors table holds the rows:
      | task_id                | kind  | agent       | model           |
      | {task:Ship the editor} | agent | claude-code | claude-opus-5-5 |
    When I visit "/admin/tasks/{task:Ship the editor}/edit"
    And I tick the page box "input[type=checkbox][name='task[contributors][owner]']"
    And I click "Save"
    Then the toast says "Task saved"
    And the task_contributors rows are:
      | kind  | agent       | model           |
      | owner | none        | none            |
      | agent | claude-code | claude-opus-5-5 |
    When I visit "/admin/tasks/{task:Ship the editor}/edit"
    And I untick the page box "input[type=checkbox][name='task[contributors][agents][0][keep]']"
    And I click "Save"
    Then the toast says "Task saved"
    And the task_contributors rows are:
      | kind  | agent | model |
      | owner | none  | none  |

  Scenario: Saving writes no rows when the contributors did not change, or when the form sends none
    When I visit "/admin/tasks/{task:Ship the editor}/edit"
    And I click "Save"
    Then the toast says "Task saved"
    And the task_contributors table holds 0 rows
    Given the task_contributors table holds the rows:
      | task_id                | kind  | agent       | model           |
      | {task:Ship the editor} | agent | claude-code | claude-opus-5-5 |
    When I send the admin form "/admin/tasks/{task:Ship the editor}" with:
      | task[title] | Ship the editor |
    Then the task_contributors rows are:
      | kind  | agent       | model           |
      | agent | claude-code | claude-opus-5-5 |

  Scenario: An agent without a model is refused and keeps what was typed
    When I visit "/admin/tasks/{task:Ship the editor}/edit"
    And I set the page field "[name='task[contributors][agents][new][agent]']" to "claude-code"
    And I send the admin form "/admin/tasks/{task:Ship the editor}" with:
      | filter                                   | next            |
      | task[title]                              | Ship the editor |
      | task[contributors][owner]                | 1               |
      | task[contributors][agents][new][agent]   | claude-code     |
    Then the server answers 422
    When I look at the admin answer
    Then the page part "#task-{task:Ship the editor}-contributors-error" holds "Give an agent and its model, each in lowercase letters, numbers, dots and dashes."
    And the page box "input[type=checkbox][name='task[contributors][owner]']" is ticked
    And the page field "[name='task[contributors][agents][new][agent]']" holds "claude-code"
    And the task_contributors table holds 0 rows

  Scenario: The task page lists me, or each agent with its model
    When I visit "/admin/tasks/{task:Ship the editor}"
    Then the page parts ".task-fact:has(dt:text-is('Contributors')) .pill" read "Me"
    Given the task_contributors table holds the rows:
      | task_id                | kind  | agent       | model           |
      | {task:Ship the editor} | agent | claude-code | claude-opus-5-5 |
      | {task:Ship the editor} | agent | claude-code | claude-sonnet-5 |
    When I visit "/admin/tasks/{task:Ship the editor}"
    Then the page parts ".task-fact:has(dt:text-is('Contributors')) .pill" read "claude-code on claude-opus-5-5 | claude-code on claude-sonnet-5"
