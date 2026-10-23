Feature: A social post over a network's limit
  A part too long for a network fails that network for good before anything goes out, measured on the text the
  network would get.

  Scenario: A part over the limit sends nothing at all
    Given a Mastodon account on "ruby.social" is connected
    And a social post due now to "mastodon" saying "one" then 501 "a"s
    When social post 1 goes out on account 1
    Then the social_post_deliveries table has a row with:
      | remote_ids | failed | error                             |
      | {}         | true   | Part 2 is over the mastodon limit |
    And the social_posts table has a row with:
      | id | status |
      | 1  | posted |

  Scenario: Mastodon takes a long link as a short one
    Given a Mastodon account on "ruby.social" is connected
    And a social post due now to "mastodon" with 470 "a"s before "http://203.0.113.5/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    And the web answers GET "http://203.0.113.5/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" with:
      """
      <title>Bees</title>
      """
    And Mastodon answers POST "/ruby.social/api/v1/statuses" with:
      """
      {"id": "1", "url": "https://ruby.social/@ada/1"}
      """
    When social post 1 goes out on account 1
    Then the social_post_deliveries table has a row with:
      | remote_ids | error |
      | {1}        | null  |

  Scenario: Bluesky counts graphemes and bytes
    Given a Bluesky account "ada.example" is connected
    And a social post due now to "bluesky" saying 300 "👩‍👩‍👧‍👦"s
    When social post 1 goes out on account 1
    Then the social_post_deliveries table has a row with:
      | failed | error                            |
      | true   | Part 1 is over the bluesky limit |

  Scenario: A mention counts as the handle the network gets
    Given a Bluesky account "ada.example" is connected
    And the people table holds:
      | key | name         | bluesky_handle  | bluesky_did          |
      | ada | Ada Lovelace | ada.bsky.social | did:plc:ada-lovelace |
    And a social post due now to "bluesky" with 290 "a"s before "@{ada}"
    When social post 1 goes out on account 1
    Then the social_post_deliveries table has a row with:
      | failed | error                            |
      | true   | Part 1 is over the bluesky limit |

  Scenario: The tag on a link to the site counts toward the limit
    Given a Bluesky account "ada.example" is connected
    And a social post due now to "bluesky" that fills 300 characters with a link to the site's "/writing/hello"
    When social post 1 goes out on account 1
    Then the social_post_deliveries table has a row with:
      | failed | error                            |
      | true   | Part 1 is over the bluesky limit |

  Scenario: A part the tag brings right up to the limit still goes out
    Given a Bluesky account "ada.example" is connected
    And a social post due now to "bluesky" that fills 288 characters with a link to the site's "/writing/hello"
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
      | remote_ids                                  | error | failed |
      | {at://did:plc:ada/app.bsky.feed.post/3kabc} | null  | false  |
    And social post 1 still links to the site's "/writing/hello" untagged

  Scenario: A link to another site stays long in the stored post
    Given a Mastodon account on "ruby.social" is connected
    And a social post due now to "mastodon" saying "see http://203.0.113.5/ada"
    And the web answers GET "http://203.0.113.5/ada" with:
      """
      <title>Ada</title>
      """
    And Mastodon answers POST "/ruby.social/api/v1/statuses" with:
      """
      {"id": "1", "url": "https://ruby.social/@ada/1"}
      """
    When social post 1 goes out on account 1
    Then the social_post_deliveries table has a row with:
      | remote_ids | error |
      | {1}        | null  |
    And social post 1 reads "see http://203.0.113.5/ada"
