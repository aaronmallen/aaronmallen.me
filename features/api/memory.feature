Feature: API memory
  Agents read, search and change memory files through the API, each change naming the agent that made it.

  Background:
    Given an API token with the scopes "read, write, delete, agents"
    And I POST "/memory_files" through the API with:
      """
      { "path": "hanami", "description": "Notes", "scope": "global", "agent": "claude-code", "model": "claude-opus-5-5" }
      """
    And I keep the answer's "id" as "file"
    And I POST "/memory_files/{file}/facts" through the API with:
      """
      { "type": "gotcha", "text": "Mind the cache", "agent": "claude-code", "model": "claude-opus-5-5" }
      """
    And I keep the answer's "id" as "fact"

  Scenario: A file walks through every change and answers each as documented
    When I PATCH "/memory_files/{file}/facts/{fact}" through the API with:
      """
      { "text": "Mind the query cache", "agent": "claude-code", "model": "claude-opus-5-5" }
      """
    And I POST "/memory_files/{file}/facts/{fact}/remove" through the API with:
      """
      { "agent": "claude-code", "model": "claude-opus-5-5" }
      """
    And I GET "/memory_files/{file}?history=true" through the API
    And I keep the answer's "history.0.id" as "removed"
    And I POST "/memory_files/{file}/history/{removed}/revert" through the API with:
      """
      { "agent": "claude-code", "model": "claude-opus-5-5" }
      """
    And I GET "/memory_files/{file}" through the API
    Then the API answer at "facts" matches:
      """
      [{ "text": "Mind the query cache" }]
      """

  Scenario: Fact text of any length adds and edits
    When I call the API POST "memory_files/{file}/facts" with a gotcha of 5000 "a"s
    And I keep the answer's "id" as "long"
    And I call the API PATCH "memory_files/{file}/facts/{long}" with a text of 6000 "b"s
    And I POST "/memory_files/{file}/facts/{fact}/remove" through the API with:
      """
      { "agent": "claude-code", "model": "claude-opus-5-5" }
      """
    And I GET "/memory_files/{file}" through the API
    Then the API answer's facts are 1 text of 6000 "b"s

  Scenario: The index lists the files without their facts
    When I GET "/memory" through the API
    Then the API answer is:
      """
      { "files": [{ "id": {file}, "path": "hanami.md", "description": "Notes", "scope": "global",
                    "project_id": null, "task_id": null, "fact_count": 1 }] }
      """

  Scenario Outline: A change that names <what> is refused
    When I call the API <method> "<path>" with the body '<body>'
    Then the API answers 422
    And the API answer at "errors" is '<errors>'

    Examples:
      | what                       | method | path                         | body                                                                                              | errors                                                                      |
      | no agent                   | POST   | memory_files/{file}/facts    | {"type": "gotcha", "text": "Trust me"}                                                            | {"agent": ["agent is missing"], "model": ["model is missing"]}              |
      | an agent without a model   | POST   | memory_files/{file}/facts    | {"type": "gotcha", "text": "Half named", "agent": "claude-code"}                                  | {"model": ["model is missing"]}                                             |
      | a blank agent beside a model | POST | memory_files                 | {"path": "other", "description": "Notes", "scope": "global", "agent": "", "model": "claude-opus-5-5"} | {"agent": ["name the agent along with its model"]}                      |
      | an agent over the slug limit | POST | memory_files                 | {"path": "other", "description": "Notes", "scope": "global", "agent": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "model": "claude-opus-5-5"} | {"agent": ["keep an agent to 64 characters"]} |
      | a task that does not exist | POST   | memory_files                 | {"path": "notes", "description": "Notes", "scope": "task", "task_id": 999999, "agent": "claude-code", "model": "claude-opus-5-5"} | {"task_id": ["a task file needs a task that exists"]} |

  Scenario: An edit that names no agent is refused and keeps the agent's name on the fact
    When I PATCH "/memory_files/{file}/facts/{fact}" through the API with:
      """
      { "text": "Trust me" }
      """
    Then the API answers 422
    When I GET "/memory_files/{file}" through the API
    Then the API answer at "facts.0" matches:
      """
      { "text": "Mind the cache", "agent": "claude-code", "model": "claude-opus-5-5" }
      """

  Scenario: Another agent's edit names that agent
    When I PATCH "/memory_files/{file}/facts/{fact}" through the API with:
      """
      { "text": "Trust me", "agent": "codex", "model": "gpt-5" }
      """
    And I GET "/memory_files/{file}" through the API
    Then the API answer at "facts.0" matches:
      """
      { "text": "Trust me", "agent": "codex", "model": "gpt-5" }
      """

  Scenario: A revert that names no agent is refused
    When I POST "/memory_files/{file}/facts/{fact}/remove" through the API with:
      """
      { "agent": "claude-code", "model": "claude-opus-5-5" }
      """
    And I GET "/memory_files/{file}?history=true" through the API
    And I keep the answer's "history.0.id" as "removed"
    And I POST "/memory_files/{file}/history/{removed}/revert" through the API with:
      """
      {}
      """
    Then the API answers 422
    And the API answer at "errors" is '{"agent": ["agent is missing"], "model": ["model is missing"]}'

  Scenario: A file's description changes
    When I POST "/memory_files/{file}/describe" through the API with:
      """
      { "description": "How we test", "agent": "claude-code", "model": "claude-opus-5-5" }
      """
    And I GET "/memory_files/{file}" through the API
    Then the API answer at "description" is '"How we test"'

  Scenario: A file without a description, or with a repo scope, is refused
    When I POST "/memory_files" through the API with:
      """
      { "path": "other", "scope": "global", "agent": "claude-code", "model": "claude-opus-5-5" }
      """
    Then the API answers 422
    When I POST "/memory_files" through the API with:
      """
      { "path": "other", "description": "Notes", "scope": "repo", "agent": "claude-code", "model": "claude-opus-5-5" }
      """
    Then the API answers 422
    And the API answer at "message" is:
      """
      "value at `/scope` is not one of: [\"global\", \"project\", \"task\"]"
      """

  Scenario: Reverting the file's creation is refused
    When I GET "/memory_files/{file}?history=true" through the API
    And I keep the answer's "history.1.id" as "created"
    And I POST "/memory_files/{file}/history/{created}/revert" through the API with:
      """
      { "agent": "claude-code", "model": "claude-opus-5-5" }
      """
    Then the API answer at "errors" is '{"event_id": ["only an add, an edit, a remove or a describe can be reverted"]}'

  Scenario: An edit to a removed fact is not found
    When I POST "/memory_files/{file}/facts/{fact}/remove" through the API with:
      """
      { "agent": "claude-code", "model": "claude-opus-5-5" }
      """
    And I PATCH "/memory_files/{file}/facts/{fact}" through the API with:
      """
      { "text": "Back again", "agent": "claude-code", "model": "claude-opus-5-5" }
      """
    Then the API answers 404

  Scenario: Deleting a file takes agents and delete
    Given an API token with the scopes "agents"
    When I DELETE "/memory_files/{file}" through the API
    Then the API answers 403
    And the API answer at "error_description" is '"this endpoint needs a token with the delete scope"'
    Given an API token with the scopes "agents, delete"
    When I DELETE "/memory_files/{file}" through the API
    Then the API answer is:
      """
      { "id": {file}, "deleted": true }
      """

  Scenario: A search finds the text of live facts and memory stays out of the global search
    When I GET "/memory/search?query=cache" through the API
    Then the API answer at "facts" matches:
      """
      [{ "id": {fact}, "path": "hanami.md" }]
      """
    When I GET "/search?query=cache" through the API
    Then the API answer at "results" is "[]"

  Scenario: Memory and its search are refused to a token without agents
    Given an API token with the scopes "read, write, delete"
    When I GET "/memory/search?query=cache" through the API
    Then the API answers 403
    When I GET "/memory" through the API
    Then the API answers 403
