Feature: Acting on many posts at once
  Ticking posts shows a bar that tags or deletes them together, and a batch changes all or nothing.

  Background:
    Given I am signed in to the admin

  Scenario: The bar shows once a post is ticked and select all ticks the page
    Given I wrote a draft post "first draft"
    And I wrote a draft post "second draft"
    And I wrote a published post "live post"
    When I visit "/admin/posts"
    Then the bar actions show in the page as served, so they work with scripts off
    And the bulk actions are hidden
    And the post bulk boxes are named "Select first draft, Select second draft, Select live post" in any order
    When I tick the post "first draft"
    Then the bulk actions are shown
    When I tick every post on the page
    Then 3 posts are ticked
    And the page has no axe breaches in light or dark

  Scenario: Deleting ticked drafts asks first and says how many went
    Given I wrote a draft post "first draft"
    And I wrote a draft post "second draft"
    And I wrote a draft post "kept draft"
    When I visit "/admin/posts"
    And I tick the post "first draft"
    And I tick the post "second draft"
    And I delete the ticked posts
    Then the post admin shows "Delete the ticked drafts? This cannot be undone."
    When I confirm the post action
    Then the post toast says "Deleted 2 drafts"
    And the posts table holds 1 rows

  Scenario Outline: A batch with a post that is not a draft deletes nothing and names it
    Given I wrote a draft post "first draft"
    And I wrote a <status> post "<title>"
    When I visit "/admin/posts"
    And I tick every post on the page
    And I delete the ticked posts
    And I confirm the post action
    Then the post toast says "Nothing changed · <title> is not a draft"
    And the posts table holds 2 rows

    Examples:
      | status    | title            |
      | published | Out in the world |
      | scheduled | Coming soon      |

  Scenario: Enter in the tag field tags the ticked posts
    Given I wrote a published post "live post"
    When I visit "/admin/posts"
    And I tick the post "live post"
    And I tag the ticked posts "ruby" with Enter
    Then the post toast says "Tagged 1 post ruby"
    And the post "live post" carries the tags "ruby"

  Scenario: Tagging adds the tag to the ticked posts, keeps their others and marks them updated
    Given I wrote a draft post "One" with:
      | tags       | ruby       |
      | updated_at | 1 hour ago |
    And I wrote a published post "Two" with:
      | updated_at | 1 hour ago |
    And I wrote a draft post "Left" with:
      | tags | ruby |
    And I visit "/admin/posts"
    When I send the post bulk form with "tag" on "One, Two" and:
      | tag |  Hanami  |
    Then the post toast says "Tagged 2 posts hanami"
    And the post "One" carries the tags "hanami, ruby"
    And the post "Two" carries the tags "hanami"
    And the post "Left" carries the tags "ruby"
    And the post "Two" was touched since "1 hour ago"

  Scenario: Tagging a post that has the tag keeps one and leaves it as it was
    Given I wrote a draft post "One" with:
      | tags       | ruby       |
      | updated_at | 1 hour ago |
    And I visit "/admin/posts"
    When I send the post bulk form with "tag" on "One" and:
      | tag | ruby |
    Then the post "One" carries the tags "ruby"
    And the post "One" was not touched since "1 hour ago"

  Scenario: Untagging takes the tag off the ticked posts and marks them updated
    Given I wrote a draft post "One" with:
      | tags | ruby, hanami |
    And I wrote a published post "Two" with:
      | tags       | ruby       |
      | updated_at | 1 hour ago |
    And I wrote a draft post "Left" with:
      | tags | ruby |
    And I wrote a draft post "Without" with:
      | tags       | hanami     |
      | updated_at | 1 hour ago |
    And I visit "/admin/posts"
    When I send the post bulk form with "untag" on "One, Two, Without" and:
      | tag |  Ruby  |
    Then the post toast says "Took ruby off 3 posts"
    And the post "One" carries the tags "hanami"
    And the post "Two" carries the tags ""
    And the post "Left" carries the tags "ruby"
    And the post "Two" was touched since "1 hour ago"
    And the post "Without" was not touched since "1 hour ago"

  Scenario Outline: A batch with a post that is gone changes nothing and names it
    Given I wrote a draft post "One" with:
      | tags | ruby |
    And I visit "/admin/posts"
    When I send the post bulk form with "<act>" on "One, #999" and:
      | tag | hanami |
    Then the post toast says "Nothing changed · #999 is gone"
    And the posts table holds 1 rows
    And the post "One" carries the tags "ruby"

    Examples:
      | act    |
      | delete |
      | tag    |
      | untag  |

  Scenario Outline: A refused batch says why and changes nothing
    Given I wrote a draft post "One"
    And I visit "/admin/posts"
    When I send the post bulk form with "<act>" on "One" and:
      | tag | <tag> |
    Then the post toast says "<toast>"
    And the posts table has a row with:
      | title | status |
      | One   | draft  |
    And the post "One" carries the tags ""

    Examples:
      | act     | tag        | toast                                                               |
      | tag     |       | Type a tag first                                                    |
      | untag   |            | Type a tag first                                                    |
      | tag     | not a tag! | Nothing changed · a tag takes lowercase letters, numbers and dashes |
      | publish |            | Nothing changed · pick an action from the bar                       |

  Scenario: Delete ignores the tag field
    Given I wrote a draft post "One"
    And I visit "/admin/posts"
    When I send the post bulk form with "delete" on "One" and:
      | tag | not a tag! |
    Then the posts table holds 0 rows

  Scenario: A batch with no tick asks for one
    Given I wrote a draft post "One"
    And I visit "/admin/posts"
    When I send the post form to "/admin/posts/bulk" with:
      | act | delete |
    Then the post toast says "Tick a post first"

  Scenario: A batch of more than 100 posts changes none
    Given I wrote 101 draft posts
    And I visit "/admin/posts"
    When I send the post bulk form with "delete" on every post
    Then the post toast says "Tick 100 posts or fewer"
    And the posts table holds 101 rows

  Scenario: A batch goes back to the filter and page it came from
    Given I wrote 102 draft posts
    And I visit "/admin/posts"
    When I send the post bulk form with "tag" on "draft 1" and:
      | tag    | ruby  |
      | status | draft |
    Then I am on "/admin/posts?status=draft"
    When I send the post bulk form with "delete" on "draft 1" and:
      | page | 2 |
    Then I am on "/admin/posts?status=all&page=2"
    When I send the post bulk form with "delete" on "draft 2" and:
      | page | 2 |
    Then I am on "/admin/posts?status=all"
    When I send the post bulk form with "delete" on "#999" and:
      | status | published |
    Then I am on "/admin/posts?status=published"

  Scenario: The bar keeps the filter and page, and is gone from an empty list
    Given I wrote 101 draft posts
    When I visit "/admin/posts?status=draft&page=2"
    Then the post bulk bar keeps "status" as "draft" and "page" as "2"
    When I visit "/admin/posts?status=scheduled"
    Then there is no bulk bar

  Scenario: A refused delete keeps the drafts' photos claimed
    Given the photos table holds:
      | key                                  | width | height | byte_size |
      | 0123456789abcdef0123456789abcdef.png | 10    | 10     | 100       |
    And I wrote a draft post "Pictured" with:
      | body | ![A photo](/media/0123456789abcdef0123456789abcdef.png) |
    And the photo_claims table holds:
      | photo_id | owner | owner_id |
      | 1        | post  | 1        |
    And I wrote a published post "Live"
    And I visit "/admin/posts"
    When I send the post bulk form with "delete" on "Pictured, Live" and:
      | tag |  |
    Then the post toast says "Nothing changed · Live is not a draft"
    And the photo_claims table has a row with:
      | photo_id | owner | owner_id |
      | 1        | post  | 1        |
