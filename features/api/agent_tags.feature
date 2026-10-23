Feature: API agent tags
  Sessions, memory files and artifacts take their project's own tags, or private tags with no project.

  Background:
    Given an API token with the scopes "read, write, delete, agents"
    And the project "BLOG" in the repo "aaronmallen/blog"
    And the project "POD"
    And I note the ids of "nothing"

  Scenario: A session in a project takes the project's own tag, made there when missing, and drops it
    When I POST "/agent_sessions" through the API with:
      """
      { "title": "Spike", "repo": "aaronmallen/blog", "agent": "claude-code", "model": "claude-opus-5-5" }
      """
    And I keep the answer's "session_id" as "session"
    And I POST "/agent_sessions/{session}/tags" through the API with:
      """
      { "tag": "Perf" }
      """
    Then the API answers 201
    And the API answer at "tags" is '["perf"]'
    And the tags agent_session_tags holds for {session} are "perf project {project1}"
    When I DELETE "/agent_sessions/{session}/tags/perf" through the API
    Then the API answer at "tags" is "[]"

  Scenario: A session in no project takes a private tag, lists it, and refuses a tag it lacks or one that is no slug
    When I POST "/agent_sessions" through the API with:
      """
      { "title": "Spike", "agent": "claude-code", "model": "claude-opus-5-5" }
      """
    And I keep the answer's "session_id" as "session"
    And I POST "/agent_sessions/{session}/tags" through the API with:
      """
      { "tag": "perf" }
      """
    Then the tags agent_session_tags holds for {session} are "perf private"
    When I GET "/agent_sessions" through the API
    Then the API answer at "sessions.0.tags" is '["perf"]'
    When I DELETE "/agent_sessions/{session}/tags/other" through the API
    Then the API answers 404
    And the API answer at "message" is '"session {session} has no tag other"'
    When I POST "/agent_sessions/{session}/tags" through the API with:
      """
      { "tag": "two words" }
      """
    Then the API answers 422

  Scenario: A project memory file takes the project's own tag, and a global one a private tag it can drop
    When I POST "/memory_files" through the API with:
      """
      { "path": "notes", "description": "Notes", "scope": "project", "project_id": {project1}, "agent": "claude-code", "model": "claude-opus-5-5" }
      """
    And I keep the answer's "id" as "projectfile"
    And I POST "/memory_files/{projectfile}/tags" through the API with:
      """
      { "tag": "perf" }
      """
    Then the API answer at "tags" is '["perf"]'
    And the tags memory_file_tags holds for {projectfile} are "perf project {project1}"
    When I POST "/memory_files" through the API with:
      """
      { "path": "notes", "description": "Notes", "scope": "global", "agent": "claude-code", "model": "claude-opus-5-5" }
      """
    And I keep the answer's "id" as "globalfile"
    And I POST "/memory_files/{globalfile}/tags" through the API with:
      """
      { "tag": "perf" }
      """
    Then the tags memory_file_tags holds for {globalfile} are "perf private"
    When I DELETE "/memory_files/{globalfile}/tags/perf" through the API
    And I GET "/memory_files/{globalfile}" through the API
    Then the API answer at "tags" is "[]"

  Scenario: An artifact takes private tags, then its linked project's own in place of them
    When I POST "/artifacts" through the API with:
      """
      { "title": "Plan", "type": "plan", "body": "Steps", "agent": "claude-code", "model": "claude-opus-5-5" }
      """
    And I keep the answer's "id" as "artifact"
    And I PATCH "/artifacts/{artifact}" through the API with:
      """
      { "tags": ["perf"], "agent": "claude-code", "model": "claude-opus-5-5" }
      """
    Then the tags artifact_tags holds for {artifact} are "perf private"
    When I POST "/links/artifact/{artifact}" through the API with:
      """
      { "other_kind": "project", "other_id": {project1} }
      """
    And I PATCH "/artifacts/{artifact}" through the API with:
      """
      { "tags": ["perf"], "agent": "claude-code", "model": "claude-opus-5-5" }
      """
    Then the tags artifact_tags holds for {artifact} are "perf project {project1}"

  Scenario: An artifact takes a copy of each tag in every project it links to, and drops a project's when its link goes
    When I POST "/artifacts" through the API with:
      """
      { "title": "Plan", "type": "plan", "body": "Steps", "agent": "claude-code", "model": "claude-opus-5-5" }
      """
    And I keep the answer's "id" as "artifact"
    And I POST "/links/artifact/{artifact}" through the API with:
      """
      { "other_kind": "project", "other_id": {project1} }
      """
    And I POST "/links/artifact/{artifact}" through the API with:
      """
      { "other_kind": "project", "other_id": {project2} }
      """
    And I PATCH "/artifacts/{artifact}" through the API with:
      """
      { "tags": ["perf"], "agent": "claude-code", "model": "claude-opus-5-5" }
      """
    Then the tags artifact_tags holds for {artifact} are "perf project {project1}, perf project {project2}"
    When I DELETE "/links/artifact/{artifact}/project/{project1}" through the API
    Then the tags artifact_tags holds for {artifact} are "perf project {project2}"

  Scenario: The project tag lists each agent record that carries it, and none to a token without agents
    When I POST "/agent_sessions" through the API with:
      """
      { "title": "Spike", "repo": "aaronmallen/blog", "agent": "claude-code", "model": "claude-opus-5-5" }
      """
    And I keep the answer's "session_id" as "session"
    And I POST "/agent_sessions/{session}/tags" through the API with:
      """
      { "tag": "perf" }
      """
    And I POST "/memory_files" through the API with:
      """
      { "path": "notes", "description": "Notes", "scope": "project", "project_id": {project1}, "agent": "claude-code", "model": "claude-opus-5-5" }
      """
    And I keep the answer's "id" as "file"
    And I POST "/memory_files/{file}/tags" through the API with:
      """
      { "tag": "perf" }
      """
    And I POST "/artifacts" through the API with:
      """
      { "title": "Plan", "type": "plan", "body": "Steps", "agent": "claude-code", "model": "claude-opus-5-5" }
      """
    And I keep the answer's "id" as "artifact"
    And I POST "/links/artifact/{artifact}" through the API with:
      """
      { "other_kind": "project", "other_id": {project1} }
      """
    And I PATCH "/artifacts/{artifact}" through the API with:
      """
      { "tags": ["perf"], "agent": "claude-code", "model": "claude-opus-5-5" }
      """
    When I GET "/tags/perf?project=BLOG" through the API
    Then the API answer holds 1 record under each of "agent_sessions, memory_files, artifacts"
    Given an API token with the scopes "read"
    When I GET "/tags/perf?project=BLOG" through the API
    Then the API answer leaves out "agent_sessions, memory_files, artifacts" and their counts
