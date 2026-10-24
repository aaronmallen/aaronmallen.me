Feature: Project board
  A public project with a published board shows its tasks at /projects/<slug>, as five columns and as a list of
  groups, with the project's tags and a filter bar. Closed tasks drop off after 14 days and each column shows
  20 at a time.

  Background:
    Given the projects:
      | name     | tagline           | repo              | url                           | stars | release | board     |
      | Doing It | Track what you do | aaronmallen/doing | https://doing.aaronmallen.dev | 40    | 0.2.2   | published |

  Scenario: The board renders at the slug made from its name, with its tagline, links, stars and release
    When I visit "/projects/doing-it"
    Then "header.hd > .kicker + h1.board-name" reads "Doing It"
    And "header.hd p.ld" reads "Track what you do"
    And ".board-links > span" reads "★ 40 · 0.2.2"
    And ".board-links" has a link "aaronmallen/doing" to "https://github.com/aaronmallen/doing"
    And ".board-links" has a link "doing.aaronmallen.dev" to "https://doing.aaronmallen.dev"
    When I request "/projects/doing-it"
    Then it answers 200
    And the "Cache-Control" header is "public, max-age=0, s-maxage=300"

  Scenario: The oldest board opens when a newer name shares its slug
    Given the projects:
      | name     | tagline | board     |
      | doing-it | Newer   | published |
    When I visit "/projects/doing-it"
    Then "h1.board-name" reads "Doing It"

  Scenario: The url link is left out when it points at the repo
    Given the projects:
      | name | repo            | url                                | board     |
      | sai  | aaronmallen/sai | https://github.com/aaronmallen/sai | published |
    When I visit "/projects/sai"
    Then the page has 1 of ".board-links a"

  Scenario: The five columns and the list groups show in order, each with a count, the open and total in the bar
    Given the tasks of the project "Doing It":
      | status      | stage |
      | open        |       |
      | in_progress |       |
      | done        |       |
      | done        |       |
      | canceled    |       |
      | open        | ready |
    When I visit "/projects/doing-it"
    Then the texts of ".board-col h2" are:
      | backlog 1     |
      | ready 1       |
      | in progress 1 |
      | done 2        |
      | canceled 1    |
    And the texts of ".board-group > summary" are:
      | backlog 1     |
      | ready 1       |
      | in progress 1 |
      | done 2        |
      | canceled 1    |
    And ".board-bar > .meta" reads "3 open · 6 total"

  Scenario: An empty column and group are marked, every group opens but canceled, and the view switch starts unpressed
    When I visit "/projects/doing-it"
    Then ".board-col.backlog .board-empty" reads "Nothing here."
    And ".board-group.backlog .board-empty" reads "Nothing here."
    And the open states of ".board-group" are:
      | true  |
      | true  |
      | true  |
      | true  |
      | false |
    And the page has no axe breaches in light or dark
    When I request "/projects/doing-it"
    Then the body matches "<div class=\"board-switch\" role=\"group\" aria-label=\"View\">"
    And the body includes "data-board-view=\"board\" aria-pressed=\"false\""
    And the body includes "data-board-view=\"list\" aria-pressed=\"false\""

  Scenario: The board shows only the project's tasks, open ones in place order, closed ones newest first
    Given the tasks of the project "Doing It":
      | title  | position | status | closed        |
      | second | 2        |        |               |
      | first  | 1        |        |               |
      | older  |          | done   | 2 hours ago   |
      | newer  |          | done   | 1 minute ago  |
    And the tasks of the project "nobody":
      | title    |
      | Not mine |
    When I visit "/projects/doing-it"
    Then the texts of ".board-col.backlog .board-title" are:
      | first  |
      | second |
    And the texts of ".board-col.done .board-title" are:
      | newer |
      | older |
    And the page does not show "Not mine"

  Scenario: A card and a row show the number, then the title, link to the task page and leave off the note and time
    Given the tasks of the project "Doing It":
      | title   | note        | worked |
      | Ship it | secret note | 3600   |
    When I visit "/projects/doing-it"
    Then "li > .board-card > .board-num + .board-title" reads "Ship it"
    And ".board-num" reads "DOI-1"
    And ".board-col.backlog a.board-card[href='/projects/doing-it/tasks/1']" includes "Ship it"
    And the tag names of ".board-col.backlog li *" are:
      | a    |
      | span |
      | span |
    And the texts of ".board-group.backlog a.board-row[href='/projects/doing-it/tasks/1'] span" are:
      | DOI-1   |
      | Ship it |
    And the tag names of ".board-group.backlog li *" are:
      | a    |
      | span |
      | span |
    And the page does not show "secret note"

  Scenario: A closed task shows the day it closed, on a card and a row
    Given the tasks of the project "Doing It":
      | status   | closed     |
      | done     | 2 days ago |
      | canceled | 1 day ago  |
    When I visit "/projects/doing-it"
    Then ".board-col.done .board-meta" reads "done" with the day 2 days ago
    And ".board-col.canceled .board-meta" reads "canceled" with the day 1 days ago
    And ".board-group.done .board-row-meta" reads "done" with the day 2 days ago
    And ".board-group.canceled .board-row-meta" reads "canceled" with the day 1 days ago

  Scenario: A task closed 14 days ago or more drops off the board, but keeps its page
    Given the tasks of the project "Doing It":
      | title   | status   | closed           |
      | Shipped | done     | 14 days ago      |
      | Dropped | canceled | 13 days ago      |
    When I visit "/projects/doing-it"
    Then the texts of ".board-title" are:
      | Dropped |
    And ".board-group.done .board-empty" reads "Nothing here."
    When I visit "/projects/doing-it/tasks/1"
    Then "h1" reads "Shipped"

  Scenario: A full column shows 20 and links Load More to the rest, growing only that column
    Given 21 backlog tasks in the project "Doing It"
    And 21 ready tasks in the project "Doing It"
    When I visit "/projects/doing-it"
    Then ".board-col.backlog .board-title" counts 20
    And ".board-col.backlog a.board-more" includes "Load more · 1 left"
    And ".board-col.backlog a.board-more" has the attribute "href" set to "/projects/doing-it?backlog=40&view=board"
    And the texts of ".board-col h2 .n" are:
      | 21 |
      | 21 |
      | 0  |
      | 0  |
      | 0  |
    When I visit "/projects/doing-it?backlog=40"
    Then ".board-col.backlog .board-title" counts 21
    And ".board-col.ready .board-title" counts 20
    And the page has no ".board-col.backlog a.board-more"
    And ".board-col.ready a.board-more" has the attribute "href" set to "/projects/doing-it?backlog=40&ready=40&view=board"
    And ".board-group.backlog .board-row" counts 21
    And the page has no ".board-group.backlog a.board-more"
    And ".board-group.ready .board-row" counts 20
    And ".board-group.ready a.board-more" has the attribute "href" set to "/projects/doing-it?backlog=40&ready=40&view=list"

  Scenario Outline: A column size of <size> shows the cap
    Given 21 backlog tasks in the project "Doing It"
    When I visit "/projects/doing-it?backlog=<size>"
    Then ".board-col.backlog .board-title" counts 20

    Examples:
      | size |
      | 1    |
      | lots |

  Scenario: Old closed tasks stay out of a column's count, its Load More and its group
    Given 20 tasks done 1 day ago in the project "Doing It"
    And 1 task done 30 days ago in the project "Doing It"
    When I visit "/projects/doing-it"
    Then ".board-col.done h2 .n" reads "20"
    And the page has no ".board-col.done a.board-more"
    And ".board-group.done .board-row" counts 20

  Scenario: An old closed task leaves its group empty
    Given 1 task done 30 days ago in the project "Doing It"
    When I visit "/projects/doing-it"
    Then the page has ".board-group.done .board-empty"

  Scenario: The latest closed tasks show first in a full column
    Given 20 tasks canceled 1 day ago in the project "Doing It"
    And the tasks of the project "Doing It":
      | title  | status   | closed     |
      | Oldest | canceled | 3 days ago |
      | Newest | canceled | 1 minute ago |
    When I visit "/projects/doing-it"
    Then the first of ".board-col.canceled .board-title" reads "Newest" and the last "canceled 19", 20 in all

  Scenario: A card and a row show the project tags, each linking to the board filtered by it
    Given the tasks of the project "Doing It":
      | title            | tags  |
      | Record the intro | audio |
    When I visit "/projects/doing-it"
    Then ".board-col.backlog li > .board-tags > a.tag" reads "#audio"
    And ".board-group.backlog li > .board-row-tags > a.tag" reads "#audio"
    And ".board-col.backlog a.tag" has the attribute "href" set to "/projects/doing-it?q=label:audio"
    When I visit "/projects/doing-it?q=intro"
    Then ".board-col.backlog a.tag" has the attribute "href" set to "/projects/doing-it?q=intro%20label:audio"
    When I visit "/projects/doing-it?q=label:audio"
    Then ".board-col.backlog a.tag" has the attribute "href" set to "/projects/doing-it?q=label:audio"

  Scenario: A private tag and another project's tag stay off the board, and the filter bar offers only the project's
    Given the projects:
      | name   | visibility |
      | Hidden | private    |
    And the tasks of the project "Doing It":
      | tags  | private tags |
      | audio | secret       |
    And the tasks of the project "Hidden":
      | tags   |
      | hidden |
    When I visit "/projects/doing-it"
    Then the texts of "a.tag" are:
      | #audio |
      | #audio |
    And the page has "form.task-filter-box[action='/projects/doing-it'][method='get'] input[name='q']"
    And the tags the filter bar offers are:
      | audio |

  Scenario: The filter narrows the board and the list, counts the matches and stays in the field and Load More
    Given the tasks of the project "Doing It":
      | title            | tags  |
      | Record the intro | audio |
      | Book a guest     |       |
    When I visit "/projects/doing-it?q=label:audio"
    Then the texts of ".board-title, .board-row-title" are:
      | Record the intro |
      | Record the intro |
    And ".task-filter-meta" includes "1 of 2 tasks match"
    And "input[name='q']" has the value "label:audio"

  Scenario: Load More keeps the filter
    Given 21 backlog tasks in the project "Doing It"
    And the database runs:
      """
      INSERT INTO tags (name, color, scope, project_id) SELECT 'audio', 'mk-blue', 'project', id FROM projects WHERE name = 'Doing It';
      INSERT INTO task_tags (task_id, tag_id, tag_scope) SELECT tasks.id, tags.id, 'project' FROM tasks, tags;
      """
    When I visit "/projects/doing-it?q=label:audio"
    Then ".board-col.backlog a.board-more" has the attribute "href" set to "/projects/doing-it?backlog=40&q=label:audio&view=board"

  Scenario: A board that is not published keeps its tags off its page
    Given the projects:
      | name     |
      | unlisted |
    And the tasks of the project "unlisted":
      | tags         |
      | unlisted-tag |
    When I request "/projects/unlisted"
    Then the body does not include "unlisted-tag"
    And the body does not include "data-task-filter"

  Scenario: The board stays once the project is archived
    Given the projects:
      | name | archived   | board     |
      | old  | 2026-01-01 | published |
    When I visit "/projects/old"
    Then "h1" reads "old"

  Scenario Outline: <what> reads that the board isn't public
    Given the projects:
      | name   | visibility | board   |
      | hidden | private    | published |
      | plain  |            |         |
    When I request "/projects/<slug>"
    Then it answers 404
    And the body matches "<h1[^>]*>That board isn&#39;t public.</h1>|<h1[^>]*>That board isn’t public.</h1>|<h1[^>]*>That board isn't public.</h1>"
    And the body does not include "class=\"board\""
    And the "Cache-Control" header does not include "s-maxage"

    Examples:
      | what                                  | slug    |
      | A private project                     | hidden  |
      | A public project without the toggle   | plain   |
      | A slug no project has                 | nothing |
