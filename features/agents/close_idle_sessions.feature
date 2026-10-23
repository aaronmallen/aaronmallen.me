Feature: Closing idle agent sessions
  A job closes each agent session no call has named for two hours.

  Scenario: A session no call named for two hours closes
    Given the agent starts the session "Spike"
    And the database runs "UPDATE agent_sessions SET last_seen_at = now() - interval '2 hours 1 second'"
    When the job "Agents::Jobs::CloseIdleSessions" runs
    Then the database soon answers "true" for:
      """
      SELECT ended_at IS NOT NULL FROM agent_sessions
      """

  Scenario: A session seen within two hours stays open
    Given the agent starts the session "Spike"
    And the agent starts the session "Marker"
    And the database runs "UPDATE agent_sessions SET last_seen_at = now() - interval '1 hour 59 minutes' WHERE title = 'Spike'"
    And the database runs "UPDATE agent_sessions SET last_seen_at = now() - interval '3 hours' WHERE title = 'Marker'"
    When the job "Agents::Jobs::CloseIdleSessions" runs
    Then the database soon answers "Marker true, Spike false" for:
      """
      SELECT string_agg(title || ' ' || (ended_at IS NOT NULL), ', ' ORDER BY title) FROM agent_sessions
      """
