Feature: Reading one blog post through the API
  An API client reads every field the admin editor shows, and read_post answers the same.

  Background:
    Given an API token

  Scenario: The post answers every field the editor shows
    Given the posts table holds:
      | title | slug  | summary       | body          | og_title    | og_image_url                 | canonical_url                  | syndication_enabled | syndication_body | syndication_targets | webmentions_enabled | status    | published_at | word_count |
      | Hello | hello | A short hello | one two three | On the card | https://example.com/card.png | https://elsewhere.example/hello | true                | Out now          | {bluesky}           | true                | scheduled | in 3 days    | 9          |
    And blog post 1 carries the tag "ruby"
    When I GET "/posts/1" through the API
    Then the API answers 200
    And the API answer holds:
      """
      {
        "id": 1, "status": "scheduled", "tags": ["ruby"], "word_count": 9, "read_time": 1,
        "title": "Hello", "slug": "hello", "summary": "A short hello", "body": "one two three",
        "og_title": "On the card", "og_image_url": "https://example.com/card.png",
        "canonical_url": "https://elsewhere.example/hello", "syndication_enabled": true,
        "syndication_body": "Out now", "syndication_targets": ["bluesky"], "webmentions_enabled": true,
        "webmentions_received": 0, "edit_notes": [], "suggestion_id": null, "suggestion_edits": [], "record_links": {}
      }
      """

  Scenario: A post that leaves fields blank gives empty text and null card fields
    Given the posts table holds:
      | title |
      | Hello |
    When I GET "/posts/1" through the API
    Then the API answer holds:
      """
      {"summary": "", "og_title": null, "og_image_url": null, "canonical_url": null, "published_at": null}
      """

  Scenario: The post counts its webmentions and gives its edit notes newest first
    Given the posts table holds:
      | title | status    | published_at |
      | Hello | published | 1 day ago    |
    And the webmentions table holds:
      | post_id | source_url               | type  |
      | 1       | https://203.0.113.5/one  | reply |
      | 1       | https://203.0.113.5/two  | like  |
    And the post_edits table holds:
      | post_id | note         | note_html           | created_at  |
      | 1       | fixed a typo | <p>fixed a typo</p> | 1 hour ago  |
      | 1       | added a link | <p>added a link</p> | now         |
    When I GET "/posts/1" through the API
    Then the API answer holds:
      """
      {"webmentions_received": 2, "edit_notes": [{"id": 2, "note": "added a link"}, {"id": 1, "note": "fixed a typo"}]}
      """

  Scenario: The post gives the open suggested edits and the suggestion that holds them
    Given the posts table holds:
      | title | body            |
      | Hello | a cat and a dog |
    And the suggestions table holds:
      | post_id |
      | 1       |
    And the suggestion_edits table holds:
      | suggestion_id | position | original | replacement | reason | status   |
      | 1             | 1        | cat      | black cat   | typo   | pending  |
      | 1             | 2        | dog      | dogs        | typo   | rejected |
    When I GET "/posts/1" through the API
    Then the API answer holds:
      """
      {
        "suggestion_id": 1,
        "suggestion_edits": [
          {"id": 1, "part": null, "original": "cat", "replacement": "black cat", "reason": "typo", "status": "pending"}
        ]
      }
      """

  Scenario: A suggestion with every edit settled leaves suggestion_id null
    Given the posts table holds:
      | title | body  |
      | Hello | a cat |
    And the suggestions table holds:
      | post_id |
      | 1       |
    And the suggestion_edits table holds:
      | suggestion_id | position | original | replacement | reason | status   |
      | 1             | 1        | cat      | dog         | typo   | rejected |
    When I GET "/posts/1" through the API
    Then the API answer holds:
      """
      {"suggestion_id": null, "suggestion_edits": []}
      """

  Scenario: The post gives its linked records grouped by kind
    Given the posts table holds:
      | title |
      | Hello |
    And the commits table holds:
      | sha     | repo         | branch | message         | commit_date | commit_time |
      | abc1234 | owner/server | main   | Move the server | 2026-10-01  | 09:00       |
    And the record_links table holds:
      | left_kind | left_id | right_kind | right_id |
      | post      | 1       | commit     | 1        |
    When I GET "/posts/1" through the API
    Then the API answer holds:
      """
      {"record_links": {"commit": [{"kind": "commit", "id": 1, "title": "Move the server"}]}}
      """

  Scenario: A post that is not there answers 404, and read_post says the same
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read"
    When I GET "/posts/999999" through the API
    Then the API answers 404
    And the API answer holds:
      """
      {"error": "not_found", "message": "no blog post has the ID 999999"}
      """
    And the MCP tool "read_post" refuses as the API did, given:
      """
      {"id": 999999}
      """

  Scenario: read_post answers as the endpoint does
    Given the posts table holds:
      | title | summary | status    | published_at | syndication_enabled | syndication_body | syndication_targets |
      | Hello | Short   | published | 1 day ago    | true                | Out now          | {bluesky}           |
    And blog post 1 carries the tag "ruby"
    And the post_edits table holds:
      | post_id | note  | note_html    |
      | 1       | fixed | <p>fixed</p> |
    And I am signed in to the admin
    And an MCP client connected with the scopes "read"
    When I GET "/posts/1" through the API
    Then the MCP tool "read_post" answers as the API did, given:
      """
      {"id": 1}
      """
