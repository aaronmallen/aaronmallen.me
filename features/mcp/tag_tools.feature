Feature: MCP tag tools
  The list_tags, save_tag, remove_tag and read_tag tools list, add, change, remove and read tags in the public,
  private or one project's scope, the way the admin does.

  Background:
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read write publish delete"

  Scenario Outline: <tool> without a scope refuses, naming the field
    When I call the MCP tool "<tool>" with:
      """
      <arguments>
      """
    Then it refuses
    And the answer includes "scope"

    Examples:
      | tool       | arguments        |
      | list_tags  | {}               |
      | save_tag   | {"name": "ruby"} |
      | remove_tag | {"id": 1}        |

  Scenario: Every tag tool that takes a scope names each kind the scopes cover
    When I list the MCP tag tools
    Then the MCP tag tools that take a scope include "list_tags, save_tag, remove_tag"
    And each MCP tag tool that takes a scope says "posts and projects"
    And each MCP tag tool that takes a scope says "journal entries, tasks, decisions and task rules"

  Scenario: save_tag says it sets a description
    When I list the MCP tag tools
    Then the MCP tag tool "save_tag" says "describe"
    And the MCP tag tool "save_tag" says "description is markdown"

  Rule: list_tags

    Background:
      Given the tagging records:
        | kind    | title       | tags         |
        | post    | Ruby on Pis | ruby         |
        | project | gem-one     | ruby         |
        | project | gem-two     | ruby, cli    |
        | task    | Bump ruby   | chores, ruby |
      And the tagging tags:
        | name   | scope  | description      |
        | unused | public | kept for *later* |

    Scenario: Listing the public scope gives each tag its scope, description and record counts by kind
      When I call the MCP tool "list_tags" with:
        """
        {"scope": "public"}
        """
      Then the answer matches:
        """
        {"count": 3, "tags": [
          {"name": "cli", "scope": "public"},
          {"name": "ruby", "scope": "public", "count": 3, "description": null},
          {"name": "unused", "scope": "public", "count": 0, "description": "kept for *later*"}]}
        """
      And the answer's "tags.1.by_kind" is:
        """
        {"posts": 1, "projects": 2}
        """
      And the answer's "tags.2.by_kind" is:
        """
        {}
        """

    Scenario: A query lists and counts only the tags whose name holds it, each with its record count
      When I call the MCP tool "list_tags" with:
        """
        {"scope": "public", "query": " RU "}
        """
      Then the answer's "tags" lists 1
      And the answer matches:
        """
        {"count": 1, "tags": [{"name": "ruby", "count": 3}]}
        """

    Scenario: A query no tag name holds lists nothing
      When I call the MCP tool "list_tags" with:
        """
        {"scope": "public", "query": "go"}
        """
      Then the answer's "tags" lists 0
      And the answer's "count" is "0"

    Scenario: Listing the private scope counts each tag by its private kinds
      When I call the MCP tool "list_tags" with:
        """
        {"scope": "private"}
        """
      Then the answer's "tags" lists 2
      And the answer matches:
        """
        {"tags": [{"name": "chores", "scope": "private"}, {"name": "ruby", "scope": "private", "count": 1}]}
        """
      And the answer's "tags.1.by_kind" is:
        """
        {"tasks": 1}
        """

  Rule: save_tag

    Scenario: Adding a public tag
      When I call the MCP tool "save_tag" with:
        """
        {"scope": "public", "name": "Elixir", "color": "mk-blue"}
        """
      Then the answer matches:
        """
        {"name": "elixir", "color": "mk-blue"}
        """
      And the database answers "elixir" for:
        """
        select string_agg(name, ', ') from tags where scope = 'public'
        """

    Scenario: Adding a private tag, even with a name the other scope holds
      Given the tagging tags:
        | name | scope  |
        | ruby | public |
      When I call the MCP tool "save_tag" with:
        """
        {"scope": "private", "name": "chores"}
        """
      And I call the MCP tool "save_tag" with:
        """
        {"scope": "private", "name": "ruby"}
        """
      Then the database answers "chores, ruby" for:
        """
        select string_agg(name, ', ' order by name) from tags where scope = 'private'
        """

    Scenario: Recolouring a tag keeps its name, in either scope
      Given the tagging tags:
        | id   | name   | scope   | color   |
        | 9001 | ruby   | public  | mk-pink |
        | 9002 | chores | private | mk-pink |
      When I call the MCP tool "save_tag" with:
        """
        {"scope": "public", "id": 9001, "color": "mk-green"}
        """
      And I call the MCP tool "save_tag" with:
        """
        {"scope": "private", "id": 9002, "color": "mk-green"}
        """
      Then the database answers "ruby mk-green, chores mk-green" for:
        """
        select string_agg(name || ' ' || color, ', ' order by id) from tags
        """

    Scenario: Renaming a tag keeps its colour and its description
      Given the tagging tags:
        | id   | name | scope  | color   | description    |
        | 9001 | ruby | public | mk-pink | all about ruby |
      When I call the MCP tool "save_tag" with:
        """
        {"scope": "public", "id": 9001, "name": "crystal"}
        """
      Then the database answers "crystal, mk-pink, all about ruby" for:
        """
        select name, color, description from tags
        """

    Scenario: A change that leaves the description out keeps it
      Given the tagging tags:
        | id   | name | scope  | description    |
        | 9001 | ruby | public | all about ruby |
      When I call the MCP tool "save_tag" with:
        """
        {"scope": "public", "id": 9001, "name": "crystal", "color": "mk-green"}
        """
      Then the database answers "all about ruby" for:
        """
        select description from tags
        """

    Scenario: Adding a tag with a description trims it and returns it
      When I call the MCP tool "save_tag" with:
        """
        {"scope": "public", "name": "ruby", "description": "  all about *ruby*  "}
        """
      Then the answer's "description" is "all about *ruby*"

    Scenario: Describing a tag returns the description and keeps the name
      Given the tagging tags:
        | id   | name | scope  |
        | 9001 | ruby | public |
      When I call the MCP tool "save_tag" with:
        """
        {"scope": "public", "id": 9001, "description": "all about ruby"}
        """
      Then the answer matches:
        """
        {"name": "ruby", "description": "all about ruby"}
        """
      And the database answers "all about ruby" for:
        """
        select description from tags
        """

    Scenario: An empty description clears it
      Given the tagging tags:
        | id   | name | scope  | description    |
        | 9001 | ruby | public | all about ruby |
      When I call the MCP tool "save_tag" with:
        """
        {"scope": "public", "id": 9001, "description": ""}
        """
      Then the database answers "true" for:
        """
        select description is null from tags
        """

    Scenario: save_tag refuses a tag from the other scope as not found
      Given the tagging tags:
        | id   | name   | scope   |
        | 9001 | chores | private |
      When I call the MCP tool "save_tag" with:
        """
        {"scope": "public", "id": 9001, "name": "errands"}
        """
      Then it refuses
      And the answer includes "no tag has the ID 9001"
      And the database answers "chores" for:
        """
        select name from tags
        """

    Scenario: save_tag refuses a name another tag holds, with the admin's reason
      Given the tagging tags:
        | name | scope  |
        | ruby | public |
      When I call the MCP tool "save_tag" with:
        """
        {"scope": "public", "name": "ruby"}
        """
      Then it refuses
      And the answer includes "name: another tag already holds that name"

    Scenario Outline: save_tag refuses <a name>
      When I call the MCP tool "save_tag" with:
        """
        {"scope": "public", "name": "<name>"}
        """
      Then it refuses
      And the answer includes "<reason>"

      Examples:
        | a name                                               | name       | reason                                           |
        | a name that is not lowercase words joined by hyphens | two words  | name: a tag is lowercase words joined by hyphens |
        | a name holding a control character                   | ru\u0007by | name: holds a control character                  |

    Scenario: save_tag refuses an ID no tag has
      When I call the MCP tool "save_tag" with:
        """
        {"scope": "public", "id": 999999, "name": "ghost"}
        """
      Then it refuses
      And the answer includes "no tag has the ID 999999"

    Scenario: save_tag refuses a scope that is neither public nor private
      When I call the MCP tool "save_tag" with:
        """
        {"scope": "secret", "name": "ghost"}
        """
      Then it refuses

  Rule: remove_tag

    Scenario: Removing a tag nothing carries, in either scope
      Given the tagging tags:
        | id   | name   | scope   |
        | 9001 | ruby   | public  |
        | 9002 | chores | private |
      When I call the MCP tool "remove_tag" with:
        """
        {"scope": "public", "id": 9001}
        """
      And I call the MCP tool "remove_tag" with:
        """
        {"scope": "private", "id": 9002}
        """
      Then the database answers "0" for:
        """
        select count(*) from tags
        """

    Scenario: remove_tag refuses a tag from the other scope as not found
      Given the tagging tags:
        | id   | name   | scope   |
        | 9001 | chores | private |
      When I call the MCP tool "remove_tag" with:
        """
        {"scope": "public", "id": 9001}
        """
      Then it refuses
      And the answer includes "no tag has the ID 9001"
      And the database answers "1" for:
        """
        select count(*) from tags
        """

    Scenario: Removing a tag records carry takes it off every record
      Given the tagging tags:
        | id   | name | scope  |
        | 9001 | ruby | public |
      And the tagging records:
        | kind    | title      | tags        |
        | post    | Ruby post  | ruby, rails |
        | project | ruby-gem   | ruby        |
      When I call the MCP tool "remove_tag" with:
        """
        {"scope": "public", "id": 9001}
        """
      Then it does not refuse
      And the database answers "rails" for:
        """
        select string_agg(name, ', ') from tags where scope = 'public'
        """
      And the tagged post "Ruby post" holds "rails in public"
      And the tagged project "ruby-gem" holds ""

    Scenario: Removing a private tag a task carries
      Given the tagging records:
        | kind | title        | tags   |
        | task | Water plants | chores |
      When I call the MCP tool "remove_tag" with:
        """
        {"scope": "private", "id": 1}
        """
      Then the database answers "0" for:
        """
        select count(*) from tags
        """

    Scenario: remove_tag refuses the only tag on task rules, naming the rules
      Given the tagging tags:
        | id   | name | scope   |
        | 9001 | ruby | private |
      And the tagging task rule "rails/*" carries "ruby"
      And the tagging task rule "aaronmallen/*" carries "ruby"
      When I call the MCP tool "remove_tag" with:
        """
        {"scope": "private", "id": 9001}
        """
      Then it refuses
      And the answer includes "tag 9001 is the only tag on the task rules aaronmallen/*, rails/*"
      And the database answers "1" for:
        """
        select count(*) from tags
        """

    Scenario: remove_tag names one rule as one
      Given the tagging tags:
        | id   | name | scope   |
        | 9001 | ruby | private |
      And the tagging task rule "rails/*" carries "ruby"
      When I call the MCP tool "remove_tag" with:
        """
        {"scope": "private", "id": 9001}
        """
      Then it refuses
      And the answer includes "tag 9001 is the only tag on the task rule rails/*"

    Scenario: remove_tag refuses an ID no tag has
      When I call the MCP tool "remove_tag" with:
        """
        {"scope": "public", "id": 999999}
        """
      Then it refuses
      And the answer includes "no tag has the ID 999999"

  Rule: Project tags

    Background:
      Given the tagging records:
        | kind    | title | key  |
        | project | blog  | BLOG |

    Scenario: save_tag adds a tag to the project it names, and list_tags lists it there
      When I call the MCP tool "save_tag" with:
        """
        {"scope": "project", "project": "BLOG", "name": "bug", "description": "something broke"}
        """
      And I call the MCP tool "list_tags" with:
        """
        {"scope": "project", "project": "BLOG"}
        """
      Then the answer's "tags" lists 1
      And the answer matches:
        """
        {"tags": [{"name": "bug", "scope": "project", "description": "something broke"}]}
        """
      And the database answers "bug, BLOG" for:
        """
        select tags.name, key from tags join projects on projects.id = tags.project_id
        """

    Scenario: The project scope with no project refuses
      When I call the MCP tool "list_tags" with:
        """
        {"scope": "project"}
        """
      Then it refuses
      And the answer includes "name the project that holds the tags"

    Scenario: read_tag with no project leaves project tags out
      Given the tagging tags:
        | name | scope        |
        | bug  | project BLOG |
      When I call the MCP tool "read_tag" with:
        """
        {"name": "bug"}
        """
      Then it refuses
      And the answer includes "no tag has the name bug"

    Scenario: read_tag with a project groups what carries the project's own tag, with its description and no projects
      Given the tagging tags:
        | name | scope        | description |
        | bug  | project BLOG | it broke    |
      And the tagging records:
        | kind     | title                 | key | tags     |
        | project  | pod                   | POD |          |
        | task     | Fix the feed          |     | BLOG:bug |
        | decision | Drop the feed         |     | BLOG:bug |
        | task     | Another project's bug |     | POD:bug  |
        | task     | A private bug         |     | bug      |
      When I call the MCP tool "read_tag" with:
        """
        {"name": "bug", "project": "blog"}
        """
      Then the answer's "tasks.records" lists 1
      And the answer's "tasks.records.0.title" is "Fix the feed"
      And the answer's "decisions.records" lists 1
      And the answer's "decisions.records.0.title" is "Drop the feed"
      And the answer's "projects" is "undefined"
      And the answer's "descriptions" is:
        """
        {"project": "it broke"}
        """

    Scenario: read_tag refuses a project no key names and a name the project lacks
      Given the tagging tags:
        | name | scope        |
        | bug  | project BLOG |
      When I call the MCP tool "read_tag" with:
        """
        {"name": "bug", "project": "NOPE"}
        """
      Then it refuses
      And the answer includes "no project has the key NOPE"
      When I call the MCP tool "read_tag" with:
        """
        {"name": "docs", "project": "BLOG"}
        """
      Then it refuses
      And the answer includes "no tag has the name docs"

  Rule: read_tag

    Scenario: read_tag groups everything with the name by kind, each with its status
      Given the tagging records:
        | kind          | title           | state    | tags |
        | post          | A ruby draft    | draft    | ruby |
        | project       | old-gem         | archived | ruby |
        | decision      | Ruby or not     | dropped  | ruby |
        | task          | Shipped ruby    | done     | ruby |
        | journal_entry | Wrote some ruby |          | ruby |
      When I call the MCP tool "read_tag" with:
        """
        {"name": "ruby"}
        """
      Then the answer matches:
        """
        {"posts": {"records": [{"title": "A ruby draft", "status": "draft"}]},
          "projects": {"records": [{"name": "old-gem", "status": "archived"}]},
          "decisions": {"records": [{"title": "Ruby or not", "status": "dropped"}]},
          "tasks": {"records": [{"title": "Shipped ruby", "status": "done"}]},
          "journal_entries": {"records": [{"opening": "Wrote some ruby"}]}}
        """

    Scenario: read_tag gives each scope's description of the name
      Given the tagging tags:
        | name | scope   | description  |
        | ruby | public  | the language |
        | ruby | private |              |
      And the tagging records:
        | kind | title     | tags |
        | task | Bump ruby | ruby |
      When I call the MCP tool "read_tag" with:
        """
        {"name": "ruby"}
        """
      Then the answer's "descriptions" is:
        """
        {"public": "the language", "private": null}
        """

    Scenario: read_tag refuses a name no tag holds
      When I call the MCP tool "read_tag" with:
        """
        {"name": "nothing"}
        """
      Then it refuses
      And the answer includes "no tag has the name nothing"
