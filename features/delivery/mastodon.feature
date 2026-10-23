Feature: Social posts go out to Mastodon
  A due social post goes out to each Mastodon account it targets, and its delivery keeps what came back.

  Background:
    Given a Mastodon account on "ruby.social" is connected

  Scenario: A due post goes out to Mastodon
    Given a social post due now to "mastodon" saying "hello"
    And Mastodon answers POST "/ruby.social/api/v1/statuses" with:
      """
      {"id": "110", "url": "https://ruby.social/@ada/110"}
      """
    When social post 1 goes out on account 1
    Then the social_post_deliveries table has a row with:
      | network  | remote_ids | remote_url                   | error | failed |
      | mastodon | {110}      | https://ruby.social/@ada/110 | null  | false  |
    And the social_posts table has a row with:
      | id | status | posted_at |
      | 1  | posted | set       |

  Scenario: Mastodon gives no web url
    Given a social post due now to "mastodon" saying "hello"
    And Mastodon answers POST "/ruby.social/api/v1/statuses" with:
      """
      {"id": "110", "url": " "}
      """
    When social post 1 goes out on account 1
    Then the social_post_deliveries table has a row with:
      | remote_ids | remote_url |
      | {110}      | null       |

  Scenario Outline: Mastodon refuses the send
    Given a social post due now to "mastodon" saying "hello"
    And Mastodon answers POST "/ruby.social/api/v1/statuses" with status <status>
    When social post 1 goes out on account 1
    Then the social_post_deliveries table has a row with:
      | remote_ids | error   | failed |
      | {}         | <error> | false  |
    And the social_posts table has a row with:
      | id | status    |
      | 1  | scheduled |
    And the delivery job fails so Sidekiq tries again

    Examples:
      | status | error                                              |
      | 429    | Mastodon rate limited POST /api/v1/statuses        |
      | 401    | Mastodon answered 401 for POST /api/v1/statuses    |
      | 500    | Mastodon answered 500 for POST /api/v1/statuses    |

  Scenario Outline: Mastodon answers with something it should not
    Given a social post due now to "mastodon" saying "hello"
    And Mastodon answers POST "/ruby.social/api/v1/statuses" with:
      """
      <answer>
      """
    When social post 1 goes out on account 1
    Then the social_post_deliveries table has a row with:
      | error   | failed |
      | <error> | false  |
    And the delivery job fails so Sidekiq tries again

    Examples:
      | answer                                | error                                                               |
      | <html></html>                         | Mastodon answered POST /api/v1/statuses with String instead of JSON |
      | {"url": "https://ruby.social/@ada/1"} | Mastodon answered /api/v1/statuses without a status ID              |

  Scenario: A refused send keeps the token out of the error
    Given a social post due now to "mastodon" saying "hello"
    And Mastodon answers POST "/ruby.social/api/v1/statuses" with status 401
    When social post 1 goes out on account 1
    Then the social_post_deliveries table has a row with:
      | failed |
      | false  |
    And no delivery error holds "mastodon-token"

  Scenario: A post goes out in public as written, with the account's token and a key against repeats
    Given a social post due now to "mastodon" saying "read #ruby."
    And Mastodon answers POST "/ruby.social/api/v1/statuses" with:
      """
      {"id": "110", "url": "https://ruby.social/@ada/110"}
      """
    When social post 1 goes out on account 1
    Then the network heard these POST "/ruby.social/api/v1/statuses" bodies:
      | status      | visibility |
      | read #ruby. | public     |
    And the network heard POST "/ruby.social/api/v1/statuses" with the header "Authorization" set to "Bearer mastodon-token"
    And the network heard POST "/ruby.social/api/v1/statuses" with the header "Idempotency-Key" set to "social-post-1-1-1"

  Scenario: A thread goes out with each part in reply to the one before
    Given a social post due now to "mastodon" in parts:
      | one   |
      | two   |
      | three |
    And the network answers POST "/mastodon/ruby.social/api/v1/statuses" in turn:
      """
      [
        {"body": {"id": "1", "url": "https://ruby.social/@ada/1"}},
        {"body": {"id": "2", "url": "https://ruby.social/@ada/2"}},
        {"body": {"id": "3", "url": "https://ruby.social/@ada/3"}}
      ]
      """
    When social post 1 goes out on account 1
    Then the network heard these POST "/ruby.social/api/v1/statuses" bodies:
      | status | in_reply_to_id | visibility |
      | one    | absent         | public     |
      | two    | 1              | public     |
      | three  | 2              | public     |
    And the social_post_deliveries table has a row with:
      | remote_ids | remote_url                 |
      | {1,2,3}    | https://ruby.social/@ada/1 |

  Scenario: A retry picks up at the part that failed
    Given a social post due now to "mastodon" in parts:
      | one   |
      | two   |
      | three |
    And the network answers POST "/mastodon/ruby.social/api/v1/statuses" in turn:
      """
      [{"body": {"id": "1", "url": "https://ruby.social/@ada/1"}}, {"status": 500}]
      """
    When social post 1 goes out on account 1
    Then the delivery error on account 1 holds "500"
    And the social_post_deliveries table has a row with:
      | remote_ids | remote_url                 |
      | {1}        | https://ruby.social/@ada/1 |
    Given the network answers POST "/mastodon/ruby.social/api/v1/statuses" in turn:
      """
      [{"body": {"id": "2", "url": "https://ruby.social/@ada/2"}}, {"body": {"id": "3", "url": "https://ruby.social/@ada/3"}}]
      """
    When social post 1 goes out on account 1
    Then the social_post_deliveries table has a row with:
      | remote_ids | error |
      | {1,2,3}    | null  |
    And the network heard these POST "/ruby.social/api/v1/statuses" bodies:
      | status | in_reply_to_id |
      | one    | absent         |
      | two    | 1              |
      | two    | 1              |
      | three  | 2              |

  Scenario: Mastodon not answering in time is kept as the error
    Given a social post due now to "mastodon" saying "hello"
    And the network answers POST "/mastodon/ruby.social/api/v1/statuses" in turn:
      """
      [{"delay": 15000, "body": {"id": "1"}}]
      """
    When social post 1 goes out on account 1
    Then the delivery error on account 1 holds "Mastodon request POST /api/v1/statuses failed"
