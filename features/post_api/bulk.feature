Feature: Acting on many blog posts through the API
  An API client deletes drafts or tags posts in one call, all or none, and the MCP tools answer the same.

  Background:
    Given an API token
    And the posts table holds:
      | title | status    | published_at |
      | One   | draft     | null         |
      | Two   | draft     | null         |
      | Left  | draft     | null         |
      | Out   | published | 1 day ago    |
    And blog post 1 carries the tag "ruby"

  Scenario: A bulk delete removes the drafts it names and leaves the rest
    When I POST "/posts/bulk/delete" through the API with:
      """
      {"ids": [1, 2]}
      """
    Then the API answers 200
    And the API answer holds:
      """
      {"posts": [{"id": 1, "title": "One", "deleted": true}, {"id": 2, "title": "Two", "deleted": true}]}
      """
    And blog post 1 is gone
    And blog post 2 is gone
    And blog post 3 is still there

  Scenario: A bulk delete removes none when one ID is gone
    When I POST "/posts/bulk/delete" through the API with:
      """
      {"ids": [1, 2, 99]}
      """
    Then the API answers 422
    And the API answer holds:
      """
      {"error": "invalid", "message": "no blog post has the ID 99", "errors": {"ids": ["no blog post has the ID 99"]}}
      """
    And blog post 1 is still there
    And blog post 2 is still there

  Scenario: A bulk delete removes none when one post is not a draft
    When I POST "/posts/bulk/delete" through the API with:
      """
      {"ids": [1, 2, 4]}
      """
    Then the API answers 422
    And the API answer holds:
      """
      {"errors": {"ids": ["blog post 4 is not a draft"]}}
      """
    And blog post 1 is still there
    And blog post 4 is still there

  Scenario: A bulk tag adds the tag to posts in any status and answers each as it stands
    When I POST "/posts/bulk/tag" through the API with:
      """
      {"ids": [1, 4], "tag": "Release"}
      """
    Then the API answers 200
    And the API answer holds:
      """
      {
        "posts": [
          {"id": 1, "title": "One", "slug": "one", "status": "draft", "published_at": null, "tags": ["release", "ruby"]},
          {"id": 4, "tags": ["release"]}
        ]
      }
      """
    And blog post 1 carries the tags "release ruby"

  Scenario: A bulk tag tags none when one ID is gone
    When I POST "/posts/bulk/tag" through the API with:
      """
      {"ids": [1, 4, 99], "tag": "release"}
      """
    Then the API answers 422
    And the API answer holds "no blog post has the ID 99"
    And blog post 1 carries the tags "ruby"
    And blog post 4 carries the tags ""

  Scenario Outline: A bulk tag refuses a tag it cannot take
    When I POST "/posts/bulk/tag" through the API with:
      """
      {"ids": [1], <tag>}
      """
    Then the API answers 422
    And the API answer holds "<message>"

    Examples:
      | tag                 | message                                    |
      | "tag": "two words"  | a tag is lowercase words joined by hyphens |
      | "tag": " "          | tag: name the tag first                    |
      | "none": true        | tag is missing                             |

  Scenario: A repeated ID counts once
    When I POST "/posts/bulk/tag" through the API with:
      """
      {"ids": [1, 1], "tag": "ruby"}
      """
    Then the API answer holds:
      """
      {"posts": [{"id": 1}]}
      """

  Scenario Outline: The list of IDs must hold one to a hundred numbers
    When I POST "/posts/bulk/delete" through the API with:
      """
      <body>
      """
    Then the API answers 422
    And the API answer holds "ids"

    Examples:
      | body                                                                                                                                                                                                                                                                                                                                                                                                   |
      | {"ids": []}                                                                                                                                                                                                                                                                                                                                                                                            |
      | {"ids": ["one"]}                                                                                                                                                                                                                                                                                                                                                                                       |
      | {}                                                                                                                                                                                                                                                                                                                                                                                                     |
      | {"ids": [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100,101]} |

  Scenario: tag_posts and delete_posts answer as the endpoints do
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read write delete"
    When I POST "/posts/bulk/tag" through the API with:
      """
      {"ids": [1], "tag": "ruby"}
      """
    Then the MCP tool "tag_posts" answers as the API did apart from "updated_at", given:
      """
      {"ids": [1], "tag": "ruby"}
      """
    When I POST "/posts/bulk/delete" through the API with:
      """
      {"ids": [4]}
      """
    Then the MCP tool "delete_posts" refuses as the API did, given:
      """
      {"ids": [4]}
      """
    When I POST "/posts/bulk/delete" through the API with:
      """
      {"ids": [2]}
      """
    Then the MCP tool "delete_posts" answers as the API did apart from "id title", given:
      """
      {"ids": [3]}
      """
