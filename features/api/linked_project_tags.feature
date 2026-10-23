Feature: API linked project tags
  Through the API and the MCP, a record linked to a project takes that project's tags, a post keeps its project tags
  apart from its public ones, and reading a project tag lists its notes and mail threads for a token that may see them.

  Background:
    Given an API token with the scopes "read write notes mail"
    And I am signed in to the admin
    And an MCP client connected with the scopes "read write notes mail"
    And the tagging records:
      | kind    | title | key  |
      | project | blog  | BLOG |

  Scenario: Tagging a linked decision through the API takes the project's tag
    Given the tagging records:
      | id | kind     | title       |
      | 7  | decision | Pick a host |
    And the tagging decision "Pick a host" links to the project "BLOG"
    When I call the API with "POST /api/v1/decisions/7/tags" and:
      """
      {"tags": ["bug"]}
      """
    Then the tagged decision "Pick a host" holds "bug in BLOG"

  Scenario: Tagging a linked journal entry through the API takes the project's tag
    Given the tagging records:
      | id | kind          | title          |
      | 7  | journal_entry | Wrote the feed |
    And the tagging journal_entry "Wrote the feed" links to the project "BLOG"
    When I call the API with "PATCH /api/v1/journal_entries/7" and:
      """
      {"tags": ["bug"]}
      """
    Then the tagged journal_entry "Wrote the feed" holds "bug in BLOG"

  Scenario: Tagging a linked note through the MCP takes the project's tag
    Given the tagging records:
      | id | kind | title      |
      | 7  | note | Feed notes |
    And the tagging note "Feed notes" links to the project "BLOG"
    When I call the MCP tool "tag_note" with:
      """
      {"id": 7, "tag": "bug"}
      """
    Then the tagged note "Feed notes" holds "bug in BLOG"

  Scenario: Tagging a linked mail thread through the MCP takes the project's tag
    Given the tagging records:
      | id | kind        | title      |
      | 7  | mail_thread | Feed broke |
    And the tagging mail_thread "Feed broke" links to the project "BLOG"
    When I call the MCP tool "tag_mail_threads" with:
      """
      {"ids": [7], "tag": "bug"}
      """
    Then the tagged mail_thread "Feed broke" holds "bug in BLOG"

  Rule: A post linked to a project

    Background:
      Given the tagging records:
        | id | kind | title           | state | tags |
        | 7  | post | Fixing the feed | draft | ruby |
      And the tagging post "Fixing the feed" links to the project "BLOG"

    Scenario: A post takes project tags beside its public tags and reads them apart
      When I call the API with "PATCH /api/v1/posts/7" and:
        """
        {"project_tags": ["bug"]}
        """
      Then the tagged post "Fixing the feed" holds "bug in BLOG, ruby in public"
      And the answer's "tags" is:
        """
        ["ruby"]
        """
      When I call the API with "GET /api/v1/posts/7"
      Then the answer's "tags" is:
        """
        ["ruby"]
        """
      And the answer's "project_tags" is:
        """
        ["bug"]
        """

    Scenario: A post takes project tags through the MCP
      When I call the MCP tool "update_post" with:
        """
        {"id": 7, "project_tags": ["bug"]}
        """
      Then the tagged post "Fixing the feed" holds "bug in BLOG, ruby in public"

  Rule: Reading a project tag

    Background:
      Given the tagging records:
        | kind        | title      | tags     |
        | note        | Feed notes | BLOG:bug |
        | mail_thread | Feed broke | BLOG:bug |

    Scenario: Reading a project tag lists its notes and mail threads
      When I call the API with "GET /api/v1/tags/bug?project=BLOG"
      Then the answer's "notes.records.0.title" is "Feed notes"
      And the answer's "notes.records" lists 1
      And the answer's "messages.records.0.subject" is "Feed broke"
      And the answer's "messages.records" lists 1
      And the answer's "counts.notes" is "1"
      And the answer's "counts.messages" is "1"

    Scenario: Reading a project tag leaves notes and mail out without their scopes
      Given an API token with the scopes "read"
      When I call the API with "GET /api/v1/tags/bug?project=BLOG"
      Then the call answers 200
      And the answer's "notes" is "undefined"
      And the answer's "messages" is "undefined"

    Scenario: Reading a project tag answers the same JSON as read_tag
      Then the tag API call "GET /api/v1/tags/bug?project=BLOG" answers what the MCP tool "read_tag" does with:
        """
        {"name": "bug", "project": "BLOG"}
        """
