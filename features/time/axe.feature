Feature: The pages the project, work and time features visit pass axe
  Each page these features open, filled with the records they use, has no axe breaches in light or dark.

  Background:
    Given I am signed in to the admin
    And the work entries:
      | role  | org  | from | to   | blurb        |
      | Staff | Acme | 2018 | 2021 | Built things |
    And the projects:
      | name | url                                 | archived  |
      | live | https://github.com/aaronmallen/live |           |
      | gone | https://github.com/aaronmallen/gone | today - 3 |
    And the worked tasks:
      | title      | sessions                           | total | sprint |
      | Write docs | today - 1 09:00 to today - 1 09:30 | 1800  | today  |
      | Running    | 30 minutes ago to                  | 0     | today  |

  Scenario Outline: <path> passes axe
    When I visit "<path>"
    Then the page has no axe breaches in light or dark

    Examples:
      | path                                     |
      | /about                                   |
      | /projects                                |
      | /admin                                   |
      | /admin/tasks                             |
      | /admin/tasks/{task:Running}?filter=next  |
      | /admin/tasks/{task:Write docs}/edit      |
      | /admin/posts?status=draft                |
      | /admin/time?from=2026-03-02&to=2026-03-08&by=day |
