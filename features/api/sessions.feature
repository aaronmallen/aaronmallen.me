Feature: API sessions
  An agent opens a session, works inside it and ends it, and the session keeps what it loaded, read, searched and wrote.

  Background:
    Given an API token with the scopes "read, write, delete, agents"
    And the task "Index the activities table"
    And I note the ids of "nothing"

  Scenario: A session walks from start to end and answers each as documented
    When I POST "/agent_sessions" through the API with:
      """
      { "title": "Spike", "client": "Terminal", "tasks": [{task1}], "agent": "claude-code", "model": "claude-opus-5-5" }
      """
    And I keep the answer's "session_id" as "session"
    And I POST "/memory_files" through the API with:
      """
      { "path": "hanami", "description": "Notes", "scope": "global", "session_id": {session}, "agent": "claude-code", "model": "claude-opus-5-5" }
      """
    And I keep the answer's "id" as "file"
    And I POST "/artifacts" through the API with:
      """
      { "title": "Plan", "type": "plan", "body": "Steps", "session_id": {session}, "agent": "claude-code", "model": "claude-opus-5-5" }
      """
    And I POST "/agent_sessions/{session}/end" through the API
    And I GET "/agent_sessions" through the API
    Then the API answer at "sessions.0" matches:
      """
      { "task_ids": [{task1}], "memory_changes": [{ "memory_file_id": {file}, "op": "create" }],
        "artifact_versions": [{ "number": 1 }] }
      """
    And the API answer at "sessions.0.ended_at" is a time

  Scenario: The list filters by the project a session ran in
    Given the project "Blog" in the repo "aaronmallen/blog"
    And I note the ids of "nothing"
    When I POST "/agent_sessions" through the API with:
      """
      { "title": "Spike", "repo": "aaronmallen/blog", "agent": "claude-code", "model": "claude-opus-5-5" }
      """
    And I keep the answer's "session_id" as "inside"
    And I POST "/agent_sessions" through the API with:
      """
      { "title": "Spike", "agent": "claude-code", "model": "claude-opus-5-5" }
      """
    And I GET "/agent_sessions?project_id={project1}" through the API
    Then the API answer at "sessions" matches:
      """
      [{ "id": {inside}, "project_id": {project1} }]
      """
    And the API answer at "sessions" holds 1 item

  Scenario: A session records the files it reads and searches, and returns the index it records
    Given the agent files the global memory "hanami" described "Notes"
    And the agent adds the gotcha "Mind the cache" to "hanami"
    And I note the ids of "hanami"
    When I POST "/agent_sessions" through the API with:
      """
      { "title": "Spike", "agent": "claude-code", "model": "claude-opus-5-5" }
      """
    And I keep the answer's "session_id" as "session"
    Then the API answer at "files" matches:
      """
      [{ "id": {file}, "path": "hanami.md", "fact_count": 1 }]
      """
    And the database answers "{file}, 1" for:
      """
      SELECT memory_file_id, fact_count FROM agent_session_index_lines
      """
    When I GET "/memory_files/{file}?session_id={session}" through the API
    And I GET "/memory/search?query=cache&session_id={session}" through the API
    And I GET "/agent_sessions" through the API
    Then the API answer at "sessions.0.loaded" is:
      """
      [{ "memory_file_id": {file}, "path": "hanami.md" }]
      """

  Scenario: A search in a session answers as one without, and records its query, filters and hits
    Given the agent files the global memory "hanami" described "Notes"
    And the agent adds the gotcha "Mind the cache" to "hanami"
    And I note the ids of "hanami"
    And I POST "/agent_sessions" through the API with:
      """
      { "title": "Spike", "agent": "claude-code", "model": "claude-opus-5-5" }
      """
    And I keep the answer's "session_id" as "session"
    When I GET "/memory/search?query=cache&scope=global&repo=aaronmallen/blog" through the API
    And I keep the answer as "plain"
    And I GET "/memory/search?query=cache&scope=global&repo=aaronmallen/blog&session_id={session}" through the API
    Then the API answer is the one kept as "plain"
    And the database answers "{session}, cache, global, aaronmallen/blog, true" for:
      """
      SELECT agent_session_id, query, scope, repo, project_id IS NULL AND task_id IS NULL AS unfiltered FROM agent_session_searches
      """
    And the database answers "{file}, Mind the cache, hanami.md" for:
      """
      SELECT memory_file_id, text, path FROM agent_session_search_hits
      """

  Scenario: A search with no hits is recorded, and none without a session
    Given the agent files the global memory "hanami" described "Notes"
    And the agent adds the gotcha "Mind the cache" to "hanami"
    And I GET "/memory/search?query=cache" through the API
    Then the table agent_session_searches holds 0 rows
    When I POST "/agent_sessions" through the API with:
      """
      { "title": "Spike", "agent": "claude-code", "model": "claude-opus-5-5" }
      """
    And I keep the answer's "session_id" as "session"
    And I GET "/memory/search?query=nothing&session_id={session}" through the API
    Then the table agent_session_searches holds 1 row
    And the table agent_session_search_hits holds 0 rows

  Scenario: A read in a session is recorded each time with its time, and none without an open session
    Given the agent files the global memory "hanami" described "Notes"
    And I note the ids of "hanami"
    And I POST "/agent_sessions" through the API with:
      """
      { "title": "Spike", "agent": "claude-code", "model": "claude-opus-5-5" }
      """
    And I keep the answer's "session_id" as "session"
    When I GET "/memory_files/{file}" through the API
    Then the table agent_session_reads holds 0 rows
    When I GET "/memory_files/{file}?session_id={session}" through the API
    And I GET "/memory_files/{file}?session_id={session}" through the API
    Then the database answers "2, true" for:
      """
      SELECT count(*), bool_and(read_at > now() - interval '1 minute' AND memory_file_id = {file}) FROM agent_session_reads
      """
    When I GET "/memory_files/{file}?session_id=999" through the API
    Then the API answers 422
    And the table agent_session_reads holds 2 rows

  Scenario: An ended session reads and searches as no session does, records nothing and refuses a write
    Given the agent files the global memory "hanami" described "Notes"
    And the agent adds the gotcha "Mind the cache" to "hanami"
    And I note the ids of "hanami"
    And I POST "/agent_sessions" through the API with:
      """
      { "title": "Spike", "agent": "claude-code", "model": "claude-opus-5-5" }
      """
    And I keep the answer's "session_id" as "session"
    And I POST "/agent_sessions/{session}/end" through the API
    When I GET "/memory_files/{file}" through the API
    And I keep the answer as "plain"
    And I GET "/memory_files/{file}?session_id={session}" through the API
    Then the API answer is the one kept as "plain"
    When I GET "/memory/search?query=cache" through the API
    And I keep the answer as "plain search"
    And I GET "/memory/search?query=cache&session_id={session}" through the API
    Then the API answer is the one kept as "plain search"
    And the database answers "0" for:
      """
      SELECT (SELECT count(*) FROM agent_session_loads) + (SELECT count(*) FROM agent_session_searches) + (SELECT count(*) FROM agent_session_reads)
      """
    When I POST "/memory_files/{file}/facts" through the API with:
      """
      { "type": "gotcha", "text": "Late", "session_id": {session}, "agent": "claude-code", "model": "claude-opus-5-5" }
      """
    Then the API answer at "errors" is:
      """
      { "session_id": ["that session is not open; start_session opens one"] }
      """

  Scenario: Ending a session twice is refused
    When I POST "/agent_sessions" through the API with:
      """
      { "title": "Spike", "agent": "claude-code", "model": "claude-opus-5-5" }
      """
    And I keep the answer's "session_id" as "session"
    And I POST "/agent_sessions/{session}/end" through the API
    And I POST "/agent_sessions/{session}/end" through the API
    Then the API answers 422
    And the API answer at "errors" is:
      """
      { "id": ["session {session} already ended"] }
      """

  Scenario: A write into a session that does not exist is refused, and so is a session with no agent
    When I POST "/memory_files" through the API with:
      """
      { "path": "hanami", "description": "Notes", "scope": "global", "session_id": 999, "agent": "claude-code", "model": "claude-opus-5-5" }
      """
    Then the API answer at "errors" is:
      """
      { "session_id": ["that session is not open; start_session opens one"] }
      """
    When I POST "/agent_sessions" through the API with:
      """
      { "title": "Spike" }
      """
    Then the API answers 422
