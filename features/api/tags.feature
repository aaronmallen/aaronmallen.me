Feature: API tags
  The JSON API lists, adds, renames, describes and removes tags in the public, private or one project's scope. A
  token without the mail scope sees no mail thread in a tag's counts and may not change a tag only mail carries.

  Background:
    Given an API token with the scopes "read suggest write publish delete mail"

  Scenario: Listing a scope gives its tags by name with how many records carry each
    Given the tagging records:
      | kind | title       | tags |
      | post | Ruby on Pis | ruby |
    And the tagging tags:
      | name   | scope   |
      | health | private |
    When I call the API with "GET /api/v1/tags?scope=public"
    Then the call answers 200
    And the answer's "tags" lists 1
    And the answer matches:
      """
      {"tags": [{"name": "ruby", "count": 1}]}
      """

  Scenario: A query keeps only the tags whose name holds it
    Given the tagging tags:
      | name  | scope  |
      | ruby  | public |
      | rails | public |
    When I call the API with "GET /api/v1/tags?scope=public&query=rub"
    Then the answer matches:
      """
      {"count": 1, "partial": false}
      """

  Scenario: Listing tags answers the same JSON as list_tags
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read suggest write publish delete mail"
    And the tagging records:
      | kind | title       | tags |
      | post | Ruby on Pis | ruby |
    Then the tag API call "GET /api/v1/tags?scope=public" answers what the MCP tool "list_tags" does with:
      """
      {"scope": "public"}
      """

  Scenario: Without the mail scope a tag's count and kinds leave mail threads out
    Given an API token with the scopes "read"
    And the tagging records:
      | kind        | title     | tags    |
      | task        | Pay bills | billing |
      | mail_thread | Your bill | billing |
    When I call the API with "GET /api/v1/tags?scope=private"
    Then the answer's "tags" lists 1
    And the answer's "tags.0.name" is "billing"
    And the answer's "tags.0.count" is "1"
    And the answer's "tags.0.by_kind" is:
      """
      {"tasks": 1}
      """

  Scenario: Without the mail scope a tag only mail threads carry stays out of the list and the count
    Given an API token with the scopes "read"
    And the tagging records:
      | kind        | title        | tags    |
      | task        | Water plants | chores  |
      | mail_thread | Your bill    | billing |
    When I call the API with "GET /api/v1/tags?scope=private"
    Then the answer's "tags" lists 1
    And the answer's "tags.0.name" is "chores"
    And the answer's "count" is "1"

  Scenario: Without the mail scope a tag nothing carries stays in the list
    Given an API token with the scopes "read"
    And the tagging tags:
      | name   | scope   |
      | chores | private |
    When I call the API with "GET /api/v1/tags?scope=private"
    Then the answer's "tags" lists 1
    And the answer's "tags.0.name" is "chores"

  Scenario: With the mail scope a tag's kinds count mail threads
    Given the tagging records:
      | kind        | title     | tags    |
      | mail_thread | Your bill | billing |
    When I call the API with "GET /api/v1/tags?scope=private"
    Then the answer's "tags.0.name" is "billing"
    And the answer's "tags.0.by_kind" is:
      """
      {"messages": 1}
      """

  Scenario: Listing tags with no scope answers 422
    When I call the API with "GET /api/v1/tags"
    Then the call answers 422

  Scenario: Adding a tag puts it in its scope and answers 201
    When I call the API with "POST /api/v1/tags" and:
      """
      {"scope": "private", "name": "health", "color": "mk-blue"}
      """
    Then the call answers 201
    And the answer matches:
      """
      {"name": "health", "color": "mk-blue"}
      """

  Scenario: Adding a name another tag holds answers 422
    Given the tagging tags:
      | name | scope  |
      | ruby | public |
    When I call the API with "POST /api/v1/tags" and:
      """
      {"scope": "public", "name": "ruby"}
      """
    Then the call answers 422
    And the answer's "errors" is:
      """
      {"name": ["another tag already holds that name"]}
      """

  Scenario: Renaming a tag keeps its colour
    Given the tagging tags:
      | id   | name | scope  | color   |
      | 9001 | ruby | public | mk-blue |
    When I call the API with "PATCH /api/v1/tags/public/9001" and:
      """
      {"name": "rails"}
      """
    Then the answer matches:
      """
      {"name": "rails", "color": "mk-blue"}
      """

  Scenario: Describing a tag keeps its name
    Given the tagging tags:
      | id   | name | scope  |
      | 9001 | ruby | public |
    When I call the API with "PATCH /api/v1/tags/public/9001" and:
      """
      {"description": "the language"}
      """
    Then the answer matches:
      """
      {"name": "ruby", "description": "the language"}
      """

  Scenario: Changing a tag from the other scope answers 404
    Given the tagging tags:
      | id   | name   | scope   |
      | 9001 | chores | private |
    When I call the API with "PATCH /api/v1/tags/public/9001" and:
      """
      {"name": "rails"}
      """
    Then the call answers 404

  Scenario: Renaming a tag only mail threads carry needs the mail scope and says so
    Given the tagging tags:
      | id   | name    | scope   |
      | 9001 | billing | private |
    And the tagging records:
      | kind        | title     | tags    |
      | mail_thread | Your bill | billing |
    And an API token with the scopes "write"
    When I call the API with "PATCH /api/v1/tags/private/9001" and:
      """
      {"name": "invoices"}
      """
    Then the call answers 422
    And the answer includes "mail scope"
    And the database answers "billing" for:
      """
      select name from tags where id = 9001
      """
    Given an API token with the scopes "write mail"
    When I call the API with "PATCH /api/v1/tags/private/9001" and:
      """
      {"name": "invoices"}
      """
    Then the call answers 200
    And the database answers "invoices" for:
      """
      select name from tags where id = 9001
      """

  Scenario: Renaming a tag mail threads and other records carry needs no mail scope
    Given the tagging tags:
      | id   | name    | scope   |
      | 9001 | billing | private |
    And the tagging records:
      | kind        | title     | tags    |
      | mail_thread | Your bill | billing |
      | task        | Pay bills | billing |
    And an API token with the scopes "write"
    When I call the API with "PATCH /api/v1/tags/private/9001" and:
      """
      {"name": "invoices"}
      """
    Then the call answers 200
    And the database answers "invoices" for:
      """
      select name from tags where id = 9001
      """

  Scenario: Removing a tag takes it away for good
    Given the tagging tags:
      | id   | name | scope  |
      | 9001 | ruby | public |
    When I call the API with "DELETE /api/v1/tags/public/9001"
    Then the call answers 200
    And the answer matches:
      """
      {"id": 9001, "removed": true}
      """
    And the database answers "0" for:
      """
      select count(*) from tags
      """

  Scenario: Removing a tag a mail thread carries needs the mail scope and says so
    Given the tagging tags:
      | id   | name    | scope   |
      | 9001 | billing | private |
    And the tagging records:
      | kind        | title     | tags    |
      | mail_thread | Your bill | billing |
    And an API token with the scopes "delete"
    When I call the API with "DELETE /api/v1/tags/private/9001"
    Then the call answers 422
    And the answer includes "mail scope"
    And the database answers "1" for:
      """
      select count(*) from tags where id = 9001
      """
    Given an API token with the scopes "delete mail"
    When I call the API with "DELETE /api/v1/tags/private/9001"
    Then the call answers 200
    And the database answers "0" for:
      """
      select count(*) from tags where id = 9001
      """

  Rule: One project's tags

    Background:
      Given the tagging records:
        | kind    | title | key  |
        | project | blog  | BLOG |
        | project | pod   | POD  |

    Scenario: Listing the project scope gives only the named project's tags
      Given the tagging tags:
        | name   | scope        |
        | bug    | project BLOG |
        | chore  | project POD  |
        | health | private      |
      When I call the API with "GET /api/v1/tags?scope=project&project=BLOG"
      Then the answer's "tags" lists 1
      And the answer's "tags.0.name" is "bug"

    Scenario: The public and private lists leave project tags out
      Given the tagging tags:
        | name | scope        |
        | bug  | project BLOG |
      When I call the API with "GET /api/v1/tags?scope=public"
      Then the answer's "tags" lists 0
      When I call the API with "GET /api/v1/tags?scope=private"
      Then the answer's "tags" lists 0

    Scenario: Listing a project's tags answers the same JSON as list_tags
      Given I am signed in to the admin
      And an MCP client connected with the scopes "read suggest write publish delete mail"
      And the tagging tags:
        | name | scope        |
        | bug  | project BLOG |
      Then the tag API call "GET /api/v1/tags?scope=project&project=BLOG" answers what the MCP tool "list_tags" does with:
        """
        {"scope": "project", "project": "BLOG"}
        """

    Scenario: Adding a tag to a project answers 201
      Given the tagging tags:
        | name | scope       |
        | bug  | project POD |
      When I call the API with "POST /api/v1/tags" and:
        """
        {"scope": "project", "project": "blog", "name": "bug"}
        """
      Then the call answers 201
      And the answer's "name" is "bug"
      And the database answers "bug" for:
        """
        select string_agg(tags.name, ', ') from tags join projects on projects.id = tags.project_id where key = 'BLOG'
        """

    Scenario: Adding a name the project holds answers 422
      Given the tagging tags:
        | name | scope        |
        | bug  | project BLOG |
      When I call the API with "POST /api/v1/tags" and:
        """
        {"scope": "project", "project": "BLOG", "name": "bug"}
        """
      Then the call answers 422
      And the answer's "errors" is:
        """
        {"name": ["another tag already holds that name"]}
        """

    Scenario: The project scope with no project answers 422
      When I call the API with "POST /api/v1/tags" and:
        """
        {"scope": "project", "name": "bug"}
        """
      Then the call answers 422
      And the answer's "errors" is:
        """
        {"project": ["name the project that holds the tags"]}
        """

    Scenario: A project with another scope answers 422
      When I call the API with "GET /api/v1/tags?scope=private&project=BLOG"
      Then the call answers 422
      And the answer's "errors" is:
        """
        {"project": ["only the project scope takes a project"]}
        """

    Scenario: A key no project has answers 404
      When I call the API with "GET /api/v1/tags?scope=project&project=NOPE"
      Then the call answers 404
      And the answer's "message" is "no project has the key NOPE"

    Scenario: Renaming and describing a project tag
      Given the tagging tags:
        | id   | name | scope        |
        | 9001 | bug  | project BLOG |
      When I call the API with "PATCH /api/v1/tags/project/9001" and:
        """
        {"project": "BLOG", "name": "defect", "description": "fix it"}
        """
      Then the answer matches:
        """
        {"name": "defect", "description": "fix it"}
        """

    Scenario: Naming a project finds only that project's tags, and the ID alone finds any
      Given the tagging tags:
        | id   | name | scope       |
        | 9001 | bug  | project POD |
      When I call the API with "PATCH /api/v1/tags/project/9001" and:
        """
        {"project": "BLOG", "name": "defect"}
        """
      Then the call answers 404
      When I call the API with "PATCH /api/v1/tags/project/9001" and:
        """
        {"name": "defect"}
        """
      Then the answer's "name" is "defect"

    Scenario: Removing a project tag takes it away for good
      Given the tagging tags:
        | id   | name | scope        |
        | 9001 | bug  | project BLOG |
      When I call the API with "DELETE /api/v1/tags/project/9001"
      Then the answer matches:
        """
        {"id": 9001, "removed": true}
        """
      When I call the API with "GET /api/v1/tags?scope=project&project=BLOG"
      Then the answer's "tags" lists 0
