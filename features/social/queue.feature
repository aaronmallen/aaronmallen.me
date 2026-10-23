Feature: Social queue
  The social page lists queued, drafted and posted items, pages through them, and lets me edit or remove what has
  not gone out.

  Background:
    Given Mastodon and Bluesky are connected
    And I am signed in to the admin

  Scenario: Each filter shows only its own items, queued first
    Given the social posts:
      | text    | status    | at                   |
      | waiting | scheduled | in 90 minutes        |
      | a draft | draft     |                      |
      | posted  | posted    | 2026-09-13T02:30:00Z |
    When I visit "/admin/social"
    Then the social queue shows "waiting"
    And the page has no axe breaches in light or dark
    When I open the social page at "?filter=posted"
    Then the social queue shows "posted"
    And the page has no axe breaches in light or dark
    When I open the social page at "?filter=drafts"
    Then the social queue shows "a draft"
    And the social page has 1 "input[name='filter'][value='drafts'][checked]"
    And the page has no axe breaches in light or dark
    When I open the social page at "?filter=burned"
    Then the social queue shows "waiting"

  Scenario: Choosing a filter submits it
    Given the social posts:
      | text    | status |
      | a-draft | draft  |
    When I visit "/admin/social"
    And I choose "drafts" on the social page
    Then I am on "/admin/social?filter=drafts"

  Scenario: A thread shows as one item with its parts and line breaks
    Given the social posts:
      | text                     | status    |
      | one // two\nlines // six | scheduled |
    When I visit "/admin/social"
    Then the social page has 1 "[data-social-item]"
    And the social queue shows "one // two\nlines // six"

  Scenario: Each network is named and colored, and a sent post links out in a new tab
    Given the social posts:
      | text   | status | targets          | at                   |
      | posted | posted | mastodon,bluesky | 2026-09-13T02:30:00Z |
    And the social_post_deliveries table holds:
      | social_post_id | network  | remote_url              | remote_ids |
      | 1              | mastodon | https://ruby.social/@a/1 | {7}       |
    When I open the social page at "?filter=posted"
    Then the social page has 1 "a.sq-network.mastodon[href='https://ruby.social/@a/1'][target='_blank']"
    And the social page has 1 "span.sq-network.bluesky"
    And the social page shows "Sep 12" in ".sq-time"
    And the social page has no ".sq-fail"

  Scenario: A queued item names its network
    Given the social posts:
      | text    | status    |
      | waiting | scheduled |
    When I visit "/admin/social"
    Then the social page shows "Mastodon" in ".sq-network"

  Scenario: A sent network with no address shows without a link
    Given the social posts:
      | text   | status | at         |
      | posted | posted | 1 hour ago |
    And the social_post_deliveries table holds:
      | social_post_id | network  |
      | 1              | mastodon |
    When I open the social page at "?filter=posted"
    Then the social page shows "Mastodon" in "span.sq-network"
    And the social page has no "a.sq-network"

  Scenario: A network that went to two accounts links each sent post by its account
    Given my Mastodon account "ada" on "hachyderm.io" is connected
    And the social posts:
      | text   | status | at         |
      | posted | posted | 1 hour ago |
    And the social_post_deliveries table holds:
      | social_post_id | network  | connection_id | remote_url      |
      | 1              | mastodon | 1             | https://e.test/1 |
      | 1              | mastodon | 3             | https://e.test/2 |
    When I open the social page at "?filter=posted"
    Then the social page has 1 "a.sq-network[href='https://e.test/1']"
    And the social page shows "@aaronmallen@ruby.social" in "a.sq-network[href='https://e.test/1']"
    And the social page shows "@ada@hachyderm.io" in "a.sq-network[href='https://e.test/2']"

  Scenario Outline: The queue counts down to an upcoming item
    Given the social posts:
      | text    | status    | at   |
      | waiting | scheduled | <at> |
    When I visit "/admin/social"
    Then the social page shows "<shown>" in ".sq-time"

    Examples:
      | at                    | shown          |
      | in 90 minutes         | in 1 hour      |
      | in 26 hours           | in 1 day       |
      | in 330 seconds        | in 5 minutes   |
      | in 30 seconds         | in a moment    |

  Scenario: Engagement sums across the networks
    Given the social posts:
      | text   | status | targets          | at         |
      | posted | posted | mastodon,bluesky | 1 hour ago |
    And the social_post_deliveries table holds:
      | social_post_id | network  | like_count | repost_count | reply_count |
      | 1              | mastodon | 3          | 1            | 2           |
      | 1              | bluesky  | 4          | 5            | 0           |
    When I open the social page at "?filter=posted"
    Then the social page lists "[data-social-engagement]" as "7 // 6 // 2"

  Scenario: A delivery that gave up reads failed with its last error, and one with a retry left says so
    Given the social posts:
      | text  | status    |
      | one   | scheduled |
      | two   | scheduled |
    And the social_post_deliveries table holds:
      | social_post_id | network  | failed | error        |
      | 1              | mastodon | true   | rate limited |
      | 2              | mastodon | false  | rate limited |
    When I visit "/admin/social"
    Then the social page shows "Mastodon failed" in ".sq-network.bad"
    And the social page shows "Mastodon: rate limited" in ".sq-fail"
    And the social page shows "Mastodon: rate limited · retry queued" in ".sq-fail"
    And the social page has no "[data-social-edit]"
    And the social page has no "[data-social-remove-item]"

  Scenario: Queued items and drafts offer Edit and Remove, posted items do not
    Given the social posts:
      | text    | status    | at         |
      | waiting | scheduled | in 1 hour  |
      | a draft | draft     |            |
      | posted  | posted    | 1 hour ago |
    When I visit "/admin/social"
    Then the social page has 1 "[data-social-remove-item]"
    When I open the social page at "?filter=drafts"
    Then the social page has 1 "[data-social-remove-item]"
    When I open the social page at "?filter=posted"
    Then the social page has no "[data-social-remove-item]"

  Scenario: Empty filters say so
    When I visit "/admin/social"
    Then the social page shows "Nothing waiting" in ".empty"
    When I open the social page at "?filter=posted"
    Then the social page shows "Nothing posted yet" in ".empty"
    And the page has no axe breaches in light or dark

  Scenario: The queue pages oldest first, counts every queued post and links both ways
    Given 101 social posts scheduled "an hour" apart
    And the social posts:
      | text    | status |
      | a draft | draft  |
    When I visit "/admin/social"
    Then the social page has 100 ".sq-item"
    And the first social queue item reads "scheduled 1"
    And the social page has 1 "nav.pager a[rel='next'][href='/admin/social?filter=queued&page=2']"
    And the social page has no "nav.pager a[rel='prev']"
    When I open the social page at "?filter=queued&page=2"
    Then the social queue shows "scheduled 101"
    And the social page has 1 "nav.pager a[rel='prev'][href='/admin/social?filter=queued']"
    And the social page has no "nav.pager a[rel='next']"
    And the social page shows "101 queued" in ".page-head-sub"
    When I open the social page at "?filter=queued&page=3"
    Then the social page answered 404
    When I open the social page at "?page=0"
    Then the social page answered 404

  Scenario: Drafts and posted items page newest first
    Given 101 social posts draft "a day" apart
    And 101 social posts posted "a day" apart
    When I open the social page at "?filter=drafts&page=2"
    Then the social queue shows "draft 1"
    And the social page has 1 "nav.pager a[rel='prev'][href='/admin/social?filter=drafts']"
    When I open the social page at "?filter=posted"
    Then the first social queue item reads "posted 1"
    And the social page has 1 "nav.pager a[rel='next'][href='/admin/social?filter=posted&page=2']"

  Scenario: One page draws no pager
    Given the social posts:
      | text | status | at         |
      | only | posted | 1 hour ago |
    When I open the social page at "?filter=posted"
    Then the social queue shows "only"
    And the social page has no "nav.pager"

  Scenario: Removing a queued item or a draft deletes it and goes back to its filter
    Given the social posts:
      | text | status    | at  |
      | bye  | scheduled | now |
      | bye  | draft     |     |
    When I remove social post 1 from the queued queue
    Then social post 1 is gone
    When I remove social post 2 from the drafts queue
    Then social post 2 is gone
    And I am on "/admin/social?filter=drafts"
    And the social toast says "Removed from queue"

  Scenario: A posted item cannot be removed
    Given the social posts:
      | text | status | at  |
      | bye  | posted | now |
    When I remove social post 1 from the queued queue
    Then the social page answered 404
    And social post 1 is posted

  Scenario: An item mid-delivery is kept with its delivery
    Given the social posts:
      | text | status    | at  |
      | bye  | scheduled | now |
    And the social_post_deliveries table holds:
      | social_post_id | network  | error        |
      | 1              | mastodon | rate limited |
    When I remove social post 1 from the queued queue
    Then I am on "/admin/social?filter=queued"
    And the social toast says "Already posted · nothing was removed"
    And social post 1 is scheduled
    And the social_post_deliveries table holds 1 rows

  Scenario: Removing an item that is not there answers 404
    When I remove social post 1 from the queued queue
    Then the social page answered 404

  Scenario: Editing a draft from the queue fills the composer and saves back to it
    Given the social posts:
      | text    | status    | at            |
      | waiting | scheduled | in 90 minutes |
      | a-draft | draft     |               |
    When I visit "/admin/social"
    And I choose "drafts" on the social page
    Then I am on "/admin/social?filter=drafts"
    When I click "Edit"
    Then the social composer holds "a-draft"
    When I write "rewritten" in social part 1
    And I click "Post now"
    Then the social toast says "Queued for Mastodon"
    And social post 2 has the parts "rewritten"
    And social post 2 is scheduled
    And there are 2 social posts
