Feature: Task writes that land at once
  Two writes that race for the same place or the same task each finish, and leave the tasks whole.

  Background:
    Given an API token

  Scenario: Two tasks captured at once get different positions
    When two tasks are captured through the API while another session holds the task lock
    Then the database reads "2" for:
      """
      SELECT count(DISTINCT position) FROM tasks
      """

  Scenario: Two starts of one task at once both succeed and leave one open session
    Given a task "Start me"
    When the task "Start me" is started twice at once while another session holds its row
    Then the database reads "1" for:
      """
      SELECT count(*) FROM work_sessions WHERE ended_at IS NULL
      """
