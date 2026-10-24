Feature: The project board's filter bar
  The filter bar narrows a project's board and list with a GitHub style query, counts the matches and keeps
  the query in every link the board offers.

  Background:
    Given I am signed in to the admin
    And the projects:
      | name    | key |
      | Podcast | POD |
    And the project tasks:
      | title            | project | tags   | status      |
      | Record the intro | Podcast | audio  | open        |
      | Book a guest     | Podcast | guests | in_progress |

  Scenario: The bar shows no match line without a query, and offers the project tags button beside it
    When I visit "/admin/projects/{project:Podcast}"
    Then the page has no ".task-filter-meta"
    And the page part ".task-filter-row > button" holds "Tags"
    And the page has no axe breaches in light or dark

  Scenario: A query narrows the board and the list, counts the matches and shows what it ignored
    When I visit "/admin/projects/{project:Podcast}?q=label:audio"
    Then the page field "input[name='q']" holds "label:audio"
    And the page has 1 of ".kb .kc"
    And the page part ".kb .kc" holds "Record the intro"
    And the page has 1 of ".kb-list .kli"
    And the page part ".task-filter-meta a:has-text('clear filter')" has "href" set to "/admin/projects/1"
    And the page part "a:has-text('Clear filter')" has "href" set to "/admin/projects/1"
    And the page has "a[href='/admin/projects/1?q=label:audio&view=list']"
    And the page part "input[name='return_to']" has "value" set to "/admin/projects/1?q=label:audio"
    And the page has no axe breaches in light or dark
    When I visit "/admin/projects/{project:Podcast}?q=is:doing+guest"
    Then the page has 1 of ".kb .kc"
    And the page part ".kb .kc" holds "Book a guest"
    When I visit "/admin/projects/{project:Podcast}?q=-label:audio"
    Then the page part ".task-filter-meta" holds "1 of 2 tasks match"
    When I visit "/admin/projects/{project:Podcast}?q=author:me+is:soon+is:open"
    Then the page part ".task-filter-meta .task-filter-ignored" holds "ignored author:me is:soon"

  Scenario: Loading more keeps the query
    Given 20 more tasks in "Podcast" tagged "audio"
    When I visit "/admin/projects/{project:Podcast}?q=label:audio"
    Then the page part "form:has(button.bt.gh) input[name='q']" has "value" set to "label:audio"

  Scenario: The bar suggests the qualifiers, the project's tags and the columns
    Given the tags table holds the rows:
      | name | color   | scope   |
      | home | mk-blue | private |
    When I visit "/admin/projects/{project:Podcast}"
    Then the filter bar suggests:
      | qualifiers | label: \| -label: \| no:label \| column: |
      | columns    | in_progress = in progress |
    And the project filter tags are "audio, guests"
    When I click the page part "input[name='q']"
    Then the page parts "#task-filter-list [role=option]" include one starting "label:" and one starting "is:open"
    When I type "label:gu" in "input[name='q']"
    Then the page parts "#task-filter-list [role=option]" read "#guests"
    When I set the page field "input[name='q']" to ""
    And I type "column:re" in "input[name='q']"
    Then the page parts "#task-filter-list [role=option]" include one starting "column:ready" and one starting "column:ready"

  Scenario: Picking a tag filters the board in place and keeps the query on reload
    When I visit "/admin/projects/{project:Podcast}"
    And I type "label:aud" in "input[name='q']"
    And I press "Enter"
    Then the page part ".task-filter-meta" holds "1 of 2 tasks match"
    And I am on "/admin/projects/1?q=label%3Aaudio+"
    When I visit "/admin/projects/1?q=label%3Aaudio+"
    Then the page field "input[name='q']" holds "label:audio"

  Scenario: Picking a suggestion with the arrow keys filters the board
    When I visit "/admin/projects/{project:Podcast}"
    And I type "is:do" in "input[name='q']"
    And I press "ArrowDown"
    And I press "Enter"
    Then the page part ".task-filter-meta" holds "1 of 2 tasks match"
    And I am on "/admin/projects/1?q=is%3Adoing+"
