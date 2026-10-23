Feature: Edit notes and publishing through the API
  An API client revises a published post's edit note and publishes drafts, and the MCP tools answer the same.

  Background:
    Given an API token
    And the posts table holds:
      | title  | status    | published_at |
      | Hello  | published | 1 day ago    |
      | Other  | published | 1 day ago    |
      | Draft  | draft     | null         |
      | Later  | draft     | in 3 days    |
      | Soon   | scheduled | in 3 days    |
    And the post_edits table holds:
      | post_id | note         | note_html           |
      | 1       | Fixed a typo | <p>Fixed a typo</p> |
      | 2       | Elsewhere    | <p>Elsewhere</p>    |

  Scenario: A revised note replaces the old one, trimmed
    When I PATCH "/posts/1/edits/1" through the API with:
      """
      {"note": "  Fixed the benchmark numbers  "}
      """
    Then the API answers 200
    And the API answer holds:
      """
      {"id": 1, "note": "Fixed the benchmark numbers"}
      """
    And the API answer holds "created_at"
    And the post_edits table has a row with:
      | id | note                        |
      | 1  | Fixed the benchmark numbers |

  Scenario: A note of exactly 500 characters is taken
    When I PATCH "/posts/1/edits/1" through the API with:
      """
      {"note": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}
      """
    Then the API answers 200

  Scenario Outline: A note the edit cannot take is refused and the old one stays
    When I PATCH "/posts/1/edits/1" through the API with:
      """
      <body>
      """
    Then the API answers 422
    And the API answer holds "<message>"
    And the post_edits table has a row with:
      | id | note         |
      | 1  | Fixed a typo |

    Examples:
      | body                     | message                                    |
      | {"note": " "}            | note can't be blank: say what changed and why |
      | {"note": "Fixed\u0007it"} | note holds a control character            |
      | {}                       | note is missing                            |
      | {"note": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"} | note runs over 500 characters |

  Scenario Outline: A note on an edit that is not the post's answers 404
    When I PATCH "<path>" through the API with:
      """
      {"note": "Mine"}
      """
    Then the API answers 404
    And the API answer holds "<message>"
    And the post_edits table has a row with:
      | id | note      |
      | 2  | Elsewhere |

    Examples:
      | path                            | message                                 |
      | /posts/999999/edits/1    | blog post 999999 has no edit with the ID 1 |
      | /posts/1/edits/999999    | blog post 1 has no edit with the ID 999999 |
      | /posts/1/edits/2         | blog post 1 has no edit with the ID 2      |

  Scenario: update_post_edit_note answers and refuses as the endpoint does
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read write publish"
    When I PATCH "/posts/1/edits/1" through the API with:
      """
      {"note": "the same"}
      """
    Then the MCP tool "update_post_edit_note" answers as the API did apart from "updated_at", given:
      """
      {"id": 1, "edit_id": 1, "note": "the same"}
      """
    When I PATCH "/posts/1/edits/1" through the API with:
      """
      {"note": " "}
      """
    Then the MCP tool "update_post_edit_note" refuses as the API did, given:
      """
      {"id": 1, "edit_id": 1, "note": " "}
      """
    When I PATCH "/posts/1/edits/999999" through the API with:
      """
      {"note": "Mine"}
      """
    Then the MCP tool "update_post_edit_note" refuses as the API did, given:
      """
      {"id": 1, "edit_id": 999999, "note": "Mine"}
      """

  Scenario: Publishing a draft makes it live now
    When I POST "/posts/3/publish" through the API
    Then the API answers 200
    And the API answer holds:
      """
      {"id": 3, "slug": "draft", "status": "published", "outcome": "published"}
      """
    And blog post 3 was published within the last minute

  Scenario: Publishing a draft with a time still to come schedules it
    When I POST "/posts/4/publish" through the API
    Then the API answer holds:
      """
      {"status": "scheduled", "outcome": "scheduled"}
      """

  Scenario: Publishing a scheduled post makes it live now
    When I POST "/posts/5/publish" through the API
    Then the API answer holds:
      """
      {"status": "published", "outcome": "published"}
      """
    And blog post 5 was published within the last minute

  Scenario: Publishing a post already live is refused, changes nothing and sends no second webmention pass
    Given jobs left over from before have finished
    When I POST "/posts/1/publish" through the API
    Then the API answers 422
    And the API answer holds:
      """
      {"error": "invalid", "message": "blog post 1 is already published", "errors": {"id": ["blog post 1 is already published"]}}
      """
    And the posts table has no row with:
      | id | published_at |
      | 1  | null         |
    When I POST "/posts/3/publish" through the API
    Then the job "Social::Jobs::SendWebmentions" has run 1 time and no more

  Scenario: Publishing a post that fails the editor's checks leaves it a draft
    Given the posts table holds:
      | title | syndication_enabled | syndication_targets | syndication_body                                                                                                                                                                                                                                                                                                                  |
      | Long  | true                | {bluesky}           | aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa |
    When I POST "/posts/6/publish" through the API
    Then the API answers 422
    And the API answer holds:
      """
      {"errors": {"syndication_body": ["syndication_body runs over a network's limit"]}}
      """
    And the posts table has a row with:
      | id | status |
      | 6  | draft  |

  Scenario: Publishing a post that is not there answers 404
    When I POST "/posts/999999/publish" through the API
    Then the API answers 404
    And the API answer holds:
      """
      {"error": "not_found", "message": "no blog post has the ID 999999"}
      """

  Scenario: publish_post answers and refuses as the endpoint does
    Given the posts table holds:
      | title | slug      |
      | Draft | draft-two |
    And I am signed in to the admin
    And an MCP client connected with the scopes "read write publish"
    When I POST "/posts/3/publish" through the API
    Then the MCP tool "publish_post" answers as the API did apart from "id slug published_at updated_at", given:
      """
      {"id": 6}
      """
    When I POST "/posts/1/publish" through the API
    Then the MCP tool "publish_post" refuses as the API did, given:
      """
      {"id": 1}
      """
