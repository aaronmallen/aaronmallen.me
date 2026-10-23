Feature: Due social posts go out
  The due social posts job claims each due post for every account on the networks it targets, once, and hands each
  claim to a delivery job.

  Background:
    Given a Mastodon account on "ruby.social" is connected
    And a Bluesky account "ada.example" is connected

  Scenario: A due post goes out on every network it targets
    Given a social post due now to "mastodon bluesky" saying "hello"
    And Mastodon answers POST "/ruby.social/api/v1/statuses" with:
      """
      {"id": "110", "url": "https://ruby.social/@ada/110"}
      """
    And Bluesky answers POST "/xrpc/com.atproto.server.createSession" with:
      """
      {"accessJwt": "jwt", "did": "did:plc:ada", "handle": "ada.example"}
      """
    And Bluesky answers POST "/xrpc/com.atproto.repo.putRecord" with:
      """
      {"cid": "cid", "uri": "at://did:plc:ada/app.bsky.feed.post/3kabc"}
      """
    When the due social posts go out
    Then the social_posts table has a row with:
      | id | status |
      | 1  | posted |
    And the social_post_deliveries table has a row with:
      | connection_id | remote_ids |
      | 1             | {110}      |
    And the delivery on account 2 holds 1 remote ids

  Scenario: A due post goes out on the one network it targets
    Given a social post due now to "mastodon" saying "hello"
    And Mastodon answers POST "/ruby.social/api/v1/statuses" with:
      """
      {"id": "110", "url": "https://ruby.social/@ada/110"}
      """
    When the due social posts go out
    Then the social_posts table has a row with:
      | id | status |
      | 1  | posted |
    And the social_post_deliveries table holds 1 rows

  Scenario: A due post goes out on each account of a network with two
    Given a Mastodon account on "hachyderm.io" is connected
    And a social post due now to "mastodon" saying "hello"
    And Mastodon answers POST "/ruby.social/api/v1/statuses" with:
      """
      {"id": "110", "url": "https://ruby.social/@ada/110"}
      """
    And Mastodon answers POST "/hachyderm.io/api/v1/statuses" with:
      """
      {"id": "220", "url": "https://hachyderm.io/@ada/220"}
      """
    When the due social posts go out
    Then the social_post_deliveries table has a row with:
      | connection_id | remote_ids |
      | 1             | {110}      |
    And the social_post_deliveries table has a row with:
      | connection_id | remote_ids |
      | 3             | {220}      |

  Scenario: A due post goes out only on the accounts it picked
    Given a Mastodon account on "hachyderm.io" is connected
    And a social post due now to "mastodon" saying "hello"
    And social post 1 picked accounts "3"
    And Mastodon answers POST "/hachyderm.io/api/v1/statuses" with:
      """
      {"id": "220", "url": "https://hachyderm.io/@ada/220"}
      """
    When the due social posts go out
    Then the social_posts table has a row with:
      | id | status |
      | 1  | posted |
    And the social_post_deliveries table holds 1 rows

  Scenario: A due post with no account left on its network fails that network once
    Given social account 1 is disconnected
    And a social post due now to "mastodon" saying "hello"
    When the due social posts go out
    And the due social posts go out
    And the social jobs have all run
    Then the social_posts table has a row with:
      | id | status |
      | 1  | posted |
    And the social_post_deliveries table has a row with:
      | network  | failed | error                            |
      | mastodon | true   | No mastodon account is connected |
    And the social_post_deliveries table holds 1 rows

  Scenario: A due post whose picked accounts are gone fails
    Given a social post due now to "mastodon" saying "hello"
    And social post 1 picked accounts "99"
    When the due social posts go out
    Then the social_post_deliveries table has a row with:
      | network  | failed |
      | mastodon | true   |

  Scenario: A post with no account left waits until it is due
    Given social account 1 is disconnected
    And the social_posts table holds:
      | targets    | status    | posted_at |
      | {mastodon} | scheduled | in 1 hour |
    And the social_post_parts table holds:
      | social_post_id | position | body  |
      | 1              | 1        | hello |
    When the due social posts go out
    And the social jobs have all run
    Then the social_posts table has a row with:
      | id | status    |
      | 1  | scheduled |
    And the social_post_deliveries table holds 0 rows

  Scenario: A due post goes out on the network still connected
    Given social account 2 is disconnected
    And a social post due now to "mastodon bluesky" saying "hello"
    And Mastodon answers POST "/ruby.social/api/v1/statuses" with:
      """
      {"id": "110", "url": "https://ruby.social/@ada/110"}
      """
    When the due social posts go out
    Then the social_post_deliveries table has a row with:
      | connection_id | remote_ids |
      | 1             | {110}      |
    And the social_post_deliveries table has no row with:
      | connection_id |
      | 2             |

  Scenario: A picked account gone by send time fails once the rest have sent
    Given a social post due now to "mastodon bluesky" saying "hello"
    And social post 1 picked accounts "2 1"
    And social account 1 is disconnected
    And Bluesky answers POST "/xrpc/com.atproto.server.createSession" with:
      """
      {"accessJwt": "jwt", "did": "did:plc:ada", "handle": "ada.example"}
      """
    And Bluesky answers POST "/xrpc/com.atproto.repo.putRecord" with:
      """
      {"cid": "cid", "uri": "at://did:plc:ada/app.bsky.feed.post/3kabc"}
      """
    When the due social posts go out
    Then the social_post_deliveries table has a row with:
      | network | failed |
      | bluesky | false  |
    And the social_post_deliveries table has a row with:
      | network  | failed |
      | mastodon | true   |

  Scenario Outline: A post that is not due is left alone
    Given the social_posts table holds:
      | targets             | status   | posted_at   |
      | {mastodon,bluesky} | <status> | <posted at> |
    And the social_post_parts table holds:
      | social_post_id | position | body  |
      | 1              | 1        | hello |
    When the due social posts go out
    And the social jobs have all run
    Then the social_post_deliveries table holds 0 rows

    Examples:
      | status    | posted at  |
      | scheduled | in 1 hour  |
      | draft     | null       |
      | posted    | 1 hour ago |

  Scenario Outline: A network still retrying is never sent again, however long ago it failed
    Given a social post due now to "mastodon" saying "hello"
    And the deliveries of social post 1 are:
      | network  | connection_id | error | updated_at   |
      | mastodon | 1             | down  | <updated at> |
    When the due social posts go out
    And the social jobs have all run
    Then the social_post_deliveries table has a row with:
      | connection_id | error | remote_ids |
      | 1             | down  | {}         |

    Examples:
      | updated at     |
      | 1 minute ago   |
      | 20 minutes ago |

  Scenario: A claim whose job never ran is sent again once it stalls
    Given a social post due now to "mastodon" saying "hello"
    And the deliveries of social post 1 are:
      | network  | connection_id | updated_at     |
      | mastodon | 1             | 20 minutes ago |
    And Mastodon answers POST "/ruby.social/api/v1/statuses" with:
      """
      {"id": "110", "url": "https://ruby.social/@ada/110"}
      """
    When the due social posts go out
    Then the social_post_deliveries table has a row with:
      | connection_id | remote_ids |
      | 1             | {110}      |

  Scenario: A claim whose job died partway is picked up again once it stalls
    Given a social post due now to "mastodon" saying "hello"
    And the deliveries of social post 1 are:
      | network  | connection_id | remote_ids | updated_at     |
      | mastodon | 1             | {1}        | 20 minutes ago |
    When the due social posts go out
    Then the social_posts table has a row with:
      | id | status |
      | 1  | posted |

  Scenario: A claim whose job has not had time to start is left to it
    Given a social post due now to "mastodon" saying "hello"
    And the deliveries of social post 1 are:
      | network  | connection_id | updated_at   |
      | mastodon | 1             | 1 minute ago |
    When the due social posts go out
    And the social jobs have all run
    Then the social_posts table has a row with:
      | id | status    |
      | 1  | scheduled |

  Scenario: The network with no delivery yet goes out while the other retries
    Given a social post due now to "mastodon bluesky" saying "hello"
    And the deliveries of social post 1 are:
      | network  | connection_id | error |
      | mastodon | 1             | down  |
    And Bluesky answers POST "/xrpc/com.atproto.server.createSession" with:
      """
      {"accessJwt": "jwt", "did": "did:plc:ada", "handle": "ada.example"}
      """
    And Bluesky answers POST "/xrpc/com.atproto.repo.putRecord" with:
      """
      {"cid": "cid", "uri": "at://did:plc:ada/app.bsky.feed.post/3kabc"}
      """
    When the due social posts go out
    Then the delivery on account 2 holds 1 remote ids
    And the social_post_deliveries table has a row with:
      | connection_id | error |
      | 1             | down  |

  Scenario: Running the job twice sends each network once
    Given a social post due now to "mastodon" saying "hello"
    And Mastodon answers POST "/ruby.social/api/v1/statuses" with:
      """
      {"id": "110", "url": "https://ruby.social/@ada/110"}
      """
    When the due social posts go out
    And the due social posts go out
    Then the social job "Social::Jobs::SendDueSocialPosts" ran 2 times
    And the social_post_deliveries table has a row with:
      | connection_id | remote_ids |
      | 1             | {110}      |
    When the social jobs have all run
    Then the social job "Social::Jobs::DeliverSocialPost" ran 1 time
    And the network heard POST "/ruby.social/api/v1/statuses" 1 time
