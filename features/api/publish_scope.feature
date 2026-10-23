Feature: Changes that show in public
  A token with read and write but not publish cannot change what the public sees, and one with publish can.

  Background:
    Given the owner calls POST "projects" with:
      """
      { "name": "Doing It", "visibility": "public", "board_published": true }
      """
    And I keep the answer's "id" as "board"
    And the owner calls POST "projects" with:
      """
      { "name": "Quiet", "visibility": "private" }
      """
    And I keep the answer's "id" as "quiet"
    And the task "On the board"
    And the task "Off the board"
    And the task "On the board" sits on the project "Doing It"
    And I keep the id of the task "On the board" as "boarded"
    And I keep the id of the task "Off the board" as "loose"
    And the published post "Live" with the body "as it was" as "live"
    And the draft post "Draft" with the body "teh cat sat" as "draft"
    And the scheduled post "Soon" with the body "teh cat sat" as "soon"
    And the owner calls POST "people" with:
      """
      { "name": "Jane", "key": "jane", "mastodon_handle": "@jane@ruby.social" }
      """
    And I keep the answer's "id" as "jane"
    And an API token with the scopes "read, write"

  Scenario Outline: A token without publish cannot <change>
    When I call the API <method> "<path>" with the body '<body>'
    Then the API refuses for want of the publish scope

    Examples:
      | change                                          | method | path                                   | body                                                        |
      | add a public project                            | POST   | projects                               | {"name": "Hush", "visibility": "public"}                    |
      | upload a share                                  | POST   | shares                                 | {"data": "aGk=", "filename": "a.txt"}                       |
      | upload a share group                            | POST   | share_groups                           | {"files": [{"data": "aGk=", "filename": "a.txt"}]}          |
      | group shares                                    | POST   | shares/bulk/group                      | {"ids": [1, 2]}                                             |
      | move shares into a group                        | POST   | share_groups/1/files                   | {"ids": [1, 2]}                                             |
      | ungroup a share                                 | POST   | share_groups/1/files/2/ungroup         | {"ids": [1, 2]}                                             |
      | rename a share                                  | PATCH  | shares/1                               | {"filename": "b.txt"}                                       |
      | rename a share group                            | PATCH  | share_groups/1                         | {"name": "Loud"}                                            |
      | rename a file in a group                        | PATCH  | share_groups/1/files/2                 | {"filename": "b.txt"}                                       |
      | change a task on a published board              | PATCH  | tasks/{boarded}                        | {"title": "changed"}                                        |
      | comment on a task on a published board          | POST   | tasks/{boarded}/comments               | {"body": "hello"}                                           |
      | close a task on a published board               | POST   | tasks/{boarded}/complete               |                                                             |
      | put a task on a published board                 | POST   | links/task/{loose}                     | {"other_kind": "project", "other_id": {board}}              |
      | move a task off a published board into a private project | POST | links/task/{boarded}           | {"other_kind": "project", "other_id": {quiet}}              |
      | add a task rule that files into a published board | POST | task_rules                             | {"pattern": "aaronmallen/*", "projects": [{board}]}         |
      | add a work entry                                | POST   | work_entries                           | {"org": "Acme", "role": "Engineer", "from_year": 2020}      |
      | change the webmention settings                  | PATCH  | webmention_settings                    | {"auto_approve_known_authors": true}                        |
      | change the social card of a published post      | PATCH  | posts/{live}/seo                       | {"og_title": "Loud"}                                        |

  Scenario: A token without publish cannot add a public project, and its page answers 404
    When I POST "/projects" through the API with:
      """
      { "name": "Hush", "visibility": "public" }
      """
    Then the API refuses for want of the publish scope
    And the page "/projects/hush" answers 404

  Scenario: A token without publish cannot make a private project public or publish a public board
    Given the owner calls POST "projects" with:
      """
      { "name": "Hush", "visibility": "private", "board_published": true }
      """
    And I keep the answer's "id" as "hush"
    And the owner calls POST "projects" with:
      """
      { "name": "Open", "visibility": "public" }
      """
    And I keep the answer's "id" as "open"
    When I PATCH "/projects/{hush}" through the API with:
      """
      { "visibility": "public" }
      """
    Then the API refuses for want of the publish scope
    And the page "/projects/hush" answers 404
    When I PATCH "/projects/{open}" through the API with:
      """
      { "board_published": true }
      """
    Then the API refuses for want of the publish scope

  Scenario: A token without publish still changes a private project, a draft and a task on no board
    When I PATCH "/projects/{quiet}" through the API with:
      """
      { "tagline": "quiet" }
      """
    Then the API answers 200
    When I PATCH "/posts/{draft}" through the API with:
      """
      { "body": "changed" }
      """
    Then the API answers 200
    When I PATCH "/tasks/{loose}" through the API with:
      """
      { "title": "changed" }
      """
    Then the API answers 200

  Scenario Outline: A token without publish cannot change the body of a <kind> post, which keeps it
    When I PATCH "/posts/{<post>}" through the API with:
      """
      { "body": "changed", "edit_note": "why" }
      """
    Then the API refuses for want of the publish scope
    And the database answers "<body>" for:
      """
      SELECT body FROM posts WHERE id = {<post>}
      """

    Examples:
      | kind      | post | body        |
      | published | live | as it was   |
      | scheduled | soon | teh cat sat |

  Scenario: A token without publish cannot take a task off a published board, which keeps it there
    When I DELETE "/links/task/{boarded}/project/{board}" through the API
    Then the API refuses for want of the publish scope
    And the database answers "{board}" for:
      """
      SELECT project_id FROM tasks WHERE id = {boarded}
      """

  Scenario: A token without publish still links a task on no board to a private project and adds a task rule there
    When I POST "/links/task/{loose}" through the API with:
      """
      { "other_kind": "project", "other_id": {quiet} }
      """
    Then the API answers 201
    When I POST "/task_rules" through the API with:
      """
      { "pattern": "aaronmallen/*", "projects": [{quiet}] }
      """
    Then the API answers 201

  Scenario: A token without publish cannot accept edits to a scheduled post, but still accepts them on a draft
    Given the owner calls POST "suggestions" with:
      """
      { "target": "post", "id": {soon}, "edits": [{ "original": "teh", "replacement": "the", "reason": "typo" }] }
      """
    And I keep the answer's "suggestion_id" as "onsoon"
    And the owner calls POST "suggestions" with:
      """
      { "target": "post", "id": {draft}, "edits": [{ "original": "teh", "replacement": "the", "reason": "typo" }] }
      """
    And I keep the answer's "suggestion_id" as "ondraft"
    When I POST "/suggestions/{onsoon}/accept" through the API
    Then the API refuses for want of the publish scope
    And the database answers "teh cat sat" for:
      """
      SELECT body FROM posts WHERE id = {soon}
      """
    When I POST "/suggestions/{ondraft}/accept" through the API
    Then the API answers 200

  Scenario Outline: A token without publish cannot rename a tag <what> carries, which keeps its name
    Given <carrier>
    When I PATCH "/tags/public/{ruby}" through the API with:
      """
      { "name": "rails" }
      """
    Then the API refuses for want of the publish scope
    And the database answers "ruby" for:
      """
      SELECT name FROM tags WHERE id = {ruby}
      """

    Examples:
      | what             | carrier                                                    |
      | a published post | the post "Live" carries the tag "ruby" kept as "ruby"      |
      | a public project | the project "Doing It" carries the tag "ruby" kept as "ruby" |

  Scenario Outline: A token without publish still renames a tag only <what> carries
    Given <carrier>
    When I PATCH "/tags/public/{ruby}" through the API with:
      """
      { "name": "rails" }
      """
    Then the API answers 200

    Examples:
      | what              | carrier                                                 |
      | drafts            | the post "Draft" carries the tag "ruby" kept as "ruby"  |
      | a private project | the project "Quiet" carries the tag "ruby" kept as "ruby" |

  Scenario: A token without publish cannot capture a task numbered on a published board, however the key is spelled
    Given the owner calls POST "projects" with:
      """
      { "name": "Keyed", "key": "PUB", "visibility": "public", "board_published": true }
      """
    Then capturing a task into each of "PUB, pub,  PUB " is refused for want of the publish scope

  Scenario: A token without publish still captures a task numbered in a private project
    Given the owner calls POST "projects" with:
      """
      { "name": "Keyed", "key": "HUSH", "visibility": "private", "board_published": true }
      """
    When I POST "/tasks" through the API with:
      """
      { "title": "Quiet", "project": "HUSH" }
      """
    Then the API answers 201

  Scenario: A token without publish cannot point a task rule at a published board or change one that files there
    Given the owner calls POST "task_rules" with:
      """
      { "pattern": "aaronmallen/*", "projects": [{quiet}] }
      """
    And I keep the answer's "id" as "quietrule"
    And the owner calls POST "task_rules" with:
      """
      { "pattern": "aaronmallen/blog", "projects": [{board}] }
      """
    And I keep the answer's "id" as "boardrule"
    When I PATCH "/task_rules/{quietrule}" through the API with:
      """
      { "projects": [{board}] }
      """
    Then the API refuses for want of the publish scope
    When I PATCH "/task_rules/{boardrule}" through the API with:
      """
      { "pattern": "aaronmallen/other" }
      """
    Then the API refuses for want of the publish scope
    When I PATCH "/task_rules/{boardrule}" through the API with:
      """
      { "projects": [{quiet}] }
      """
    Then the API answers 200

  Scenario: A token without publish cannot resume a series on a published board, but still resumes one off it
    Given the owner calls PATCH "tasks/{boarded}" with:
      """
      { "recur": { "cadence": "days", "every": 2 } }
      """
    And the owner calls PATCH "tasks/{loose}" with:
      """
      { "recur": { "cadence": "days", "every": 2 } }
      """
    And I keep the id of the series of "On the board" as "boardedseries"
    And I keep the id of the series of "Off the board" as "looseseries"
    When I POST "/task_series/{boardedseries}/resume" through the API
    Then the API refuses for want of the publish scope
    When I POST "/task_series/{looseseries}/resume" through the API
    Then the API answers 200

  Scenario: A token without publish cannot accept edits to a scheduled social post, which keeps its text
    Given the scheduled social post "teh one" as "social"
    And the owner calls POST "suggestions" with:
      """
      { "target": "social_post", "id": {social}, "edits": [{ "part": 1, "original": "teh", "replacement": "the", "reason": "typo" }] }
      """
    And I keep the answer's "suggestion_id" as "suggestion"
    When I POST "/suggestions/{suggestion}/accept" through the API
    Then the API refuses for want of the publish scope
    And the database answers "teh one" for:
      """
      SELECT body FROM social_post_parts
      """

  Scenario: A token without publish cannot change a person a scheduled social post mentions, and the refusal names the post
    Given the scheduled social post "hi @{jane}" as "social"
    When I PATCH "/people/{jane}" through the API with:
      """
      { "mastodon_handle": "@someone@else.social" }
      """
    Then the API refuses for want of the publish scope
    And the API answer's "error_description" holds "social post {social}"
    And the database answers "@jane@ruby.social" for:
      """
      SELECT mastodon_handle FROM people WHERE id = {jane}
      """

  Scenario: A token without publish cannot rename a person to a key a scheduled social post mentions
    Given the scheduled social post "hi @{joan}" as "social"
    When I PATCH "/people/{jane}" through the API with:
      """
      { "key": "joan" }
      """
    Then the API refuses for want of the publish scope

  Scenario: A token without publish cannot add a person a scheduled social post mentions, and the refusal names the post
    Given the scheduled social post "hi @{joan}" as "social"
    When I POST "/people" through the API with:
      """
      { "name": "Joan", "key": "joan", "mastodon_handle": "@joan@ruby.social" }
      """
    Then the API refuses for want of the publish scope
    And the API answer's "error_description" holds "social post {social}"
    And the database answers "0" for:
      """
      SELECT count(*) FROM people WHERE key = 'joan'
      """

  Scenario: A token without publish still adds a person only a draft mentions and changes a person no scheduled post mentions
    Given the draft social post "hi @{joan}" as "draftsocial"
    And the draft social post "hi @{jane}" as "otherdraft"
    And the scheduled social post "hi @{janet}" as "scheduledsocial"
    When I POST "/people" through the API with:
      """
      { "name": "Joan", "key": "joan", "mastodon_handle": "@joan@ruby.social" }
      """
    Then the API answers 201
    When I PATCH "/people/{jane}" through the API with:
      """
      { "name": "Jane Doe" }
      """
    Then the API answers 200

  Scenario: A token without publish cannot tag a published post, which stays untagged, but still tags a draft
    When I POST "/posts/bulk/tag" through the API with:
      """
      { "ids": [{draft}, {live}], "tag": "ruby" }
      """
    Then the API refuses for want of the publish scope
    And the table post_tags holds 0 rows
    When I POST "/posts/bulk/tag" through the API with:
      """
      { "ids": [{draft}], "tag": "ruby" }
      """
    Then the API answers 200

  Scenario: A token without publish still changes the social card of a draft
    When I PATCH "/posts/{draft}/seo" through the API with:
      """
      { "og_title": "Quiet" }
      """
    Then the API answers 200

  Scenario: A token without publish cannot approve webmentions, which stay pending, but still ignores one
    Given a pending webmention on post "Live" as "mention"
    When I POST "/webmentions/bulk/approve" through the API with:
      """
      { "ids": [{mention}] }
      """
    Then the API refuses for want of the publish scope
    And the database answers "pending" for:
      """
      SELECT status FROM webmentions
      """
    When I POST "/webmentions/{mention}/moderate" through the API with:
      """
      { "verdict": "approved" }
      """
    Then the API refuses for want of the publish scope
    When I POST "/webmentions/{mention}/moderate" through the API with:
      """
      { "verdict": "ignored" }
      """
    Then the API answers 200

  Scenario Outline: A token without publish cannot sync issues while <what>
    Given <setup>
    When I POST "/tasks/issues/sync" through the API
    Then the API refuses for want of the publish scope

    Examples:
      | what                                         | setup                                                                       |
      | a task rule files into a published board     | the owner calls POST "task_rules" with the body '{"pattern": "aaronmallen/*", "projects": [{board}]}' |
      | a synced task sits on a published board      | the task "On the board" syncs from GitHub                                   |
      | a published board tracks a repo              | the owner calls POST "projects" with the body '{"name": "Tracked", "visibility": "public", "board_published": true, "repo": "aaronmallen/aaronmallen.me"}' |

  Scenario Outline: A token with publish <change>
    Given an API token with the scopes "write, publish"
    And <setup>
    When I call the API <method> "<path>" with the body '<body>'
    Then the API answers <status>

    Examples:
      | change                                          | setup                                                          | method | path                                   | body                                                  | status |
      | adds a public project                           | nothing more                                                   | POST   | projects                               | {"name": "Open", "visibility": "public"}              | 201    |
      | tags a published post                           | nothing more                                                   | POST   | posts/bulk/tag                         | {"ids": [{live}], "tag": "ruby"}                      | 200    |
      | approves webmentions                            | a pending webmention on post "Live" as "mention"               | POST   | webmentions/bulk/approve               | {"ids": [{mention}]}                                  | 200    |
      | takes a task off a published board              | nothing more                                                   | DELETE | links/task/{boarded}/project/{board}   |                                                       | 200    |
      | adds a task rule that files into a published board | nothing more                                                | POST   | task_rules                             | {"pattern": "aaronmallen/*", "projects": [{board}]}   | 201    |
      | renames a tag a published post carries          | the post "Live" carries the tag "ruby" kept as "ruby"          | PATCH  | tags/public/{ruby}                     | {"name": "rails"}                                     | 200    |
      | renames a tag a public project carries          | the project "Doing It" carries the tag "ruby" kept as "ruby"   | PATCH  | tags/public/{ruby}                     | {"name": "rails"}                                     | 200    |
      | changes a task on a published board             | nothing more                                                   | PATCH  | tasks/{boarded}                        | {"title": "changed"}                                  | 200    |
      | changes a person a scheduled social post mentions | the scheduled social post "hi @{jane}" as "social"           | PATCH  | people/{jane}                          | {"name": "Jane Doe"}                                  | 200    |
      | adds a person whose key a scheduled social post mentions | the scheduled social post "hi @{joan}" as "social"    | POST   | people                                 | {"name": "Joan", "key": "joan", "mastodon_handle": "@joan@ruby.social"} | 201 |

  Scenario: A token with publish captures a task numbered on a published board and points a task rule at it
    Given an API token with the scopes "write, publish"
    And the owner calls POST "projects" with:
      """
      { "name": "Keyed", "key": "PUB", "visibility": "public", "board_published": true }
      """
    And the owner calls POST "task_rules" with:
      """
      { "pattern": "aaronmallen/*", "projects": [{quiet}] }
      """
    And I keep the answer's "id" as "rule"
    When I POST "/tasks" through the API with:
      """
      { "title": "Loud", "project": " pub " }
      """
    Then the API answers 201
    When I PATCH "/task_rules/{rule}" through the API with:
      """
      { "projects": [{board}] }
      """
    Then the API answers 200

  Scenario: A token with publish accepts edits to a scheduled post and a scheduled social post, and resumes a series on a board
    Given an API token with the scopes "write, publish"
    And the scheduled social post "teh one" as "social"
    And the owner calls POST "suggestions" with:
      """
      { "target": "post", "id": {soon}, "edits": [{ "original": "teh", "replacement": "the", "reason": "typo" }] }
      """
    And I keep the answer's "suggestion_id" as "onsoon"
    And the owner calls POST "suggestions" with:
      """
      { "target": "social_post", "id": {social}, "edits": [{ "part": 1, "original": "teh", "replacement": "the", "reason": "typo" }] }
      """
    And I keep the answer's "suggestion_id" as "onsocial"
    And the owner calls PATCH "tasks/{boarded}" with:
      """
      { "recur": { "cadence": "days", "every": 2 } }
      """
    And I keep the id of the series of "On the board" as "series"
    When I POST "/suggestions/{onsoon}/accept" through the API
    Then the API answers 200
    When I POST "/suggestions/{onsocial}/accept" through the API
    Then the API answers 200
    When I POST "/task_series/{series}/resume" through the API
    Then the API answers 200

  Scenario Outline: An MCP client without publish is refused <what>, naming publish
    Given an MCP client connected with the scopes "read write"
    And <setup>
    When I call the MCP tool "<tool>" with:
      """
      <arguments>
      """
    Then the MCP tool refuses
    And the MCP tool refuses with "<says>"

    Examples:
      | what                                   | setup                                                  | tool                     | arguments                                                                        | says                                                                         |
      | a public project                       | nothing more                                           | save_project             | {"name": "Hush", "visibility": "public"}                                         | this project shows in public, so this change needs the publish scope        |
      | an approved webmention                 | a pending webmention on post "Live" as "mention"       | moderate_webmention      | {"id": {mention}, "verdict": "approved"}                                         | an approved webmention shows in public, so this change needs the publish scope |
      | a sync that reaches a published board  | the task "On the board" syncs from GitHub              | sync_issues              | {}                                                                               | a published board shows in public, so this change needs the publish scope   |
      | a change to a scheduled post           | nothing more                                           | update_post              | {"id": {soon}, "title": "Loud"}                                                  | this blog post shows in public, so this change needs the publish scope      |
      | a comment on a task on a published board | nothing more                                         | add_task_comment         | {"id": {boarded}, "body": "hello"}                                               | a task on a published board shows in public, so this change needs the publish scope |
      | taking a task off a published board    | nothing more                                           | unlink_records           | {"kind": "task", "id": {boarded}, "other_kind": "project", "other_id": {board}}  | a task on a published board shows in public, so this change needs the publish scope |
      | a task rule that files into a published board | nothing more                                         | save_task_rule     | {"pattern": "aaronmallen/*", "projects": [{board}]}                              | a published board shows in public, so this change needs the publish scope   |
      | renaming a tag a published post carries | the post "Live" carries the tag "ruby" kept as "ruby" | save_tag                 | {"id": {ruby}, "scope": "public", "name": "rails"}                               | a blog post with this tag shows in public, so this change needs the publish scope |

  Scenario: An MCP client without publish is refused accepting edits to a scheduled post, naming publish
    Given an MCP client connected with the scopes "read write"
    And the owner calls POST "suggestions" with:
      """
      { "target": "post", "id": {soon}, "edits": [{ "original": "teh", "replacement": "the", "reason": "typo" }] }
      """
    And I keep the answer's "suggestion_id" as "onsoon"
    When I call the MCP tool "accept_suggestion_edits" with:
      """
      { "suggestion_id": {onsoon} }
      """
    Then the MCP tool refuses
    And the MCP tool refuses with "this blog post shows in public, so this change needs the publish scope"
