Feature: Admin row actions
  Rows keep their action buttons hidden until the row is hovered or focus moves into them, and show them at all
  times on a touch screen. Each button is a 32px icon button with a label for screen readers.

  Background:
    Given I am signed in to the admin

  Scenario Outline: The actions on <row name> stay hidden until hovered, show on focus, and show at all times on a touch screen
    Given the menu screens hold "<seed>"
    When I visit "<path>"
    Then the actions of the first "<row>" are hidden
    When I hover the first "<row>"
    Then the actions of the first "<row>" show
    When I visit "<path>"
    And I move focus into the actions of the first "<row>"
    Then the actions of the first "<row>" show
    When I visit "<path>" on a touch screen
    Then the actions of the first "<row>" show

    Examples:
      | row name           | seed                     | path                        | row                  |
      | a task row         | a task                   | /admin/tasks?filter=next    | .task                |
      | a pull in row      | a task                   | /admin/tasks?filter=today   | .task-pull .li       |
      | an attention row   | an old draft             | /admin                      | [data-attention] .li |
      | a journal entry    | a journal entry          | /admin/journal              | .journal-entry       |
      | a project card     | a project                | /admin/projects             | .project-card        |
      | a decision option  | a decision option        | /admin/decisions/1          | .decision-option     |
      | a task rule        | a task rule for projects | /admin/settings/tagging     | .rule-row            |
      | a work history row | a work entry             | /admin/projects?filter=work | .work-row            |

  Scenario Outline: The actions on <row name> are 32px icon buttons, each with a label for screen readers
    Given the menu screens hold "<seed>"
    When I visit "<path>"
    And I hover the first "<row>"
    Then each shown action on the first "<row>" has a label
    And each shown action on the first "<row>" stands 32 pixels tall

    Examples:
      | row name           | seed                     | path                        | row                  |
      | a task row         | a task                   | /admin/tasks?filter=next    | .task                |
      | a pull in row      | a task                   | /admin/tasks?filter=today   | .task-pull .li       |
      | an attention row   | an old draft             | /admin                      | [data-attention] .li |
      | a journal entry    | a journal entry          | /admin/journal              | .journal-entry       |
      | a project card     | a project                | /admin/projects             | .project-card        |
      | a decision option  | a decision option        | /admin/decisions/1          | .decision-option     |
      | a task rule        | a task rule for projects | /admin/settings/tagging     | .rule-row            |
      | a work history row | a work entry             | /admin/projects?filter=work | .work-row            |

  Scenario: A task row reached with j shows its actions and the green bar
    Given the menu screens hold "a task"
    When I visit "/admin/tasks?filter=next"
    And I press "j"
    Then the actions of the first ".task" show
    And the first ".task" wears the green bar

  Scenario Outline: The screen at <path> passes axe
    Given the menu screens hold "<seed>"
    When I visit "<path>"
    Then the page has no axe breaches in light or dark

    Examples:
      | seed              | path                        |
      | a task            | /admin/tasks?filter=today   |
      | an old draft      | /admin                      |
      | a journal entry   | /admin/journal              |
      | a decision option | /admin/decisions/1          |
      | a work entry      | /admin/projects?filter=work |
