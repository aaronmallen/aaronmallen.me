Feature: Publishing a draft from the list
  Each draft in the list has a publish button, which runs the editor's checks and goes back to the same list.

  Background:
    Given I am signed in to the admin

  Scenario: Only a draft gets a publish button, named for it and bound to the p key
    Given I wrote a draft post "Half done"
    And I wrote a scheduled post "Later"
    And I wrote a published post "Live"
    When I visit "/admin/posts"
    Then the post list has 1 publish button
    And the post row "Half done" offers "Publish Half done" on the p key, labelled "Publish the highlighted draft"

  Scenario: Publishing a draft goes back to the list that was open
    Given I wrote a draft post "Half done"
    When I visit "/admin/posts?status=draft"
    And I publish "Half done" from the list
    Then the post toast says "Published"
    And I am on "/admin/posts?status=draft"
    And the post "Half done" went live just now

  Scenario: A draft published from the list queues its cross-post as the editor does
    Given Mastodon and Bluesky are connected for cross-posts
    And I wrote a draft post "Hello" with:
      | syndication_enabled | true               |
      | syndication_targets | {mastodon,bluesky} |
    When I visit "/admin/posts"
    And I publish "Hello" from the list
    Then 1 cross-post waits to go out for "Hello"
    And the cross-post for "Hello" went out at its publish time

  Scenario: A draft with a publish time still to come is scheduled
    Given I wrote a draft post "Soon" with:
      | published_at | in 1 day |
    When I visit "/admin/posts"
    And I publish "Soon" from the list
    Then the post toast starts "Scheduled for "
    And the posts table has a row with:
      | title | status    |
      | Soon  | scheduled |

  Scenario: A scheduled post goes out now
    Given I wrote a scheduled post "Later"
    And I open the editor for "Later"
    When I send the post form to "/admin/posts/{Later}/publish" with:
      | status | all |
    Then the post toast says "Published"
    And the post "Later" went live just now

  Scenario: A published post stays as it was
    Given I wrote a published post "Out in the world" with:
      | published_at | 2026-09-01T00:00:00Z |
    And I open the editor for "Out in the world"
    When I send the post form to "/admin/posts/{Out in the world}/publish" with:
      | status | all |
    Then the post toast says "Nothing published · Out in the world is not a draft"
    And the post "Out in the world" goes live at "2026-09-01T00:00:00Z"

  Scenario: A draft that fails the editor's checks stays a draft
    Given Mastodon and Bluesky are connected for cross-posts
    And I wrote a draft post "Too loud" with:
      | syndication_enabled | true      |
      | syndication_targets | {bluesky} |
      | syndication_body    | {301 a}   |
    When I visit "/admin/posts"
    And I publish "Too loud" from the list
    Then the post toast says "Not published · open Too loud to fix it"
    And the posts table has a row with:
      | title    | status |
      | Too loud | draft  |

  Scenario: Publishing the last draft on a page falls back a page
    Given I wrote 101 draft posts
    When I visit "/admin/posts?status=draft&page=2"
    Then the publish form keeps the page 2
    When I publish "draft 1" from the list
    Then I am on "/admin/posts?status=draft"

  Scenario: A post that is not there is not found
    Given I visit "/admin/posts"
    When I send the post form to "/admin/posts/999/publish" with:
      | status | all |
    Then the post admin answers 404

  Scenario: A forged CSRF token is refused
    Given I wrote a draft post "Half done"
    And I visit "/admin/posts"
    When I send the post form to "/admin/posts/{Half done}/publish" with:
      | _csrf_token | forged |
    Then the post admin answers 403
    And the posts table has a row with:
      | title     | status |
      | Half done | draft  |
