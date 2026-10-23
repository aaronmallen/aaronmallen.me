Feature: MCP artifact tools
  Agents write numbered documents in versions; the text an agent wrote comes marked untrusted.

  Background:
    Given an MCP client connected with the scopes "read agents delete"

  Scenario: An agent's edits add a version for each body with its agent, model and note, and read_artifact reads any version
    When before it I call 'create_artifact {"title": "Index the activities table", "type": "plan", "body": "## Steps", "note": "First pass", "agent": "claude-code", "model": "claude-opus-5-5"}'
    And before it I call 'update_artifact {"id": 1, "body": "## Steps\n\n1. Add the index", "note": "Added a step", "agent": "claude-code", "model": "claude-opus-5-5"}'
    And before it I call 'update_artifact {"id": 1, "body": "## Done", "agent": "codex", "model": "gpt-5"}'
    And I call the MCP tool "read_artifact" with:
      """
      { "id": 1 }
      """
    Then the "number, agent, model, note" of each row at "versions" in the MCP tool answer, read as text, are:
      """
      [[1, "claude-code", "claude-opus-5-5", "First pass"], [2, "claude-code", "claude-opus-5-5", "Added a step"], [3, "codex", "gpt-5", null]]
      """
    And the MCP tool answer at "body", read as text, matches:
      """
      "## Done"
      """
    When I call the MCP tool "read_artifact" with:
      """
      { "id": 1, "version": 2 }
      """
    Then the MCP tool answer at "body", read as text, matches:
      """
      "## Steps\n\n1. Add the index"
      """

  Scenario: A title, type or tag change adds no version, and neither does the same body
    When before it I call 'create_artifact {"title": "Index the activities table", "type": "plan", "body": "## Steps", "agent": "claude-code", "model": "claude-opus-5-5"}'
    And I call the MCP tool "update_artifact" with:
      """
      { "id": 1, "title": "Handoff", "type": "handoff", "tags": ["site", "perf"], "agent": "claude-code", "model": "claude-opus-5-5" }
      """
    Then the MCP tool answer at "", read as text, matches:
      """
      { "title": "Handoff", "type": "handoff", "tags": ["perf", "site"], "version": 1 }
      """
    When before it I call 'update_artifact {"id": 1, "body": "## Steps", "note": "Nothing new", "agent": "claude-code", "model": "claude-opus-5-5"}'
    Then the table artifact_versions holds 1 row

  Scenario: Restoring an old version adds a new one with its body, and a version the artifact lacks is refused
    When before it I call 'create_artifact {"title": "Index the activities table", "type": "plan", "body": "## Steps", "agent": "claude-code", "model": "claude-opus-5-5"}'
    And before it I call 'update_artifact {"id": 1, "body": "## Wrong turn", "agent": "claude-code", "model": "claude-opus-5-5"}'
    And I call the MCP tool "restore_artifact_version" with:
      """
      { "id": 1, "version": 1, "agent": "claude-code", "model": "claude-opus-5-5" }
      """
    Then the MCP tool answer at "body", read as text, matches:
      """
      "## Steps"
      """
    And the "number, note" of each row at "versions" in the MCP tool answer, read as text, are:
      """
      [[1, null], [2, null], [3, "Restored version 1"]]
      """
    When I call the MCP tool "restore_artifact_version" with:
      """
      { "id": 1, "version": 4, "agent": "claude-code", "model": "claude-opus-5-5" }
      """
    Then the MCP tool refuses with "artifact 1 has no version 4"

  Scenario: After the owner edits an agent's artifact, the agent's body, note and title stay marked and the owner's body is plain
    Given I am signed in to the admin
    When before it I call 'create_artifact {"title": "Index the activities table", "type": "plan", "body": "## Steps", "note": "Draft", "agent": "claude-code", "model": "claude-opus-5-5"}'
    And I save "Index the activities table" with:
      | body | ## Owner's |
      | note | Mine       |
    And I call the MCP tool "read_artifact" with:
      """
      { "id": 1, "version": 1 }
      """
    Then the MCP tool answer at "body" is marked "## Steps"
    And the "note" of each row at "versions" in the MCP tool answer are:
      | marked | Draft |
      | plain  | Mine  |
    When I call the MCP tool "read_artifact" with:
      """
      { "id": 1 }
      """
    Then the MCP tool answer at "body" is plain "## Owner's"
    And the MCP tool answer at "title" is marked "Index the activities table"

  Scenario: A title the owner sets stays plain, and a title an agent sets on the owner's artifact comes marked
    Given I am signed in to the admin
    When before it I call 'create_artifact {"title": "Index the activities table", "type": "plan", "body": "## Steps", "agent": "claude-code", "model": "claude-opus-5-5"}'
    And I save "Index the activities table" with:
      | title | Owner's plan |
    And I call the MCP tool "list_artifacts"
    Then the "title" of each row at "artifacts" in the MCP tool answer are:
      | plain | Owner's plan |
    Given I write the plan "Mine" with the body "## Steps"
    When before it I call 'update_artifact {"id": 2, "title": "Theirs", "agent": "claude-code", "model": "claude-opus-5-5"}'
    And I call the MCP tool "read_artifact" with:
      """
      { "id": 2 }
      """
    Then the MCP tool answer at "title" is marked "Theirs"

  Scenario: list_artifacts lists every artifact last changed first, filters by type, and searches the title, the latest body and the tags
    When before it I call 'create_artifact {"title": "Index the activities table", "type": "plan", "body": "Add a composite index", "tags": ["perf"], "agent": "claude-code", "model": "claude-opus-5-5"}'
    And before it I call 'create_artifact {"title": "Webmention receiver", "type": "spec", "body": "Reject sources without a link back", "agent": "claude-code", "model": "claude-opus-5-5"}'
    And before it I call 'create_artifact {"title": "Ractor notes", "type": "research", "body": "Contexts are not shareable", "tags": ["ractors"], "agent": "claude-code", "model": "claude-opus-5-5"}'
    And I call the MCP tool "list_artifacts"
    Then the "title" of each row at "artifacts" in the MCP tool answer, read as text, are:
      """
      ["Ractor notes", "Webmention receiver", "Index the activities table"]
      """
    When I call the MCP tool "list_artifacts" with:
      """
      { "type": "spec" }
      """
    Then the "title" of each row at "artifacts" in the MCP tool answer, read as text, are:
      """
      ["Webmention receiver"]
      """
    When I call the MCP tool "list_artifacts" with:
      """
      { "query": "receiver" }
      """
    Then the "title" of each row at "artifacts" in the MCP tool answer, read as text, are:
      """
      ["Webmention receiver"]
      """
    When I call the MCP tool "list_artifacts" with:
      """
      { "query": "composite" }
      """
    Then the "title" of each row at "artifacts" in the MCP tool answer, read as text, are:
      """
      ["Index the activities table"]
      """
    When I call the MCP tool "list_artifacts" with:
      """
      { "query": "ractors" }
      """
    Then the "title" of each row at "artifacts" in the MCP tool answer, read as text, are:
      """
      ["Ractor notes"]
      """

  Scenario: list_artifacts searches only the latest body
    When before it I call 'create_artifact {"title": "Webmention receiver", "type": "spec", "body": "Reject sources without a link back", "agent": "claude-code", "model": "claude-opus-5-5"}'
    And before it I call 'update_artifact {"id": 1, "body": "Accept every source", "agent": "claude-code", "model": "claude-opus-5-5"}'
    And I call the MCP tool "list_artifacts" with:
      """
      { "query": "link back" }
      """
    Then the MCP tool answer at "artifacts" is "[]"
    When I call the MCP tool "list_artifacts" with:
      """
      { "query": "every source" }
      """
    Then the "title" of each row at "artifacts" in the MCP tool answer, read as text, are:
      """
      ["Webmention receiver"]
      """

  Scenario: delete_artifact deletes an artifact with every version
    When before it I call 'create_artifact {"title": "Index the activities table", "type": "plan", "body": "## Steps", "agent": "claude-code", "model": "claude-opus-5-5"}'
    And before it I call 'update_artifact {"id": 1, "body": "## Two", "agent": "claude-code", "model": "claude-opus-5-5"}'
    And I call the MCP tool "delete_artifact" with:
      """
      { "id": 1 }
      """
    Then the MCP answer holds:
      """
      { "id": 1, "deleted": true }
      """
    And the table artifact_versions holds 0 rows
    When I call the MCP tool "read_artifact" with:
      """
      { "id": 1 }
      """
    Then the MCP tool refuses with "no artifact has the ID 1"

  Scenario Outline: <tool> refuses a <field> over <cap> characters
    When before it I call 'create_artifact {"title": "Index the activities table", "type": "plan", "body": "## Steps", "agent": "claude-code", "model": "claude-opus-5-5"}'
    And I call the MCP tool "<tool>" with a <field> of <length> "a"s and:
      """
      <input>
      """
    Then the MCP tool refuses with "<field>: keep a <field> to <cap> characters"

    Examples:
      | tool            | field | length | cap    | input                                                                                    |
      | create_artifact | body  | 100001 | 100000 | {"title": "Big", "type": "notes", "agent": "claude-code", "model": "claude-opus-5-5"}    |
      | create_artifact | title | 201    | 200    | {"type": "notes", "body": "## Steps", "agent": "claude-code", "model": "claude-opus-5-5"} |
      | update_artifact | note  | 201    | 200    | {"id": 1, "body": "## New", "agent": "claude-code", "model": "claude-opus-5-5"}          |

  Scenario: The database numbers versions in order, refuses two versions with one number and a title over 200 characters
    When before it I call 'create_artifact {"title": "Index the activities table", "type": "plan", "body": "## Steps", "agent": "claude-code", "model": "claude-opus-5-5"}'
    And the database runs "INSERT INTO artifact_versions (artifact_id, number, body) VALUES (1, 7, '## Again')"
    Then the database answers "1, 2" for:
      """
      SELECT string_agg(number::text, ', ' ORDER BY number) FROM artifact_versions
      """
    And the database refuses, breaking a unique constraint:
      """
      UPDATE artifact_versions SET number = 1 WHERE number = 2
      """
    And the database refuses, breaking a check constraint:
      """
      INSERT INTO artifacts (title, type) VALUES (repeat('a', 201), 'plan')
      """
