Feature: Which accounts a social post goes out on
  A delivery job posts as the account it names, only when the post picked that account and is due.

  Scenario: Each Mastodon account posts to its own server
    Given a Mastodon account on "ruby.social" is connected
    And a Mastodon account on "hachyderm.io" is connected
    And a social post due now to "mastodon" saying "hello"
    And Mastodon answers POST "/ruby.social/api/v1/statuses" with:
      """
      {"id": "110", "url": "https://ruby.social/@ada/110"}
      """
    And Mastodon answers POST "/hachyderm.io/api/v1/statuses" with:
      """
      {"id": "220", "url": "https://hachyderm.io/@ada/220"}
      """
    When social post 1 goes out on account 1
    And social post 1 goes out on account 2
    Then the social_post_deliveries table has a row with:
      | connection_id | remote_ids |
      | 1             | {110}      |
    And the social_post_deliveries table has a row with:
      | connection_id | remote_ids |
      | 2             | {220}      |
    And the social_posts table has a row with:
      | id | status |
      | 1  | posted |

  Scenario: A job posts as the account it names and waits for the rest
    Given a Mastodon account on "ruby.social" is connected
    And a Mastodon account on "hachyderm.io" is connected
    And a social post due now to "mastodon" saying "hello"
    And Mastodon answers POST "/hachyderm.io/api/v1/statuses" with:
      """
      {"id": "220", "url": "https://hachyderm.io/@ada/220"}
      """
    When social post 1 goes out on account 2
    Then the social_post_deliveries table has a row with:
      | connection_id | remote_ids |
      | 2             | {220}      |
    And the social_posts table has a row with:
      | id | status    |
      | 1  | scheduled |

  Scenario: A post that picked one account is posted once that account sends
    Given a Mastodon account on "ruby.social" is connected
    And a Mastodon account on "hachyderm.io" is connected
    And a social post due now to "mastodon" saying "hello"
    And social post 1 picked accounts "2"
    And Mastodon answers POST "/hachyderm.io/api/v1/statuses" with:
      """
      {"id": "220", "url": "https://hachyderm.io/@ada/220"}
      """
    When social post 1 goes out on account 2
    Then the social_posts table has a row with:
      | id | status |
      | 1  | posted |

  Scenario: An account the post did not pick sends nothing
    Given a Mastodon account on "ruby.social" is connected
    And a Mastodon account on "hachyderm.io" is connected
    And a social post due now to "mastodon" saying "hello"
    And social post 1 picked accounts "2"
    When social post 1 goes out on account 1
    And the social jobs have all run
    Then the social_post_deliveries table holds 0 rows

  Scenario: An account disconnected before its job runs sends nothing
    Given a Mastodon account on "ruby.social" is connected
    And a social post due now to "mastodon" saying "hello"
    And social account 1 is disconnected
    When social post 1 goes out on account 1
    And the social jobs have all run
    Then the social_post_deliveries table holds 0 rows

  Scenario: A network the post does not target sends nothing
    Given a Bluesky account "ada.example" is connected
    And a social post due now to "mastodon" saying "hello"
    When social post 1 goes out on account 1
    And the social jobs have all run
    Then the social_post_deliveries table holds 0 rows

  Scenario Outline: A post that is not due sends nothing
    Given a Mastodon account on "ruby.social" is connected
    And the social_posts table holds:
      | targets    | status   | posted_at   |
      | {mastodon} | <status> | <posted at> |
    And the social_post_parts table holds:
      | social_post_id | position | body  |
      | 1              | 1        | hello |
    When social post 1 goes out on account 1
    And the social jobs have all run
    Then the social_post_deliveries table holds 0 rows

    Examples:
      | status    | posted at  |
      | draft     | null       |
      | scheduled | in 1 hour  |
      | posted    | 1 hour ago |

  Scenario: A picked account gone by send time fails its network once the rest have sent
    Given a Mastodon account on "ruby.social" is connected
    And a Bluesky account "ada.example" is connected
    And a social post due now to "mastodon bluesky" saying "hello"
    And social post 1 picked accounts "1 2"
    And social account 1 is disconnected
    And Bluesky answers POST "/xrpc/com.atproto.server.createSession" with:
      """
      {"accessJwt": "jwt", "did": "did:plc:ada", "handle": "ada.example"}
      """
    And Bluesky answers POST "/xrpc/com.atproto.repo.putRecord" with:
      """
      {"cid": "cid", "uri": "at://did:plc:ada/app.bsky.feed.post/3kabc"}
      """
    When social post 1 goes out on account 2
    Then the social_posts table has a row with:
      | id | status |
      | 1  | posted |
    And the social_post_deliveries table has a row with:
      | network  | connection_id | failed | error                            |
      | mastodon | null          | true   | No mastodon account is connected |
    When social post 1 goes out on account 2
    And the social jobs have all run
    Then the social_post_deliveries table holds 2 rows

  Scenario: A picked account gone by send time fails nothing while the rest still send
    Given a Mastodon account on "ruby.social" is connected
    And a Bluesky account "ada.example" is connected
    And a social post due now to "mastodon bluesky" saying "hello"
    And social post 1 picked accounts "1 2"
    And social account 1 is disconnected
    And Bluesky answers POST "/xrpc/com.atproto.server.createSession" with:
      """
      {"accessJwt": "jwt", "did": "did:plc:ada", "handle": "ada.example"}
      """
    And Bluesky answers POST "/xrpc/com.atproto.repo.putRecord" with status 502
    When social post 1 goes out on account 2
    And the social jobs have all run
    Then the social_post_deliveries table holds 1 rows
    And the social_post_deliveries table has no row with:
      | network  |
      | mastodon |

  Scenario: A job posts to its own account's server with that account's key
    Given a Mastodon account on "ruby.social" is connected
    And a Mastodon account on "hachyderm.io" is connected
    And a social post due now to "mastodon" saying "hello"
    And Mastodon answers POST "/hachyderm.io/api/v1/statuses" with:
      """
      {"id": "220", "url": "https://hachyderm.io/@ada/220"}
      """
    When social post 1 goes out on account 2
    Then the network heard POST "/hachyderm.io/api/v1/statuses" with the header "Authorization" set to "Bearer mastodon-token"
    And the network heard POST "/hachyderm.io/api/v1/statuses" with the header "Idempotency-Key" set to "social-post-1-2-1"
    And the network heard POST "/ruby.social/api/v1/statuses" 0 times

  Scenario: A job for the second Bluesky account signs in as that account
    Given a Bluesky account "ada.example" is connected
    And a Bluesky account "grace.example" is connected
    And a social post due now to "bluesky" saying "hello"
    And Bluesky answers POST "/xrpc/com.atproto.server.createSession" with:
      """
      {"accessJwt": "jwt", "did": "did:plc:grace", "handle": "grace.example"}
      """
    And Bluesky answers POST "/xrpc/com.atproto.repo.putRecord" with:
      """
      {"cid": "cid", "uri": "at://did:plc:grace/app.bsky.feed.post/3kabc"}
      """
    When social post 1 goes out on account 2
    Then Bluesky heard the sign-in of "grace.example"

  Scenario: A social post that is gone finishes quietly
    Given a Mastodon account on "ruby.social" is connected
    When social post 99 goes out on account 1
    Then the social job "Social::Jobs::DeliverSocialPost" finishes without an error
    And the social_post_deliveries table holds 0 rows
