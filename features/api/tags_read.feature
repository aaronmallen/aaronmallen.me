Feature: API reading a tag
  GET /api/v1/tags/:name groups every record that carries a tag name, in either scope, by kind, with a count for each
  kind and a page of records per kind.

  Background:
    Given an API token with the scopes "read suggest write publish delete health mail agents notes contacts"

  Scenario: Drafts and closed records come with their status
    Given the tagging records:
      | kind     | title        | state    | tags |
      | post     | A ruby draft | draft    | ruby |
      | project  | old-gem      | archived | ruby |
      | task     | Shipped ruby | done     | ruby |
      | task     | Dropped ruby | canceled | ruby |
      | decision | Ruby or not  | dropped  | ruby |
    When I call the API with "GET /api/v1/tags/ruby"
    Then the answer matches:
      """
      {"posts": {"records": [{"title": "A ruby draft", "status": "draft"}]},
        "projects": {"records": [{"name": "old-gem", "status": "archived"}]},
        "decisions": {"records": [{"title": "Ruby or not", "status": "dropped"}]}}
      """
    And the answer's "tasks.records" lists 2
    And the answer includes "\"title\":\"Shipped ruby\",\"status\":\"done\""
    And the answer includes "\"title\":\"Dropped ruby\",\"status\":\"canceled\""

  Scenario: A tag nothing carries answers empty kinds
    Given the tagging tags:
      | name   | scope   | description    |
      | unused | private | kept for later |
    When I call the API with "GET /api/v1/tags/unused"
    Then the answer matches:
      """
      {"name": "unused", "descriptions": {"public": null, "private": "kept for later"},
        "posts": {"records": [], "partial": false}, "projects": {"records": [], "partial": false},
        "tasks": {"records": [], "partial": false}, "journal_entries": {"records": [], "partial": false},
        "decisions": {"records": [], "partial": false}, "agent_sessions": {"records": [], "partial": false},
        "memory_files": {"records": [], "partial": false}, "artifacts": {"records": [], "partial": false}}
      """
    And the answer's "counts" is:
      """
      {"posts": 0, "projects": 0, "tasks": 0, "journal_entries": 0, "decisions": 0, "agent_sessions": 0,
        "memory_files": 0, "artifacts": 0}
      """

  Scenario: A kind it does not know answers 422
    Given the tagging tags:
      | name | scope  |
      | ruby | public |
    When I call the API with "GET /api/v1/tags/ruby?kind=people"
    Then the call answers 422
    And the answer's "error" is "invalid"

  Scenario: A blank name answers 404
    When I call the API with "GET /api/v1/tags/%20"
    Then the call answers 404
    And the answer's "error" is "not_found"

  Scenario: A name no tag holds answers 404
    When I call the API with "GET /api/v1/tags/nothing"
    Then the call answers 404
    And the answer's "error" is "not_found"
    And the answer's "message" is "no tag has the name nothing"

  Rule: A name both scopes hold

    Background:
      Given the tagging records:
        | id | kind          | title           | tags |
        | 11 | post          | Ruby on a Pi    | ruby |
        | 11 | project       | ruby-gem        | ruby |
        | 11 | task          | Bump ruby       | ruby |
        | 11 | journal_entry | Wrote some ruby | ruby |
        | 11 | decision      | Pick a ruby     | ruby |
        | 12 | post          | Rust on a Pi    | rust |
        | 12 | task          | Bump rust       | rust |

    Scenario: Reading a name answers 200 with the name, each kind's records and counts
      When I call the API with "GET /api/v1/tags/ruby"
      Then the call answers 200
      And the answer matches:
        """
        {"name": "ruby",
          "posts": {"records": [{"id": 11}]}, "projects": {"records": [{"id": 11}]},
          "tasks": {"records": [{"id": 11}]}, "journal_entries": {"records": [{"id": 11, "opening": "Wrote some ruby"}]},
          "decisions": {"records": [{"id": 11}]}, "agent_sessions": {"records": []},
          "memory_files": {"records": []}, "artifacts": {"records": []}}
        """
      And the answer's "counts" is:
        """
        {"posts": 1, "projects": 1, "tasks": 1, "journal_entries": 1, "decisions": 1, "agent_sessions": 0,
          "memory_files": 0, "artifacts": 0}
        """

    Scenario: Reading a name works however it is cased
      When I call the API with "GET /api/v1/tags/Ruby"
      Then the answer's "posts.records" lists 1
      And the answer's "posts.records.0.title" is "Ruby on a Pi"

    Scenario: Asking for one kind answers only that kind
      When I call the API with "GET /api/v1/tags/ruby?kind=tasks"
      Then the answer's "tasks.records" lists 1
      And the answer's "posts" is "undefined"
      And the answer does not include "Ruby on a Pi"

    Scenario: Reading a name answers the same JSON as read_tag
      Given an API token with the scopes "read suggest write publish delete mail"
      And I am signed in to the admin
      And an MCP client connected with the scopes "read suggest write publish delete mail"
      Then the tag API call "GET /api/v1/tags/ruby" answers what the MCP tool "read_tag" does with:
        """
        {"name": "ruby"}
        """

  Rule: A tag on more records than a page holds

    Background:
      Given the database runs:
        """
        insert into tags (name, color, scope) values ('ruby', 'mk-green', 'private');
        insert into tasks (title, list, position) select 'Task ' || n, 'next', n from generate_series(1, 101) as n;
        insert into task_tags (task_id, tag_id) select id, 1 from tasks;
        """
      And the tagging records:
        | kind     | title       | tags |
        | decision | Pick a ruby | ruby |

    Scenario: Paging counts every record, marks a kind with more partial and names the next page
      When I call the API with "GET /api/v1/tags/ruby"
      Then the answer matches:
        """
        {"counts": {"tasks": 101, "decisions": 1}, "tasks": {"partial": true, "next_page": 2},
          "decisions": {"partial": false}}
        """
      And the answer's "tasks.records" lists 100
      And the answer's "decisions.next_page" is "undefined"

    Scenario: Paging one kind reaches every record and ends on the last page
      When I call the API with "GET /api/v1/tags/ruby?kind=tasks"
      Then the answer's "tasks.records" lists 100
      And the answer's "tasks.next_page" is "2"
      When I call the API with "GET /api/v1/tags/ruby?kind=tasks&page=2"
      Then the answer's "tasks.records" lists 1
      And the answer's "tasks.partial" is "false"
