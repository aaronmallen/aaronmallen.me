Feature: Bluesky threads, retries and sessions
  Each part of a Bluesky thread replies to the part before and keeps the thread's root. A retry writes a part again
  under the key it tried before, and an expired session signs in once more.

  Background:
    Given a Bluesky account "ada.example" is connected

  Scenario: A thread replies each part to the one before and keeps the root
    Given a social post due now to "bluesky" in parts:
      | one   |
      | two   |
      | three |
    And Bluesky answers POST "/xrpc/com.atproto.server.createSession" with:
      """
      {"accessJwt": "jwt", "did": "did:plc:ada", "handle": "ada.example"}
      """
    And the network answers POST "/bluesky/pds/xrpc/com.atproto.repo.putRecord" in turn:
      """
      [
        {"body": {"cid": "c1", "uri": "at://did:plc:ada/app.bsky.feed.post/one"}},
        {"body": {"cid": "c2", "uri": "at://did:plc:ada/app.bsky.feed.post/two"}},
        {"body": {"cid": "c3", "uri": "at://did:plc:ada/app.bsky.feed.post/three"}}
      ]
      """
    And the network answers GET "/bluesky/pds/xrpc/com.atproto.repo.getRecord" in turn:
      """
      [
        {"body": {"cid": "cid-one", "uri": "at://did:plc:ada/app.bsky.feed.post/one", "value": {}}},
        {"body": {"cid": "cid-two", "uri": "at://did:plc:ada/app.bsky.feed.post/two",
                  "value": {"reply": {"root": {"cid": "cid-root", "uri": "at://did:plc:ada/app.bsky.feed.post/one"}}}}}
      ]
      """
    When social post 1 goes out on account 1
    Then Bluesky record 2 holds:
      """
      {
        "record": {
          "reply": {
            "parent": {"cid": "cid-one", "uri": "at://did:plc:ada/app.bsky.feed.post/one"},
            "root": {"cid": "cid-one", "uri": "at://did:plc:ada/app.bsky.feed.post/one"}
          }
        }
      }
      """
    And Bluesky record 3 holds:
      """
      {"record": {"reply": {"root": {"cid": "cid-root", "uri": "at://did:plc:ada/app.bsky.feed.post/one"}}}}
      """
    And Bluesky record 1 has no "reply"
    And the Bluesky parent lookup asked for "at://did:plc:ada/app.bsky.feed.post/one"
    And Bluesky wrote 3 records, each under a TID key of its own
    And the network heard POST "/xrpc/com.atproto.server.createSession" 1 time
    And the social_post_deliveries table has a row with:
      | remote_ids                                                                                                    |
      | {at://did:plc:ada/app.bsky.feed.post/one,at://did:plc:ada/app.bsky.feed.post/two,at://did:plc:ada/app.bsky.feed.post/three} |

  Scenario: A retry after the account reconnects signs in once more with the new password
    Given a social post due now to "bluesky" in parts:
      | one   |
      | two   |
      | three |
    And the network answers POST "/bluesky/pds/xrpc/com.atproto.server.createSession" in turn:
      """
      [
        {"body": {"accessJwt": "old", "did": "did:plc:ada", "handle": "ada.example"}},
        {"body": {"accessJwt": "new", "did": "did:plc:ada", "handle": "ada.example"}}
      ]
      """
    And the network answers POST "/bluesky/pds/xrpc/com.atproto.repo.putRecord" in turn:
      """
      [{"body": {"cid": "c1", "uri": "at://did:plc:ada/app.bsky.feed.post/one"}}, {"status": 500}]
      """
    And Bluesky answers GET "/xrpc/com.atproto.repo.getRecord" with:
      """
      {"cid": "cid-one", "uri": "at://did:plc:ada/app.bsky.feed.post/one", "value": {}}
      """
    When social post 1 goes out on account 1
    Then the delivery error on account 1 holds "500"
    Given Bluesky account 1 reconnects as "ada.example"
    And Bluesky answers POST "/xrpc/com.atproto.repo.putRecord" with:
      """
      {"cid": "c2", "uri": "at://did:plc:ada/app.bsky.feed.post/two"}
      """
    When social post 1 goes out on account 1
    Then the network heard POST "/xrpc/com.atproto.repo.putRecord" 2 times with the header "Authorization" set to "Bearer new"
    And the network heard POST "/xrpc/com.atproto.server.createSession" 2 times
    And Bluesky heard the sign-in of "ada.example"

  Scenario: A retry writes the failed part again under the same key and keeps the session
    Given a social post due now to "bluesky" in parts:
      | one |
      | two |
    And Bluesky answers POST "/xrpc/com.atproto.server.createSession" with:
      """
      {"accessJwt": "jwt", "did": "did:plc:ada", "handle": "ada.example"}
      """
    And Bluesky answers POST "/xrpc/com.atproto.repo.putRecord" with status 500
    When social post 1 goes out on account 1
    Then the delivery error on account 1 holds "500"
    Given Bluesky answers POST "/xrpc/com.atproto.repo.putRecord" with:
      """
      {"cid": "c1", "uri": "at://did:plc:ada/app.bsky.feed.post/one"}
      """
    And Bluesky answers GET "/xrpc/com.atproto.repo.getRecord" with:
      """
      {"cid": "cid-one", "uri": "at://did:plc:ada/app.bsky.feed.post/one", "value": {}}
      """
    When social post 1 goes out on account 1
    Then the delivery on account 1 holds 2 remote ids
    And Bluesky records 1 and 2 went under the same key
    And the network heard POST "/xrpc/com.atproto.server.createSession" 1 time

  Scenario Outline: An expired session signs in once more and sends the rest
    Given a social post due now to "bluesky" in parts:
      | one |
      | two |
    And the network answers POST "/bluesky/pds/xrpc/com.atproto.server.createSession" in turn:
      """
      [
        {"body": {"accessJwt": "old", "did": "did:plc:ada", "handle": "ada.example"}},
        {"body": {"accessJwt": "new", "did": "did:plc:ada", "handle": "ada.example"}}
      ]
      """
    And the network answers POST "/bluesky/pds/xrpc/com.atproto.repo.putRecord" in turn:
      """
      <writes>
      """
    And Bluesky answers GET "/xrpc/com.atproto.repo.getRecord" with:
      """
      {"cid": "cid-one", "uri": "at://did:plc:ada/app.bsky.feed.post/one", "value": {}}
      """
    When social post 1 goes out on account 1
    Then the social_post_deliveries table has a row with:
      | error |
      | null  |
    And the delivery on account 1 holds 2 remote ids
    And the network heard POST "/xrpc/com.atproto.server.createSession" 2 times
    And the network heard POST "/xrpc/com.atproto.repo.putRecord" <with new> times with the header "Authorization" set to "Bearer new"

    Examples:
      | writes                                                                                                                                                                                                 | with new |
      | [{"status": 400, "body": {"error": "ExpiredToken", "message": "Token has expired"}}, {"body": {"cid": "c", "uri": "at://did:plc:ada/app.bsky.feed.post/one"}}]                                         | 2        |
      | [{"body": {"cid": "c", "uri": "at://did:plc:ada/app.bsky.feed.post/one"}}, {"status": 400, "body": {"error": "ExpiredToken", "message": "Token has expired"}}, {"body": {"cid": "c", "uri": "at://did:plc:ada/app.bsky.feed.post/two"}}] | 1        |

  Scenario: Bluesky not answering in time is kept as the error
    Given a social post due now to "bluesky" saying "hello"
    And Bluesky answers POST "/xrpc/com.atproto.server.createSession" with:
      """
      {"accessJwt": "jwt", "did": "did:plc:ada", "handle": "ada.example"}
      """
    And the network answers POST "/bluesky/pds/xrpc/com.atproto.repo.putRecord" in turn:
      """
      [{"delay": 15000, "body": {}}]
      """
    When social post 1 goes out on account 1
    Then the delivery error on account 1 holds "Bluesky request com.atproto.repo.putRecord failed"
