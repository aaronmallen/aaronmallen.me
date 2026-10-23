Feature: Admin tag page
  A tag's page groups everything that carries the name, a card for each kind. It draws the public tag on public
  kinds and the private tag on private kinds, shows ten items a card, and pages one kind on its own.

  Background:
    Given I am signed in to the admin

  Scenario: The tag page groups every kind that carries the name, and nothing else
    Given the tag manager holds these tags:
      | name | scope   | color    |
      | ruby | public  | mk-green |
      | ruby | private | mk-pink  |
    And these records carry tags for the tag manager:
      | kind           | title                          | tags |
      | published post | Ruby on a Pi                   | ruby |
      | project        | ruby-gem                       | ruby |
      | task           | Bump ruby                      | ruby |
      | journal entry  | "\nWrote some ruby\n\nall day" | ruby |
      | decision       | Pick a ruby                    | ruby |
      | published post | Rust on a Pi                   | rust |
      | task           | Bump rust                      | rust |
    When I visit "/admin/tags/ruby"
    Then the tag summary's "Posts" card lists "Ruby on a Pi"
    And the tag summary's "Projects" card lists "ruby-gem"
    And the tag summary's "Tasks" card lists "Bump ruby"
    And the tag summary's "Journal entries" card lists "Wrote some ruby"
    And the tag summary's "Decisions" card lists "Pick a ruby"
    And the tag summary's "Posts" card shows ".tag.green" reading "#ruby"
    And the tag summary's "Tasks" card shows ".tag.pink" reading "#ruby"
    And the tag summary's "Decisions" card shows ".tag.pink" reading "#ruby"
    And the tag manager shows "a[href='/admin/posts/1/edit']" reading "Ruby on a Pi"
    And the tag manager shows "a[href='/admin/projects/1/edit']" reading "ruby-gem"
    And the tag manager shows "a[href='/admin/tasks/1']" reading "Bump ruby"
    And the tag manager shows "a[href='/admin/journal?to=2026-09-07#day-2026-09-07']" reading "Wrote some ruby"
    And the tag manager shows "a[href='/admin/decisions/1']" reading "Pick a ruby"
    And the tag manager shows ".page-head-sub" reading "5 items carry this tag"
    And the tag manager shows "a[href='/admin/settings/tagging#tags']" reading "Tags"

  Scenario: The tag page lists finished and hidden items and marks each status
    Given these records carry tags for the tag manager:
      | kind             | title        | tags |
      | draft post       | A ruby draft | ruby |
      | archived project | old-gem      | ruby |
      | done task        | Shipped ruby | ruby |
      | canceled task    | Dropped ruby | ruby |
      | dropped decision | Ruby or not  | ruby |
    When I visit "/admin/tags/ruby"
    Then the tag summary's "Posts" card lists "A ruby draft"
    And the tag summary's "Projects" card lists "old-gem"
    And the tag summary's "Tasks" card lists 2 items
    And the tag summary's "Decisions" card lists "Ruby or not"
    And the tag summary's "Posts" card marks "A ruby draft" as "Draft"
    And the tag summary's "Projects" card marks "old-gem" as "Archived"
    And the tag summary's "Tasks" card marks "Shipped ruby" as "Done"
    And the tag summary's "Tasks" card marks "Dropped ruby" as "Canceled"
    And the tag summary's "Decisions" card marks "Ruby or not" as "Dropped"

  Scenario: The tag page caps each kind at ten and links to the rest
    Given 11 tasks for the tag manager carry the tag "ruby"
    And these records carry tags for the tag manager:
      | kind          | title      | tags |
      | journal entry | Ruby notes | ruby |
    When I visit "/admin/tags/ruby"
    Then the tag summary's "Tasks" card lists 10 items
    And the tag summary's "Tasks" card shows "a[href='/admin/tags/ruby?kind=tasks']" reading "All 11"
    And the tag summary's "Journal entries" card shows no "a[href*='kind=']"
    And the tag manager shows ".page-head-sub" reading "12 items carry this tag"

  Scenario: The tag page shows a page of one kind on its own, then the rest, then answers 404
    Given 105 tasks for the tag manager carry the tag "ruby"
    And these records carry tags for the tag manager:
      | kind          | title      | tags |
      | journal entry | Ruby notes | ruby |
    When I visit "/admin/tags/ruby?kind=tasks"
    Then the tag summary's "Tasks" card lists 100 items
    And the tag summary has no "Journal entries" card
    And the tag manager shows "a[href='/admin/tags/ruby?kind=tasks&page=2']"
    When I visit "/admin/tags/ruby?kind=tasks&page=2"
    Then the tag summary's "Tasks" card lists 5 items
    And visiting "/admin/tags/ruby?kind=tasks&page=3" answers 404

  Scenario: The tag page cuts a long title to 80 characters
    Given these records carry tags for the tag manager:
      | kind          | title  | tags |
      | journal entry | 85 × a | ruby |
    When I visit "/admin/tags/ruby"
    Then the tag summary's "Journal entries" card lists "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa…"

  Scenario: The tag page says so for a tag nothing carries
    Given the tag manager holds the private tags "unused"
    Then visiting "/admin/tags/unused" answers 200
    And the tag manager shows ".empty" reading "Nothing carries this tag yet."

  Scenario: The tag page says so for a kind nothing carries the tag on
    Given these records carry tags for the tag manager:
      | kind | title     | tags |
      | task | Bump ruby | ruby |
    When I visit "/admin/tags/ruby?kind=posts"
    Then the tag manager shows ".empty" reading "Nothing carries this tag yet."

  Scenario: The tag page answers 404 for a name no tag holds
    Then visiting "/admin/tags/nothing" answers 404
