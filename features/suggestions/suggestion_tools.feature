Feature: Suggested edits through MCP
  An agent lists suggested edits and accepts or rejects them with the MCP tools.

  Background:
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read suggest write publish delete"

  Scenario: list_suggestions lists each set made in the range with its target and edits
    Given a draft post that reads "teh cat sat"
    And a draft social post to "mastodon" that reads "teh one"
    And the suggested edits for post 1:
      | original | replacement | status   |
      | teh      | the         | rejected |
    And the suggested edits for social post 1:
      | original | replacement | part |
      | teh      | the         | 1    |
    When I ask MCP for the suggestions from "today" to "today"
    Then the MCP answer holds:
      """
      {"suggestions": [
        {"id": 2, "target": "social_post", "target_id": 1},
        {"id": 1, "target": "post", "target_id": 1, "edits": [
          {"id": 1, "part": null, "original": {"untrusted": true, "text": "teh"},
            "replacement": {"untrusted": true, "text": "the"}, "reason": {"untrusted": true, "text": "typo"},
            "status": "rejected"}
        ]}
      ]}
      """

  Scenario: list_suggestions leaves out a set made outside the range
    Given a draft post that reads "teh cat sat"
    And the suggested edits for post 1:
      | original | replacement |
      | teh      | the         |
    When I ask MCP for the suggestions from "a week ago" to "yesterday"
    Then the MCP answer holds:
      """
      {"suggestions": []}
      """

  Scenario: list_suggestions refuses a range that runs backwards
    When I ask MCP for the suggestions from "today" to "yesterday"
    Then the MCP tool refuses with "from comes after to"

  Scenario: accept_suggestion_edits writes every pending edit and says which it took
    Given a draft post that reads "teh cat sta"
    And the suggested edits for post 1:
      | original | replacement |
      | teh      | the         |
      | sta      | sat         |
    When I call the MCP tool "accept_suggestion_edits" with:
      """
      {"suggestion_id": 1}
      """
    Then the MCP answer holds:
      """
      {"suggestion_id": 1, "accepted": [1, 2], "refused": [], "stale": []}
      """
    And post 1 reads "the cat sat"

  Scenario: accept_suggestion_edits takes only the edits it names
    Given a draft post that reads "teh cat sta"
    And the suggested edits for post 1:
      | original | replacement |
      | teh      | the         |
      | sta      | sat         |
    When I call the MCP tool "accept_suggestion_edits" with:
      """
      {"suggestion_id": 1, "edit_ids": [1]}
      """
    Then the edits on post 1 stand as "accepted pending"
    And post 1 reads "the cat sta"

  Scenario: accept_suggestion_edits marks an edit stale when its text has gone
    Given a draft post that reads "teh cat sat"
    And the suggested edits for post 1:
      | original | replacement |
      | dgo      | dog         |
    When I call the MCP tool "accept_suggestion_edits" with:
      """
      {"suggestion_id": 1}
      """
    Then the MCP answer holds:
      """
      {"stale": [1]}
      """

  Scenario: An agent accepts an edit through the suggestion ID read_post gives
    Given a draft post that reads "teh cat sta"
    And the suggested edits for post 1:
      | original | replacement |
      | teh      | the         |
      | sta      | sat         |
    When I call the MCP tool "read_post" with:
      """
      {"id": 1}
      """
    Then the MCP answer holds:
      """
      {"suggestion_id": 1, "suggestion_edits": [{"id": 1}, {"id": 2}]}
      """
    When I call the MCP tool "accept_suggestion_edits" with:
      """
      {"suggestion_id": 1, "edit_ids": [1]}
      """
    Then post 1 reads "the cat sta"

  Scenario: An agent accepts through the suggestion ID read_social_post gives
    Given a draft social post to "mastodon" that reads "teh one"
    And the suggested edits for social post 1:
      | original | replacement | part |
      | teh      | the         | 1    |
    When I call the MCP tool "read_social_post" with:
      """
      {"id": 1}
      """
    Then the MCP answer holds:
      """
      {"suggestion_id": 1}
      """
    When I call the MCP tool "accept_suggestion_edits" with:
      """
      {"suggestion_id": 1}
      """
    Then social post 1 has the parts:
      | the one |

  Scenario: accept_suggestion_edits refuses an edit that fits Bluesky only before its link is tagged
    Given a draft social post to "bluesky" that reads "teh {a*247} {site}/writing/hello"
    And the suggested edits for social post 1:
      | original | replacement | part |
      | teh      | their       | 1    |
    When I call the MCP tool "accept_suggestion_edits" with:
      """
      {"suggestion_id": 1}
      """
    Then the MCP answer holds:
      """
      {"refused": [1]}
      """
    And social post 1 has the parts:
      | teh {a*247} {site}/writing/hello |

  Scenario: accept_suggestion_edits refuses edits that would leave a part empty
    Given a draft social post to "mastodon" with the parts:
      | teh one |
      | teh     |
    And the suggested edits for social post 1:
      | original | replacement | part |
      | teh      | the         | 1    |
      | teh      | {nbsp}      | 2    |
    When I call the MCP tool "accept_suggestion_edits" with:
      """
      {"suggestion_id": 1}
      """
    Then the MCP tool refuses with "the edits would leave part 2 of the social post under suggestion 1 empty; nothing changed"
    And social post 1 has the parts:
      | teh one |
      | teh     |
    And the edits on social post 1 stand as "pending pending"

  Scenario Outline: A suggestion tool refuses a social post already sent
    Given a posted social post to "mastodon" that reads "teh one"
    And the suggested edits for social post 1:
      | original | replacement | part |
      | teh      | the         | 1    |
    When I call the MCP tool "<tool>" with:
      """
      <arguments>
      """
    Then the MCP tool refuses with "the social post under suggestion 1 has been sent"

    Examples:
      | tool                    | arguments                                     |
      | accept_suggestion_edits | {"suggestion_id": 1}                          |
      | reject_suggestion_edits | {"suggestion_id": 1}                          |
      | reject_suggestion_edits | {"suggestion_id": 1, "edit_ids": [999999]}    |

  Scenario: accept_suggestion_edits refuses a published post and leaves it alone
    Given a published post that reads "teh cat sat"
    And the suggested edits for post 1:
      | original | replacement |
      | teh      | the         |
    When I call the MCP tool "accept_suggestion_edits" with:
      """
      {"suggestion_id": 1}
      """
    Then the MCP tool refuses with "the blog post under suggestion 1 is published; its edits can no longer apply"
    And post 1 reads "teh cat sat"
    And the edits on post 1 stand as "pending"

  Scenario: accept_suggestion_edits writes into a scheduled post
    Given a scheduled post that reads "teh cat sat"
    And the suggested edits for post 1:
      | original | replacement |
      | teh      | the         |
    When I call the MCP tool "accept_suggestion_edits" with:
      """
      {"suggestion_id": 1}
      """
    Then post 1 reads "the cat sat"

  Scenario: accept_suggestion_edits refuses when no pending edit is left
    Given a draft post that reads "teh cat sat"
    And the suggested edits for post 1:
      | original | replacement | status   |
      | teh      | the         | rejected |
    When I call the MCP tool "accept_suggestion_edits" with:
      """
      {"suggestion_id": 1}
      """
    Then the MCP tool refuses with "suggestion 1 has no pending edit with those IDs"

  Scenario Outline: A suggestion tool calls an unknown ID an error
    When I call the MCP tool "<tool>" with:
      """
      {"suggestion_id": 999999}
      """
    Then the MCP tool refuses with "no suggestion has the ID 999999"

    Examples:
      | tool                    |
      | accept_suggestion_edits |
      | reject_suggestion_edits |

  Scenario: reject_suggestion_edits rejects every open edit and leaves the post alone
    Given a draft post that reads "teh cat sta"
    And the suggested edits for post 1:
      | original | replacement |
      | teh      | the         |
      | sta      | sat         |
    When I call the MCP tool "reject_suggestion_edits" with:
      """
      {"suggestion_id": 1}
      """
    Then the edits on post 1 stand as "rejected rejected"
    And post 1 reads "teh cat sta"

  Scenario: reject_suggestion_edits rejects only the edits it names and says which
    Given a draft post that reads "teh cat sta"
    And the suggested edits for post 1:
      | original | replacement |
      | teh      | the         |
      | sta      | sat         |
    When I call the MCP tool "reject_suggestion_edits" with:
      """
      {"suggestion_id": 1, "edit_ids": [2]}
      """
    Then the MCP answer holds:
      """
      {"suggestion_id": 1, "rejected": [2]}
      """
    And the edits on post 1 stand as "pending rejected"

  Scenario: reject_suggestion_edits refuses when no open edit matches
    Given a draft post that reads "teh cat sat"
    And the suggested edits for post 1:
      | original | replacement |
      | teh      | the         |
    When I call the MCP tool "reject_suggestion_edits" with:
      """
      {"suggestion_id": 1, "edit_ids": [999999]}
      """
    Then the MCP tool refuses with "suggestion 1 has no open edit with those IDs"
