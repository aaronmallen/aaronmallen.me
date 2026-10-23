Feature: MCP endpoint
  The MCP endpoint takes a bearer access token bound to this server, speaks JSON-RPC one message at a time and offers
  the tools and prompts the token's scopes allow.

  Scenario: A request with no token is refused and pointed at the resource metadata it serves
    When I ask MCP for "tools/list" with no token
    Then the answer is 401
    And the answer has the header "WWW-Authenticate" set to "Bearer resource_metadata=\"SITE/.well-known/oauth-protected-resource/mcp\""
    And the answer has the header "Access-Control-Expose-Headers" set to "WWW-Authenticate"
    And the API answer at "error_description" is '"this endpoint takes a bearer access token"'
    When I send GET "/.well-known/oauth-protected-resource/mcp"
    Then the API answer at "resource" is '"SITE/mcp"'

  Scenario: A request whose Host somebody else picked still points at the configured metadata
    When I ask MCP for "tools/list" with no token and the forwarded host "evil.example"
    Then the answer has the header "WWW-Authenticate" holding "resource_metadata=\"SITE/.well-known/oauth-protected-resource/mcp\""
    And the answer's header "WWW-Authenticate" does not hold "evil.example"

  Scenario: A token it never issued is refused, naming the token, and pointing at the metadata
    When I ask MCP for "tools/list" with the authorization "Bearer never-issued-token-that-is-long-enough-to-read"
    Then the answer is 401
    And the API answer at "error" is '"invalid_token"'
    And the answer has the header "WWW-Authenticate" holding "resource_metadata=\"SITE/.well-known/oauth-protected-resource/mcp\""

  Scenario Outline: A token is refused when <what>
    Given an MCP client connected with the scopes "read"
    And <setup>
    When I ask MCP for "tools/list" with the authorization "<authorization>"
    Then the answer is 401

    Examples:
      | what                                    | setup                                                                                          | authorization      |
      | it comes in a scheme it does not take   | nothing more                                                                                   | Basic {access}     |
      | it is a refresh token                   | nothing more                                                                                   | Bearer {refresh}   |
      | it expired                              | the database runs "UPDATE oauth_tokens SET expires_at = now() - interval '1 second' WHERE type = 'access'" | Bearer {access} |
      | it was revoked                          | the database runs "UPDATE oauth_tokens SET revoked_at = now() WHERE type = 'access'"           | Bearer {access}    |
      | it was issued for another resource      | the database runs "UPDATE oauth_tokens SET resource = 'https://elsewhere.example/mcp' WHERE type = 'access'" | Bearer {access} |
      | it is bound to no resource              | the database runs "UPDATE oauth_tokens SET resource = NULL WHERE type = 'access'"              | Bearer {access}    |
      | the owner revoked it from the admin     | the owner revokes every MCP client from the admin                                              | Bearer {access}    |

  Scenario: A refresh retires the access token it was issued with, answers the new one, and keeps another pair working
    Given an MCP client connected with the scopes "read"
    And the MCP client connects a second pair
    When the MCP client spends its refresh token
    And I ask MCP for "tools/list" with the authorization "Bearer {access}"
    Then the answer is 401
    When I ask MCP for "tools/list" with the authorization "Bearer {newaccess}"
    Then the answer is 200
    When I ask MCP for "tools/list" with the authorization "Bearer {secondaccess}"
    Then the answer is 200

  Scenario: A client that names no resource is still answered, bound to this server
    Given an MCP client connected with "read" naming no resource
    When I ask MCP for "tools/list"
    Then the answer is 200
    And the database answers "SITE/mcp" for:
      """
      SELECT resource FROM oauth_tokens WHERE type = 'access'
      """

  Scenario: initialize names the server, its version and title, and tells the client what each permission grants
    Given an MCP client connected with the scopes "read"
    When I ask MCP for "initialize" with:
      """
      { "protocolVersion": "2025-06-18", "capabilities": {}, "clientInfo": { "name": "Claude", "version": "1" } }
      """
    Then the MCP reply at "result.serverInfo.name" is '"127.0.0.1"'
    And the MCP reply at "result.serverInfo.title" is:
      """
      "Aaron Allen's site"
      """
    And the MCP server reports the version git describes
    And the MCP instructions hold "Read everything"
    And the MCP instructions hold "Make any change the admin makes"
    And the MCP instructions hold "publish grants publishing posts and sending social posts, and every change that shows in public"
    And the MCP instructions hold "Delete grants every tool that removes a record for good"
    And the MCP instructions hold "accept_suggestion_edits"
    And the MCP instructions hold "reject_suggestion_edits"
    And the MCP instructions name each of these kinds:
      | compose_announcement     | announcements |
      | list_api_tokens          | API tokens |
      | list_attention           | attention |
      | list_calendar            | the calendar |
      | list_clients             | MCP clients |
      | list_commits             | commits |
      | list_decisions           | decisions |
      | list_inbox               | the inbox |
      | list_journal_entries     | the journal |
      | list_links               | record links |
      | list_people              | people |
      | list_posts               | posts |
      | list_projects            | projects |
      | list_pull_requests       | pull requests |
      | list_saved_views         | saved views |
      | list_share_groups        | shares |
      | list_shares              | shares |
      | list_short_links         | short links |
      | list_social_posts        | social posts |
      | list_sprints             | sprints |
      | list_suggestions         | suggestions |
      | list_tags                | tags |
      | list_task_rules          | task rules |
      | list_task_series         | tasks |
      | list_tasks               | tasks |
      | list_trusted_authors     | trusted webmention authors |
      | list_webmentions         | webmentions |
      | list_work_entries        | work history |
      | read_activity            | activity feed |
      | read_analytics           | analytics |
      | read_commit              | commits |
      | read_current_sprint      | sprints |
      | read_decision            | decisions |
      | read_journal_entry       | the journal |
      | read_performance         | performance timing |
      | read_person              | people |
      | read_photo               | photos |
      | read_post                | posts |
      | read_project             | projects |
      | read_pull_request        | pull requests |
      | read_review              | the review |
      | read_saved_view          | saved views |
      | read_share               | shares |
      | read_share_group         | shares |
      | read_social_post         | social posts |
      | read_sync_state          | the sync state |
      | read_tag                 | tags |
      | read_task                | tasks |
      | read_time_report         | the time report |
      | read_webmention          | webmentions |
      | read_webmention_settings | webmentions and their settings |
      | read_work_entry          | work history |
      | search                   | Search every kind |
      | search_accounts          | accounts on Mastodon and Bluesky |
      | summarize_activity       | activity feed |

  Scenario: The transport takes a notification, answers JSON, answers only to POST and calls a broken batch a parse error
    Given an MCP client connected with the scopes "read"
    When I send MCP a notification "notifications/initialized"
    Then the answer is 202
    When I ask MCP for "tools/list"
    Then the answer has the header "Content-Type" set to "application/json"
    When I post the bare body "[not json" to MCP
    Then the MCP error code is -32700
    When I send GET "/mcp"
    Then the answer is 405

  Scenario Outline: A batch is refused as an invalid request and runs none of its tools, when <what>
    Given an MCP client connected with the scopes "read write publish"
    And the published post "Hello" with the body "First" as "post"
    When I post the body '<body>' to MCP
    Then the MCP error code is -32600
    And the database answers "" for:
      """
      SELECT og_title FROM posts
      """

    Examples:
      | what                       | body                                                                                                                                                                                                                         |
      | it holds two tool calls    | [{"jsonrpc": "2.0", "id": 1, "method": "tools/call", "params": {"name": "write_post_seo", "arguments": {"id": 1, "og_title": "First"}}}, {"jsonrpc": "2.0", "id": 2, "method": "tools/call", "params": {"name": "write_post_seo", "arguments": {"id": 1, "og_title": "Second"}}}] |
      | it holds one               | [{"jsonrpc": "2.0", "id": 1, "method": "tools/call", "params": {"name": "write_post_seo", "arguments": {"id": 1, "og_title": "First"}}}] |
      | it opens with blank space  | \r\n\t[{"jsonrpc": "2.0", "id": 1, "method": "tools/call", "params": {"name": "write_post_seo", "arguments": {"id": 1, "og_title": "First"}}}] |
      | it is empty                | []                                                                                                                                                                                                                           |

  Scenario: search names a read tool for every kind it finds
    Given an MCP client connected with the scopes "read mail notes"
    When I ask MCP for "tools/list"
    Then every read tool search names for a kind is a tool it offers

  Scenario: A token that may only read is offered the reading tools and nothing else
    Given an MCP client connected with the scopes "read"
    When I ask MCP for "tools/list"
    Then the MCP tools offered are:
      | compose_announcement     |
      | list_api_tokens          |
      | list_attention           |
      | list_calendar            |
      | list_clients             |
      | list_commits             |
      | list_decisions           |
      | list_inbox               |
      | list_journal_entries     |
      | list_links               |
      | list_people              |
      | list_posts               |
      | list_projects            |
      | list_pull_requests       |
      | list_saved_views         |
      | list_share_groups        |
      | list_shares              |
      | list_short_links         |
      | list_social_posts        |
      | list_sprints             |
      | list_suggestions         |
      | list_tags                |
      | list_task_rules          |
      | list_task_series         |
      | list_tasks               |
      | list_trusted_authors     |
      | list_webmentions         |
      | list_work_entries        |
      | read_activity            |
      | read_analytics           |
      | read_commit              |
      | read_current_sprint      |
      | read_decision            |
      | read_journal_entry       |
      | read_performance         |
      | read_person              |
      | read_photo               |
      | read_post                |
      | read_project             |
      | read_pull_request        |
      | read_review              |
      | read_saved_view          |
      | read_share               |
      | read_share_group         |
      | read_social_post         |
      | read_sync_state          |
      | read_tag                 |
      | read_task                |
      | read_time_report         |
      | read_webmention          |
      | read_webmention_settings |
      | read_work_entry          |
      | search                   |
      | search_accounts          |
      | summarize_activity       |

  Scenario: A token that may only read still reads posts, decisions and the activity feed and summary
    Given an MCP client connected with the scopes "read"
    And the published post "Hello" with the body "First" as "post"
    And the owner calls POST "decisions" with:
      """
      { "title": "Pick a queue", "problem": "Jobs pile up" }
      """
    And I keep the answer's "id" as "decision"
    When I call the MCP tool "read_post" with:
      """
      { "id": {post} }
      """
    Then the MCP tool answer at "id" is "{post}"
    When I call the MCP tool "list_decisions"
    Then the MCP tool answer at "decisions" matches:
      """
      [{ "id": {decision} }]
      """
    When I call the MCP tool "read_decision" with:
      """
      { "id": {decision} }
      """
    Then the MCP tool answer at "id" is "{decision}"
    When I call the MCP tool "read_activity" with:
      """
      { "from": "2026-01-01", "to": "2026-12-31" }
      """
    Then the MCP answer holds:
      """
      { "from": "2026-01-01", "to": "2026-12-31" }
      """
    When I call the MCP tool "summarize_activity" with:
      """
      { "from": "2026-01-01", "to": "2026-12-31" }
      """
    Then the MCP answer holds:
      """
      { "from": "2026-01-01", "to": "2026-12-31" }
      """

  Scenario: A token that may only read is refused the social card write as an MCP error, and nothing is stored
    Given an MCP client connected with the scopes "read"
    And the published post "Hello" with the body "First" as "post"
    When I call the MCP tool "write_post_seo" with:
      """
      { "id": {post}, "og_title": "On the card" }
      """
    Then the answer is 200
    And the MCP error code is -32602
    And the database answers "" for:
      """
      SELECT og_title FROM posts
      """
    When I call the MCP tool "suggest_edits" with:
      """
      { "target": "post", "id": {post}, "edits": [{ "original": "teh", "replacement": "the", "reason": "typo" }] }
      """
    Then the table suggestions holds 0 rows

  Scenario: A token that may read and suggest is offered suggest_edits and stores a suggestion
    Given an MCP client connected with the scopes "read suggest"
    And the draft post "Draft" with the body "teh cat sat" as "post"
    When I ask MCP for "tools/list"
    Then the MCP tools offered are:
      | compose_announcement     |
      | list_api_tokens          |
      | list_attention           |
      | list_calendar            |
      | list_clients             |
      | list_commits             |
      | list_decisions           |
      | list_inbox               |
      | list_journal_entries     |
      | list_links               |
      | list_people              |
      | list_posts               |
      | list_projects            |
      | list_pull_requests       |
      | list_saved_views         |
      | list_share_groups        |
      | list_shares              |
      | list_short_links         |
      | list_social_posts        |
      | list_sprints             |
      | list_suggestions         |
      | list_tags                |
      | list_task_rules          |
      | list_task_series         |
      | list_tasks               |
      | list_trusted_authors     |
      | list_webmentions         |
      | list_work_entries        |
      | read_activity            |
      | read_analytics           |
      | read_commit              |
      | read_current_sprint      |
      | read_decision            |
      | read_journal_entry       |
      | read_performance         |
      | read_person              |
      | read_photo               |
      | read_post                |
      | read_project             |
      | read_pull_request        |
      | read_review              |
      | read_saved_view          |
      | read_share               |
      | read_share_group         |
      | read_social_post         |
      | read_sync_state          |
      | read_tag                 |
      | read_task                |
      | read_time_report         |
      | read_webmention          |
      | read_webmention_settings |
      | read_work_entry          |
      | search                   |
      | search_accounts          |
      | summarize_activity       |
      | suggest_edits |
    When I call the MCP tool "suggest_edits" with:
      """
      { "target": "post", "id": {post}, "edits": [{ "original": "teh", "replacement": "the", "reason": "typo" }] }
      """
    Then the table suggestion_edits holds 1 row

  Scenario: A token issued before a scope was stored carries reading alone and must connect again to write
    Given an MCP client connected with the scopes "read write publish"
    And the published post "Hello" with the body "First" as "post"
    And the database runs "UPDATE oauth_tokens SET scopes = DEFAULT WHERE type = 'access'"
    Then the database answers "read" for:
      """
      SELECT array_to_string(scopes, ' ') FROM oauth_tokens WHERE type = 'access'
      """
    When I ask MCP for "tools/list"
    Then the MCP tools offered are:
      | compose_announcement     |
      | list_api_tokens          |
      | list_attention           |
      | list_calendar            |
      | list_clients             |
      | list_commits             |
      | list_decisions           |
      | list_inbox               |
      | list_journal_entries     |
      | list_links               |
      | list_people              |
      | list_posts               |
      | list_projects            |
      | list_pull_requests       |
      | list_saved_views         |
      | list_share_groups        |
      | list_shares              |
      | list_short_links         |
      | list_social_posts        |
      | list_sprints             |
      | list_suggestions         |
      | list_tags                |
      | list_task_rules          |
      | list_task_series         |
      | list_tasks               |
      | list_trusted_authors     |
      | list_webmentions         |
      | list_work_entries        |
      | read_activity            |
      | read_analytics           |
      | read_commit              |
      | read_current_sprint      |
      | read_decision            |
      | read_journal_entry       |
      | read_performance         |
      | read_person              |
      | read_photo               |
      | read_post                |
      | read_project             |
      | read_pull_request        |
      | read_review              |
      | read_saved_view          |
      | read_share               |
      | read_share_group         |
      | read_social_post         |
      | read_sync_state          |
      | read_tag                 |
      | read_task                |
      | read_time_report         |
      | read_webmention          |
      | read_webmention_settings |
      | read_work_entry          |
      | search                   |
      | search_accounts          |
      | summarize_activity       |
    When I call the MCP tool "write_post_seo" with:
      """
      { "id": {post}, "og_title": "On the card" }
      """
    Then the MCP reply at "error.data" holds "Connect the app again"
    And the database answers "" for:
      """
      SELECT og_title FROM posts
      """

  Scenario: The prompts it offers are proofreading and a report, and nothing else
    Given an MCP client connected with the scopes "read"
    When I ask MCP for "prompts/list"
    Then the MCP reply at "result.prompts" names "proofread, report"

  Scenario: proofread asks, as the user, for grammar, spelling and punctuation fixes sent back through suggest_edits
    Given an MCP client connected with the scopes "read"
    When I ask MCP for "prompts/get" with:
      """
      { "name": "proofread", "arguments": { "target": "post", "id": "12" } }
      """
    Then the MCP reply at "result.description" is '"Proofread blog post 12"'
    And the MCP reply at "result.messages.0.role" is '"user"'
    And the prompt holds "Call read_post with the ID 12 and read its markdown body"
    And the prompt holds "suggest_edits, with the target \"post\" and the ID 12."
    And the prompt holds "Fix grammar, spelling and punctuation, and nothing else"
    And the prompt holds "Leave the style, the tone, the word choice and the structure as they stand"
    And the prompt holds "Skip code blocks, inline code and link targets"
    And the prompt holds "the original text copied from the body exactly as it stands"
    And the prompt holds "a reason of a few words, such as \"typo\" or \"subject-verb agreement\""

  Scenario: proofread reads a social post by its parts and numbers each fix's part
    Given an MCP client connected with the scopes "read"
    When I ask MCP for "prompts/get" with:
      """
      { "name": "proofread", "arguments": { "target": "social_post", "id": "12" } }
      """
    Then the MCP reply at "result.description" is '"Proofread social post 12"'
    And the prompt holds "Call read_social_post with the ID 12 and read its parts in order"
    And the prompt holds "Give each fix the number of the part it belongs to, counting from 1"

  Scenario Outline: proofread refuses <what>
    Given an MCP client connected with the scopes "read"
    When I ask MCP for "prompts/get" with:
      """
      { "name": "proofread", "arguments": <arguments> }
      """
    Then the MCP error code is -32602
    And the MCP reply at "error.message" holds "<says>"

    Examples:
      | what                       | arguments                                 | says                            |
      | a target it does not know  | { "target": "journal_entry", "id": "12" } | target takes post or social_post |
      | an ID that is not a number | { "target": "post", "id": "twelve" }      |                                 |
      | a call with no ID          | { "target": "post" }                      |                                 |

  Scenario: report asks for the summary, then the feed paged to the end, then what the feed leaves out
    Given an MCP client connected with the scopes "read mail"
    When I ask MCP for "prompts/get" with:
      """
      { "name": "report", "arguments": { "from": "2026-01-01", "to": "2026-03-31" } }
      """
    Then the MCP reply at "result.description" is '"Report on 2026-01-01 to 2026-03-31"'
    And the MCP reply at "result.messages.0.role" is '"user"'
    And the prompt holds "First call summarize_activity with from 2026-01-01 and to 2026-03-31"
    And the prompt names read_activity after summarize_activity
    And the prompt holds "continue_to as to, and keep going until partial comes back false"
    And the prompt names the tools "list_tasks, list_projects, read_analytics, list_mail_threads"
    And the prompt holds "list_tasks with the statuses open and in_progress"
    And the prompt holds "list_tasks with the status canceled, window_by closed and from 2026-01-01 and to 2026-03-31"
    And the prompt holds "report them apart from the done ones"
    And the prompt holds "The tools only hand back data, so the report is yours to write"
    And every tool the prompt names is a tool the server offers

  Scenario: report's call for canceled tasks finds only the tasks canceled in the range
    Given an MCP client connected with the scopes "read mail"
    And the table tasks holds:
      | title         | list | position | status   | created_at                            | completed_at                          |
      | dropped       | next | 1        | canceled | (TIMESTAMPTZ '2026-01-05 00:00:00+00') | (TIMESTAMPTZ '2026-02-10 00:00:00+00') |
      | dropped later | next | 2        | canceled | (TIMESTAMPTZ '2026-02-10 00:00:00+00') | (TIMESTAMPTZ '2026-04-05 00:00:00+00') |
    When I call the MCP tool "list_tasks" with:
      """
      { "statuses": ["canceled"], "window_by": "closed", "from": "2026-01-01", "to": "2026-03-31" }
      """
    Then the MCP tool answer's task titles are "dropped"

  Scenario Outline: report <does>
    Given an MCP client connected with the scopes "read mail"
    When I ask MCP for "prompts/get" with:
      """
      { "name": "report", "arguments": <arguments> }
      """
    Then <outcome>

    Examples:
      | does                                 | arguments                                     | outcome                                                                  |
      | refuses a day it cannot read         | { "from": "January", "to": "2026-03-31" }     | the MCP error code is -32602                                             |
      | refuses a start after the end        | { "from": "2026-04-01", "to": "2026-03-31" }  | the MCP reply at "error.data" holds "from comes after to"               |
      | refuses a range longer than 366 days | { "from": "2024-01-01", "to": "2025-01-01" }  | the MCP reply at "error.data" holds "give a range of 366 days or fewer" |
      | reports on a range of 366 days       | { "from": "2024-01-01", "to": "2024-12-31" }  | the MCP reply at "result.description" is '"Report on 2024-01-01 to 2024-12-31"' |
      | refuses a call with no end           | { "from": "2026-01-01" }                      | the MCP error code is -32602                                             |

  Scenario: write_post_seo sets the card fields it takes, keeps the rest, clears an empty one and answers what the post carries
    Given an MCP client connected with the scopes "read write publish"
    And the published post "Hello" with the body "First" as "post"
    And I keep the row of the post "{post}"
    When I call the MCP tool "write_post_seo" with:
      """
      { "id": {post}, "og_title": "On the card", "og_image_url": "https://e.example/c.png" }
      """
    Then the database answers "On the card, https://e.example/c.png" for:
      """
      SELECT og_title, og_image_url FROM posts
      """
    When I call the MCP tool "write_post_seo" with:
      """
      { "id": {post}, "og_image_url": "https://example.com/card.png" }
      """
    Then the database answers "On the card" for:
      """
      SELECT og_title FROM posts
      """
    When I call the MCP tool "write_post_seo" with:
      """
      { "id": {post}, "og_title": "" }
      """
    Then the database answers "true" for:
      """
      SELECT og_title IS NULL OR og_title = '' FROM posts
      """
    When I call the MCP tool "write_post_seo" with:
      """
      { "id": {post}, "og_title": "On the card" }
      """
    Then the MCP answer holds:
      """
      { "id": {post}, "canonical_url": null, "og_image_url": "https://example.com/card.png", "og_title": "On the card" }
      """
    And the post "{post}" changed nothing but its card and its time since it was kept

  Scenario: write_post_seo offers no canonical URL and names it back when a client sends one anyway
    Given an MCP client connected with the scopes "read write publish"
    And the published post "Hello" with the body "First" as "post"
    When I ask MCP for "tools/list"
    Then the input schema of "write_post_seo" takes only "id, og_image_url, og_title"
    When I call the MCP tool "write_post_seo" with:
      """
      { "id": {post}, "canonical_url": "https://elsewhere.example/hello" }
      """
    Then the MCP tool's words hold "canonical_url"
    And the database answers "true" for:
      """
      SELECT canonical_url IS NULL OR canonical_url = '' FROM posts
      """

  Scenario Outline: write_post_seo refuses <what> and leaves the post alone
    Given an MCP client connected with the scopes "read write publish"
    And the published post "Hello" with the body "First" as "post"
    When I call the MCP tool "write_post_seo" with:
      """
      <arguments>
      """
    Then the MCP tool refuses
    And the MCP tool's words hold "<says>"
    And the database answers "true" for:
      """
      SELECT og_title IS NULL OR og_title = '' FROM posts
      """

    Examples:
      | what                       | arguments                                                         | says                                |
      | an image that is not a URL | { "id": {post}, "og_image_url": "card.png" }                      | og_image_url                        |
      | a card title holding a NUL | { "id": {post}, "og_title": "On the\u0000card" }                  | og_title holds a control character  |
      | a good title beside a bad image | { "id": {post}, "og_title": "On the card", "og_image_url": "card.png" } | og_image_url               |
      | an unknown ID              | { "id": 999999, "og_title": "On the card" }                       | no blog post has the ID 999999      |
      | a call with no ID          | { "og_title": "On the card" }                                     |                                     |

  Scenario: Reading changes nothing
    Given an MCP client connected with the scopes "read"
    And the draft post "Draft" with the body "teh cat sat" as "post"
    And I keep the row of the post "{post}"
    When I call the MCP tool "read_post" with:
      """
      { "id": {post} }
      """
    Then the post "{post}" changed nothing since it was kept

  Scenario: A call notes when the client last called, again after five minutes, and leaves updated_at alone
    Given an MCP client connected with the scopes "read"
    When I ask MCP for "tools/list"
    Then the database answers "true" for:
      """
      SELECT last_used_at > now() - interval '1 minute' FROM oauth_clients
      """
    Given the database runs "UPDATE oauth_clients SET last_used_at = now() - interval '6 minutes', updated_at = date_trunc('second', now()) - interval '1 day'"
    When I ask MCP for "tools/list"
    Then the database answers "true, true" for:
      """
      SELECT last_used_at > now() - interval '1 minute' AS noted, updated_at < now() - interval '23 hours' AS kept FROM oauth_clients
      """

  Scenario: A call within five minutes of the last leaves the last call alone
    Given an MCP client connected with the scopes "read"
    And the database runs "UPDATE oauth_clients SET last_used_at = date_trunc('second', now()) - interval '4 minutes'"
    When I ask MCP for "tools/list"
    Then the database answers "true" for:
      """
      SELECT last_used_at < now() - interval '3 minutes' FROM oauth_clients
      """

  Scenario Outline: <tool> refuses an argument no tool names rather than raising on it
    Given an MCP client connected with the scopes "read suggest write publish delete health mail agents notes contacts"
    When I call the MCP tool "<tool>" with:
      """
      <arguments>
      """
    Then the MCP tool's words hold "stray"

    Examples:
      | tool                       | arguments |
      | accept_suggestion_edits    | {"suggestion_id": 1, "stray": "x"} |
      | add_decision_comment       | {"id": 1, "body": "Leaning on Sidekiq", "stray": "x"} |
      | add_decision_option        | {"id": 1, "title": "Sidekiq", "stray": "x"} |
      | add_memory_fact            | {"id": 1, "type": "gotcha", "text": "Mind the cache", "agent": "claude-code", "model": "claude-opus-5-5", "stray": "x"} |
      | add_shares_to_group        | {"id": 1, "ids": [2], "stray": "x"} |
      | add_task_comment           | {"id": 1, "body": "Blocked on review", "stray": "x"} |
      | add_work_entry             | {"org": "Acme", "role": "Engineer", "from_year": 2019, "stray": "x"} |
      | add_work_session           | {"id": 1, "started_at": "2026-01-01T09:00", "ended_at": "2026-01-01T10:00", "stray": "x"} |
      | approve_webmentions        | {"ids": [1], "stray": "x"} |
      | archive_project            | {"id": 1, "stray": "x"} |
      | cancel_task                | {"id": 1, "stray": "x"} |
      | cancel_tasks               | {"ids": [1], "stray": "x"} |
      | capture_task               | {"title": "Email the accountant", "stray": "x"} |
      | check_post_links           | {"id": 1, "stray": "x"} |
      | check_short_link           | {"id": 1, "stray": "x"} |
      | clear_inbox                | {"messages": [1], "stray": "x"} |
      | complete_task              | {"id": 1, "stray": "x"} |
      | complete_tasks             | {"ids": [1], "stray": "x"} |
      | compose_announcement       | {"id": 1, "stray": "x"} |
      | create_artifact            | {"title": "Plan", "type": "plan", "body": "Steps", "agent": "claude-code", "model": "claude-opus-5-5", "stray": "x"} |
      | create_event               | {"calendar_id": 1, "title": "Lunch", "date": "2026-01-01", "stray": "x"} |
      | create_journal_entry       | {"body": "Wrote it down", "stray": "x"} |
      | create_memory_file         | {"path": "hanami", "description": "Notes", "scope": "global", "agent": "claude-code", "model": "claude-opus-5-5", "stray": "x"} |
      | create_note                | {"stray": "x"} |
      | create_note_folder         | {"path": "work", "stray": "x"} |
      | create_post                | {"title": "A draft", "stray": "x"} |
      | create_saved_view          | {"name": "Open deploys", "screen": "tasks", "stray": "x"} |
      | create_short_link          | {"destination": "https://example.com", "stray": "x"} |
      | create_social_post         | {"parts": ["Hello"], "targets": ["mastodon"], "stray": "x"} |
      | delete_artifact            | {"id": 1, "stray": "x"} |
      | delete_decision_comment    | {"id": 1, "comment_id": 2, "stray": "x"} |
      | delete_decision_option     | {"id": 1, "option_id": 2, "stray": "x"} |
      | delete_event               | {"id": 1, "stray": "x"} |
      | delete_journal_entry       | {"id": 1, "stray": "x"} |
      | delete_mail_threads        | {"ids": [1], "stray": "x"} |
      | delete_memory_file         | {"id": 1, "stray": "x"} |
      | delete_note                | {"id": 1, "stray": "x"} |
      | describe_memory_file       | {"id": 1, "description": "Notes", "agent": "claude-code", "model": "claude-opus-5-5", "stray": "x"} |
      | delete_person              | {"id": 1, "stray": "x"} |
      | delete_post                | {"id": 1, "stray": "x"} |
      | delete_posts               | {"ids": [1], "stray": "x"} |
      | delete_saved_view          | {"id": 1, "stray": "x"} |
      | delete_share               | {"id": 1, "stray": "x"} |
      | delete_share_group         | {"id": 1, "stray": "x"} |
      | delete_social_post         | {"id": 1, "stray": "x"} |
      | delete_task                | {"id": 1, "stray": "x"} |
      | delete_task_comment        | {"id": 1, "comment_id": 2, "stray": "x"} |
      | delete_task_rule           | {"id": 1, "stray": "x"} |
      | delete_tasks               | {"ids": [1], "stray": "x"} |
      | delete_work_entry          | {"id": 1, "stray": "x"} |
      | delete_work_session        | {"id": 1, "session_id": 2, "stray": "x"} |
      | describe_note_folder       | {"id": 1, "description": "Client work", "stray": "x"} |
      | drop_decision              | {"id": 1, "reason": "Not needed", "stray": "x"} |
      | drop_sprint                | {"id": 1, "stray": "x"} |
      | duplicate_note             | {"id": 1, "stray": "x"} |
      | edit_decision              | {"id": 1, "stray": "x"} |
      | edit_decision_comment      | {"id": 1, "comment_id": 2, "body": "Leaning on Resque", "stray": "x"} |
      | edit_decision_option       | {"id": 1, "option_id": 2, "stray": "x"} |
      | edit_memory_fact           | {"id": 1, "fact_id": 2, "agent": "claude-code", "model": "claude-opus-5-5", "stray": "x"} |
      | edit_event                 | {"id": 1, "stray": "x"} |
      | edit_note                  | {"id": 1, "version": 1, "stray": "x"} |
      | edit_task_comment          | {"id": 1, "comment_id": 2, "body": "Blocked on deploy", "stray": "x"} |
      | end_session                | {"id": 1, "stray": "x"} |
      | group_shares               | {"ids": [1, 2], "stray": "x"} |
      | ignore_webmentions         | {"ids": [1], "stray": "x"} |
      | import_commits             | {"stray": "x"} |
      | link_records               | {"kind": "post", "id": 1, "other_kind": "commit", "other_id": 2, "stray": "x"} |
      | link_tasks                 | {"id": 1, "kind": "blocks", "other_id": 2, "stray": "x"} |
      | list_api_tokens            | {"stray": "x"} |
      | list_artifacts             | {"stray": "x"} |
      | list_attention             | {"stray": "x"} |
      | list_calendar              | {"from": "2026-01-01", "to": "2026-01-31", "stray": "x"} |
      | list_clients               | {"stray": "x"} |
      | list_commits               | {"from": "2026-01-01", "to": "2026-12-31", "stray": "x"} |
      | list_decisions             | {"stray": "x"} |
      | list_inbox                 | {"stray": "x"} |
      | list_journal_entries       | {"from": "2026-01-01", "to": "2026-12-31", "stray": "x"} |
      | list_links                 | {"kind": "post", "id": 1, "stray": "x"} |
      | list_mail_threads          | {"from": "2026-01-01", "to": "2026-12-31", "stray": "x"} |
      | list_note_folders          | {"stray": "x"} |
      | list_notes                 | {"stray": "x"} |
      | list_people                | {"stray": "x"} |
      | list_posts                 | {"stray": "x"} |
      | list_projects              | {"stray": "x"} |
      | list_pull_requests         | {"from": "2026-01-01", "to": "2026-12-31", "stray": "x"} |
      | list_saved_views           | {"stray": "x"} |
      | list_sessions              | {"stray": "x"} |
      | list_share_groups          | {"stray": "x"} |
      | list_shares                | {"stray": "x"} |
      | list_short_links           | {"stray": "x"} |
      | list_social_posts          | {"from": "2026-01-01", "to": "2026-12-31", "stray": "x"} |
      | list_sprints               | {"stray": "x"} |
      | list_suggestions           | {"from": "2026-01-01", "to": "2026-12-31", "stray": "x"} |
      | list_tags                  | {"scope": "public", "stray": "x"} |
      | list_task_rules            | {"stray": "x"} |
      | list_task_series           | {"stray": "x"} |
      | list_tasks                 | {"stray": "x"} |
      | list_trusted_authors       | {"stray": "x"} |
      | list_webmentions           | {"from": "2026-01-01", "to": "2026-12-31", "stray": "x"} |
      | list_work_entries          | {"from": "2026-01-01", "to": "2026-12-31", "stray": "x"} |
      | make_mail_task             | {"id": 1, "title": "Reply", "stray": "x"} |
      | mark_mail_thread           | {"id": 1, "status": "read", "stray": "x"} |
      | mark_mail_threads_read     | {"ids": [1], "stray": "x"} |
      | mark_mail_threads_unread   | {"ids": [1], "stray": "x"} |
      | mark_task_seen             | {"id": 1, "stray": "x"} |
      | mark_webmentions_spam      | {"ids": [1], "stray": "x"} |
      | moderate_webmention        | {"id": 1, "verdict": "spam", "stray": "x"} |
      | move_memory_file           | {"id": 1, "scope": "global", "agent": "claude-code", "model": "claude-opus-5-5", "stray": "x"} |
      | move_event                 | {"id": 1, "to": "2026-01-01", "stray": "x"} |
      | move_note                  | {"id": 1, "folder_id": null, "stray": "x"} |
      | move_note_folder           | {"id": 1, "parent_id": null, "stray": "x"} |
      | move_task                  | {"id": 1, "list": "next", "stray": "x"} |
      | move_tasks                 | {"ids": [1], "list": "next", "stray": "x"} |
      | open_decision              | {"title": "Pick a queue", "problem": "Jobs pile up", "stray": "x"} |
      | pause_task                 | {"id": 1, "stray": "x"} |
      | pause_task_series          | {"id": 1, "stray": "x"} |
      | pin_note                   | {"id": 1, "pinned": true, "stray": "x"} |
      | plan_sprint                | {"sprint_on": "2026-01-01", "stray": "x"} |
      | publish_post               | {"id": 1, "stray": "x"} |
      | read_activity              | {"from": "2026-01-01", "to": "2026-12-31", "stray": "x"} |
      | read_analytics             | {"from": "2026-01-01", "to": "2026-12-31", "stray": "x"} |
      | read_artifact              | {"id": 1, "stray": "x"} |
      | read_commit                | {"id": 1, "stray": "x"} |
      | read_current_sprint        | {"stray": "x"} |
      | read_decision              | {"id": 1, "stray": "x"} |
      | read_journal_entry         | {"id": 1, "stray": "x"} |
      | read_mail_thread           | {"id": 1, "stray": "x"} |
      | read_memory                | {"stray": "x"} |
      | read_memory_file           | {"id": 1, "stray": "x"} |
      | read_note                  | {"id": 1, "stray": "x"} |
      | read_performance           | {"from": "2026-01-01", "to": "2026-12-31", "stray": "x"} |
      | read_person                | {"id": 1, "stray": "x"} |
      | read_photo                 | {"photo": "x", "stray": "x"} |
      | read_post                  | {"id": 1, "stray": "x"} |
      | read_project               | {"id": 1, "stray": "x"} |
      | read_pull_request          | {"id": 1, "stray": "x"} |
      | read_review                | {"stray": "x"} |
      | read_saved_view            | {"id": 1, "stray": "x"} |
      | read_share                 | {"id": 1, "stray": "x"} |
      | read_share_group           | {"id": 1, "stray": "x"} |
      | read_social_post           | {"id": 1, "stray": "x"} |
      | read_sync_state            | {"stray": "x"} |
      | read_tag                   | {"name": "ruby", "stray": "x"} |
      | read_task                  | {"id": 1, "stray": "x"} |
      | read_health_days           | {"from": "2026-01-01", "to": "2026-01-31", "stray": "x"} |
      | read_time_report           | {"from": "2026-01-01", "to": "2026-12-31", "stray": "x"} |
      | read_webmention            | {"id": 1, "stray": "x"} |
      | read_webmention_settings   | {"stray": "x"} |
      | read_work_entry            | {"id": 1, "stray": "x"} |
      | reject_suggestion_edits    | {"suggestion_id": 1, "stray": "x"} |
      | remove_memory_fact         | {"id": 1, "fact_id": 2, "agent": "claude-code", "model": "claude-opus-5-5", "stray": "x"} |
      | remove_note_folder         | {"id": 1, "stray": "x"} |
      | remove_share_group_file    | {"id": 1, "file_id": 2, "stray": "x"} |
      | remove_tag                 | {"id": 1, "scope": "public", "stray": "x"} |
      | remove_trusted_author      | {"author_url": "https://ada.example/", "stray": "x"} |
      | rename_note                | {"id": 1, "title": "Plan", "stray": "x"} |
      | rename_note_folder         | {"id": 1, "name": "work", "stray": "x"} |
      | reopen_decision            | {"id": 1, "reason": "Load grew", "stray": "x"} |
      | reopen_task                | {"id": 1, "stray": "x"} |
      | reorder_task               | {"id": 1, "direction": "up", "stray": "x"} |
      | resolve_decision           | {"id": 1, "option_id": 2, "reason": "It runs today", "stray": "x"} |
      | restore_artifact_version   | {"id": 1, "version": 1, "agent": "claude-code", "model": "claude-opus-5-5", "stray": "x"} |
      | restore_project            | {"id": 1, "stray": "x"} |
      | resume_task_series         | {"id": 1, "stray": "x"} |
      | revert_memory_event        | {"id": 1, "event_id": 2, "agent": "claude-code", "model": "claude-opus-5-5", "stray": "x"} |
      | run_link_check             | {"stray": "x"} |
      | save_mail_draft            | {"from": "Work", "stray": "x"} |
      | save_person                | {"name": "Ada Lovelace", "key": "ada", "stray": "x"} |
      | save_project               | {"id": 1, "stray": "x"} |
      | save_review_note           | {"day": "2026-09-16", "body": "A good week", "stray": "x"} |
      | save_tag                   | {"id": 1, "scope": "public", "stray": "x"} |
      | save_task                  | {"id": 1, "stray": "x"} |
      | save_task_rule             | {"pattern": "aaronmallen/*", "tags": ["ruby"], "stray": "x"} |
      | schedule_task              | {"id": 1, "sprint_on": "", "stray": "x"} |
      | search                     | {"query": "zeppelin", "stray": "x"} |
      | search_accounts            | {"network": "bluesky", "query": "ada", "stray": "x"} |
      | search_memory              | {"query": "cache", "stray": "x"} |
      | search_notes               | {"query": "plan", "stray": "x"} |
      | send_social_post           | {"id": 1, "stray": "x"} |
      | set_task_total             | {"id": 1, "hours": 2, "stray": "x"} |
      | snooze_attention           | {"kind": "journal", "stray": "x"} |
      | snooze_inbox               | {"messages": [1], "snoozed_until": "2026-01-01T09:00", "stray": "x"} |
      | snooze_inbox_row           | {"kind": "message", "id": 1, "snoozed_until": "2026-01-01T09:00", "stray": "x"} |
      | snooze_mail_threads        | {"ids": [1], "snoozed_until": "2026-01-01T09:00", "stray": "x"} |
      | stage_task                 | {"id": 1, "stage": "ready", "stray": "x"} |
      | start_session              | {"title": "Spike", "agent": "claude-code", "model": "claude-opus-5-5", "stray": "x"} |
      | start_task                 | {"id": 1, "stray": "x"} |
      | suggest_edits              | {"target": "post", "id": 1, "edits": [{"original": "teh", "replacement": "the", "reason": "typo"}], "stray": "x"} |
      | summarize_activity         | {"from": "2026-01-01", "to": "2026-12-31", "stray": "x"} |
      | sync_issues                | {"stray": "x"} |
      | sync_people                | {"stray": "x"} |
      | tag_decision               | {"id": 1, "tags": ["queues"], "stray": "x"} |
      | tag_mail_threads           | {"ids": [1], "tag": "ruby", "stray": "x"} |
      | tag_memory_file            | {"id": 1, "tag": "ruby", "stray": "x"} |
      | tag_note                   | {"id": 1, "tag": "ruby", "stray": "x"} |
      | tag_posts                  | {"ids": [1], "tag": "ruby", "stray": "x"} |
      | tag_session                | {"id": 1, "tag": "ruby", "stray": "x"} |
      | tag_tasks                  | {"ids": [1], "tag": "ruby", "stray": "x"} |
      | ungroup_share_file         | {"id": 1, "file_id": 2, "stray": "x"} |
      | unlink_records             | {"kind": "post", "id": 1, "other_kind": "commit", "other_id": 2, "stray": "x"} |
      | unlink_task                | {"id": 1, "other_id": 2, "stray": "x"} |
      | untag_decision             | {"id": 1, "tag": "queues", "stray": "x"} |
      | untag_mail_threads         | {"ids": [1], "tag": "ruby", "stray": "x"} |
      | untag_memory_file          | {"id": 1, "tag": "ruby", "stray": "x"} |
      | untag_note                 | {"id": 1, "tag": "ruby", "stray": "x"} |
      | untag_session              | {"id": 1, "tag": "ruby", "stray": "x"} |
      | untag_tasks                | {"ids": [1], "tag": "ruby", "stray": "x"} |
      | update_artifact            | {"id": 1, "agent": "claude-code", "model": "claude-opus-5-5", "stray": "x"} |
      | update_journal_entry       | {"id": 1, "stray": "x"} |
      | update_post                | {"id": 1, "stray": "x"} |
      | update_post_edit_note      | {"id": 1, "edit_id": 2, "note": "Fixed the numbers", "stray": "x"} |
      | update_saved_view          | {"id": 1, "stray": "x"} |
      | update_share               | {"id": 1, "filename": "notes.txt", "stray": "x"} |
      | update_share_group         | {"id": 1, "name": "Trip", "stray": "x"} |
      | update_share_group_file    | {"id": 1, "file_id": 2, "filename": "notes.txt", "stray": "x"} |
      | update_short_link          | {"id": 1, "stray": "x"} |
      | update_social_post         | {"id": 1, "stray": "x"} |
      | update_webmention_settings | {"stray": "x"} |
      | update_work_session        | {"id": 1, "session_id": 2, "started_at": "2026-01-01T09:00", "stray": "x"} |
      | upload_photo               | {"data": "", "filename": "photo.png", "stray": "x"} |
      | upload_share               | {"data": "", "filename": "notes.txt", "stray": "x"} |
      | upload_share_group         | {"files": [{"data": "", "filename": "notes.txt"}], "stray": "x"} |
      | wake_inbox_row             | {"kind": "message", "id": 1, "stray": "x"} |
      | write_post_seo             | {"id": 1, "stray": "x"} |
