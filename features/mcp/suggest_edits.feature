Feature: MCP suggest_edits
  An agent suggests edits to a draft or scheduled post or an unsent social post, and the body stays as it was.

  Background:
    Given an MCP client connected with the scopes "read suggest"
    And the draft post "Draft" with the body "teh cat sat" as "post"

  Scenario: Edits to a draft are stored pending with what each says, counted back, and the body stays
    When I call the MCP tool "suggest_edits" with:
      """
      { "target": "post", "id": {post}, "edits": [{ "original": "teh", "replacement": "the", "reason": "typo", "part": 4 }] }
      """
    Then the MCP answer holds:
      """
      { "edits": 1, "status": "pending", "target": "post" }
      """
    And the suggested edits are "pending teh the typo"
    And the database answers "teh cat sat" for:
      """
      SELECT body FROM posts
      """

  Scenario: A later call replaces the edits still waiting and leaves an answered one alone
    When I call the MCP tool "suggest_edits" with:
      """
      { "target": "post", "id": {post}, "edits": [{ "original": "teh", "replacement": "the", "reason": "typo" }] }
      """
    And the edit "teh" is accepted
    And I call the MCP tool "suggest_edits" with:
      """
      { "target": "post", "id": {post}, "edits": [{ "original": "sat", "replacement": "slept", "reason": "typo" }] }
      """
    Then the suggested edits are "accepted teh the typo, pending sat slept typo"
    When I call the MCP tool "suggest_edits" with:
      """
      { "target": "post", "id": {post}, "edits": [{ "original": "cat", "replacement": "dog", "reason": "typo" }] }
      """
    Then the suggested edits are "accepted teh the typo, pending cat dog typo"

  Scenario: Edits to an unsent social post keep their part, take the first part when none is named, and leave the parts alone
    Given the draft social post with the parts '["teh first", "teh second"]' as "social"
    When I call the MCP tool "suggest_edits" with:
      """
      { "target": "social_post", "id": {social}, "edits": [{ "original": "teh", "replacement": "the", "reason": "typo", "part": 2 },
                                                            { "original": "teh", "replacement": "the", "reason": "typo" }] }
      """
    Then the database answers "2, 1" for:
      """
      SELECT string_agg(part::text, ', ' ORDER BY position) FROM suggestion_edits
      """
    And the database answers "teh first, teh second" for:
      """
      SELECT string_agg(body, ', ' ORDER BY position) FROM social_post_parts
      """

  Scenario: A scheduled blog post takes edits
    Given the scheduled post "Soon" with the body "teh cat sat" as "soon"
    When I call the MCP tool "suggest_edits" with:
      """
      { "target": "post", "id": {soon}, "edits": [{ "original": "teh", "replacement": "the", "reason": "typo" }] }
      """
    Then the suggested edits are "pending teh the typo"

  Scenario Outline: suggest_edits refuses <what>, says so as a tool error and stores nothing
    Given the published post "Out" with the body "teh cat sat" as "published"
    And the posted social post with the parts '["gone out"]' as "sent"
    And the draft social post with the parts '["teh first"]' as "social"
    When I call the MCP tool "suggest_edits" with:
      """
      <arguments>
      """
    Then the MCP tool refuses
    And the MCP tool's words hold "<says>"
    And the table suggestion_edits holds 0 rows

    Examples:
      | what                                   | arguments                                                                                                                       | says |
      | an unknown blog post                   | { "target": "post", "id": 999999, "edits": [{ "original": "teh", "replacement": "the", "reason": "typo" }] }                    | no blog post has the ID 999999 |
      | a published blog post                  | { "target": "post", "id": {published}, "edits": [{ "original": "teh", "replacement": "the", "reason": "typo" }] }               | blog post {published} is published; suggest edits only on a draft or scheduled post |
      | an unknown social post                 | { "target": "social_post", "id": 999999, "edits": [{ "original": "teh", "replacement": "the", "reason": "typo" }] }             | no unsent social post has the ID 999999 |
      | a social post already sent             | { "target": "social_post", "id": {sent}, "edits": [{ "original": "teh", "replacement": "the", "reason": "typo" }] }             | |
      | an empty edit list                     | { "target": "post", "id": {post}, "edits": [] }                                                                                 | give at least one edit |
      | a part the social post has not got     | { "target": "social_post", "id": {social}, "edits": [{ "original": "teh", "replacement": "the", "reason": "typo", "part": 3 }] } | social post {social} has no part 3 |
      | a target it does not know              | { "target": "journal_entry", "id": {post}, "edits": [{ "original": "teh", "replacement": "the", "reason": "typo" }] }           | |
      | an edit with a property it does not know | { "target": "post", "id": {post}, "edits": [{ "original": "teh", "replacement": "the", "reason": "typo", "note": "by the way" }] } | |
      | an edit with no reason                 | { "target": "post", "id": {post}, "edits": [{ "original": "teh", "replacement": "the" }] }                                      | |
      | an original of nothing but space       | { "target": "post", "id": {post}, "edits": [{ "original": "   ", "replacement": "the", "reason": "typo" }] }                   | edit 1: original needs a character that is not a space |
      | a reason of nothing but space          | { "target": "post", "id": {post}, "edits": [{ "original": "teh", "replacement": "the", "reason": " " }] }                      | edit 1: reason needs a character that is not a space |
      | an original of Unicode spaces          | { "target": "post", "id": {post}, "edits": [{ "original": " 　", "replacement": "the", "reason": "typo" }] }          | edit 1: original needs a character that is not a space |
      | a reason of Unicode spaces             | { "target": "post", "id": {post}, "edits": [{ "original": "teh", "replacement": "the", "reason": " 　" }] }            | edit 1: reason needs a character that is not a space |
      | a second edit with a blank reason      | { "target": "post", "id": {post}, "edits": [{ "original": "teh", "replacement": "the", "reason": "typo" }, { "original": "teh", "replacement": "the", "reason": "\t" }] } | edit 2: reason needs a character that is not a space |
      | an original holding a NUL              | { "target": "post", "id": {post}, "edits": [{ "original": "t\u0000he", "replacement": "the", "reason": "typo" }] }              | edit 1: original holds a control character |
      | a reason holding a NUL                 | { "target": "post", "id": {post}, "edits": [{ "original": "teh", "replacement": "the", "reason": "t\u0000he" }] }               | edit 1: reason holds a control character |
      | a replacement holding a NUL            | { "target": "post", "id": {post}, "edits": [{ "original": "teh", "replacement": "t\u0000he", "reason": "typo" }] }              | edit 1: replacement holds a control character |
      | a social post edit of nothing but space | { "target": "social_post", "id": {social}, "edits": [{ "original": "teh", "replacement": "the", "reason": "  " }] }            | edit 1: reason needs a character that is not a space |
      | a reason longer than the ceiling       | { "target": "post", "id": {post}, "edits": [{ "original": "teh", "replacement": "the", "reason": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" }] } | |

  Scenario: A blank original is a tool error, not an internal one, and keeps the edits an earlier call stored
    When I call the MCP tool "suggest_edits" with:
      """
      { "target": "post", "id": {post}, "edits": [{ "original": "teh", "replacement": "the", "reason": "typo" }] }
      """
    And I call the MCP tool "suggest_edits" with:
      """
      { "target": "post", "id": {post}, "edits": [{ "original": "  ", "replacement": "the", "reason": "typo" }] }
      """
    Then the MCP tool refuses
    And the MCP reply has no error
    And the suggested edits are "pending teh the typo"

  Scenario: More edits than one call may carry are refused, naming the ceiling, and nothing is stored
    When I call the MCP tool "suggest_edits" with 51 typo edits to the post "{post}"
    Then the MCP tool refuses
    And the MCP tool's words hold "50"
    And the table suggestion_edits holds 0 rows
