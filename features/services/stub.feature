Feature: Outside services answer from the stub
  No request leaves the machine. A Given step sets each reply, and a request
  no step set a reply for fails the scenario.

  Scenario: The app hears the reply a step sets
    Given I am signed in to the admin
    And Mastodon answers POST "/203.0.113.9/api/v1/apps" with:
      """
      {"client_id": "stub-app", "client_secret": "stub-secret"}
      """
    And Mastodon answers GET "/203.0.113.9/oauth/authorize" with:
      """
      <h1>Authorize the blog</h1>
      """
    When I connect Mastodon on "203.0.113.9"
    Then I see "Authorize the blog"

  Scenario: The app reaches a page on the web through the stub
    Given I am signed in to the admin
    And a post "Engines" that takes webmentions
    And the page "http://203.0.113.7/reply" replies to the post "Engines" as "Ada Lovelace"
    When "http://203.0.113.7/reply" sends a webmention for the post "Engines"
    Then the inbox lists a webmention from "Ada Lovelace"

  @fail
  Scenario: A request no step set a reply for fails the scenario
    Given I am signed in to the admin
    When I connect Mastodon on "203.0.113.9"

  @fail
  Scenario: A browser request off the machine fails the scenario
    When the browser asks for "https://example.com/"
