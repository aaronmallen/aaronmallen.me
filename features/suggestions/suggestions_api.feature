Feature: Suggested edits through the API
  A client with the suggest scope suggests edits, lists them, and accepts or rejects them over the JSON API.

  Background:
    Given an API token

  Scenario: The API lists the sets made in a range, settled edits too
    Given a draft post that reads "teh cat sat"
    And the suggested edits for post 1:
      | original | replacement | status   |
      | teh      | the         | rejected |
    When I ask the API for the suggestions from "today" to "today"
    Then the API answers 200
    And the API answer holds:
      """
      {"suggestions": [{"edits": [{"status": "rejected"}]}]}
      """

  Scenario: The API lists the same suggestions as the MCP tool
    Given a draft post that reads "teh cat sat"
    And the suggested edits for post 1:
      | original | replacement |
      | teh      | the         |
    And I am signed in to the admin
    And an MCP client connected with the scopes "read"
    When I ask the API for the suggestions from "today" to "today"
    Then the API answer is what MCP lists for today, unmarked

  Scenario: A suggestion on a draft post is stored as pending
    Given a draft post that reads "teh cat sat"
    When I POST "/suggestions" through the API with:
      """
      {"target": "post", "id": 1, "edits": [{"original": "teh", "replacement": "the", "reason": "typo"}]}
      """
    Then the API answers 201
    And the API answer holds:
      """
      {"target": "post", "edits": 1, "status": "pending"}
      """
    And the edits on post 1 stand as "pending"

  Scenario: A suggestion on a published post is refused
    Given a published post that reads "teh cat sat"
    When I POST "/suggestions" through the API with:
      """
      {"target": "post", "id": 1, "edits": [{"original": "teh", "replacement": "the", "reason": "typo"}]}
      """
    Then the API answers 422
    And the API answer holds:
      """
      {"message": "blog post 1 is published; suggest edits only on a draft or scheduled post"}
      """

  Scenario: A suggestion with no edits is refused
    Given a draft post that reads "teh cat sat"
    When I POST "/suggestions" through the API with:
      """
      {"target": "post", "id": 1, "edits": []}
      """
    Then the API answers 422
    And the API answer holds:
      """
      {"message": "give at least one edit"}
      """

  Scenario: A suggestion on a post that does not exist answers 404
    When I POST "/suggestions" through the API with:
      """
      {"target": "post", "id": 999999, "edits": [{"original": "a", "replacement": "b", "reason": "typo"}]}
      """
    Then the API answers 404

  Scenario: A token without the suggest scope cannot suggest
    Given an API token with the scopes "read write"
    When I POST "/suggestions" through the API with:
      """
      {"target": "post", "id": 1, "edits": [{"original": "a", "replacement": "b", "reason": "typo"}]}
      """
    Then the API answers 403

  Scenario: A suggestion on a social post names its part
    Given a draft social post to "mastodon" with the parts:
      | the cat sat |
      | teh dog ran |
    When I POST "/suggestions" through the API with:
      """
      {"target": "social_post", "id": 1, "edits": [{"original": "teh", "replacement": "the", "reason": "typo", "part": 2}]}
      """
    Then the API answers 201
    And the suggestion_edits table has a row with:
      | part | status  |
      | 2    | pending |

  Scenario: A suggestion on a part a social post lacks is refused
    Given a draft social post to "mastodon" with the parts:
      | the cat sat |
      | teh dog ran |
    When I POST "/suggestions" through the API with:
      """
      {"target": "social_post", "id": 1, "edits": [{"original": "teh", "replacement": "the", "reason": "typo", "part": 5}]}
      """
    Then the API answers 422
    And the API answer holds "social post 1 has no part 5"

  Scenario: A suggestion on a social post already sent is not found
    Given a posted social post to "mastodon" that reads "teh cat sat"
    When I POST "/suggestions" through the API with:
      """
      {"target": "social_post", "id": 1, "edits": [{"original": "teh", "replacement": "the", "reason": "typo", "part": 1}]}
      """
    Then the API answers 404
    And no suggestion is stored for social post 1

  Scenario: Accepting writes every pending edit and says which it took
    Given a draft post that reads "teh cat sat"
    And the suggested edits for post 1:
      | original | replacement |
      | teh      | the         |
    When I POST "/suggestions/1/accept" through the API with:
      """
      {}
      """
    Then the API answers 200
    And the API answer holds:
      """
      {"accepted": [1], "refused": [], "stale": []}
      """
    And post 1 reads "the cat sat"

  Scenario: Accepting an unknown suggestion answers 404
    When I POST "/suggestions/999999/accept" through the API with:
      """
      {}
      """
    Then the API answers 404

  Scenario: Rejecting rejects every open edit and leaves the post alone
    Given a draft post that reads "teh cat sat"
    And the suggested edits for post 1:
      | original | replacement |
      | teh      | the         |
    When I POST "/suggestions/1/reject" through the API with:
      """
      {}
      """
    Then the API answer holds:
      """
      {"rejected": [1]}
      """
    And post 1 reads "teh cat sat"

  Scenario: Rejecting a set with nothing open is refused
    Given a draft post that reads "teh cat sat"
    And the suggested edits for post 1:
      | original | replacement | status   |
      | teh      | the         | rejected |
    When I POST "/suggestions/1/reject" through the API with:
      """
      {}
      """
    Then the API answers 422
