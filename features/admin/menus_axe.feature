Feature: Admin context menus pass axe
  Every right-click menu in the admin, open over the screen that draws it, passes axe in light and dark.

  Background:
    Given I am signed in to the admin

  Scenario Outline: The <menu> row menu passes axe in light and dark
    Given the menu screens hold "<seed>"
    When I visit "<path>"
    And I right-click the first row whose menu matches "<pattern>" at "<target>"
    Then the page has no axe breaches in light or dark

    Examples:
      | menu                     | seed                 | path                         | pattern                                | target      |
      | clients.menu             | a client             | /admin/settings/services     | /clients/[0-9]+/menu                   |             |
      | commits.menu             | a commit today       | /admin                       | /commits/[0-9]+/menu                   |             |
      | decisions.comment_menu   | a decision comment   | /admin/decisions/1           | /decisions/[0-9]+/comments/[0-9]+/menu |             |
      | decisions.menu           | a decision           | /admin/decisions             | /decisions/[0-9]+/menu                 |             |
      | files.menu               | a file               | /admin/files                 | /files/[0-9]+/menu                     |             |
      | journal.menu             | a journal entry      | /admin/journal               | /journal/[0-9]+/menu                   |             |
      | links.menu               | a link               | /admin/links                 | /links/[0-9]+/menu                     |             |
      | mail.menu                | two messages         | /admin/mail                  | /mail/[0-9]+/menu                      |             |
      | notes.folder_menu        | a note in a folder   | /admin/notes                 | /notes/folders/[0-9]+/menu             |             |
      | notes.menu               | a note               | /admin/notes                 | /notes/[0-9]+/menu                     |             |
      | notes.root_menu          | nothing more         | /admin/notes                 | /notes/menu                            | .nt-gh      |
      | people.menu              | a person             | /admin/contacts              | /contacts/[0-9]+/menu                  |             |
      | posts.menu               | two drafts           | /admin/posts                 | /posts/[0-9]+/menu                     | .li-sub     |
      | projects.menu            | a project            | /admin/projects              | /projects/[0-9]+/menu                  |             |
      | settings.cron_entry_menu | nothing more         | /admin/settings/jobs         | /settings/jobs/cron/[A-Za-z0-9_]+/menu |             |
      | social.menu              | a queued social post | /admin/social                | /social/[0-9]+/menu                    |             |
      | sprints.menu             | a sprint in two days | /admin/tasks?filter=upcoming | /tasks/sprints/[0-9]+/menu             |             |
      | tags.menu                | a tag                | /admin/settings/tagging      | /tags/[0-9]+/menu                      |             |
      | task_rules.menu          | a task rule          | /admin/settings/tagging      | /tasks/rules/[0-9]+/menu               |             |
      | tasks.comment_menu       | a task comment       | /admin/tasks/1               | /tasks/[0-9]+/comments/[0-9]+/menu     |             |
      | tasks.menu               | two tasks            | /admin/tasks?filter=next     | /tasks/[0-9]+/menu                     | .record-key |
      | tasks.session_menu       | a work session       | /admin/tasks/1               | /tasks/[0-9]+/sessions/[0-9]+/menu     |             |
      | today.attention_menu     | a carried task       | /admin                       | /attention/menu                        |             |
      | tokens.menu              | a token              | /admin/settings/services     | /tokens/[0-9]+/menu                    |             |
      | webmentions.menu         | two webmentions      | /admin/webmentions           | /webmentions/[0-9]+/menu               |             |

  Scenario Outline: The <menu> bulk menu passes axe in light and dark
    Given the menu screens hold "<seed>"
    When I visit "<path>"
    And I tick every row box
    And I right-click the picked row whose menu matches "<pattern>" at "<target>"
    Then the menu head holds "picked"
    And the page has no axe breaches in light or dark

    Examples:
      | menu                  | seed            | path                     | pattern                  | target      |
      | mail.bulk_menu        | two messages    | /admin/mail              | /mail/[0-9]+/menu        |             |
      | posts.bulk_menu       | two drafts      | /admin/posts             | /posts/[0-9]+/menu       | .li-sub     |
      | tasks.bulk_menu       | two tasks       | /admin/tasks?filter=next | /tasks/[0-9]+/menu       | .record-key |
      | webmentions.bulk_menu | two webmentions | /admin/webmentions       | /webmentions/[0-9]+/menu |             |

  Scenario: The calendar.event_menu row menu passes axe in light and dark
    Given the menu screens hold "a calendar event today"
    When I visit "/admin/calendar"
    And I right-click the row part "[data-calendar-panel] .cal-event-time"
    Then the row menu offers "Edit"
    And the page has no axe breaches in light or dark

  Scenario: The services.menu row menu passes axe in light and dark
    Given the services hold a linear connection labelled "Work"
    When I visit "/admin/settings/services"
    And I right-click the first row whose menu matches "/services/[a-z0-9]+/menu" at ""
    Then the page has no axe breaches in light or dark

  Scenario: The settings.set_job_menu row menu passes axe in light and dark
    Given the job "Social::Jobs::CrossPost" waits to retry
    When I visit "/admin/settings/jobs"
    And I right-click the first row whose menu matches "/settings/jobs/[a-z_]+/[0-9a-f]+/menu" at ".jobs-meta"
    Then the page has no axe breaches in light or dark
