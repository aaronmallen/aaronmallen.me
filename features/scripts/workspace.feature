Feature: Workspace scripts
  The workspace scripts take a number as a workspace's id, and find each workspace under WORKTREES_DIR.

  Scenario Outline: A workspace script refuses an id that is not a number
    When I run "scripts/dev/<script> '<id>'"
    Then it exits with status 1
    And the output is:
      """
      id must be a number
      """

    Examples:
      | script           | id  |
      | create-workspace |     |
      | create-workspace | 12a |
      | remove-workspace |     |
      | remove-workspace | 12a |

  Scenario: A workspace script finds each workspace under WORKTREES_DIR when it is set
    Given the environment sets WORKTREES_DIR to "/elsewhere"
    When I run "scripts/util/workspace 7"
    Then the output is:
      """
      /elsewhere/ws7
      """
