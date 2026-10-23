Feature: Admin saved views
  The tasks, posts, journal and activity screens each keep a bar of saved views. The owner saves the filters on
  screen under a name, opens a view to get them back, and renames, changes or deletes it.

  Background:
    Given I am signed in to the admin

  Scenario Outline: The <screen> screen lists its own views, marks the open one and holds the Save view form
    Given a saved view "Mine" on the <screen> screen with the filters:
      """
      <filters>
      """
    And a saved view "Elsewhere" on the <other> screen
    When I visit "<url>"
    Then the saved views bar lists "Mine"
    And the saved view "Mine" links to "<url>"
    And the saved views page shows ".saved-view-link.current[aria-current='page']" reading "Mine"
    And the saved views page shows "<bar> > .saved-views"
    And the saved views page's "form[action='/admin/saved-views'] input[type='hidden'][name='screen']" holds "<screen>"
    And the saved views page's "form[action='/admin/saved-views'] input[type='hidden'][name='return_to']" holds "<url>"

    Examples:
      | screen   | other | url                                                         | filters                                           | bar                |
      | tasks    | posts | /admin/tasks?filter=next&q=accountant                       | {"filter": "next", "q": "accountant"}             | .screen-tabs-side  |
      | posts    | tasks | /admin/posts?status=draft                                   | {"status": "draft"}                               | .screen-tabs-side  |
      | journal  | tasks | /admin/journal?q=commute                                    | {"q": "commute"}                                  | .screen-tabs-side  |
      | activity | tasks | /admin/activity?types%5Bpost%5D=1&types%5Bcommit%5D=0&q=ship | {"types": {"post": "1", "commit": "0"}, "q": "ship"} | .activity-bar      |

  Scenario Outline: Saving on the <screen> screen keeps the filters it reads and returns with a toast
    When I post the Save view form on the <screen> screen named "Weekly" for "<query>" adding "page=2&stray=x"
    Then the saved views admin post sends me to "<base>?<query>"
    And the stored saved views are:
      """
      [{"name": "Weekly", "screen": "<screen>", "filters": <filters>}]
      """
    When I follow the saved views admin post
    Then the saved views toast says "View saved"

    Examples:
      | screen   | base            | query                                              | filters                                           |
      | tasks    | /admin/tasks    | filter=next&q=accountant                           | {"filter": "next", "q": "accountant"}             |
      | posts    | /admin/posts    | status=draft                                       | {"status": "draft"}                               |
      | journal  | /admin/journal  | q=commute                                          | {"q": "commute"}                                  |
      | activity | /admin/activity | types%5Bpost%5D=1&types%5Bcommit%5D=0&q=ship       | {"types": {"post": "1", "commit": "0"}, "q": "ship"} |

  Scenario Outline: A blank name on the <screen> screen saves nothing and says why
    When I post the Save view form on the <screen> screen named " " for "<query>"
    And I follow the saved views admin post
    Then the saved views toast says "Nothing saved · give the view a name of 100 characters or fewer"
    And the stored saved views are:
      """
      []
      """

    Examples:
      | screen   | query                    |
      | tasks    | filter=next&q=accountant |
      | posts    | status=draft             |
      | journal  | q=commute                |
      | activity | q=ship                   |

  Scenario Outline: Saving from the <screen> screen's bar keeps the name and stays on the filters
    When I visit "<first>"
    And I save the view "Weekly" from the saved views bar
    Then the saved views page is at "<first>"
    And the database answers "Weekly, <screen>" for:
      """
      select name, screen from saved_views
      """

    Examples:
      | screen   | first                                 |
      | tasks    | /admin/tasks?filter=next&q=accountant |
      | posts    | /admin/posts?status=draft             |
      | journal  | /admin/journal?q=commute              |
      | activity | /admin/activity?q=ship                |

  Scenario Outline: A view saved on the <screen> screen opens with its filters set
    When I visit "<first>"
    And I save the view "Weekly" from the saved views bar
    And I visit "<base>"
    And I click the link "Weekly"
    Then the saved views page is at "<first>"

    Examples:
      | screen   | first                                 | base            |
      | tasks    | /admin/tasks?filter=next&q=accountant | /admin/tasks    |
      | posts    | /admin/posts?status=draft             | /admin/posts    |
      | journal  | /admin/journal?q=commute              | /admin/journal  |
      | activity | /admin/activity?q=ship                | /admin/activity |

  Scenario Outline: Renaming a view on the <screen> screen shows the new name with a toast
    When I visit "<first>"
    And I save the view "Weekly" from the saved views bar
    And I rename the saved view "Weekly" to "Monthly"
    Then the saved views toast says "View renamed"
    And the saved views bar lists "Monthly"

    Examples:
      | screen   | first                                 |
      | tasks    | /admin/tasks?filter=next&q=accountant |
      | posts    | /admin/posts?status=draft             |
      | journal  | /admin/journal?q=commute              |
      | activity | /admin/activity?q=ship                |

  Scenario Outline: A view on the <screen> screen takes the filters on screen
    When I visit "<first>"
    And I save the view "Weekly" from the saved views bar
    And I visit "<second>"
    And I point the saved view "Weekly" at the filters on screen
    Then the saved views toast says "View now holds these filters"
    And the saved view "Weekly" links to "<second>"

    Examples:
      | screen   | first                                 | second                         |
      | tasks    | /admin/tasks?filter=next&q=accountant | /admin/tasks?filter=someday    |
      | posts    | /admin/posts?status=draft             | /admin/posts?status=published  |
      | journal  | /admin/journal?q=commute              | /admin/journal?q=ruby          |
      | activity | /admin/activity?q=ship                | /admin/activity?q=deploy       |

  Scenario Outline: Deleting a view on the <screen> screen takes it off the list
    When I visit "<first>"
    And I save the view "Weekly" from the saved views bar
    And I delete the saved view "Weekly" and confirm
    Then the saved views toast says "View deleted"
    And the saved views bar lists ""
    And the database answers "0" for:
      """
      select count(*) from saved_views
      """

    Examples:
      | screen   | first                                 |
      | tasks    | /admin/tasks?filter=next&q=accountant |
      | posts    | /admin/posts?status=draft             |
      | journal  | /admin/journal?q=commute              |
      | activity | /admin/activity?q=ship                |

  Scenario: A view saved from the Completed tab over a range of days leaves out a task closed outside it
    Given the database runs:
      """
      insert into tasks (title, list, status, position, completed_at) values
        ('In range', 'next', 'done', 1, ((now() at time zone 'America/Chicago')::date - 3 + time '12:00') at time zone 'America/Chicago'),
        ('Out of range', 'next', 'done', 2, ((now() at time zone 'America/Chicago')::date - 1 + time '12:00') at time zone 'America/Chicago');
      insert into saved_views (name, screen, filters)
      select 'Done last week', 'tasks', jsonb_build_object(
        'filter', 'completed',
        'from', ((now() at time zone 'America/Chicago')::date - 4)::text,
        'to', ((now() at time zone 'America/Chicago')::date - 3)::text)
      """
    When I visit "/admin/tasks"
    And I click the link "Done last week"
    Then the saved views page shows ".task-title" reading "In range"
    And I do not see "Out of range"

  Scenario: A view holding filters the screen no longer knows links to the ones it does
    Given a saved view "Stale" on the tasks screen with the filters:
      """
      {"filter": "gone", "colour": "red"}
      """
    When I visit "/admin/tasks"
    Then the saved view "Stale" links to "/admin/tasks?filter=gone"

  Scenario: Renaming a view keeps the filters the screen no longer knows
    Given a saved view "Stale" on the tasks screen with the filters:
      """
      {"filter": "gone", "colour": "red"}
      """
    When I post to the saved views admin at "/admin/saved-views/1" with:
      | saved_view[name] | Fresh        |
      | return_to        | /admin/tasks |
    Then the stored saved views are:
      """
      [{"name": "Fresh", "screen": "tasks", "filters": {"filter": "gone", "colour": "red"}}]
      """

  Scenario: A filter value the screen no longer takes opens at the screen's default
    Then visiting "/admin/tasks?filter=gone" answers 200
    And the saved views page's ".task-tabs .screen-tab[aria-current='page']" begins with "today"

  Scenario: Renaming or changing a view that is gone answers 404
    When I post to the saved views admin at "/admin/saved-views/999999" with:
      | saved_view[name] | New |
    Then the saved views admin post answers 404
    When I post to the saved views admin at "/admin/saved-views/999999/change" with:
      | filters[q] | x |
    Then the saved views admin post answers 404

  Scenario: Saving a filter that is not text saves nothing
    When I post to the saved views admin at "/admin/saved-views" with:
      | screen           | tasks        |
      | filters[q][a]    | b            |
      | saved_view[name] | Odd          |
      | return_to        | /admin/tasks |
    Then the stored saved views are:
      """
      []
      """

  Scenario: A return path that leaves the admin sends me home
    Given a saved view "Old" on the tasks screen
    When I post to the saved views admin at "/admin/saved-views/1/delete" with:
      | return_to | https://example.com/ |
    Then the saved views admin post sends me to "/admin"

  Scenario Outline: The <screen> screen with a saved view passes axe
    Given a saved view "Mine" on the <screen> screen
    When I visit "<base>"
    Then the page has no axe breaches in light or dark

    Examples:
      | screen   | base            |
      | tasks    | /admin/tasks    |
      | posts    | /admin/posts    |
      | journal  | /admin/journal  |
      | activity | /admin/activity |
