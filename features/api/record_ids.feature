Feature: API record IDs
  An unknown record ID answers 404 naming it, and an ID that is no number answers 422 naming its field.

  Background:
    Given an API token that may do all but "nothing"

  Scenario Outline: <method> <path> answers an unknown <field> with a 404
    When I call the API <method> "<call>" with the body '<body>'
    Then the API answers 404
    And the API answer at "error" is "\"not_found\""
    And the API answer's "message" holds "999999"

    Examples:
      | method | path                                         | field         | call                                  | body                                                                              |
      | GET    | /journal_entries/{id}                        | id            | /journal_entries/999999               |                                                                                   |
      | PATCH  | /journal_entries/{id}                        | id            | /journal_entries/999999               | {}                                                                                |
      | DELETE | /journal_entries/{id}                        | id            | /journal_entries/999999               |                                                                                   |
      | GET    | /tasks/{id}                                  | id            | /tasks/999999                         |                                                                                   |
      | PATCH  | /tasks/{id}                                  | id            | /tasks/999999                         | {}                                                                                |
      | DELETE | /tasks/{id}                                  | id            | /tasks/999999                         |                                                                                   |
      | POST   | /tasks/{id}/cancel                           | id            | /tasks/999999/cancel                  | {}                                                                                |
      | POST   | /tasks/{id}/complete                         | id            | /tasks/999999/complete                | {}                                                                                |
      | POST   | /tasks/{id}/move                             | id            | /tasks/999999/move                    | {"list":"next"}                                                                   |
      | POST   | /tasks/{id}/reopen                           | id            | /tasks/999999/reopen                  | {}                                                                                |
      | POST   | /tasks/{id}/seen                             | id            | /tasks/999999/seen                    | {}                                                                                |
      | POST   | /tasks/{id}/stage                            | id            | /tasks/999999/stage                   | {"stage":"ready"}                                                                 |
      | POST   | /tasks/{id}/reorder                          | id            | /tasks/999999/reorder                 | {"direction":"up"}                                                                |
      | POST   | /tasks/{id}/schedule                         | id            | /tasks/999999/schedule                | {"sprint_on":""}                                                                  |
      | POST   | /tasks/{id}/pause                            | id            | /tasks/999999/pause                   | {}                                                                                |
      | POST   | /tasks/{id}/start                            | id            | /tasks/999999/start                   | {}                                                                                |
      | POST   | /tasks/{id}/total                            | id            | /tasks/999999/total                   | {}                                                                                |
      | POST   | /tasks/{id}/sessions                         | id            | /tasks/999999/sessions                | {"started_at":"2026-10-01T09:00","ended_at":"2026-10-01T10:00"}                   |
      | PATCH  | /tasks/{id}/sessions/{session_id}            | id            | /tasks/999999/sessions/1              | {"started_at":"2026-10-01T09:00"}                                                 |
      | DELETE | /tasks/{id}/sessions/{session_id}            | id            | /tasks/999999/sessions/1              |                                                                                   |
      | POST   | /tasks/{id}/comments                         | id            | /tasks/999999/comments                | {"body":"A note"}                                                                 |
      | PATCH  | /tasks/{id}/comments/{comment_id}            | id            | /tasks/999999/comments/1              | {"body":"A note"}                                                                 |
      | DELETE | /tasks/{id}/comments/{comment_id}            | id            | /tasks/999999/comments/1              |                                                                                   |
      | POST   | /tasks/{id}/links                            | id            | /tasks/999999/links                   | {"kind":"relates","other_id":1}                                                   |
      | DELETE | /tasks/{id}/links/{other_id}                 | id            | /tasks/999999/links/1                 |                                                                                   |
      | GET    | /commits/{id}                                | id            | /commits/999999                       |                                                                                   |
      | GET    | /pull_requests/{id}                          | id            | /pull_requests/999999                 |                                                                                   |
      | GET    | /decisions/{id}                              | id            | /decisions/999999                     |                                                                                   |
      | PATCH  | /decisions/{id}                              | id            | /decisions/999999                     | {}                                                                                |
      | POST   | /decisions/{id}/drop                         | id            | /decisions/999999/drop                | {"reason":"Moot"}                                                                 |
      | POST   | /decisions/{id}/reopen                       | id            | /decisions/999999/reopen              | {"reason":"Back"}                                                                 |
      | POST   | /decisions/{id}/resolve                      | id            | /decisions/999999/resolve             | {"option_id":1,"reason":"Cheaper"}                                                |
      | POST   | /decisions/{id}/options                      | id            | /decisions/999999/options             | {"title":"Rent"}                                                                  |
      | PATCH  | /decisions/{id}/options/{option_id}          | id            | /decisions/999999/options/1           | {}                                                                                |
      | DELETE | /decisions/{id}/options/{option_id}          | id            | /decisions/999999/options/1           |                                                                                   |
      | POST   | /decisions/{id}/comments                     | id            | /decisions/999999/comments            | {"body":"A note"}                                                                 |
      | PATCH  | /decisions/{id}/comments/{comment_id}        | id            | /decisions/999999/comments/1          | {"body":"A note"}                                                                 |
      | DELETE | /decisions/{id}/comments/{comment_id}        | id            | /decisions/999999/comments/1          |                                                                                   |
      | POST   | /decisions/{id}/tags                         | id            | /decisions/999999/tags                | {"tags":["house"]}                                                                |
      | DELETE | /decisions/{id}/tags/{tag}                   | id            | /decisions/999999/tags/house          |                                                                                   |
      | GET    | /mail/threads/{id}                           | id            | /mail/threads/999999                  |                                                                                   |
      | POST   | /mail/threads/{id}/mark                      | id            | /mail/threads/999999/mark             | {"status":"read"}                                                                 |
      | POST   | /mail/threads/{id}/task                      | id            | /mail/threads/999999/task             | {"title":"Reply"}                                                                 |
      | GET    | /artifacts/{id}                              | id            | /artifacts/999999                     |                                                                                   |
      | PATCH  | /artifacts/{id}                              | id            | /artifacts/999999                     | {"agent":"claude-code","model":"claude-opus-5-5"}                                 |
      | DELETE | /artifacts/{id}                              | id            | /artifacts/999999                     |                                                                                   |
      | POST   | /artifacts/{id}/versions/{version}/restore   | id            | /artifacts/999999/versions/1/restore  | {"agent":"claude-code","model":"claude-opus-5-5"}                                 |
      | POST   | /agent_sessions/{id}/end                     | id            | /agent_sessions/999999/end            | {}                                                                                |
      | POST   | /agent_sessions/{id}/tags                    | id            | /agent_sessions/999999/tags           | {"tag":"house"}                                                                   |
      | DELETE | /agent_sessions/{id}/tags/{tag}              | id            | /agent_sessions/999999/tags/house     |                                                                                   |
      | GET    | /memory_files/{id}                           | id            | /memory_files/999999                  |                                                                                   |
      | DELETE | /memory_files/{id}                           | id            | /memory_files/999999                  |                                                                                   |
      | POST   | /memory_files/{id}/move                      | id            | /memory_files/999999/move             | {"scope":"global","agent":"claude-code","model":"claude-opus-5-5"}                |
      | POST   | /memory_files/{id}/describe                  | id            | /memory_files/999999/describe         | {"description":"Notes","agent":"claude-code","model":"claude-opus-5-5"}           |
      | POST   | /memory_files/{id}/tags                      | id            | /memory_files/999999/tags             | {"tag":"house"}                                                                   |
      | DELETE | /memory_files/{id}/tags/{tag}                | id            | /memory_files/999999/tags/house       |                                                                                   |
      | POST   | /memory_files/{id}/facts                     | id            | /memory_files/999999/facts            | {"type":"gotcha","text":"A note","agent":"claude-code","model":"claude-opus-5-5"} |
      | PATCH  | /memory_files/{id}/facts/{fact_id}           | id            | /memory_files/999999/facts/1          | {"agent":"claude-code","model":"claude-opus-5-5"}                                 |
      | POST   | /memory_files/{id}/facts/{fact_id}/remove    | id            | /memory_files/999999/facts/1/remove   | {"agent":"claude-code","model":"claude-opus-5-5"}                                 |
      | POST   | /memory_files/{id}/history/{event_id}/revert | id            | /memory_files/999999/history/1/revert | {"agent":"claude-code","model":"claude-opus-5-5"}                                 |
      | GET    | /notes/{id}                                  | id            | /notes/999999                         |                                                                                   |
      | PATCH  | /notes/{id}                                  | id            | /notes/999999                         | {"version":1}                                                                     |
      | DELETE | /notes/{id}                                  | id            | /notes/999999                         |                                                                                   |
      | POST   | /notes/{id}/rename                           | id            | /notes/999999/rename                  | {"title":"Plan"}                                                                  |
      | POST   | /notes/{id}/move                             | id            | /notes/999999/move                    | {"folder_id":null}                                                                |
      | POST   | /notes/{id}/pin                              | id            | /notes/999999/pin                     | {"pinned":true}                                                                   |
      | POST   | /notes/{id}/duplicate                        | id            | /notes/999999/duplicate               | {}                                                                                |
      | POST   | /notes/{id}/tags                             | id            | /notes/999999/tags                    | {"tag":"house"}                                                                   |
      | DELETE | /notes/{id}/tags/{tag}                       | id            | /notes/999999/tags/house              |                                                                                   |
      | DELETE | /note_folders/{id}                           | id            | /note_folders/999999                  |                                                                                   |
      | POST   | /note_folders/{id}/rename                    | id            | /note_folders/999999/rename           | {"name":"work"}                                                                   |
      | POST   | /note_folders/{id}/move                      | id            | /note_folders/999999/move             | {"parent_id":null}                                                                |
      | POST   | /note_folders/{id}/describe                  | id            | /note_folders/999999/describe         | {"description":"Client work"}                                                     |
      | GET    | /posts/{id}                                  | id            | /posts/999999                         |                                                                                   |
      | PATCH  | /posts/{id}                                  | id            | /posts/999999                         | {}                                                                                |
      | DELETE | /posts/{id}                                  | id            | /posts/999999                         |                                                                                   |
      | GET    | /posts/{id}/announcement                     | id            | /posts/999999/announcement            |                                                                                   |
      | PATCH  | /posts/{id}/seo                              | id            | /posts/999999/seo                     | {}                                                                                |
      | POST   | /posts/{id}/publish                          | id            | /posts/999999/publish                 | {}                                                                                |
      | PATCH  | /posts/{id}/edits/{edit_id}                  | id            | /posts/999999/edits/1                 | {"note":"Typo"}                                                                   |
      | POST   | /posts/{id}/links/check                      | id            | /posts/999999/links/check             | {}                                                                                |
      | GET    | /shares/{id}                                 | id            | /shares/999999                        |                                                                                   |
      | PATCH  | /shares/{id}                                 | id            | /shares/999999                        | {"filename":"notes.txt"}                                                          |
      | DELETE | /shares/{id}                                 | id            | /shares/999999                        |                                                                                   |
      | GET    | /share_groups/{id}                           | id            | /share_groups/999999                  |                                                                                   |
      | PATCH  | /share_groups/{id}                           | id            | /share_groups/999999                  | {"name":"Trip"}                                                                   |
      | DELETE | /share_groups/{id}                           | id            | /share_groups/999999                  |                                                                                   |
      | PATCH  | /share_groups/{id}/files/{file_id}           | id            | /share_groups/999999/files/1          | {"filename":"notes.txt"}                                                          |
      | DELETE | /share_groups/{id}/files/{file_id}           | id            | /share_groups/999999/files/1          |                                                                                   |
      | POST   | /share_groups/{id}/files                     | id            | /share_groups/999999/files            | {"ids":[1]}                                                                       |
      | POST   | /share_groups/{id}/files/{file_id}/ungroup   | id            | /share_groups/999999/files/1/ungroup  | {}                                                                                |
      | PATCH  | /short_links/{id}                            | id            | /short_links/999999                   | {}                                                                                |
      | POST   | /short_links/{id}/check                      | id            | /short_links/999999/check             | {}                                                                                |
      | PATCH  | /calendar/events/{id}                        | id            | /calendar/events/999999               | {}                                                                                |
      | DELETE | /calendar/events/{id}                        | id            | /calendar/events/999999               |                                                                                   |
      | POST   | /calendar/events/{id}/move                   | id            | /calendar/events/999999/move          | {"to":"2026-01-01"}                                                               |
      | GET    | /links/{kind}/{id}                           | id            | /links/post/999999                    |                                                                                   |
      | POST   | /links/{kind}/{id}                           | id            | /links/post/999999                    | {"other_kind":"post","other_id":1}                                                |
      | DELETE | /links/{kind}/{id}/{other_kind}/{other_id}   | id            | /links/post/999999/post/1             |                                                                                   |
      | GET    | /people/{id}                                 | id            | /people/999999                        |                                                                                   |
      | PATCH  | /people/{id}                                 | id            | /people/999999                        | {}                                                                                |
      | DELETE | /people/{id}                                 | id            | /people/999999                        |                                                                                   |
      | GET    | /projects/{id}                               | id            | /projects/999999                      |                                                                                   |
      | PATCH  | /projects/{id}                               | id            | /projects/999999                      | {}                                                                                |
      | POST   | /projects/{id}/archive                       | id            | /projects/999999/archive              | {}                                                                                |
      | POST   | /projects/{id}/restore                       | id            | /projects/999999/restore              | {}                                                                                |
      | GET    | /social_posts/{id}                           | id            | /social_posts/999999                  |                                                                                   |
      | PATCH  | /social_posts/{id}                           | id            | /social_posts/999999                  | {}                                                                                |
      | DELETE | /social_posts/{id}                           | id            | /social_posts/999999                  |                                                                                   |
      | POST   | /social_posts/{id}/send                      | id            | /social_posts/999999/send             | {}                                                                                |
      | POST   | /suggestions/{suggestion_id}/accept          | suggestion_id | /suggestions/999999/accept            | {}                                                                                |
      | POST   | /suggestions/{suggestion_id}/reject          | suggestion_id | /suggestions/999999/reject            | {}                                                                                |
      | DELETE | /sprints/{id}                                | id            | /sprints/999999                       |                                                                                   |
      | PATCH  | /saved_views/{id}                            | id            | /saved_views/999999                   | {}                                                                                |
      | DELETE | /saved_views/{id}                            | id            | /saved_views/999999                   |                                                                                   |
      | PATCH  | /tags/{scope}/{id}                           | id            | /tags/public/999999                   | {}                                                                                |
      | DELETE | /tags/{scope}/{id}                           | id            | /tags/public/999999                   |                                                                                   |
      | PATCH  | /task_rules/{id}                             | id            | /task_rules/999999                    | {}                                                                                |
      | DELETE | /task_rules/{id}                             | id            | /task_rules/999999                    |                                                                                   |
      | POST   | /task_series/{id}/pause                      | id            | /task_series/999999/pause             | {}                                                                                |
      | POST   | /task_series/{id}/resume                     | id            | /task_series/999999/resume            | {}                                                                                |
      | GET    | /saved_views/{id}/records                    | id            | /saved_views/999999/records           |                                                                                   |
      | GET    | /webmentions/{id}                            | id            | /webmentions/999999                   |                                                                                   |
      | POST   | /webmentions/{id}/moderate                   | id            | /webmentions/999999/moderate          | {"verdict":"approved"}                                                            |
      | GET    | /work_entries/{id}                           | id            | /work_entries/999999                  |                                                                                   |
      | DELETE | /work_entries/{id}                           | id            | /work_entries/999999                  |                                                                                   |

  Scenario Outline: <method> <path> refuses a <field> that is not a number with a 422
    When I call the API <method> "<call>" with the body '<body>'
    Then the API answers 422
    And the API answer's errors are only "<field>"

    Examples:
      | method | path                                         | field         | call                               | body                                                                              |
      | GET    | /journal_entries/{id}                        | id            | /journal_entries/abc               |                                                                                   |
      | PATCH  | /journal_entries/{id}                        | id            | /journal_entries/abc               | {}                                                                                |
      | DELETE | /journal_entries/{id}                        | id            | /journal_entries/abc               |                                                                                   |
      | GET    | /tasks/{id}                                  | id            | /tasks/abc                         |                                                                                   |
      | PATCH  | /tasks/{id}                                  | id            | /tasks/abc                         | {}                                                                                |
      | DELETE | /tasks/{id}                                  | id            | /tasks/abc                         |                                                                                   |
      | POST   | /tasks/{id}/cancel                           | id            | /tasks/abc/cancel                  | {}                                                                                |
      | POST   | /tasks/{id}/complete                         | id            | /tasks/abc/complete                | {}                                                                                |
      | POST   | /tasks/{id}/move                             | id            | /tasks/abc/move                    | {"list":"next"}                                                                   |
      | POST   | /tasks/{id}/reopen                           | id            | /tasks/abc/reopen                  | {}                                                                                |
      | POST   | /tasks/{id}/seen                             | id            | /tasks/abc/seen                    | {}                                                                                |
      | POST   | /tasks/{id}/stage                            | id            | /tasks/abc/stage                   | {"stage":"ready"}                                                                 |
      | POST   | /tasks/{id}/reorder                          | id            | /tasks/abc/reorder                 | {"direction":"up"}                                                                |
      | POST   | /tasks/{id}/schedule                         | id            | /tasks/abc/schedule                | {"sprint_on":""}                                                                  |
      | POST   | /tasks/{id}/pause                            | id            | /tasks/abc/pause                   | {}                                                                                |
      | POST   | /tasks/{id}/start                            | id            | /tasks/abc/start                   | {}                                                                                |
      | POST   | /tasks/{id}/total                            | id            | /tasks/abc/total                   | {}                                                                                |
      | POST   | /tasks/{id}/sessions                         | id            | /tasks/abc/sessions                | {"started_at":"2026-10-01T09:00","ended_at":"2026-10-01T10:00"}                   |
      | PATCH  | /tasks/{id}/sessions/{session_id}            | id            | /tasks/abc/sessions/1              | {"started_at":"2026-10-01T09:00"}                                                 |
      | PATCH  | /tasks/{id}/sessions/{session_id}            | session_id    | /tasks/1/sessions/abc              | {"started_at":"2026-10-01T09:00"}                                                 |
      | DELETE | /tasks/{id}/sessions/{session_id}            | id            | /tasks/abc/sessions/1              |                                                                                   |
      | DELETE | /tasks/{id}/sessions/{session_id}            | session_id    | /tasks/1/sessions/abc              |                                                                                   |
      | POST   | /tasks/{id}/comments                         | id            | /tasks/abc/comments                | {"body":"A note"}                                                                 |
      | PATCH  | /tasks/{id}/comments/{comment_id}            | id            | /tasks/abc/comments/1              | {"body":"A note"}                                                                 |
      | PATCH  | /tasks/{id}/comments/{comment_id}            | comment_id    | /tasks/1/comments/abc              | {"body":"A note"}                                                                 |
      | DELETE | /tasks/{id}/comments/{comment_id}            | id            | /tasks/abc/comments/1              |                                                                                   |
      | DELETE | /tasks/{id}/comments/{comment_id}            | comment_id    | /tasks/1/comments/abc              |                                                                                   |
      | POST   | /tasks/{id}/links                            | id            | /tasks/abc/links                   | {"kind":"relates","other_id":1}                                                   |
      | DELETE | /tasks/{id}/links/{other_id}                 | id            | /tasks/abc/links/1                 |                                                                                   |
      | DELETE | /tasks/{id}/links/{other_id}                 | other_id      | /tasks/1/links/abc                 |                                                                                   |
      | GET    | /commits/{id}                                | id            | /commits/abc                       |                                                                                   |
      | GET    | /pull_requests/{id}                          | id            | /pull_requests/abc                 |                                                                                   |
      | GET    | /decisions/{id}                              | id            | /decisions/abc                     |                                                                                   |
      | PATCH  | /decisions/{id}                              | id            | /decisions/abc                     | {}                                                                                |
      | POST   | /decisions/{id}/drop                         | id            | /decisions/abc/drop                | {"reason":"Moot"}                                                                 |
      | POST   | /decisions/{id}/reopen                       | id            | /decisions/abc/reopen              | {"reason":"Back"}                                                                 |
      | POST   | /decisions/{id}/resolve                      | id            | /decisions/abc/resolve             | {"option_id":1,"reason":"Cheaper"}                                                |
      | POST   | /decisions/{id}/options                      | id            | /decisions/abc/options             | {"title":"Rent"}                                                                  |
      | PATCH  | /decisions/{id}/options/{option_id}          | id            | /decisions/abc/options/1           | {}                                                                                |
      | PATCH  | /decisions/{id}/options/{option_id}          | option_id     | /decisions/1/options/abc           | {}                                                                                |
      | DELETE | /decisions/{id}/options/{option_id}          | id            | /decisions/abc/options/1           |                                                                                   |
      | DELETE | /decisions/{id}/options/{option_id}          | option_id     | /decisions/1/options/abc           |                                                                                   |
      | POST   | /decisions/{id}/comments                     | id            | /decisions/abc/comments            | {"body":"A note"}                                                                 |
      | PATCH  | /decisions/{id}/comments/{comment_id}        | id            | /decisions/abc/comments/1          | {"body":"A note"}                                                                 |
      | PATCH  | /decisions/{id}/comments/{comment_id}        | comment_id    | /decisions/1/comments/abc          | {"body":"A note"}                                                                 |
      | DELETE | /decisions/{id}/comments/{comment_id}        | id            | /decisions/abc/comments/1          |                                                                                   |
      | DELETE | /decisions/{id}/comments/{comment_id}        | comment_id    | /decisions/1/comments/abc          |                                                                                   |
      | POST   | /decisions/{id}/tags                         | id            | /decisions/abc/tags                | {"tags":["house"]}                                                                |
      | DELETE | /decisions/{id}/tags/{tag}                   | id            | /decisions/abc/tags/house          |                                                                                   |
      | GET    | /mail/threads/{id}                           | id            | /mail/threads/abc                  |                                                                                   |
      | POST   | /mail/threads/{id}/mark                      | id            | /mail/threads/abc/mark             | {"status":"read"}                                                                 |
      | POST   | /mail/threads/{id}/task                      | id            | /mail/threads/abc/task             | {"title":"Reply"}                                                                 |
      | GET    | /artifacts/{id}                              | id            | /artifacts/abc                     |                                                                                   |
      | PATCH  | /artifacts/{id}                              | id            | /artifacts/abc                     | {"agent":"claude-code","model":"claude-opus-5-5"}                                 |
      | DELETE | /artifacts/{id}                              | id            | /artifacts/abc                     |                                                                                   |
      | POST   | /artifacts/{id}/versions/{version}/restore   | id            | /artifacts/abc/versions/1/restore  | {"agent":"claude-code","model":"claude-opus-5-5"}                                 |
      | POST   | /agent_sessions/{id}/end                     | id            | /agent_sessions/abc/end            | {}                                                                                |
      | POST   | /agent_sessions/{id}/tags                    | id            | /agent_sessions/abc/tags           | {"tag":"house"}                                                                   |
      | DELETE | /agent_sessions/{id}/tags/{tag}              | id            | /agent_sessions/abc/tags/house     |                                                                                   |
      | GET    | /memory_files/{id}                           | id            | /memory_files/abc                  |                                                                                   |
      | DELETE | /memory_files/{id}                           | id            | /memory_files/abc                  |                                                                                   |
      | POST   | /memory_files/{id}/move                      | id            | /memory_files/abc/move             | {"scope":"global","agent":"claude-code","model":"claude-opus-5-5"}                |
      | POST   | /memory_files/{id}/describe                  | id            | /memory_files/abc/describe         | {"description":"Notes","agent":"claude-code","model":"claude-opus-5-5"}           |
      | POST   | /memory_files/{id}/tags                      | id            | /memory_files/abc/tags             | {"tag":"house"}                                                                   |
      | DELETE | /memory_files/{id}/tags/{tag}                | id            | /memory_files/abc/tags/house       |                                                                                   |
      | POST   | /memory_files/{id}/facts                     | id            | /memory_files/abc/facts            | {"type":"gotcha","text":"A note","agent":"claude-code","model":"claude-opus-5-5"} |
      | PATCH  | /memory_files/{id}/facts/{fact_id}           | id            | /memory_files/abc/facts/1          | {"agent":"claude-code","model":"claude-opus-5-5"}                                 |
      | PATCH  | /memory_files/{id}/facts/{fact_id}           | fact_id       | /memory_files/1/facts/abc          | {"agent":"claude-code","model":"claude-opus-5-5"}                                 |
      | POST   | /memory_files/{id}/facts/{fact_id}/remove    | id            | /memory_files/abc/facts/1/remove   | {"agent":"claude-code","model":"claude-opus-5-5"}                                 |
      | POST   | /memory_files/{id}/facts/{fact_id}/remove    | fact_id       | /memory_files/1/facts/abc/remove   | {"agent":"claude-code","model":"claude-opus-5-5"}                                 |
      | POST   | /memory_files/{id}/history/{event_id}/revert | id            | /memory_files/abc/history/1/revert | {"agent":"claude-code","model":"claude-opus-5-5"}                                 |
      | POST   | /memory_files/{id}/history/{event_id}/revert | event_id      | /memory_files/1/history/abc/revert | {"agent":"claude-code","model":"claude-opus-5-5"}                                 |
      | GET    | /notes/{id}                                  | id            | /notes/abc                         |                                                                                   |
      | PATCH  | /notes/{id}                                  | id            | /notes/abc                         | {"version":1}                                                                     |
      | DELETE | /notes/{id}                                  | id            | /notes/abc                         |                                                                                   |
      | POST   | /notes/{id}/rename                           | id            | /notes/abc/rename                  | {"title":"Plan"}                                                                  |
      | POST   | /notes/{id}/move                             | id            | /notes/abc/move                    | {"folder_id":null}                                                                |
      | POST   | /notes/{id}/pin                              | id            | /notes/abc/pin                     | {"pinned":true}                                                                   |
      | POST   | /notes/{id}/duplicate                        | id            | /notes/abc/duplicate               | {}                                                                                |
      | POST   | /notes/{id}/tags                             | id            | /notes/abc/tags                    | {"tag":"house"}                                                                   |
      | DELETE | /notes/{id}/tags/{tag}                       | id            | /notes/abc/tags/house              |                                                                                   |
      | DELETE | /note_folders/{id}                           | id            | /note_folders/abc                  |                                                                                   |
      | POST   | /note_folders/{id}/rename                    | id            | /note_folders/abc/rename           | {"name":"work"}                                                                   |
      | POST   | /note_folders/{id}/move                      | id            | /note_folders/abc/move             | {"parent_id":null}                                                                |
      | POST   | /note_folders/{id}/describe                  | id            | /note_folders/abc/describe         | {"description":"Client work"}                                                     |
      | GET    | /posts/{id}                                  | id            | /posts/abc                         |                                                                                   |
      | PATCH  | /posts/{id}                                  | id            | /posts/abc                         | {}                                                                                |
      | DELETE | /posts/{id}                                  | id            | /posts/abc                         |                                                                                   |
      | GET    | /posts/{id}/announcement                     | id            | /posts/abc/announcement            |                                                                                   |
      | PATCH  | /posts/{id}/seo                              | id            | /posts/abc/seo                     | {}                                                                                |
      | POST   | /posts/{id}/publish                          | id            | /posts/abc/publish                 | {}                                                                                |
      | PATCH  | /posts/{id}/edits/{edit_id}                  | id            | /posts/abc/edits/1                 | {"note":"Typo"}                                                                   |
      | PATCH  | /posts/{id}/edits/{edit_id}                  | edit_id       | /posts/1/edits/abc                 | {"note":"Typo"}                                                                   |
      | POST   | /posts/{id}/links/check                      | id            | /posts/abc/links/check             | {}                                                                                |
      | GET    | /shares/{id}                                 | id            | /shares/abc                        |                                                                                   |
      | PATCH  | /shares/{id}                                 | id            | /shares/abc                        | {"filename":"notes.txt"}                                                          |
      | DELETE | /shares/{id}                                 | id            | /shares/abc                        |                                                                                   |
      | GET    | /share_groups/{id}                           | id            | /share_groups/abc                  |                                                                                   |
      | PATCH  | /share_groups/{id}                           | id            | /share_groups/abc                  | {"name":"Trip"}                                                                   |
      | DELETE | /share_groups/{id}                           | id            | /share_groups/abc                  |                                                                                   |
      | PATCH  | /share_groups/{id}/files/{file_id}           | id            | /share_groups/abc/files/1          | {"filename":"notes.txt"}                                                          |
      | PATCH  | /share_groups/{id}/files/{file_id}           | file_id       | /share_groups/1/files/abc          | {"filename":"notes.txt"}                                                          |
      | DELETE | /share_groups/{id}/files/{file_id}           | id            | /share_groups/abc/files/1          |                                                                                   |
      | DELETE | /share_groups/{id}/files/{file_id}           | file_id       | /share_groups/1/files/abc          |                                                                                   |
      | POST   | /share_groups/{id}/files                     | id            | /share_groups/abc/files            | {"ids":[1]}                                                                       |
      | POST   | /share_groups/{id}/files/{file_id}/ungroup   | id            | /share_groups/abc/files/1/ungroup  | {}                                                                                |
      | POST   | /share_groups/{id}/files/{file_id}/ungroup   | file_id       | /share_groups/1/files/abc/ungroup  | {}                                                                                |
      | PATCH  | /short_links/{id}                            | id            | /short_links/abc                   | {}                                                                                |
      | POST   | /short_links/{id}/check                      | id            | /short_links/abc/check             | {}                                                                                |
      | PATCH  | /calendar/events/{id}                        | id            | /calendar/events/abc               | {}                                                                                |
      | DELETE | /calendar/events/{id}                        | id            | /calendar/events/abc               |                                                                                   |
      | POST   | /calendar/events/{id}/move                   | id            | /calendar/events/abc/move          | {"to":"2026-01-01"}                                                               |
      | GET    | /links/{kind}/{id}                           | id            | /links/post/abc                    |                                                                                   |
      | POST   | /links/{kind}/{id}                           | id            | /links/post/abc                    | {"other_kind":"post","other_id":1}                                                |
      | DELETE | /links/{kind}/{id}/{other_kind}/{other_id}   | id            | /links/post/abc/post/1             |                                                                                   |
      | DELETE | /links/{kind}/{id}/{other_kind}/{other_id}   | other_id      | /links/post/1/post/abc             |                                                                                   |
      | GET    | /people/{id}                                 | id            | /people/abc                        |                                                                                   |
      | PATCH  | /people/{id}                                 | id            | /people/abc                        | {}                                                                                |
      | DELETE | /people/{id}                                 | id            | /people/abc                        |                                                                                   |
      | GET    | /projects/{id}                               | id            | /projects/abc                      |                                                                                   |
      | PATCH  | /projects/{id}                               | id            | /projects/abc                      | {}                                                                                |
      | POST   | /projects/{id}/archive                       | id            | /projects/abc/archive              | {}                                                                                |
      | POST   | /projects/{id}/restore                       | id            | /projects/abc/restore              | {}                                                                                |
      | GET    | /social_posts/{id}                           | id            | /social_posts/abc                  |                                                                                   |
      | PATCH  | /social_posts/{id}                           | id            | /social_posts/abc                  | {}                                                                                |
      | DELETE | /social_posts/{id}                           | id            | /social_posts/abc                  |                                                                                   |
      | POST   | /social_posts/{id}/send                      | id            | /social_posts/abc/send             | {}                                                                                |
      | POST   | /suggestions/{suggestion_id}/accept          | suggestion_id | /suggestions/abc/accept            | {}                                                                                |
      | POST   | /suggestions/{suggestion_id}/reject          | suggestion_id | /suggestions/abc/reject            | {}                                                                                |
      | DELETE | /sprints/{id}                                | id            | /sprints/abc                       |                                                                                   |
      | PATCH  | /saved_views/{id}                            | id            | /saved_views/abc                   | {}                                                                                |
      | DELETE | /saved_views/{id}                            | id            | /saved_views/abc                   |                                                                                   |
      | PATCH  | /tags/{scope}/{id}                           | id            | /tags/public/abc                   | {}                                                                                |
      | DELETE | /tags/{scope}/{id}                           | id            | /tags/public/abc                   |                                                                                   |
      | PATCH  | /task_rules/{id}                             | id            | /task_rules/abc                    | {}                                                                                |
      | DELETE | /task_rules/{id}                             | id            | /task_rules/abc                    |                                                                                   |
      | POST   | /task_series/{id}/pause                      | id            | /task_series/abc/pause             | {}                                                                                |
      | POST   | /task_series/{id}/resume                     | id            | /task_series/abc/resume            | {}                                                                                |
      | GET    | /saved_views/{id}/records                    | id            | /saved_views/abc/records           |                                                                                   |
      | GET    | /webmentions/{id}                            | id            | /webmentions/abc                   |                                                                                   |
      | POST   | /webmentions/{id}/moderate                   | id            | /webmentions/abc/moderate          | {"verdict":"approved"}                                                            |
      | GET    | /work_entries/{id}                           | id            | /work_entries/abc                  |                                                                                   |
      | DELETE | /work_entries/{id}                           | id            | /work_entries/abc                  |                                                                                   |
