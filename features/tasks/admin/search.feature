Feature: Searching the task lists and the archive
  The search box narrows the list it sits on by words, tags, labels, projects and who did the work, and the archive
  groups finished work by day over a range.

  Background:
    Given I am signed in to the admin

  Scenario Outline: A search for "<query>" on <filter> lists <found>
    Given the projects:
      | name           | key |
      | Podcast        | POD |
      | aaronmallen.me | AM  |
      | Other Gem      | OG  |
    And the tasks:
      | title                            | list    | tags       | project        | status |
      | Email the accountant             | next    | admin      |                | open   |
      | Ship the search                  | next    | ruby       |                | open   |
      | Learn Elixir                     | someday | elixir     |                | open   |
      | Ship the admin search            | next    | admin ruby |                | open   |
      | Ship the site                    | next    | ruby       | aaronmallen.me | open   |
      | Draft the site post              | next    | writing    | aaronmallen.me | open   |
      | Ship the gem                     | next    | ruby       | Other Gem      | open   |
      | Finished by hand                 | next    |            |                | done   |
      | Shipped the site                 | next    |            | aaronmallen.me | done   |
    And the task_contributors table holds the rows:
      | task_id                | kind  | agent       | model           |
      | {task:Ship the search} | agent | claude-code | claude-opus-5-5 |
    When I visit "/admin/tasks?filter=<filter>&q=<query>"
    Then the task rows read "<found>"

    Examples:
      | filter    | query                           | found                                                                |
      | next      | accountant                      | Email the accountant                                                 |
      | next      | elixir                          |                                                                      |
      | someday   | elixir                          | Learn Elixir                                                         |
      | next      | tag:ADMIN tag:ruby              | Ship the admin search                                                |
      | next      | contributor:Agent               | Ship the search                                                      |
      | next      | agent:claude-code               | Ship the search                                                      |
      | next      | model:claude-opus-5-5           | Ship the search                                                      |
      | next      | model:gpt-6                     |                                                                      |
      | next      | contributor:someone             |                                                                      |
      | next      | type:chore                      |                                                                      |
      | next      | tag:ruby search                 | Ship the search, Ship the admin search                               |
      | next      | project:aaronmallen-me          | Ship the site, Draft the site post                                   |
      | next      | project:Other-Gem               | Ship the gem                                                         |
      | next      | project:aaronmallen-me tag:ruby | Ship the site                                                        |
      | next      | project:nowhere                 |                                                                      |
      | completed | project:aaronmallen-me          | Shipped the site                                                     |

  Scenario Outline: A search for the label "<query>" finds the task it names first, then the titles
    Given the projects:
      | name    | key |
      | Podcast | POD |
    And the tasks:
      | title                            | tags   | project |
      | Email the accountant             | admin  |         |
      | Ship the search                  | ruby   |         |
      | Learn Elixir                     | elixir |         |
      | Mention POD-1 and 2 in the intro |        |         |
      | Record the intro                 |        | Podcast |
    When I visit "/admin/tasks?filter=next&q=<query>"
    Then the task rows read "<found>"

    Examples:
      | query | found                                              |
      | POD-1 | Record the intro, Mention POD-1 and 2 in the intro |
      | 2     | Ship the search, Mention POD-1 and 2 in the intro  |
      | ZZZ-1 |                                                    |

  Scenario: A search narrows by one tag, by the owner, and on completed
    Given the tasks:
      | title                | tags  | status |
      | Email the accountant | admin | open   |
      | Ship the search      | ruby  | open   |
      | Finished by hand     |       | done   |
    And the task_contributors table holds the rows:
      | task_id                | kind  | agent       | model           |
      | {task:Ship the search} | agent | claude-code | claude-opus-5-5 |
    When I visit "/admin/tasks?filter=next&q=tag:ruby"
    Then the task rows read "Ship the search"
    And the page field "Search tasks" by label holds "tag:ruby"
    When I visit "/admin/tasks?filter=next&q=contributor:owner"
    Then the task rows read "Email the accountant"
    When I visit "/admin/tasks?filter=completed&q=contributor:owner"
    Then the task rows read "Finished by hand"

  Scenario: The search field asks plainly, says so when nothing matches and carries the query to each tab
    Given the tasks:
      | title                |
      | Email the accountant |
      | Ship the search      |
    When I visit "/admin/tasks?filter=next&q="
    Then the task rows read "Email the accountant, Ship the search"
    And the page has "label.sr-only[for='tasks-q']"
    And the page has no "form[role='search'] .hint"
    And the page part "#tasks-q" has "placeholder" set to "search · tag:site…"
    And the page has no axe breaches in light or dark
    When I visit "/admin/tasks?filter=next&q=nothing here"
    Then the page part ".empty" reads "No matches in this list."
    When I visit "/admin/tasks?filter=next&q=ship"
    Then every page part ".task-tabs .screen-tab" has an "href" holding "q=ship"

  Scenario: A search finds matches past the first page and pages them
    Given the tasks:
      | title                | position |
      | Email the accountant | 1        |
    And 101 more tasks on next called "Ship the search"
    And the tasks:
      | title        | position |
      | Ship the fix | 999      |
    When I visit "/admin/tasks?filter=next&q=fix"
    Then the task rows read "Ship the fix"
    When I visit "/admin/tasks?filter=next&q=ship"
    Then the page has 100 of ".task-title"
    And the page part "nav.pager a[rel='next']" has "href" set to "/admin/tasks?filter=next&q=ship&page=2"
    When I visit "/admin/tasks?filter=next&q=ship&page=2"
    Then the task rows read "Ship the search 101, Ship the fix"
    And the page part "nav.pager a[rel='prev']" has "href" set to "/admin/tasks?filter=next&q=ship"
    And the page field "Search tasks" by label holds "ship"
    When I visit "/admin/tasks?filter=next&q=ship&page=3"
    Then the server answers 404

  Scenario: The filters offer no type select and ignore a type in the address
    Given the tasks:
      | title                |
      | Email the accountant |
      | Ship the search      |
    When I visit "/admin/tasks?filter=next&type=1"
    Then the task rows read "Email the accountant, Ship the search"
    And the page has no "select[name='type']"
    And the page has no "a[href='/admin/tasks/types']"
    When I visit "/admin/tasks/types"
    Then the server answers 404

  Scenario: The archive groups finished work by day, newest first
    Given the tasks:
      | title                | status |
      | Seed the queue       | done   |
      | Move the toggle      | done   |
      | Index the activities | done   |
      | Ship the screen      | done   |
    And the tasks finished at:
      | title                | at              |
      | Seed the queue       | today - 2 09:00 |
      | Move the toggle      | today - 1 11:00 |
      | Index the activities | today - 1 15:00 |
      | Ship the screen      | today 08:00     |
    When I visit "/admin/tasks?filter=completed"
    Then the page has 3 of ".day-date"
    And the page part ".day-date" reads "{long:today}"
    And the task rows read "Ship the screen, Index the activities, Move the toggle, Seed the queue"
    And the page parts ".day-note" read "Today · 1 | Yesterday · 2 | 2 days ago · 1"
    And the page has 3 of ".day-head.sunk"
    And the page has 3 of ".task-day > .day-head + .task-day-rows"
    And the page part ".task-tab-count >> nth=-1" reads "4"
    And the page part ".card-note" reads "4 shown · logged to the activity feed"
    And the page has no "form[action*='/move/'], [data-task-grip], .task-capture, nav.pager"
    And the page has no axe breaches in light or dark
    When I visit "/admin/tasks?filter=completed&q=toggle"
    Then the task rows read "Move the toggle"
    When I visit "/admin/tasks?filter=completed&q=nothing here"
    Then the page part ".empty" reads "Nothing completed matches these filters."

  Scenario: An empty archive says nothing is finished yet
    When I visit "/admin/tasks?filter=completed"
    Then the page part ".empty" reads "Nothing completed yet."

  Scenario Outline: The archive from <from> to <to> lists <found>
    Given the tasks:
      | title                | status   |
      | Seed the queue       | done     |
      | Move the toggle      | done     |
      | Index the activities | done     |
      | Ship the screen      | done     |
      | Drop the idea        | canceled |
      | Email the accountant | open     |
    And the tasks finished at:
      | title                | at              |
      | Seed the queue       | today - 3 23:00 |
      | Move the toggle      | today - 2 00:00 |
      | Index the activities | today - 1 23:00 |
      | Drop the idea        | today - 1 12:00 |
      | Ship the screen      | today 00:00     |
    When I visit "/admin/tasks?filter=completed&from=<from>&to=<to>&q=<query>"
    Then the task rows read "<found>"

    Examples:
      | from            | to              | query  | found                                                                   |
      | {day:today - 2} | {day:today - 1} |        | Index the activities, Drop the idea, Move the toggle                    |
      | {day:today}     | {day:today}     |        | Ship the screen                                                         |
      | {day:today - 1} | {day:today - 1} |        | Index the activities, Drop the idea                                     |
      | {day:today - 3} | {day:today}     | toggle | Move the toggle                                                         |
      | nope            | {day:today}     |        | Ship the screen, Index the activities, Drop the idea, Move the toggle, Seed the queue |
      | 2026-02-30      | {day:today}     |        | Ship the screen, Index the activities, Drop the idea, Move the toggle, Seed the queue |
      | {day:today - 1} |                 |        | Ship the screen, Index the activities, Drop the idea, Move the toggle, Seed the queue |
      | {day:today}     | {day:today - 2} |        | Ship the screen, Index the activities, Drop the idea, Move the toggle, Seed the queue |

  Scenario: A range leaves the open lists alone and blames the filters when it is empty
    Given the tasks:
      | title                | status |
      | Email the accountant | open   |
      | Ship the screen      | done   |
    When I visit "/admin/tasks?filter=next&from={day:today}&to={day:today}"
    Then the task rows read "Email the accountant"
    When I visit "/admin/tasks?filter=completed&from={day:today - 9}&to={day:today - 8}"
    Then the page part ".empty" reads "Nothing completed matches these filters."

  Scenario: A range stays in the search form, on the completed tab and the pager, and offers to clear it
    Given 101 more tasks on next called "Finished"
    And the database runs:
      """
      UPDATE tasks SET status = 'done', completed_at = now() - interval '1 day'
      """
    When I visit "/admin/tasks?filter=completed&from={day:today - 2}&to={day:today - 1}&q=the"
    Then the page field "input[type=hidden][name='from']" holds "{day:today - 2}"
    And the page field "input[type=hidden][name='to']" holds "{day:today - 1}"
    And the page part ".task-tabs .screen-tab >> nth=-1" has "href" set to "/admin/tasks?filter=completed&q=the&from={day:today - 2}&to={day:today - 1}"
    And every page part ".task-tabs .screen-tab:not(:last-child)" has an "href" without "from="
    And the page has "a.bt[href='/admin/tasks?filter=completed&q=the']"
    And the page part "a[aria-label='Clear the date range']" reads "{short:today - 2} → {short:today - 1}"
    When I visit "/admin/tasks?filter=completed&from={day:today - 3}&to={day:today - 1}"
    Then the page part "nav.pager a[rel='next']" has "href" set to "/admin/tasks?filter=completed&from={day:today - 3}&to={day:today - 1}&page=2"
    When I visit "/admin/tasks?filter=completed"
    Then the page has no "a[aria-label='Clear the date range']"

  Scenario: The archive pages the most recently closed tasks first, with searches
    Given 100 more tasks on next called "Older"
    And the tasks:
      | title           | status |
      | Ship the screen | done   |
      | Seed the queue  | done   |
    And the database runs:
      """
      UPDATE tasks SET status = 'done', completed_at = now() - interval '3 days' WHERE title LIKE 'Older%';
      UPDATE tasks SET completed_at = now() WHERE title = 'Ship the screen';
      UPDATE tasks SET completed_at = now() - interval '4 days' WHERE title = 'Seed the queue'
      """
    When I visit "/admin/tasks?filter=completed"
    Then the page has 100 of ".task-title"
    And the page part ".task-title" reads "Ship the screen"
    And the page part "nav.pager a[rel='next']" has "href" set to "/admin/tasks?filter=completed&page=2"
    And the page has no "nav.pager a[rel='prev']"
    And the page part ".task-tab-count >> nth=-1" reads "102"
    When I visit "/admin/tasks?filter=completed&page=2"
    Then the page part ".task-title >> nth=-1" reads "Seed the queue"
    And the page part "nav.pager a[rel='prev']" has "href" set to "/admin/tasks?filter=completed"
    And the page has no "nav.pager a[rel='next']"
    When I visit "/admin/tasks?filter=completed&page=3"
    Then the server answers 404
    When I visit "/admin/tasks?filter=completed&q=seed"
    Then the task rows read "Seed the queue"
    When I visit "/admin/tasks?filter=completed&q=e&page=2"
    Then the page part "nav.pager a[rel='prev']" has "href" set to "/admin/tasks?filter=completed&q=e"
