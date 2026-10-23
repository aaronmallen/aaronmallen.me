Feature: Social posts go out to Bluesky
  A due social post goes out to each Bluesky account it targets, signed in with that account's app password.

  Background:
    Given a Bluesky account "ada.example" is connected

  Scenario: A due post goes out to Bluesky
    Given a social post due now to "bluesky" saying "go 🎉"
    And Bluesky answers POST "/xrpc/com.atproto.server.createSession" with:
      """
      {"accessJwt": "jwt", "did": "did:plc:ada", "handle": "ada.example"}
      """
    And Bluesky answers POST "/xrpc/com.atproto.repo.putRecord" with:
      """
      {"cid": "cid", "uri": "at://did:plc:ada/app.bsky.feed.post/3kabc"}
      """
    When social post 1 goes out on account 1
    Then the social_post_deliveries table has a row with:
      | network | remote_ids                                 | remote_url                                         | error |
      | bluesky | {at://did:plc:ada/app.bsky.feed.post/3kabc} | https://bsky.app/profile/ada.example/post/3kabc | null  |
    And the social_posts table has a row with:
      | id | status |
      | 1  | posted |

  Scenario: A thread to Bluesky records every part
    Given a social post due now to "bluesky" in parts:
      | one   |
      | two   |
      | three |
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
    When social post 1 goes out on account 1
    Then the delivery on account 1 holds 3 remote ids

  Scenario: Bluesky gives back a parent with no CID
    Given a social post due now to "bluesky" in parts:
      | one |
      | two |
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
      {"uri": "at://did:plc:ada/app.bsky.feed.post/3kabc"}
      """
    When social post 1 goes out on account 1
    Then the social_post_deliveries table has a row with:
      | error                                                                             | failed |
      | Bluesky returned no CID for the parent post at://did:plc:ada/app.bsky.feed.post/3kabc | false  |

  Scenario: Bluesky refuses the app password
    Given a social post due now to "bluesky" saying "hello"
    And Bluesky refuses POST "/xrpc/com.atproto.server.createSession" with status 401 and:
      """
      {"error": "AuthenticationRequired"}
      """
    When social post 1 goes out on account 1
    Then the social_post_deliveries table has a row with:
      | error                                                                       | failed |
      | Bluesky answered 401 for com.atproto.server.createSession: AuthenticationRequired | false  |
    And the social_posts table has a row with:
      | id | status    |
      | 1  | scheduled |
    And the delivery job fails so Sidekiq tries again

  Scenario: Bluesky signs in without handing back a token
    Given a social post due now to "bluesky" saying "hello"
    And Bluesky answers POST "/xrpc/com.atproto.server.createSession" with:
      """
      {"did": "did:plc:ada", "handle": "ada.example"}
      """
    When social post 1 goes out on account 1
    Then the social_post_deliveries table has a row with:
      | error                                                | failed |
      | Bluesky returned an incomplete session for ada.example | false  |

  Scenario Outline: Bluesky refuses the write
    Given a social post due now to "bluesky" saying "hello"
    And Bluesky answers POST "/xrpc/com.atproto.server.createSession" with:
      """
      {"accessJwt": "jwt", "did": "did:plc:ada", "handle": "ada.example"}
      """
    And Bluesky refuses POST "/xrpc/com.atproto.repo.putRecord" with status <status> and:
      """
      <answer>
      """
    When social post 1 goes out on account 1
    Then the social_post_deliveries table has a row with:
      | error   | failed |
      | <error> | false  |

    Examples:
      | status | answer                                                 | error                                                        |
      | 400    | {"error": "Invalid", "message": "Bad key"}             | Bluesky answered 400 for com.atproto.repo.putRecord: Invalid: Bad key |
      | 502    | {}                                                     | Bluesky answered 502 for com.atproto.repo.putRecord          |
      | 429    | {"error": "RateLimitExceeded"}                         | Bluesky rate limited com.atproto.repo.putRecord              |
      | 400    | {"error": "ExpiredToken", "message": "Token has expired"} | Bluesky session expired for com.atproto.repo.putRecord     |
      | 200    | <html></html>                                          | Bluesky answered com.atproto.repo.putRecord with String instead of JSON |
      | 200    | {"cid": "cid"}                                         | Bluesky wrote a record for did:plc:ada without a URI         |
