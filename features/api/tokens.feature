Feature: API tokens
  An API token reaches the JSON API.

  Scenario: A request with an API token lists the posts
    Given a post "Hello world" published an hour ago
    And an API token
    Then the API lists the post "Hello world"
