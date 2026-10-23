Feature: A published post queues its cross-post
  Once a post with syndication on is published, its card's text is queued as a social post for each picked network
  that has an account.

  Background:
    Given a Mastodon account on "ruby.social" is connected
    And a Bluesky account "ada.example" is connected

  Scenario: The card's text is queued for every picked network at the time it was handed
    Given the posts table holds:
      | title | status    | published_at | syndication_enabled | syndication_body | syndication_targets |
      | Hello | published | 1 hour ago   | true                | In my own words  | {mastodon,bluesky}  |
    When blog post 1 is handed to syndication at "2026-01-01T00:00:00Z"
    Then the social_posts table has a row with:
      | post_id | status    | targets            |
      | 1       | scheduled | {mastodon,bluesky} |
    And the cross-post for blog post 1 went out at "2026-01-01T00:00:00Z"
    And social post 1 reads "In my own words"

  Scenario: A card with no text falls back to the title and the post's link
    Given the posts table holds:
      | title | status    | published_at | syndication_enabled | syndication_body | syndication_targets |
      | Hello | published | 1 hour ago   | true                |                  | {mastodon,bluesky}  |
    When blog post 1 is handed to syndication at "2026-01-01T00:00:00Z"
    Then the social_posts table holds 1 rows
    And social post 1 links to the site's "/writing/hello"

  Scenario: Only the networks the card picked are queued
    Given the posts table holds:
      | title | status    | published_at | syndication_enabled | syndication_body | syndication_targets |
      | Hello | published | 1 hour ago   | true                | In my own words  | {mastodon}          |
    When blog post 1 is handed to syndication at "2026-01-01T00:00:00Z"
    Then the social_posts table has a row with:
      | post_id | targets    |
      | 1       | {mastodon} |

  Scenario: A picked network with no account is left out
    Given social account 2 is disconnected
    And the posts table holds:
      | title | status    | published_at | syndication_enabled | syndication_body | syndication_targets |
      | Hello | published | 1 hour ago   | true                | In my own words  | {mastodon,bluesky}  |
    When blog post 1 is handed to syndication at "2026-01-01T00:00:00Z"
    Then the social_posts table has a row with:
      | post_id | targets    |
      | 1       | {mastodon} |

  Scenario Outline: Nothing is queued when there is nothing to send
    Given the posts table holds:
      | title   | status    | published_at | syndication_enabled | syndication_body | syndication_targets |
      | <title> | published | 1 hour ago   | <enabled>           | <body>           | <targets>           |
    When blog post 1 is handed to syndication at "2026-01-01T00:00:00Z"
    And the social jobs have all run
    Then the social_posts table holds 0 rows

    Examples:
      | title | enabled | body            | targets            |
      | Hello | false   | In my own words | {mastodon,bluesky} |
      | Hello | true    | In my own words | {}                 |
      |       | true    |                 | {mastodon,bluesky} |

  Scenario: Nothing is queued when no picked network has an account
    Given social account 1 is disconnected
    And social account 2 is disconnected
    And the posts table holds:
      | title | status    | published_at | syndication_enabled | syndication_body | syndication_targets |
      | Hello | published | 1 hour ago   | true                | In my own words  | {mastodon,bluesky}  |
    When blog post 1 is handed to syndication at "2026-01-01T00:00:00Z"
    And the social jobs have all run
    Then the social_posts table holds 0 rows

  Scenario: A post handed twice is queued once
    Given the posts table holds:
      | title | status    | published_at | syndication_enabled | syndication_body | syndication_targets |
      | Hello | published | 1 hour ago   | true                | In my own words  | {mastodon,bluesky}  |
    When blog post 1 is handed to syndication at "2026-01-01T00:00:00Z"
    And blog post 1 is handed to syndication at "2026-01-01T00:00:00Z"
    And the social jobs have all run
    Then the social_posts table holds 1 rows

  Scenario: A post whose cross-post was sent is left alone
    Given the posts table holds:
      | title | status    | published_at | syndication_enabled | syndication_body | syndication_targets |
      | Hello | published | 1 hour ago   | true                | In my own words  | {mastodon,bluesky}  |
    And the social_posts table holds:
      | post_id | targets    | status | posted_at  |
      | 1       | {mastodon} | posted | 1 hour ago |
    When blog post 1 is handed to syndication at "2026-01-01T00:00:00Z"
    And the social jobs have all run
    Then the social_posts table holds 1 rows

  Scenario: A post gone by the time the job runs queues nothing and finishes quietly
    When blog post 99 is handed to syndication at "2026-01-01T00:00:00Z"
    Then the social job "Social::Jobs::SyndicatePost" finishes without an error
    And the social_posts table holds 0 rows
