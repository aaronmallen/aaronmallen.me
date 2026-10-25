Feature: MCP session tools
  A session runs from start_session to end_session, loads the memory that matches it, and records what it reads and
  writes.

  Background:
    Given an MCP client connected with the scopes "read agents"

  Rule: start_session loads the global, project and task files that match

    Background:
      Given the project "Blog" in the repo "aaronmallen/blog"
      And the project "Other" in the repo "aaronmallen/other"
      And the task "Index the activities table"
      And the agent calls 'create_memory_file {"path": "task-notes", "description": "Notes", "scope": "task", "task_id": 1}'
      And the agent calls 'create_memory_file {"path": "release", "description": "Notes", "scope": "project", "project_id": 1}'
      And the agent calls 'create_memory_file {"path": "hanami", "description": "Notes", "scope": "project", "project_id": 1}'
      And the agent calls 'create_memory_file {"path": "preferences", "description": "Notes", "scope": "global"}'
      And the agent calls 'create_memory_file {"path": "elsewhere", "description": "Notes", "scope": "project", "project_id": 2}'

    Scenario: It returns an index of the matching files without their facts, and lists the session with its tasks
      When the agent calls the MCP tool "start_session" with:
        """
        { "title": "Index the activities table", "repo": "aaronmallen/blog", "branch": "activities-index", "tasks": [1] }
        """
      Then the MCP tool answer at "files" matches:
        """
        [
          { "path": "preferences.md" }, { "path": "hanami.md" }, { "path": "release.md" }, { "path": "task-notes.md" }
        ]
        """
      And the MCP tool answer at "files.length" is "4"
      And the MCP tool answer at "", read as text, matches:
        """
        { "session_id": 1 }
        """
      And the keys of the MCP tool answer are "session_id, files"
      And the keys of each row at "files" in the MCP tool answer are "id, path, description, scope, project_id, task_id, fact_count"
      When I call the MCP tool "list_sessions"
      Then the MCP tool answer at "sessions.0", read as text, matches:
        """
        { "id": 1, "branch": "activities-index", "task_ids": [1], "loaded": [] }
        """

    Scenario: A repo named in mixed case or with spaces loads and records as its lower case name
      When the agent calls the MCP tool "start_session" with:
        """
        { "title": "Index the activities table", "repo": " AaronMallen/Blog " }
        """
      Then the "path" of each row at "files" in the MCP tool answer, read as text, are:
        """
        ["preferences.md", "hanami.md", "release.md"]
        """
      When I call the MCP tool "list_sessions"
      Then the MCP tool answer at "sessions.0.repo", read as text, matches:
        """
        "aaronmallen/blog"
        """

    Scenario: A repo that is not owner/name is refused
      When the agent calls the MCP tool "start_session" with:
        """
        { "title": "Spike", "repo": "aaronmallen" }
        """
      Then the MCP tool refuses with "repo: name the repository as owner/name"

    Scenario: The project its key names loads its files, and its repo or key is recorded
      When the agent calls the MCP tool "start_session" with:
        """
        { "title": "Index the activities table", "project": "blog" }
        """
      Then the "path" of each row at "files" in the MCP tool answer, read as text, are:
        """
        ["preferences.md", "hanami.md", "release.md"]
        """
      When the agent calls 'start_session {"title": "Index", "repo": "aaronmallen/blog"}'
      And I call the MCP tool "list_sessions"
      Then the "project_id" of each row at "sessions" in the MCP tool answer, read as text, are:
        """
        [1, 1]
        """

    Scenario: A session naming neither records no project, and a key that names no project is refused
      When the agent calls 'start_session {"title": "Index"}'
      And I call the MCP tool "list_sessions"
      Then the MCP tool answer at "sessions.0.project_id" is "null"
      When the agent calls the MCP tool "start_session" with:
        """
        { "title": "Spike", "project": "NOPE" }
        """
      Then the MCP tool refuses with "project: name a project key that exists"

    Scenario: A repo no project holds makes a private project named after it, recorded on the session, whose files load next time
      When the agent calls 'start_session {"title": "Index", "repo": "aaronmallen/fresh"}'
      Then the database answers "fresh, private, 3" for:
        """
        SELECT name, visibility, id FROM projects WHERE repo = 'aaronmallen/fresh'
        """
      And the database answers "3" for:
        """
        SELECT string_agg(trp.project_id::text, ', ') FROM task_rules r JOIN task_rule_projects trp ON trp.task_rule_id = r.id
        WHERE r.pattern = 'aaronmallen/fresh'
        """
      When I call the MCP tool "list_sessions"
      Then the MCP tool answer at "sessions.0.project_id" is "3"
      When the agent calls 'create_memory_file {"path": "fresh-notes", "description": "Notes", "scope": "project", "project_id": 3}'
      And the agent calls the MCP tool "start_session" with:
        """
        { "title": "Index", "repo": "aaronmallen/fresh" }
        """
      Then the "path" of each row at "files" in the MCP tool answer, read as text, are:
        """
        ["preferences.md", "fresh-notes.md"]
        """

  Rule: list_sessions filters by project

    Scenario: list_sessions lists only the sessions of the project it names, and every session without one
      Given the project "Blog" in the repo "aaronmallen/blog"
      When the agent calls 'start_session {"title": "Inside", "repo": "aaronmallen/blog"}'
      And the agent calls 'start_session {"title": "Outside", "repo": "aaronmallen/other"}'
      And I call the MCP tool "list_sessions" with:
        """
        { "project_id": 1 }
        """
      Then the "id" of each row at "sessions" in the MCP tool answer, read as text, are:
        """
        [1]
        """
      When I call the MCP tool "list_sessions"
      Then the MCP tool answer at "sessions.length" is "2"

  Rule: Reads that name a session record what they load

    Background:
      Given the agent calls 'start_session {"title": "Index"}'
      And the agent calls 'create_memory_file {"path": "hanami", "description": "Notes", "scope": "global"}'
      And the agent calls 'create_memory_file {"path": "release", "description": "Notes", "scope": "global"}'
      And the agent calls 'create_memory_file {"path": "other", "description": "Notes", "scope": "global"}'
      And the agent calls 'add_memory_fact {"id": 1, "type": "gotcha", "text": "Mind the cache"}'
      And the agent calls 'add_memory_fact {"id": 2, "type": "gotcha", "text": "Cache the build"}'
      And the agent calls 'add_memory_fact {"id": 3, "type": "gotcha", "text": "Tag it"}'

    Scenario: read_memory_file records the file it reads, once however often
      When the agent calls 'read_memory_file {"id": 1, "session_id": 1}'
      And the agent calls 'read_memory_file {"id": 1, "session_id": 1}'
      And I call the MCP tool "list_sessions"
      Then the "path" of each row at "sessions.0.loaded" in the MCP tool answer, read as text, are:
        """
        ["hanami.md"]
        """

    Scenario: search_memory records each file it hits
      When the agent calls 'search_memory {"query": "cache", "session_id": 1}'
      And I call the MCP tool "list_sessions"
      Then the "path" of each row at "sessions.0.loaded" in the MCP tool answer, read as text, are:
        """
        ["hanami.md", "release.md"]
        """

    Scenario: A read or a search without a session records nothing
      When the agent calls 'read_memory_file {"id": 1}'
      And the agent calls 'search_memory {"query": "cache"}'
      And I call the MCP tool "list_sessions"
      Then the MCP tool answer at "sessions.0.loaded" is "[]"

    Scenario: A read that names the session moves its last-seen time
      Given the database runs "UPDATE agent_sessions SET last_seen_at = now() - interval '10 minutes'"
      When the agent calls 'read_memory_file {"id": 1, "session_id": 1}'
      And I call the MCP tool "list_sessions"
      Then the MCP tool answer at "sessions.0.last_seen_at" is about now

    Scenario: A read and a search on a session that ended answer and record neither
      When the agent calls 'end_session {"id": 1}'
      And the agent calls the MCP tool "read_memory_file" with:
        """
        { "id": 1, "session_id": 1 }
        """
      Then the MCP tool answer at "path", read as text, matches:
        """
        "hanami.md"
        """
      When the agent calls the MCP tool "search_memory" with:
        """
        { "query": "cache", "session_id": 1 }
        """
      Then the MCP tool answer at "count" is "2"
      When I call the MCP tool "list_sessions"
      Then the MCP tool answer at "sessions.0.loaded" is "[]"

  Rule: Sessions take what the agent names

    Scenario: list_sessions marks the title, client and branch
      When the agent calls 'start_session {"title": "Index the activities table", "client": "Claude Code 2.4", "branch": "main"}'
      And I call the MCP tool "list_sessions"
      Then the MCP tool answer at "sessions.0" reads:
        | title  | marked | Index the activities table |
        | client | marked | Claude Code 2.4            |
        | branch | marked | main                       |

    Scenario: start_session refuses a task that does not exist
      When the agent calls the MCP tool "start_session" with:
        """
        { "title": "Spike", "tasks": [2147483647] }
        """
      Then the MCP tool's words hold "name tasks that exist"

    Scenario: start_session's description names the idle time that closes a session
      When I ask MCP for "tools/list"
      Then the descriptions of "start_session" each hold "a session no call names for 2 hours closes on its own"

  Rule: Writes that name a session show on it

    Background:
      Given the agent calls 'start_session {"title": "Index"}'
      And the agent calls 'create_memory_file {"path": "hanami", "description": "Notes", "scope": "global"}'
      And the agent calls 'add_memory_fact {"id": 1, "type": "gotcha", "text": "Mind the cache", "session_id": 1}'
      And the agent calls 'create_artifact {"title": "Plan", "type": "plan", "body": "Steps", "session_id": 1}'

    Scenario: The session shows the memory change and the artifact version, and each names the session
      When I call the MCP tool "list_sessions"
      Then the MCP tool answer at "sessions.0" matches:
        """
        { "memory_changes": [{ "memory_file_id": 1, "op": "add" }], "artifact_versions": [{ "number": 1, "artifact_id": 1 }] }
        """
      When I call the MCP tool "read_memory_file" with:
        """
        { "id": 1, "history": true }
        """
      Then the MCP tool answer at "history.0.session_id" is "1"
      When I call the MCP tool "read_artifact" with:
        """
        { "id": 1 }
        """
      Then the MCP tool answer at "versions.0.session_id" is "1"

    Scenario: A write without a session stays out of every session
      When the agent calls 'create_memory_file {"path": "other", "description": "Notes", "scope": "global"}'
      And I call the MCP tool "list_sessions"
      Then the MCP tool answer at "sessions.0.memory_changes.length" is "1"

  Rule: A write that names a session keeps it awake

    Scenario: A write that names the session moves its last-seen time
      Given the agent calls 'start_session {"title": "Index"}'
      And the database runs "UPDATE agent_sessions SET last_seen_at = now() - interval '10 minutes'"
      When the agent calls 'create_memory_file {"path": "hanami", "description": "Notes", "scope": "global", "session_id": 1}'
      And I call the MCP tool "list_sessions"
      Then the MCP tool answer at "sessions.0.last_seen_at" is about now

  Rule: A write into a session that ended is refused

    Background:
      Given the project "Blog"
      And the agent calls 'create_memory_file {"path": "hanami", "description": "Notes", "scope": "global"}'
      And the agent calls 'add_memory_fact {"id": 1, "type": "gotcha", "text": "Mind the cache"}'
      And the agent calls 'create_artifact {"title": "Plan", "type": "plan", "body": "Steps"}'
      And the agent calls 'start_session {"title": "Index"}'
      And the agent calls 'end_session {"id": 1}'

    Scenario Outline: <tool> refuses a session that ended
      When the agent calls the MCP tool "<tool>" with:
        """
        <input>
        """
      Then the MCP tool's words hold "that session is not open"

      Examples:
        | tool                     | input                                                                                  |
        | create_memory_file       | {"path": "other", "description": "Notes", "scope": "global", "session_id": 1}          |
        | describe_memory_file     | {"id": 1, "description": "When to read it", "session_id": 1}                           |
        | move_memory_file         | {"id": 1, "scope": "project", "project_id": 1, "session_id": 1}                        |
        | add_memory_fact          | {"id": 1, "type": "gotcha", "text": "Mind the queue", "session_id": 1}                 |
        | edit_memory_fact         | {"id": 1, "fact_id": 1, "text": "Mind the queue", "session_id": 1}                     |
        | remove_memory_fact       | {"id": 1, "fact_id": 1, "session_id": 1}                                               |
        | revert_memory_event      | {"id": 1, "event_id": 2, "session_id": 1}                                              |
        | create_artifact          | {"title": "Spec", "type": "plan", "body": "Steps", "session_id": 1}                    |
        | update_artifact          | {"id": 1, "body": "More steps", "session_id": 1}                                       |
        | restore_artifact_version | {"id": 1, "version": 1, "session_id": 1}                                               |

  Rule: end_session ends a session once

    Scenario: end_session sets the end time and refuses a second call
      Given the agent calls 'start_session {"title": "Index"}'
      When I call the MCP tool "end_session" with:
        """
        { "id": 1 }
        """
      Then the MCP tool answer at "ended_at" is about now
      When I call the MCP tool "end_session" with:
        """
        { "id": 1 }
        """
      Then the MCP tool refuses
      And the MCP tool's words hold "session 1 already ended"
