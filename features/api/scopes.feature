Feature: API token scopes
  Each API operation asks for the scopes its row names, and a token lacking one is refused naming it.

  Scenario Outline: <operation> refuses a token that lacks <scopes>
    Then <method> "<path>" refuses a token with every scope but each of "<scopes>", naming that scope

    Examples:
      | method | path                                         | scopes           | operation                  |
      | GET    | /journal_entries                             | read             | list_journal_entries       |
      | POST   | /journal_entries                             | write            | create_journal_entry       |
      | GET    | /journal_entries/{id}                        | read             | read_journal_entry         |
      | PATCH  | /journal_entries/{id}                        | write            | update_journal_entry       |
      | DELETE | /journal_entries/{id}                        | delete           | delete_journal_entry       |
      | GET    | /tasks                                       | read             | list_tasks                 |
      | POST   | /tasks                                       | write            | capture_task               |
      | POST   | /tasks/bulk/cancel                           | write            | cancel_tasks               |
      | POST   | /tasks/bulk/complete                         | write            | complete_tasks             |
      | POST   | /tasks/bulk/delete                           | delete           | delete_tasks               |
      | POST   | /tasks/bulk/move                             | write            | move_tasks                 |
      | POST   | /tasks/bulk/tag                              | write            | tag_tasks                  |
      | POST   | /tasks/bulk/untag                            | write            | untag_tasks                |
      | POST   | /tasks/issues/sync                           | write            | sync_issues                |
      | GET    | /tasks/{id}                                  | read             | read_task                  |
      | PATCH  | /tasks/{id}                                  | write            | save_task                  |
      | DELETE | /tasks/{id}                                  | delete           | delete_task                |
      | POST   | /tasks/{id}/cancel                           | write            | cancel_task                |
      | POST   | /tasks/{id}/complete                         | write            | complete_task              |
      | POST   | /tasks/{id}/move                             | write            | move_task                  |
      | POST   | /tasks/{id}/reopen                           | write            | reopen_task                |
      | POST   | /tasks/{id}/seen                             | write            | mark_task_seen             |
      | POST   | /tasks/{id}/stage                            | write            | stage_task                 |
      | POST   | /tasks/{id}/reorder                          | write            | reorder_task               |
      | POST   | /tasks/{id}/schedule                         | write            | schedule_task              |
      | POST   | /tasks/{id}/pause                            | write            | pause_task                 |
      | POST   | /tasks/{id}/start                            | write            | start_task                 |
      | POST   | /tasks/{id}/total                            | write            | set_task_total             |
      | POST   | /tasks/{id}/sessions                         | write            | add_work_session           |
      | PATCH  | /tasks/{id}/sessions/{session_id}            | write            | update_work_session        |
      | DELETE | /tasks/{id}/sessions/{session_id}            | delete           | delete_work_session        |
      | POST   | /tasks/{id}/comments                         | write            | add_task_comment           |
      | PATCH  | /tasks/{id}/comments/{comment_id}            | write            | edit_task_comment          |
      | DELETE | /tasks/{id}/comments/{comment_id}            | delete           | delete_task_comment        |
      | POST   | /tasks/{id}/links                            | write            | link_tasks                 |
      | DELETE | /tasks/{id}/links/{other_id}                 | write            | unlink_task                |
      | GET    | /activity                                    | read             | read_activity              |
      | GET    | /analytics                                   | read             | read_analytics             |
      | GET    | /performance                                 | read             | read_performance           |
      | GET    | /activity/summary                            | read             | summarize_activity         |
      | GET    | /commits                                     | read             | list_commits               |
      | POST   | /commits/import                              | write            | import_commits             |
      | GET    | /commits/{id}                                | read             | read_commit                |
      | GET    | /pull_requests                               | read             | list_pull_requests         |
      | GET    | /pull_requests/{id}                          | read             | read_pull_request          |
      | GET    | /sync_state                                  | read             | read_sync_state            |
      | GET    | /decisions                                   | read             | list_decisions             |
      | POST   | /decisions                                   | write            | open_decision              |
      | GET    | /decisions/{id}                              | read             | read_decision              |
      | PATCH  | /decisions/{id}                              | write            | edit_decision              |
      | POST   | /decisions/{id}/drop                         | write            | drop_decision              |
      | POST   | /decisions/{id}/reopen                       | write            | reopen_decision            |
      | POST   | /decisions/{id}/resolve                      | write            | resolve_decision           |
      | POST   | /decisions/{id}/options                      | write            | add_decision_option        |
      | PATCH  | /decisions/{id}/options/{option_id}          | write            | edit_decision_option       |
      | DELETE | /decisions/{id}/options/{option_id}          | delete           | delete_decision_option     |
      | POST   | /decisions/{id}/comments                     | write            | add_decision_comment       |
      | PATCH  | /decisions/{id}/comments/{comment_id}        | write            | edit_decision_comment      |
      | DELETE | /decisions/{id}/comments/{comment_id}        | delete           | delete_decision_comment    |
      | POST   | /decisions/{id}/tags                         | write            | tag_decision               |
      | DELETE | /decisions/{id}/tags/{tag}                   | write            | untag_decision             |
      | GET    | /mail/threads                                | mail             | list_mail_threads          |
      | POST   | /mail/threads/bulk/delete                    | mail             | delete_mail_threads        |
      | POST   | /mail/threads/bulk/read                      | mail             | mark_mail_threads_read     |
      | POST   | /mail/threads/bulk/unread                    | mail             | mark_mail_threads_unread   |
      | POST   | /mail/threads/bulk/snooze                    | mail             | snooze_mail_threads        |
      | POST   | /mail/threads/bulk/tag                       | mail             | tag_mail_threads           |
      | POST   | /mail/threads/bulk/untag                     | mail             | untag_mail_threads         |
      | GET    | /mail/threads/{id}                           | mail             | read_mail_thread           |
      | POST   | /mail/threads/{id}/mark                      | mail             | mark_mail_thread           |
      | POST   | /mail/threads/{id}/task                      | mail, write      | make_mail_task             |
      | POST   | /mail/drafts                                 | mail             | save_mail_draft            |
      | GET    | /artifacts                                   | agents           | list_artifacts             |
      | POST   | /artifacts                                   | agents           | create_artifact            |
      | GET    | /artifacts/{id}                              | agents           | read_artifact              |
      | PATCH  | /artifacts/{id}                              | agents           | update_artifact            |
      | DELETE | /artifacts/{id}                              | agents, delete   | delete_artifact            |
      | POST   | /artifacts/{id}/versions/{version}/restore   | agents           | restore_artifact_version   |
      | GET    | /memory                                      | agents           | read_memory                |
      | GET    | /memory/search                               | agents           | search_memory              |
      | GET    | /agent_sessions                              | agents           | list_sessions              |
      | POST   | /agent_sessions                              | agents           | start_session              |
      | POST   | /agent_sessions/{id}/end                     | agents           | end_session                |
      | POST   | /agent_sessions/{id}/tags                    | agents           | tag_session                |
      | DELETE | /agent_sessions/{id}/tags/{tag}              | agents           | untag_session              |
      | POST   | /memory_files                                | agents           | create_memory_file         |
      | GET    | /memory_files/{id}                           | agents           | read_memory_file           |
      | DELETE | /memory_files/{id}                           | agents, delete   | delete_memory_file         |
      | POST   | /memory_files/{id}/move                      | agents           | move_memory_file           |
      | POST   | /memory_files/{id}/describe                  | agents           | describe_memory_file       |
      | POST   | /memory_files/{id}/tags                      | agents           | tag_memory_file            |
      | DELETE | /memory_files/{id}/tags/{tag}                | agents           | untag_memory_file          |
      | POST   | /memory_files/{id}/facts                     | agents           | add_memory_fact            |
      | PATCH  | /memory_files/{id}/facts/{fact_id}           | agents           | edit_memory_fact           |
      | POST   | /memory_files/{id}/facts/{fact_id}/remove    | agents           | remove_memory_fact         |
      | POST   | /memory_files/{id}/history/{event_id}/revert | agents           | revert_memory_event        |
      | GET    | /notes                                       | notes            | list_notes                 |
      | POST   | /notes                                       | notes            | create_note                |
      | GET    | /notes/search                                | notes            | search_notes               |
      | GET    | /notes/{id}                                  | notes            | read_note                  |
      | PATCH  | /notes/{id}                                  | notes            | edit_note                  |
      | DELETE | /notes/{id}                                  | notes, delete    | delete_note                |
      | POST   | /notes/{id}/rename                           | notes            | rename_note                |
      | POST   | /notes/{id}/move                             | notes            | move_note                  |
      | POST   | /notes/{id}/pin                              | notes            | pin_note                   |
      | POST   | /notes/{id}/duplicate                        | notes            | duplicate_note             |
      | POST   | /notes/{id}/tags                             | notes            | tag_note                   |
      | DELETE | /notes/{id}/tags/{tag}                       | notes            | untag_note                 |
      | GET    | /note_folders                                | notes            | list_note_folders          |
      | POST   | /note_folders                                | notes            | create_note_folder         |
      | DELETE | /note_folders/{id}                           | notes, delete    | remove_note_folder         |
      | POST   | /note_folders/{id}/rename                    | notes            | rename_note_folder         |
      | POST   | /note_folders/{id}/move                      | notes            | move_note_folder           |
      | POST   | /note_folders/{id}/describe                  | notes            | describe_note_folder       |
      | GET    | /posts                                       | read             | list_posts                 |
      | POST   | /posts                                       | write            | create_post                |
      | POST   | /posts/bulk/delete                           | delete           | delete_posts               |
      | POST   | /posts/links/check                           | write            | run_link_check             |
      | POST   | /posts/bulk/tag                              | write            | tag_posts                  |
      | GET    | /posts/{id}                                  | read             | read_post                  |
      | PATCH  | /posts/{id}                                  | write            | update_post                |
      | DELETE | /posts/{id}                                  | delete           | delete_post                |
      | GET    | /posts/{id}/announcement                     | read             | compose_announcement       |
      | PATCH  | /posts/{id}/seo                              | write            | write_post_seo             |
      | POST   | /posts/{id}/publish                          | publish          | publish_post               |
      | PATCH  | /posts/{id}/edits/{edit_id}                  | publish          | update_post_edit_note      |
      | POST   | /posts/{id}/links/check                      | write            | check_post_links           |
      | GET    | /photos                                      | read             | read_photo                 |
      | POST   | /photos                                      | write            | upload_photo               |
      | GET    | /shares                                      | read             | list_shares                |
      | POST   | /shares                                      | publish          | upload_share               |
      | POST   | /shares/bulk/group                           | publish          | group_shares               |
      | GET    | /shares/{id}                                 | read             | read_share                 |
      | PATCH  | /shares/{id}                                 | publish          | update_share               |
      | DELETE | /shares/{id}                                 | publish, delete  | delete_share               |
      | GET    | /share_groups                                | read             | list_share_groups          |
      | POST   | /share_groups                                | publish          | upload_share_group         |
      | GET    | /share_groups/{id}                           | read             | read_share_group           |
      | PATCH  | /share_groups/{id}                           | publish          | update_share_group         |
      | DELETE | /share_groups/{id}                           | publish, delete  | delete_share_group         |
      | PATCH  | /share_groups/{id}/files/{file_id}           | publish          | update_share_group_file    |
      | DELETE | /share_groups/{id}/files/{file_id}           | publish, delete  | remove_share_group_file    |
      | POST   | /share_groups/{id}/files                     | publish          | add_shares_to_group        |
      | POST   | /share_groups/{id}/files/{file_id}/ungroup   | publish          | ungroup_share_file         |
      | GET    | /short_links                                 | read             | list_short_links           |
      | POST   | /short_links                                 | publish          | create_short_link          |
      | PATCH  | /short_links/{id}                            | publish          | update_short_link          |
      | POST   | /short_links/{id}/check                      | write            | check_short_link           |
      | GET    | /attention                                   | read             | list_attention             |
      | GET    | /inbox                                       | read             | list_inbox                 |
      | POST   | /inbox/seen                                  | write            | clear_inbox                |
      | POST   | /inbox/snooze                                | write            | snooze_inbox_row           |
      | POST   | /inbox/snooze/all                            | write            | snooze_inbox               |
      | POST   | /inbox/wake                                  | write            | wake_inbox_row             |
      | POST   | /attention/snooze                            | write            | snooze_attention           |
      | GET    | /calendar                                    | read             | list_calendar              |
      | POST   | /calendar/events                             | write            | create_event               |
      | PATCH  | /calendar/events/{id}                        | write            | edit_event                 |
      | DELETE | /calendar/events/{id}                        | write, delete    | delete_event               |
      | POST   | /calendar/events/{id}/move                   | write            | move_event                 |
      | GET    | /links/{kind}/{id}                           | read             | list_links                 |
      | POST   | /links/{kind}/{id}                           | write            | link_records               |
      | DELETE | /links/{kind}/{id}/{other_kind}/{other_id}   | write            | unlink_records             |
      | GET    | /people                                      | read             | list_people                |
      | POST   | /people                                      | write            | create_person              |
      | GET    | /people/search/{network}                     | read             | search_accounts            |
      | POST   | /people/sync                                 | contacts, write  | sync_people                |
      | GET    | /people/{id}                                 | read             | read_person                |
      | PATCH  | /people/{id}                                 | write            | update_person              |
      | DELETE | /people/{id}                                 | contacts, delete | delete_person              |
      | GET    | /projects                                    | read             | list_projects              |
      | POST   | /projects                                    | write            | create_project             |
      | GET    | /projects/{id}                               | read             | read_project               |
      | PATCH  | /projects/{id}                               | write            | update_project             |
      | POST   | /projects/{id}/archive                       | write            | archive_project            |
      | POST   | /projects/{id}/restore                       | write            | restore_project            |
      | GET    | /review                                      | read             | read_review                |
      | POST   | /review/note                                 | write            | save_review_note           |
      | GET    | /search                                      | read             | search                     |
      | GET    | /social_posts                                | read             | list_social_posts          |
      | POST   | /social_posts                                | write            | create_social_post         |
      | GET    | /social_posts/{id}                           | read             | read_social_post           |
      | PATCH  | /social_posts/{id}                           | write            | update_social_post         |
      | DELETE | /social_posts/{id}                           | delete           | delete_social_post         |
      | POST   | /social_posts/{id}/send                      | publish          | send_social_post           |
      | GET    | /suggestions                                 | read             | list_suggestions           |
      | POST   | /suggestions                                 | suggest          | suggest_edits              |
      | POST   | /suggestions/{suggestion_id}/accept          | write            | accept_suggestion_edits    |
      | POST   | /suggestions/{suggestion_id}/reject          | write            | reject_suggestion_edits    |
      | GET    | /sprints                                     | read             | list_sprints               |
      | POST   | /sprints                                     | write            | plan_sprint                |
      | GET    | /sprints/current                             | read             | read_current_sprint        |
      | DELETE | /sprints/{id}                                | write            | drop_sprint                |
      | GET    | /saved_views                                 | read             | list_saved_views           |
      | POST   | /saved_views                                 | write            | create_saved_view          |
      | PATCH  | /saved_views/{id}                            | write            | update_saved_view          |
      | DELETE | /saved_views/{id}                            | delete           | delete_saved_view          |
      | GET    | /tags                                        | read             | list_tags                  |
      | POST   | /tags                                        | write            | create_tag                 |
      | GET    | /tags/{name}                                 | read             | read_tag                   |
      | PATCH  | /tags/{scope}/{id}                           | write            | update_tag                 |
      | DELETE | /tags/{scope}/{id}                           | delete           | remove_tag                 |
      | GET    | /task_rules                                  | read             | list_task_rules            |
      | POST   | /task_rules                                  | write            | create_task_rule           |
      | PATCH  | /task_rules/{id}                             | write            | update_task_rule           |
      | DELETE | /task_rules/{id}                             | delete           | delete_task_rule           |
      | GET    | /task_series                                 | read             | list_task_series           |
      | POST   | /task_series/{id}/pause                      | write            | pause_task_series          |
      | POST   | /task_series/{id}/resume                     | write            | resume_task_series         |
      | GET    | /saved_views/{id}/records                    | read             | read_saved_view            |
      | GET    | /health/days                                 | health           | read_health_days           |
      | GET    | /time_report                                 | read             | read_time_report           |
      | GET    | /webmentions                                 | read             | list_webmentions           |
      | POST   | /webmentions/bulk/approve                    | publish          | approve_webmentions        |
      | POST   | /webmentions/bulk/ignore                     | write            | ignore_webmentions         |
      | POST   | /webmentions/bulk/spam                       | write            | mark_webmentions_spam      |
      | GET    | /webmentions/{id}                            | read             | read_webmention            |
      | POST   | /webmentions/{id}/moderate                   | write            | moderate_webmention        |
      | GET    | /webmention_settings                         | read             | read_webmention_settings   |
      | PATCH  | /webmention_settings                         | publish          | update_webmention_settings |
      | GET    | /trusted_authors                             | read             | list_trusted_authors       |
      | POST   | /trusted_authors/remove                      | delete           | remove_trusted_author      |
      | GET    | /work_entries                                | read             | list_work_entries          |
      | POST   | /work_entries                                | publish          | add_work_entry             |
      | GET    | /work_entries/{id}                           | read             | read_work_entry            |
      | DELETE | /work_entries/{id}                           | delete           | delete_work_entry          |
      | GET    | /token                                       | read             | read_token                 |
      | GET    | /tokens                                      | read             | list_api_tokens            |
      | GET    | /clients                                     | read             | list_clients               |
      | GET    | /openapi.json                                | read             | read_document              |

  Scenario: A token without write is refused, naming the scope it lacks
    Given an API token with the scopes "read"
    When I POST "/tasks" through the API with:
      """
      {}
      """
    Then the API answers 403
    And the API answer is:
      """
      { "error": "insufficient_scope", "error_description": "this endpoint needs a token with the write scope" }
      """

  Scenario: A token with the scope gets through, and a read token reads
    Given an API token with the scopes "write"
    When I POST "/tasks" through the API with:
      """
      {}
      """
    Then the API answers 422
    Given an API token with the scopes "read"
    When I GET "/token" through the API
    Then the API answers 200

  Scenario: A token stored before scopes takes every scope
    Given the table api_tokens holds:
      | name       | token_digest              |
      | Old laptop | sha256 of old-laptop-key  |
    When I call the API POST "posts/x/publish" with the token "old-laptop-key"
    Then the API answers 422

  Scenario: Minting with no scope named gives every scope
    Given I am signed in to the admin
    When I post to "/admin/tokens" with:
      | token[name] | Terminal |
    Then the database answers "agents,contacts,delete,health,mail,notes,publish,read,suggest,write" for:
      """
      SELECT array_to_string(ARRAY(SELECT unnest(scopes)::text ORDER BY 1), ',') FROM api_tokens
      """

  Scenario: Minting refuses a scope it does not know
    Given I am signed in to the admin
    When I post to "/admin/tokens" with:
      | token[name]          | Terminal |
      | token[scopes][admin] | 1        |
    Then the answer is 422
    And the answer shows "id=\"token-scopes-error\">Check this field."
    And the table api_tokens holds 0 rows
