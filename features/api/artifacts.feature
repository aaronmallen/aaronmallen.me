Feature: API artifacts
  Agents write, revise and delete artifacts through the API, each version naming the agent.

  Background:
    Given an API token with the scopes "read, write, delete, agents"
    And I POST "/artifacts" through the API with:
      """
      { "title": "Plan", "type": "plan", "body": "## Steps", "agent": "claude-code", "model": "claude-opus-5-5" }
      """
    And I keep the answer's "id" as "artifact"

  Scenario: An artifact that names no agent is refused
    When I POST "/artifacts" through the API with:
      """
      { "title": "Plan", "type": "plan", "body": "## Steps" }
      """
    Then the API answers 422
    And the API answer at "errors" is:
      """
      { "agent": ["agent is missing"], "model": ["model is missing"] }
      """

  Scenario: An update that names no agent is refused and keeps the agent's version
    When I PATCH "/artifacts/{artifact}" through the API with:
      """
      { "title": "Trusted plan", "body": "## Trust me" }
      """
    Then the API answers 422
    When I GET "/artifacts/{artifact}" through the API
    Then the API answer holds:
      """
      { "title": "Plan", "body": "## Steps", "versions": [{ "agent": "claude-code", "model": "claude-opus-5-5" }] }
      """

  Scenario: Tags come back lowercased in name order, and a tag that is no slug is refused
    When I PATCH "/artifacts/{artifact}" through the API with:
      """
      { "tags": ["Site", "perf"], "agent": "claude-code", "model": "claude-opus-5-5" }
      """
    Then the API answer at "tags" is '["perf", "site"]'
    When I PATCH "/artifacts/{artifact}" through the API with:
      """
      { "tags": ["two words"], "agent": "claude-code", "model": "claude-opus-5-5" }
      """
    Then the API answers 422
    And the API answer at "errors" is:
      """
      { "tags": ["a tag is lowercase words joined by hyphens"] }
      """

  Scenario: A type it does not know is refused, and a version past the latest is not found
    When I POST "/artifacts" through the API with:
      """
      { "title": "Plan", "type": "memo", "body": "## Steps", "agent": "claude-code", "model": "claude-opus-5-5" }
      """
    Then the API answers 422
    When I GET "/artifacts/{artifact}?version=2" through the API
    Then the API answers 404
    And the API answer at "message" is '"artifact {artifact} has no version 2"'

  Scenario: Deleting an artifact takes agents and delete, and artifacts take agents
    Given an API token with the scopes "agents"
    When I DELETE "/artifacts/{artifact}" through the API
    Then the API answers 403
    And the API answer at "error_description" is '"this endpoint needs a token with the delete scope"'
    Given an API token with the scopes "agents, delete"
    When I DELETE "/artifacts/{artifact}" through the API
    Then the API answer is:
      """
      { "id": {artifact}, "deleted": true }
      """
    Given an API token with the scopes "read, write, delete"
    When I GET "/artifacts" through the API
    Then the API answers 403
