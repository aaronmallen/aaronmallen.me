Feature: Issue sync locks and keys
  Each provider's sync runs alone under a lock of its own, and a provider with no token or key is left alone.

  Scenario: With no GitHub token or Linear key the sync asks for nothing and records nothing
    When the GitHub issue sync runs
    And the Linear issue sync runs
    Then GitHub was asked nothing
    And Linear was asked nothing
    And the GitHub issue sync records no failure
    And the Linear issue sync records no failure

  Scenario: A GitHub run another run holds the lock for leaves the run to it
    Given GitHub holds a token for the issue sync
    And GitHub assigns me the issues:
      | number |
      | 7      |
    And another run holds the GitHub issue sync lock
    When the GitHub issue sync runs
    Then GitHub was searched 0 times
    And the GitHub issue sync records no failure

  Scenario: Each provider's sync takes a lock of its own
    Given GitHub holds a token for the issue sync
    And GitHub assigns me the issues:
      | number |
      | 7      |
    And Linear holds the keys "lin_api_one"
    And Linear assigns me the issues:
      | key   |
      | ABC-1 |
    And another run holds the Linear issue sync lock
    When the GitHub issue sync runs
    And the Linear issue sync runs
    Then the synced issues are "I_7"
    And Linear was sent 0 queries holding "assignedIssues("

  Scenario: A Linear run goes on while GitHub's lock is held
    Given Linear holds the keys "lin_api_one"
    And Linear assigns me the issues:
      | key   |
      | ABC-1 |
    And another run holds the GitHub issue sync lock
    When the Linear issue sync runs
    Then the synced issues are "L_1"
