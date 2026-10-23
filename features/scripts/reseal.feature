Feature: Resealing credentials
  mise run db:reseal opens each stored credential with data_key or previous_data_key and seals the ones
  under previous_data_key again under data_key, so the old key can go.

  Background:
    Given the previous data key is set

  Scenario: db:reseal seals credentials from previous_data_key under data_key alone
    Given a service connection whose credentials say "hunter2" sealed under the previous data key
    When I reseal the credentials
    Then it succeeds
    And the output includes "Resealed 1 credentials."
    And the credentials open to "hunter2" under the data key alone
    And the credentials do not hold "hunter2" in plain text

  Scenario: db:reseal leaves credentials sealed under data_key alone
    Given a service connection whose credentials say "hunter2" sealed under the data key
    When I reseal the credentials
    Then it succeeds
    And the output includes "Resealed 0 credentials."
    And the credentials have not changed

  Scenario: Sealing the same text twice gives different sealed text
    Given a service connection whose credentials say "hunter2" sealed under the previous data key
    And a service connection whose credentials say "hunter2" sealed under the previous data key
    When I reseal the credentials
    Then it succeeds
    And the output includes "Resealed 2 credentials."
    And no two credentials match

  Scenario Outline: db:reseal refuses credentials sealed under neither key
    Given a service connection whose credentials are <credentials>
    When I reseal the credentials
    Then it fails
    And the output includes "1 credentials open under neither data_key nor previous_data_key."

    Examples:
      | credentials                        |
      | "hunter2" sealed under another key |
      | "hunter2" sealed and then changed  |
      | not sealed                         |
