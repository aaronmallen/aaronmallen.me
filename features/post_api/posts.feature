Feature: Blog posts through the API
  An API client lists, writes, changes and deletes blog posts, and the MCP tools answer the same.

  Background:
    Given an API token

  Scenario: The list gives each post's figures and keeps the status asked for
    Given the posts table holds:
      | title | body          |
      | Hello | one two three |
    When I GET "/posts" through the API
    Then the API answers 200
    And the API answer holds:
      """
      {"posts": [{"id": 1, "draft": true, "word_count": 3}]}
      """
    When I GET "/posts?status=published" through the API
    Then the API answer holds:
      """
      {"posts": []}
      """

  Scenario: The list answers as list_posts does
    Given the posts table holds:
      | title | status    | published_at |
      | Hello | published | 1 hour ago   |
    And I am signed in to the admin
    And an MCP client connected with the scopes "read"
    When I GET "/posts" through the API
    Then the MCP tool "list_posts" answers as the API did, given:
      """
      {}
      """

  Scenario: The list refuses a day it cannot read
    When I GET "/posts?from=soon" through the API
    Then the API answers 422

  Scenario: A new post is a draft
    When I POST "/posts" through the API with:
      """
      {"title": "Hello", "body": "hi", "tags": ["ruby"]}
      """
    Then the API answers 201
    And the API answer holds:
      """
      {"title": "Hello", "status": "draft", "tags": ["ruby"], "outcome": "drafted"}
      """

  Scenario: A new post refuses a slug it cannot take
    When I POST "/posts" through the API with:
      """
      {"title": "Hello", "slug": "Not A Slug"}
      """
    Then the API answers 422
    And the API answer holds "slug"

  Scenario: A change touches only the fields it names, on the post in the path
    Given the posts table holds:
      | title | slug    | body |
      | Hello | hello   | hi   |
      | Hello | hello-2 | hi   |
    When I PATCH "/posts/1" through the API with:
      """
      {"id": 2, "body": "hello there"}
      """
    Then the posts table has a row with:
      | id | title | body        |
      | 1  | Hello | hello there |
    And the posts table has a row with:
      | id | title | body |
      | 2  | Hello | hi   |

  Scenario: A scheduled post refuses a publish time in the past
    Given the posts table holds:
      | title | status    | published_at |
      | Soon  | scheduled | in 3 days    |
    When I PATCH "/posts/1" through the API with:
      """
      {"publish_at": "2020-01-01T09:00"}
      """
    Then the API answers 422
    And the API answer holds "publish_at needs a time still to come on a scheduled post"

  Scenario: A delete removes the post in the path for good
    Given the posts table holds:
      | title | status    | published_at |
      | One   | published | 1 hour ago   |
      | Two   | draft     | null         |
    When I DELETE "/posts/1" through the API with:
      """
      {"id": 2}
      """
    Then the API answers 200
    And the API answer holds:
      """
      {"id": 1, "deleted": true}
      """
    And blog post 1 is gone
    And blog post 2 is still there

  Scenario: The social card fields change and the answer gives what the post carries
    Given the posts table holds:
      | title |
      | Hello |
    When I PATCH "/posts/1/seo" through the API with:
      """
      {"og_title": "On the card"}
      """
    Then the API answer holds:
      """
      {"id": 1, "canonical_url": null, "og_image_url": null, "og_title": "On the card"}
      """
    When I PATCH "/posts/1/seo" through the API with:
      """
      {"og_image_url": "card.png"}
      """
    Then the API answers 422

  Scenario: The announcement is composed without being sent
    Given the posts table holds:
      | title | syndication_body |
      | Hello | out now          |
    And I am signed in to the admin
    And an MCP client connected with the scopes "read"
    When I GET "/posts/1/announcement" through the API
    Then the API answers 200
    And the API answer holds "out now"
    And the MCP tool "compose_announcement" gives the API's "announcement", given:
      """
      {"id": 1}
      """
    And the social_posts table holds 0 rows
