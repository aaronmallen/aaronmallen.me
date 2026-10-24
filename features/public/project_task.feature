Feature: Project task page
  A task on a published board of a public project has a page at /projects/<slug>/tasks/<number>: its status,
  column, closing day, source issue, sanitized notes and comments, and the related tasks other visitors may see.
  It shows no tags, time or hours.

  Background:
    Given the projects:
      | name     | board     | visibility |
      | Doing It | published |            |
      | Other    | published |            |
      | Hush     | published | private    |
      | Plain    |           |            |

  Scenario: A task shows its number and title, links back to the board, and caches five minutes
    Given the tasks of the project "Doing It":
      | title   | stage |
      | Ship it | ready |
    When I visit "/projects/doing-it/tasks/1"
    Then "header.hd > .kicker" reads "Task DOI-1"
    And "h1" reads "Ship it"
    And "main" has a link "Doing It board" to "/projects/doing-it"
    And the texts of ".task-page-facts > *" are:
      | Status |
      | open   |
      | Column |
      | ready  |
    And the page has no axe breaches in light or dark
    When I request "/projects/doing-it/tasks/1"
    Then the "Cache-Control" header is "public, max-age=0, s-maxage=300"

  Scenario Outline: A <status> task shows the day it closed
    Given the tasks of the project "Doing It":
      | status   | closed     |
      | <status> | 2 days ago |
    When I visit "/projects/doing-it/tasks/1"
    Then the texts of ".task-page-facts > dt" are:
      | Status  |
      | Column  |
      | <label> |
    And ".task-page-facts > dd:last-child" reads "" with the day 2 days ago

    Examples:
      | status   | label    |
      | done     | Done     |
      | canceled | Canceled |

  Scenario: A task links its source issue and marks links in its synced notes and comments as user content
    Given the tasks of the project "Doing It":
      | note                          |
      | [note](https://example.com/n) |
    And the database runs:
      """
      INSERT INTO task_sources (task_id, provider, remote_id, url) VALUES (1, 'github', 'I_42', 'https://github.com/aaronmallen/aaronmallen.me/issues/42');
      INSERT INTO task_comments (task_id, body, provider, remote_id, url, author)
        VALUES (1, '<a href="https://example.com/c" rel="me">comment</a>', 'github', 'IC_1', 'https://github.com/aaronmallen/aaronmallen.me/issues/1#issuecomment-1', 'octocat');
      """
    When I visit "/projects/doing-it/tasks/1"
    Then "main" has a link "aaronmallen/aaronmallen.me#42" to "https://github.com/aaronmallen/aaronmallen.me/issues/42"
    And "a:text-is('note')" has the attribute "rel" set to "nofollow ugc noopener"
    And "a:text-is('comment')" has the attribute "rel" set to "nofollow ugc noopener"
    And ".task-comment-head" includes "octocat"

  Scenario: Links in the owner's notes and comments stay as they are, and comments show oldest first
    Given the tasks of the project "Doing It":
      | note                          |
      | [note](https://example.com/n) |
    And the database runs:
      """
      INSERT INTO task_comments (task_id, body, created_at) VALUES (1, '[comment](https://example.com/c)', now() - interval '1 minute');
      INSERT INTO task_comments (task_id, body) VALUES (1, 'second');
      """
    When I visit "/projects/doing-it/tasks/1"
    Then the page has "a:text-is('note'):not([rel])"
    And the page has "a:text-is('comment'):not([rel])"
    And the texts of ".task-comment .post-body" are:
      | comment |
      | second  |

  Scenario: Notes render sanitized, and an h1 in a note or comment turns into an h2
    Given the tasks of the project "Doing It":
      | note                                                                                                 |
      | **bold** <script>alert(1)</script><a href="javascript:alert(1)" onclick="x()">bad</a>\n\n# Note heading |
    And the database runs:
      """
      INSERT INTO task_comments (task_id, body) VALUES (1, '<h1>Comment heading</h1>');
      """
    When I visit "/projects/doing-it/tasks/1"
    Then ".task-section .post-body strong" reads "bold"
    And the page has 1 of "h1"
    And ".task-section .post-body h2" reads "Note heading"
    And ".task-comment .post-body h2" reads "Comment heading"
    When I request "/projects/doing-it/tasks/1"
    Then the body does not match "<script>alert|javascript:alert|onclick"

  Scenario: A task shows no tags, time or work hours
    Given the tasks of the project "Doing It":
      | private tags | worked |
      | private-tag  | 3600   |
    When I visit "/projects/doing-it/tasks/1"
    Then the page does not show "private-tag"
    And the texts of ".task-page-facts dt" are:
      | Status |
      | Column |

  Scenario: Related tasks on published boards are named by how they relate and link to their boards
    Given the tasks of the project "Doing It":
      | title   |
      | Here    |
      | Blocked |
    And the tasks of the project "Other":
      | title     |
      | Elsewhere |
    And the database runs:
      """
      INSERT INTO task_links (from_task_id, to_task_id, type)
        SELECT here.id, other.id, CASE other.title WHEN 'Blocked' THEN 'blocks'::task_link_type ELSE 'relates'::task_link_type END
        FROM tasks here, tasks other WHERE here.title = 'Here' AND other.title IN ('Blocked', 'Elsewhere');
      """
    When I visit "/projects/doing-it/tasks/1"
    Then ".task-related li:has-text('Blocked')" includes "blocks DOI-2 Blocked"
    And ".task-related" has a link "DOI-2 Blocked" to "/projects/doing-it/tasks/2"
    And ".task-related" has a link "OTH-1 Elsewhere" to "/projects/other/tasks/1"

  Scenario: A related task on no published board of a public project stays off the page
    Given the tasks of the project "Doing It":
      | title |
      | Here  |
    And the tasks of the project "Hush":
      | title          |
      | Private secret |
    And the tasks of the project "Plain":
      | title              |
      | Unpublished secret |
    And the tasks of the project "nobody":
      | title        |
      | Loose secret |
    And the database runs:
      """
      INSERT INTO task_links (from_task_id, to_task_id, type)
        SELECT here.id, other.id, 'relates' FROM tasks here, tasks other WHERE here.title = 'Here' AND other.title LIKE '%secret';
      """
    When I visit "/projects/doing-it/tasks/1"
    Then the page does not show "secret"
    And the page has no ".task-related"

  Scenario Outline: <what> answers 404, out of a shared cache
    Given the tasks of the project "nobody":
      | title |
      | One   |
      | Two   |
    And the tasks of the project "Doing It":
      | title |
      | Mine  |
    And the tasks of the project "Other":
      | title  |
      | Theirs |
    And the tasks of the project "Hush":
      | title  |
      | Hushed |
    And the tasks of the project "Plain":
      | title |
      | Flat  |
    When I request "<path>"
    Then it answers 404
    And the "Cache-Control" header does not include "s-maxage"

    Examples:
      | what                                               | path                          |
      | A task's internal id where the project has no such number | /projects/doing-it/tasks/3 |
      | A task on another project's board                  | /projects/doing-it/tasks/2    |
      | A task on a private project                        | /projects/hush/tasks/1        |
      | A task on a board that is not published            | /projects/plain/tasks/1       |
      | A number that is not a task id                     | /projects/doing-it/tasks/abc  |
      | A number past every task id                        | /projects/doing-it/tasks/99999999999 |

  Scenario: A task on no board answers 404
    Given the tasks of the project "nobody":
      | title |
      | Loose |
    When I request "/projects/doing-it/tasks/1"
    Then it answers 404
