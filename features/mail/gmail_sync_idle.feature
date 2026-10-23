Feature: Gmail sync with no account to sync
  The Gmail sync asks Google nothing and records nothing when no account can sync.

  Scenario: The sync asks Google nothing while no account granted Gmail
    When the Gmail sync runs
    Then the mail sync records no failure

  Scenario: The sync asks Google nothing for an account that needs a reconnect
    Given the Google account "aaron@example.com" is connected with "openid gmail.modify"
    And the Google connection for "aaron@example.com" is revoked
    When the Gmail sync runs
    Then the mail sync records no failure
