Feature: Prune workspaces
  mise run dev:prune-workspaces drops the test databases of workspaces whose directory is gone.

  @timeout:300_000
  Scenario: dev:prune-workspaces drops and lists the test databases of workspaces with no directory
    Given the workspace 7 has a directory
    And these test databases under a scratch prefix:
      | name      |
      | test      |
      | test_7_w2 |
      | test_8    |
      | test_8_w2 |
    When I prune the workspaces
    Then it succeeds
    And it lists the test databases "test_8, test_8_w2"
    And the test databases left are "test, test_7_w2"
