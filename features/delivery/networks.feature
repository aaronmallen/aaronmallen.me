Feature: One social post on two networks
  Each network's account sends on its own, so one network failing never holds up or repeats the other.

  Background:
    Given a Mastodon account on "ruby.social" is connected
    And a Bluesky account "ada.example" is connected
    And a social post due now to "mastodon bluesky" in parts:
      | one |
      | two |

  Scenario Outline: One network failing leaves the other to send
    Given Mastodon answers POST "/ruby.social/api/v1/statuses" with status 503
    And Bluesky answers POST "/xrpc/com.atproto.server.createSession" with:
      """
      {"accessJwt": "jwt", "did": "did:plc:ada", "handle": "ada.example"}
      """
    And Bluesky answers POST "/xrpc/com.atproto.repo.putRecord" with:
      """
      {"cid": "cid", "uri": "at://did:plc:ada/app.bsky.feed.post/3kabc"}
      """
    And Bluesky answers GET "/xrpc/com.atproto.repo.getRecord" with:
      """
      {"cid": "cid-3kabc", "uri": "at://did:plc:ada/app.bsky.feed.post/3kabc", "value": {}}
      """
    When social post 1 goes out on account <first>
    And social post 1 goes out on account <second>
    Then the delivery on account 2 holds 2 remote ids
    And the social_post_deliveries table has a row with:
      | network | remote_ids | error |
      | bluesky | set        | null  |
    And the delivery error on account 1 holds "Mastodon answered 503 for POST /api/v1/statuses"
    And the social_post_deliveries table has a row with:
      | network  | remote_ids | failed |
      | mastodon | {}         | false  |
    And the social_posts table has a row with:
      | id | status    |
      | 1  | scheduled |

    Examples:
      | first | second |
      | 1     | 2      |
      | 2     | 1      |

  Scenario: A failing network's job posts nothing to the other network
    Given Mastodon answers POST "/ruby.social/api/v1/statuses" with status 503
    When social post 1 goes out on account 1
    And the social jobs have all run
    Then the social_post_deliveries table holds 1 rows

  Scenario: A network that has sent never posts again
    Given Bluesky answers POST "/xrpc/com.atproto.server.createSession" with:
      """
      {"accessJwt": "jwt", "did": "did:plc:ada", "handle": "ada.example"}
      """
    And Bluesky answers POST "/xrpc/com.atproto.repo.putRecord" with:
      """
      {"cid": "cid", "uri": "at://did:plc:ada/app.bsky.feed.post/3kabc"}
      """
    And Bluesky answers GET "/xrpc/com.atproto.repo.getRecord" with:
      """
      {"cid": "cid-3kabc", "uri": "at://did:plc:ada/app.bsky.feed.post/3kabc", "value": {}}
      """
    When social post 1 goes out on account 2
    Then the delivery on account 2 holds 2 remote ids
    When the social networks stop answering
    And social post 1 goes out on account 2
    And the social jobs have all run
    Then the delivery on account 2 holds 2 remote ids
