Feature: MCP memory tools
  Agents keep files of facts in three scopes, with a history of every change that each entry can take back.

  Background:
    Given an MCP client connected with the scopes "read agents delete"

  Rule: A file an agent changes keeps a history, a page at a time

    Background:
      Given the agent calls 'create_memory_file {"path": "hanami", "description": "Notes", "scope": "global"}'
      And the agent calls 'add_memory_fact {"id": 1, "type": "convention", "text": "Run tests through mise"}'
      And the agent calls 'edit_memory_fact {"id": 1, "fact_id": 1, "text": "Run every check through mise"}'
      And the agent calls 'remove_memory_fact {"id": 1, "fact_id": 1, "agent": "codex", "model": "gpt-5"}'

    Scenario: Each change shows in the file's history, newest first, with its agent and model
      When I call the MCP tool "read_memory_file" with:
        """
        { "id": 1 }
        """
      Then the "op, text, was_text, agent, model" of each row at "history" in the MCP tool answer, read as text, are:
        """
        [
          ["remove", null, "Run every check through mise", "codex", "gpt-5"],
          ["edit", "Run every check through mise", "Run tests through mise", "claude-code", "claude-opus-5-5"],
          ["add", "Run tests through mise", null, "claude-code", "claude-opus-5-5"],
          ["create", null, null, "claude-code", "claude-opus-5-5"]
        ]
        """

    Scenario: The history comes a page at a time, newest first, naming the next page until the oldest
      Given the agent adds 97 gotchas to "hanami"
      When I call the MCP tool "read_memory_file" with:
        """
        { "id": 1, "page": 1 }
        """
      Then the MCP tool answer at "history.length" is "100"
      And the MCP answer holds:
        """
        { "partial": true, "next_page": 2 }
        """
      When I call the MCP tool "read_memory_file" with:
        """
        { "id": 1, "page": 2 }
        """
      Then the "op" of each row at "history" in the MCP tool answer, read as text, are:
        """
        ["create"]
        """
      And the MCP tool answer at "partial" is "false"
      And the MCP answer has no "next_page"

  Rule: Files take a path, a scope and a one-line description

    Scenario: A path gains .md, and the file comes with no repo
      When the agent calls the MCP tool "create_memory_file" with:
        """
        { "path": "rails/testing", "description": "Notes", "scope": "global" }
        """
      Then the MCP tool answer at "path" is "\"rails/testing.md\""
      And the MCP answer has no "repo"

    Scenario: The text an agent wrote comes marked and the owner's stays plain
      Given I am signed in to the admin
      And the agent calls 'create_memory_file {"path": "hanami", "description": "Notes", "scope": "global"}'
      And the agent calls 'add_memory_fact {"id": 1, "type": "convention", "text": "Prefer Sequel"}'
      When I add the preference "No emdash" to "hanami"
      And I call the MCP tool "read_memory_file" with:
        """
        { "id": 1 }
        """
      Then the "text" of each row at "facts" in the MCP tool answer are:
        | marked | Prefer Sequel |
        | plain  | No emdash     |

    Scenario: Fact text of any length adds and edits, and blank text is refused
      Given the agent calls 'create_memory_file {"path": "hanami", "description": "Notes", "scope": "global"}'
      When I call the MCP tool "add_memory_fact" with a text of 5000 "a"s and:
        """
        { "id": 1, "type": "convention", "agent": "claude-code", "model": "claude-opus-5-5" }
        """
      And I call the MCP tool "edit_memory_fact" with a text of 6000 "b"s and:
        """
        { "id": 1, "fact_id": 1, "agent": "claude-code", "model": "claude-opus-5-5" }
        """
      Then the database answers "6000, true" for:
        """
        SELECT length(text), text = repeat('b', 6000) FROM memory_facts WHERE removed_at IS NULL
        """
      When the agent calls the MCP tool "add_memory_fact" with:
        """
        { "id": 1, "type": "context", "text": " " }
        """
      Then the MCP tool refuses with "text: write the fact first"

    Scenario: A second file with one path in one scope is refused, while one path in two scopes is kept
      Given the project "Blog"
      And the agent calls 'create_memory_file {"path": "hanami.md", "description": "Notes", "scope": "project", "project_id": 1}'
      When the agent calls the MCP tool "create_memory_file" with:
        """
        { "path": "hanami.md", "description": "Notes", "scope": "project", "project_id": 1 }
        """
      Then the MCP tool refuses with "path: a file in this scope already has this path"
      When the agent calls the MCP tool "create_memory_file" with:
        """
        { "path": "hanami", "description": "Notes", "scope": "global" }
        """
      Then the MCP tool answer at "scope" is "\"global\""

    Scenario Outline: <tool> refuses a repo scope
      Given the agent calls 'create_memory_file {"path": "hanami", "description": "Notes", "scope": "global"}'
      When the agent calls the MCP tool "<tool>" with:
        """
        <input>
        """
      Then the MCP tool refuses with "Invalid arguments: value at `/scope` is not one of: [\"global\", \"project\", \"task\"]"

      Examples:
        | tool               | input                                                    |
        | create_memory_file | {"path": "rails", "description": "Notes", "scope": "repo"} |
        | move_memory_file   | {"id": 1, "scope": "repo"}                               |

    Scenario Outline: create_memory_file refuses <what>
      When the agent calls the MCP tool "create_memory_file" with:
        """
        <input>
        """
      Then the MCP tool refuses with "description: <refusal>"

      Examples:
        | what                               | input                                                         | refusal                          |
        | a blank description                | {"path": "hanami", "description": " ", "scope": "global"}     | describe the file in one line    |
        | a description over more than a line | {"path": "hanami", "description": "One\\nTwo", "scope": "global"} | keep the description to one line |

  Rule: read_memory loads the files that match, with no facts

    Background:
      Given the project "Blog" in the repo "aaronmallen/blog"
      And the project "Other" in the repo "aaronmallen/other"
      And the task "Index the activities table"
      And the agent calls 'create_memory_file {"path": "task-notes", "description": "Notes", "scope": "task", "task_id": 1}'
      And the agent calls 'add_memory_fact {"id": 1, "type": "convention", "text": "Mind the index"}'
      And the agent calls 'create_memory_file {"path": "release", "description": "Notes", "scope": "project", "project_id": 1}'
      And the agent calls 'add_memory_fact {"id": 2, "type": "convention", "text": "Tag with CalVer"}'
      And the agent calls 'create_memory_file {"path": "hanami", "description": "Notes", "scope": "project", "project_id": 1}'
      And the agent calls 'add_memory_fact {"id": 3, "type": "convention", "text": "Slices own tables"}'
      And the agent calls 'create_memory_file {"path": "preferences", "description": "Notes", "scope": "global"}'
      And the agent calls 'add_memory_fact {"id": 4, "type": "preference", "text": "No emdash"}'
      And the agent calls 'create_memory_file {"path": "elsewhere", "description": "Notes", "scope": "project", "project_id": 2}'

    Scenario: It loads global, project and task files in that order, with the files of the repo's project
      When I call the MCP tool "read_memory" with:
        """
        { "repo": "aaronmallen/blog", "task_id": 1 }
        """
      Then the "scope, path" of each row at "files" in the MCP tool answer, read as text, are:
        """
        [["global", "preferences.md"], ["project", "hanami.md"], ["project", "release.md"], ["task", "task-notes.md"]]
        """

    Scenario: It indexes each file by its id, scope, path, description and fact count
      Given I am signed in to the admin
      When I describe "hanami" as "Ours"
      And I call the MCP tool "read_memory" with:
        """
        { "repo": "aaronmallen/blog" }
        """
      Then the MCP tool answer at "files.0.id" is "4"
      And the MCP tool answer at "files.0" reads:
        | scope       | plain  | global         |
        | path        | plain  | preferences.md |
        | description | marked | Notes          |
      And the MCP tool answer at "files.0.fact_count" is "1"
      And the MCP tool answer at "files.1" reads:
        | scope       | plain | project   |
        | path        | plain | hanami.md |
        | description | plain | Ours      |
      And the MCP tool answer at "files.1.id" is "3"
      And the MCP tool answer at "files.1.fact_count" is "1"
      And the MCP answer has no "files.0.facts"

    Scenario: A removed fact leaves the count
      Given the agent calls 'add_memory_fact {"id": 4, "type": "convention", "text": "Prefer Sequel"}'
      And the agent calls 'remove_memory_fact {"id": 4, "fact_id": 5}'
      When I call the MCP tool "read_memory"
      Then the MCP tool answer at "files.0.fact_count" is "1"

    Scenario: A repo in mixed case or with spaces loads as its lower case name, and one that is not owner/name is refused
      When I call the MCP tool "read_memory" with:
        """
        { "repo": " AaronMallen/Blog " }
        """
      Then the "path" of each row at "files" in the MCP tool answer, read as text, are:
        """
        ["preferences.md", "hanami.md", "release.md"]
        """
      When I call the MCP tool "read_memory" with:
        """
        { "repo": "aaronmallen" }
        """
      Then the MCP tool refuses with "repo: name the repository as owner/name"

    Scenario Outline: Given <given>, it loads <paths>
      When I call the MCP tool "read_memory" with:
        """
        <input>
        """
      Then the "path" of each row at "files" in the MCP tool answer, read as text, are:
        """
        <paths>
        """

      Examples:
        | given                       | input                                    | paths                                         |
        | nothing                     | {}                                       | ["preferences.md"]                            |
        | a blank repo                | {"repo": " "}                            | ["preferences.md"]                            |
        | a project key               | {"project": "BLOG"}                      | ["preferences.md", "hanami.md", "release.md"] |
        | a repo no project holds     | {"repo": "aaronmallen/fresh", "task_id": 1} | ["preferences.md", "task-notes.md"]        |

    Scenario: A project key that names no project is refused, and a repo no project holds makes no project or task rule
      When I call the MCP tool "read_memory" with:
        """
        { "project": "NOPE" }
        """
      Then the MCP tool refuses with "project: name a project key that exists"
      When I call the MCP tool "read_memory" with:
        """
        { "repo": "aaronmallen/fresh" }
        """
      Then the database answers "0, 0" for:
        """
        SELECT (SELECT count(*) FROM projects WHERE repo = 'aaronmallen/fresh') AS projects, (SELECT count(*) FROM task_rules WHERE pattern = 'aaronmallen/fresh') AS rules
        """

  Rule: search_memory finds live facts in the files read_memory would load

    Background:
      Given the project "Blog" in the repo "aaronmallen/blog"
      And the project "Other" in the repo "aaronmallen/other"
      And the task "Index the activities table"
      And the agent calls 'create_memory_file {"path": "task-notes", "description": "Notes", "scope": "task", "task_id": 1}'
      And the agent calls 'add_memory_fact {"id": 1, "type": "convention", "text": "Mind the cache index"}'
      And the agent calls 'create_memory_file {"path": "release", "description": "Notes", "scope": "project", "project_id": 1}'
      And the agent calls 'add_memory_fact {"id": 2, "type": "convention", "text": "Cache the tag"}'
      And the agent calls 'create_memory_file {"path": "hanami", "description": "Notes", "scope": "project", "project_id": 1}'
      And the agent calls 'add_memory_fact {"id": 3, "type": "convention", "text": "Slices cache their tables"}'
      And the agent calls 'create_memory_file {"path": "preferences", "description": "Notes", "scope": "global"}'
      And the agent calls 'add_memory_fact {"id": 4, "type": "preference", "text": "No emdash in the cache docs"}'
      And the agent calls 'create_memory_file {"path": "elsewhere", "description": "Notes", "scope": "project", "project_id": 2}'
      And the agent calls 'add_memory_fact {"id": 5, "type": "convention", "text": "Cache nothing"}'

    Scenario: It returns each live fact that holds the query with its file's id and path, and never a removed one
      Given the agent calls 'add_memory_fact {"id": 3, "type": "convention", "text": "Bust the CACHE on deploy"}'
      And the agent calls 'add_memory_fact {"id": 3, "type": "convention", "text": "Purge the cache"}'
      And the agent calls 'remove_memory_fact {"id": 3, "fact_id": 7}'
      When I call the MCP tool "search_memory" with:
        """
        { "query": "bust the cache" }
        """
      Then the "id, memory_file_id, path" of each row at "facts" in the MCP tool answer, read as text, are:
        """
        [[6, 3, "hanami.md"]]
        """
      When I call the MCP tool "search_memory" with:
        """
        { "query": "purge" }
        """
      Then the MCP tool answer at "facts" is "[]"

    Scenario: It leaves the owner's text plain
      Given I am signed in to the admin
      When I add the preference "Owner cache rule" to "preferences"
      And I call the MCP tool "search_memory" with:
        """
        { "query": "cache rule" }
        """
      Then the "text" of each row at "facts" in the MCP tool answer are:
        | plain | Owner cache rule |

    Scenario Outline: Given <given>, it searches the files read_memory lists for it
      When I call the MCP tool "search_memory" with:
        """
        <input>
        """
      Then the texts of the facts found, in any order, are "<texts>"

      Examples:
        | given                                | input                                                                | texts                                                                                                 |
        | no filter                            | {"query": "cache"}                                                   | Mind the cache index; Cache the tag; Slices cache their tables; No emdash in the cache docs; Cache nothing |
        | a repo                               | {"query": "cache", "repo": "AaronMallen/Blog"}                       | Cache the tag; Slices cache their tables; No emdash in the cache docs                                 |
        | a project                            | {"query": "cache", "project_id": 1}                                  | Cache the tag; Slices cache their tables; No emdash in the cache docs                                 |
        | a project key                        | {"query": "cache", "project": "BLOG"}                                | Cache the tag; Slices cache their tables; No emdash in the cache docs                                 |
        | a task                               | {"query": "cache", "task_id": 1}                                     | Mind the cache index; No emdash in the cache docs                                                     |
        | a repo no project holds and a task   | {"query": "cache", "repo": "aaronmallen/fresh", "task_id": 1}        | Mind the cache index; No emdash in the cache docs                                                     |
        | one scope                            | {"query": "cache", "scope": "project", "repo": "aaronmallen/blog"}   | Cache the tag; Slices cache their tables                                                              |

    Scenario: A repo no project holds makes no project or task rule
      When I call the MCP tool "search_memory" with:
        """
        { "query": "cache", "repo": "aaronmallen/fresh" }
        """
      Then the database answers "0, 0" for:
        """
        SELECT (SELECT count(*) FROM projects WHERE repo = 'aaronmallen/fresh') AS projects, (SELECT count(*) FROM task_rules WHERE pattern = 'aaronmallen/fresh') AS rules
        """

    Scenario Outline: It refuses <what>
      When I call the MCP tool "search_memory" with:
        """
        <input>
        """
      Then the MCP tool refuses with "<refusal>"

      Examples:
        | what                                | input                                    | refusal                                  |
        | a project key that names no project | {"query": "cache", "project": "NOPE"}    | project: name a project key that exists  |
        | a blank query                       | {"query": " "}                           | query: write the words to find           |
        | a repo that is not owner/name       | {"query": "cache", "repo": "aaronmallen"} | repo: name the repository as owner/name |

    Scenario: It pages the facts
      Given the agent adds 101 gotchas to "hanami"
      When I call the MCP tool "search_memory" with:
        """
        { "query": "fact" }
        """
      Then the MCP answer holds:
        """
        { "count": 100, "partial": true, "next_page": 2 }
        """
      When I call the MCP tool "search_memory" with:
        """
        { "query": "fact", "page": 2 }
        """
      Then the MCP tool answer at "facts.length" is "1"

  Rule: revert_memory_event takes back one entry

    Background:
      Given I am signed in to the admin
      And the agent calls 'create_memory_file {"path": "hanami", "description": "Notes", "scope": "global"}'

    Scenario: Reverting takes back an add, an edit and a remove
      Given the agent calls 'add_memory_fact {"id": 1, "type": "convention", "text": "Use jj"}'
      When I keep the id of the newest add entry in the history of the memory file 1 as "add"
      And the agent calls 'revert_memory_event {"id": 1, "event_id": {add}}'
      Then the database answers "0" for:
        """
        SELECT count(*) FROM memory_facts WHERE removed_at IS NULL
        """
      Given the agent calls 'add_memory_fact {"id": 1, "type": "convention", "text": "Use jj"}'
      And the agent calls 'edit_memory_fact {"id": 1, "fact_id": 2, "type": "gotcha", "text": "Use git"}'
      When I keep the id of the newest edit entry in the history of the memory file 1 as "edit"
      And the agent calls 'revert_memory_event {"id": 1, "event_id": {edit}}'
      And I call the MCP tool "read_memory_file" with:
        """
        { "id": 1 }
        """
      Then the "type, text" of each row at "facts" in the MCP tool answer, read as text, are:
        """
        [["convention", "Use jj"]]
        """
      Given the agent calls 'remove_memory_fact {"id": 1, "fact_id": 2}'
      When I keep the id of the newest remove entry in the history of the memory file 1 as "remove"
      And the agent calls 'revert_memory_event {"id": 1, "event_id": {remove}}'
      And I call the MCP tool "read_memory_file" with:
        """
        { "id": 1 }
        """
      Then the "text" of each row at "facts" in the MCP tool answer, read as text, are:
        """
        ["Use jj"]
        """

    Scenario: Reverting the owner's edit gives an agent's fact back to the agent
      Given the agent calls 'add_memory_fact {"id": 1, "type": "convention", "text": "Use jj"}'
      When I change the convention "Use jj" in "hanami" to "Use git"
      And I revert the latest change to "hanami"
      And I call the MCP tool "read_memory_file" with:
        """
        { "id": 1 }
        """
      Then the MCP tool answer at "facts.0" matches:
        """
        { "text": { "untrusted": true, "text": "Use jj" }, "agent": "claude-code", "model": "claude-opus-5-5" }
        """
      And the MCP tool answer at "history.0" matches:
        """
        { "op": "revert", "agent": null, "model": null }
        """

    Scenario: Reverting an agent's edit gives the owner's fact back to the owner
      Given I add the convention "Use jj" to "hanami"
      And the agent calls 'edit_memory_fact {"id": 1, "fact_id": 1, "text": "Use git"}'
      When I keep the id of the newest edit entry in the history of the memory file 1 as "edit"
      And the agent calls 'revert_memory_event {"id": 1, "event_id": {edit}}'
      And I call the MCP tool "read_memory_file" with:
        """
        { "id": 1 }
        """
      Then the MCP tool answer at "facts.0" matches:
        """
        { "text": "Use jj", "agent": null, "model": null }
        """
      And the MCP tool answer at "history.0" matches:
        """
        { "op": "revert", "agent": "claude-code", "model": "claude-opus-5-5" }
        """

    Scenario: A fact that changed since is refused, naming the later entry
      Given the agent calls 'add_memory_fact {"id": 1, "type": "convention", "text": "Use jj"}'
      And I keep the id of the newest add entry in the history of the memory file 1 as "add"
      And the agent calls 'edit_memory_fact {"id": 1, "fact_id": 1, "text": "Use jj, not git"}'
      And I keep the id of the newest edit entry in the history of the memory file 1 as "edit"
      When the agent calls the MCP tool "revert_memory_event" with:
        """
        { "id": 1, "event_id": {add} }
        """
      Then the MCP tool refuses with "it changed since, in history entry {edit}; revert that entry first"
      And the database answers "Use jj, not git" for:
        """
        SELECT text FROM memory_facts WHERE removed_at IS NULL
        """

  Rule: describe_memory_file changes the one-line description

    Background:
      Given I am signed in to the admin
      And the agent calls 'create_memory_file {"path": "hanami", "description": "How we test", "scope": "global"}'

    Scenario: The agent's description reads back marked, changes with a describe entry, and the owner's stays plain
      When I call the MCP tool "read_memory_file" with:
        """
        { "id": 1 }
        """
      Then the MCP tool answer at "description" is marked "How we test"
      When the agent calls 'describe_memory_file {"id": 1, "description": "When to run which specs"}'
      And I call the MCP tool "read_memory_file" with:
        """
        { "id": 1 }
        """
      Then the MCP tool answer at "description" is marked "When to run which specs"
      And the MCP tool answer at "history.0", read as text, matches:
        """
        { "op": "describe", "text": "When to run which specs", "was_text": "How we test", "agent": "claude-code", "model": "claude-opus-5-5" }
        """
      When I describe "hanami" as "Owner notes"
      And I call the MCP tool "read_memory_file" with:
        """
        { "id": 1 }
        """
      Then the MCP tool answer at "description" is plain "Owner notes"

    Scenario: The same description adds no entry
      When the agent calls 'describe_memory_file {"id": 1, "description": "How we test"}'
      And I call the MCP tool "read_memory_file" with:
        """
        { "id": 1 }
        """
      Then the "op" of each row at "history" in the MCP tool answer, read as text, are:
        """
        ["create"]
        """

    Scenario Outline: describe_memory_file refuses <what>
      When the agent calls the MCP tool "describe_memory_file" with:
        """
        <input>
        """
      Then the MCP tool refuses with "<refusal>"

      Examples:
        | what                         | input                                  | refusal                                 |
        | a blank change               | {"id": 1, "description": " "}          | description: describe the file in one line |
        | a file that does not exist   | {"id": 999999, "description": "Notes"} | no memory file has the ID 999999        |

    Scenario: Reverting a describe takes it back, author and all
      When I describe "hanami" as "Owner notes"
      And I keep the id of the newest describe entry in the history of the memory file 1 as "describe"
      And the agent calls 'revert_memory_event {"id": 1, "event_id": {describe}}'
      And I call the MCP tool "read_memory_file" with:
        """
        { "id": 1 }
        """
      Then the MCP tool answer at "description" is marked "How we test"
      And the MCP tool answer at "history.0", read as text, matches:
        """
        { "op": "revert", "text": "How we test", "was_text": "Owner notes" }
        """

    Scenario: A describe that a later one changed is refused
      When the agent calls 'describe_memory_file {"id": 1, "description": "First"}'
      And I keep the id of the newest describe entry in the history of the memory file 1 as "first"
      And the agent calls 'describe_memory_file {"id": 1, "description": "Second"}'
      And I keep the id of the newest describe entry in the history of the memory file 1 as "second"
      And the agent calls the MCP tool "revert_memory_event" with:
        """
        { "id": 1, "event_id": {first} }
        """
      Then the MCP tool refuses with "it changed since, in history entry {second}; revert that entry first"

  Rule: move_memory_file moves a file to another scope

    Background:
      Given the project "Blog"
      And the agent calls 'create_memory_file {"path": "hanami", "description": "Notes", "scope": "global"}'

    Scenario: It moves the file and adds a scope entry with the agent and model
      When the agent calls the MCP tool "move_memory_file" with:
        """
        { "id": 1, "scope": "project", "project_id": 1 }
        """
      Then the MCP answer holds:
        """
        { "scope": "project", "project_id": 1 }
        """
      When I call the MCP tool "read_memory_file" with:
        """
        { "id": 1 }
        """
      Then the MCP tool answer at "history.0" matches:
        """
        { "op": "scope", "agent": "claude-code", "model": "claude-opus-5-5" }
        """

    Scenario: It refuses a scope that already holds its path, and a project file with no project
      Given the agent calls 'create_memory_file {"path": "hanami", "description": "Notes", "scope": "project", "project_id": 1}'
      When the agent calls the MCP tool "move_memory_file" with:
        """
        { "id": 1, "scope": "project", "project_id": 1 }
        """
      Then the MCP tool refuses with "scope: a file in that scope already has this path"
      When the agent calls the MCP tool "move_memory_file" with:
        """
        { "id": 1, "scope": "project" }
        """
      Then the MCP tool refuses with "project_id: a project file needs a project that exists"

  Rule: Deleting a file or its task deletes it with its facts

    Scenario: delete_memory_file deletes a file with its facts
      Given the agent calls 'create_memory_file {"path": "hanami", "description": "Notes", "scope": "global"}'
      And the agent calls 'add_memory_fact {"id": 1, "type": "convention", "text": "Gone soon"}'
      When I call the MCP tool "delete_memory_file" with:
        """
        { "id": 1 }
        """
      Then the MCP answer holds:
        """
        { "id": 1, "deleted": true }
        """
      And the table memory_facts holds 0 rows
      When I call the MCP tool "read_memory_file" with:
        """
        { "id": 1 }
        """
      Then the MCP tool refuses with "no memory file has the ID 1"

    Scenario: Deleting a task deletes its files
      Given I am signed in to the admin
      And the task "Index the activities table"
      And the agent calls 'create_memory_file {"path": "notes", "description": "Notes", "scope": "task", "task_id": 1}'
      When I post to "/admin/tasks/1/delete"
      And I call the MCP tool "read_memory_file" with:
        """
        { "id": 1 }
        """
      Then the MCP tool refuses with "no memory file has the ID 1"

  Rule: The database keeps one path to a scope

    Scenario: It refuses two files with one path in one project, and two global files with one path
      Given the project "Blog"
      And the database runs "INSERT INTO memory_files (description, path, scope, project_id) VALUES ('notes', 'hanami.md', 'project', 1)"
      Then the database refuses, breaking a unique constraint:
        """
        INSERT INTO memory_files (description, path, scope, project_id) VALUES ('notes', 'hanami.md', 'project', 1)
        """
      Given the database runs "INSERT INTO memory_files (description, path, scope) VALUES ('notes', 'hanami.md', 'global')"
      Then the database refuses, breaking a unique constraint:
        """
        INSERT INTO memory_files (description, path, scope) VALUES ('notes', 'hanami.md', 'global')
        """
