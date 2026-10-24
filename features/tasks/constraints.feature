Feature: The database keeps task records whole
  The schema refuses comments, contributors, events and links that would not make sense.

  Background:
    Given the tasks:
      | title |
      | One   |
      | Two   |

  Scenario: A synced comment needs its provider, remote ID and address, once each, and a body
    Then the database refuses, breaking a check constraint:
      """
      INSERT INTO task_comments (task_id, body, remote_id, url) VALUES (1, 'x', 'IC_1', 'https://github.com/a/b/issues/1#c1')
      """
    And the database refuses, breaking a check constraint:
      """
      INSERT INTO task_comments (task_id, body, provider, url) VALUES (1, 'x', 'github', 'https://github.com/a/b/issues/1#c1')
      """
    And the database refuses, breaking a check constraint:
      """
      INSERT INTO task_comments (task_id, body, provider, remote_id) VALUES (1, 'x', 'github', 'IC_1')
      """
    And the database refuses, breaking a check constraint:
      """
      INSERT INTO task_comments (task_id, body) VALUES (1, E' \n')
      """
    Given the database runs:
      """
      INSERT INTO task_comments (task_id, body, provider, remote_id, url) VALUES (1, 'x', 'github', 'IC_1', 'https://github.com/a/b/issues/1#c1')
      """
    Then the database refuses, breaking a unique constraint:
      """
      INSERT INTO task_comments (task_id, body, provider, remote_id, url) VALUES (2, 'x', 'github', 'IC_1', 'https://github.com/a/b/issues/1#c1')
      """

  Scenario: A contributor is the owner alone or an agent with a model, each once per task
    Then the database refuses, breaking a check constraint:
      """
      INSERT INTO task_contributors (task_id, kind, agent) VALUES (1, 'owner', 'claude-code')
      """
    And the database refuses, breaking a check constraint:
      """
      INSERT INTO task_contributors (task_id, kind, agent) VALUES (1, 'agent', 'claude-code')
      """
    And the database refuses, breaking a check constraint:
      """
      INSERT INTO task_contributors (task_id, kind, model) VALUES (1, 'agent', 'claude-opus-5-5')
      """
    And the database refuses, breaking a check constraint:
      """
      INSERT INTO task_contributors (task_id, kind, agent, model) VALUES (1, 'agent', 'Claude Code', 'claude-opus-5-5')
      """
    And the database refuses, breaking a check constraint:
      """
      INSERT INTO task_contributors (task_id, kind, agent, model) VALUES (1, 'agent', 'claude-code', repeat('a', 65))
      """
    And the database refuses a value its type does not hold:
      """
      INSERT INTO task_contributors (task_id, kind) VALUES (1, 'human')
      """
    Given the database runs:
      """
      INSERT INTO task_contributors (task_id, kind) VALUES (1, 'owner');
      INSERT INTO task_contributors (task_id, kind, agent, model) VALUES (1, 'agent', 'claude-code', 'claude-opus-5-5');
      """
    Then the database refuses, breaking a unique constraint:
      """
      INSERT INTO task_contributors (task_id, kind) VALUES (1, 'owner')
      """
    And the database refuses, breaking a unique constraint:
      """
      INSERT INTO task_contributors (task_id, kind, agent, model) VALUES (1, 'agent', 'claude-code', 'claude-opus-5-5')
      """

  Scenario: An event holds only the columns its kind needs
    Then the database refuses, breaking a check constraint:
      """
      INSERT INTO task_events (task_id, kind, occurred_at, from_list) VALUES (1, 'moved', now(), 'next')
      """
    And the database refuses, breaking a check constraint:
      """
      INSERT INTO task_events (task_id, kind, occurred_at, to_list) VALUES (1, 'moved', now(), 'next')
      """
    And the database refuses, breaking a check constraint:
      """
      INSERT INTO task_events (task_id, kind, occurred_at, from_list, from_sprint_on, to_list) VALUES (1, 'moved', now(), 'next', current_date, 'someday')
      """
    And the database refuses, breaking a check constraint:
      """
      INSERT INTO task_events (task_id, kind, occurred_at, from_list, to_list) VALUES (1, 'moved', now(), 'next', 'next')
      """
    And the database refuses, breaking a check constraint:
      """
      INSERT INTO task_events (task_id, kind, occurred_at, to_status) VALUES (1, 'status_changed', now(), 'done')
      """
    And the database refuses, breaking a check constraint:
      """
      INSERT INTO task_events (task_id, kind, occurred_at, from_status, to_status) VALUES (1, 'status_changed', now(), 'open', 'open')
      """
    And the database refuses, breaking a check constraint:
      """
      INSERT INTO task_events (task_id, kind, occurred_at) VALUES (1, 'tagged', now())
      """
    And the database refuses, breaking a check constraint:
      """
      INSERT INTO task_events (task_id, kind, occurred_at, tag_name, to_list) VALUES (1, 'tagged', now(), 'money', 'next')
      """
    And the database refuses, breaking a check constraint:
      """
      INSERT INTO task_events (task_id, kind, occurred_at, tag_name) VALUES (1, 'recurred', now(), 'money')
      """
    Given the database runs:
      """
      INSERT INTO task_events (task_id, kind, occurred_at) VALUES (1, 'recurred', now());
      """
    Then the database holds 1 task_events row

  Scenario: A task has one parent at most
    Given the tasks:
      | title  |
      | Child  |
    And the task "One" is the parent of the task "Child"
    Then the database refuses, breaking a unique constraint:
      """
      INSERT INTO task_links (from_task_id, to_task_id, type) VALUES (2, 3, 'parent')
      """
