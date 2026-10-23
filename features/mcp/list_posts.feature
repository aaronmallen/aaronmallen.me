Feature: MCP list_posts
  list_posts lists blog posts in every status, over a range of days, and the social posts still to go out.

  Background:
    Given an MCP client connected with the scopes "read"

  Scenario: Blog posts in every status list with their ID, slug, tags, title, status, times, words and readership
    Given the draft post "A draft" with the body "" as "draft"
    And the scheduled post "scheduled" with the body "Soon" as "scheduled"
    And the published post "published" with the body "Out" as "published"
    When I call the MCP tool "list_posts"
    Then the listed posts' draft marks read "A draft true, scheduled false, published false"
    And the listed post "A draft" is:
      """
      { "id": {draft}, "draft": true, "published_at": null, "slug": "a-draft", "status": "draft", "tags": [], "title": "A draft",
        "word_count": 1, "views": 0, "visitors": 0, "readers": 0, "read_throughs": 0, "webmentions_received": 0 }
      """
    And the listed post "published" carries the time it went out

  Scenario: Each blog post lists its tags
    Given the draft post "Tagged" with the body "Words" as "post"
    And the post "Tagged" carries the tag "ruby" kept as "ruby"
    And the post "Tagged" carries the tag "web" kept as "web"
    When I call the MCP tool "list_posts"
    Then the MCP tool answer at "posts.0.tags" is '["ruby", "web"]'

  Scenario: Over a range of days it keeps the posts whose publish time falls inside, both days whole in Chicago
    Given the published post "before" published 10 days ago at "12:00"
    And the published post "inside" published 5 days ago at "12:00"
    And the published post "after" published 1 days ago at "12:00"
    And the published post "first thing" published 6 days ago at "00:00"
    And the published post "last thing" published 4 days ago at "23:00"
    When I call the MCP tool "list_posts" over the days 6 to 4 days ago
    Then the listed posts are "last thing, inside, first thing"

  Scenario: A from alone reads every day from then on, a to alone every day up to then
    Given the published post "old" published 10 days ago at "12:00"
    And the published post "new" published 2 days ago at "12:00"
    And the scheduled post "queued" published -3 days ago at "12:00"
    When I call the MCP tool "list_posts" from 3 days ago
    Then the listed posts are "queued, new"
    When I call the MCP tool "list_posts" up to 3 days ago
    Then the listed posts are "old"

  Scenario: A range drops a draft with no publish time, keeps a dated one, and leaves the social posts alone
    Given the draft post "undated" with the body "" as "undated"
    And the draft post "dated draft" published 2 days ago at "12:00"
    And the draft social post with the parts '["a draft"]' as "social"
    When I call the MCP tool "list_posts" from 3 days ago
    Then the listed posts are "dated draft"
    And the MCP tool answer at "social_posts" holds 1 item

  Scenario Outline: A range that is <what> is refused
    When I call the MCP tool "list_posts" with:
      """
      <arguments>
      """
    Then the MCP tool refuses with "<says>"

    Examples:
      | what                 | arguments                                     | says                                          |
      | a day it cannot read | { "from": "last tuesday" }                    | give from and to as days, such as 2026-01-01 |
      | a from after its to  | { "from": "2026-10-08", "to": "2026-10-01" }  | from comes after to                           |

  Scenario: Social posts that are drafts or scheduled list, and those already sent stay out
    Given the draft social post with the parts '["a draft"]' as "draft"
    And the scheduled social post with the parts '["queued up"]' as "scheduled"
    And the posted social post with the parts '["gone out"]' as "posted"
    When I call the MCP tool "list_posts"
    Then the listed social posts' statuses are "draft, scheduled"

  Scenario Outline: A social post previews <what>
    Given the draft social post with the parts '<parts>' as "social"
    When I call the MCP tool "list_posts"
    Then the MCP tool answer at "social_posts.0.preview" is '"<preview>"'

    Examples:
      | what                                   | parts                                                                                                                                   | preview |
      | its first part                         | ["first part", "second part"]                                                                                                           | first part |
      | nothing when it has no parts           |                                                                                                                                         |         |
      | a long part cut short                  | ["aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"] | aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa… |
      | one line                               | ["  Hello\\n\\n  wide   world  "]                                                                                                       | Hello wide world |
      | no trailing space before the mark      | ["aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa bbb"]      | aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa… |
      | a family emoji whole where it cuts     | ["aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa👩‍👩‍👧‍👦 x"]       | aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa👩‍👩‍👧‍👦… |
