Feature: Social posts go out to LinkedIn
  LinkedIn takes a thread as one post, and a lapsed or refused token fails it for good.

  Scenario: A lapsed connection fails for good and names when it lapsed
    Given a LinkedIn account is connected whose token lapsed at "2026-09-01T12:00:00Z"
    And a social post due now to "linkedin" saying "hello"
    When social post 1 goes out on account 1
    Then the social_post_deliveries table has a row with:
      | failed | error                                                                |
      | true   | LinkedIn connection expired at 2026-09-01T12:00:00Z; connect it again |
    And the social job "Social::Jobs::DeliverSocialPost" finishes without an error

  Scenario: LinkedIn refusing the token fails for good
    Given a LinkedIn account is connected
    And a social post due now to "linkedin" saying "hello"
    And LinkedIn answers POST "/rest/posts" with status 401
    When social post 1 goes out on account 1
    Then the delivery error on account 1 holds "refused the access token"
    And the social_post_deliveries table has a row with:
      | failed |
      | true   |
    And the social job "Social::Jobs::DeliverSocialPost" finishes without an error

  Scenario: Any other refusal from LinkedIn is tried again
    Given a LinkedIn account is connected
    And a social post due now to "linkedin" saying "hello"
    And LinkedIn answers POST "/rest/posts" with status 500
    When social post 1 goes out on account 1
    Then the delivery error on account 1 holds "500"
    And the social_post_deliveries table has a row with:
      | failed |
      | false  |
    And the delivery job fails so Sidekiq tries again

  Scenario: A thread whose parts fit but whose joined text does not is refused
    Given a LinkedIn account is connected
    And a social post due now to "linkedin" in 2 parts of 1600 letters
    When social post 1 goes out on account 1
    Then the social_post_deliveries table has a row with:
      | failed | error                             |
      | true   | Part 1 is over the linkedin limit |
