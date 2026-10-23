Feature: MCP tool scopes
  Each tool is guarded by the scopes it needs, and a call without one is refused naming the permission.

  Scenario: A token holding every scope is offered each guarded tool and no other
    Given an MCP client connected with the scopes "read suggest write publish delete health mail agents notes contacts"
    When I ask MCP for "tools/list"
    Then the tools offered are exactly those the scopes below guard:
      | scope    | tools |
      | read     | compose_announcement list_api_tokens list_attention list_calendar list_clients list_commits list_decisions list_inbox list_journal_entries list_links list_people list_posts list_projects list_pull_requests list_saved_views list_share_groups list_shares list_short_links list_social_posts list_sprints list_suggestions list_tags list_task_rules list_task_series list_tasks list_trusted_authors list_webmentions list_work_entries read_activity read_analytics read_commit read_current_sprint read_decision read_journal_entry read_performance read_person read_photo read_post read_project read_pull_request read_review read_saved_view read_share read_share_group read_social_post read_sync_state read_tag read_task read_time_report read_webmention read_webmention_settings read_work_entry search search_accounts summarize_activity |
      | suggest  | suggest_edits |
      | write    | accept_suggestion_edits add_decision_comment add_decision_option add_task_comment add_work_session archive_project cancel_task cancel_tasks capture_task check_post_links check_short_link clear_inbox complete_task complete_tasks create_event create_journal_entry create_post create_saved_view create_social_post delete_event drop_decision drop_sprint edit_decision edit_decision_comment edit_decision_option edit_event edit_task_comment ignore_webmentions import_commits link_records link_tasks make_mail_task mark_task_seen mark_webmentions_spam moderate_webmention move_event move_task move_tasks open_decision pause_task pause_task_series plan_sprint reject_suggestion_edits reopen_decision reopen_task reorder_task resolve_decision restore_project resume_task_series run_link_check save_person save_project save_review_note save_tag save_task save_task_rule schedule_task set_task_total snooze_attention snooze_inbox snooze_inbox_row stage_task start_task sync_issues sync_people tag_decision tag_posts tag_tasks unlink_records unlink_task untag_decision untag_tasks update_journal_entry update_post update_saved_view update_social_post update_work_session upload_photo wake_inbox_row write_post_seo |
      | publish  | add_shares_to_group add_work_entry approve_webmentions create_short_link delete_share delete_share_group group_shares publish_post remove_share_group_file send_social_post ungroup_share_file update_post_edit_note update_share update_share_group update_share_group_file update_short_link update_webmention_settings upload_share upload_share_group |
      | health   | read_health_days |
      | mail     | delete_mail_threads list_mail_threads make_mail_task mark_mail_thread mark_mail_threads_read mark_mail_threads_unread read_mail_thread save_mail_draft snooze_mail_threads tag_mail_threads untag_mail_threads |
      | agents   | add_memory_fact create_artifact create_memory_file delete_artifact delete_memory_file describe_memory_file edit_memory_fact end_session list_artifacts list_sessions move_memory_file read_artifact read_memory read_memory_file remove_memory_fact restore_artifact_version revert_memory_event search_memory start_session tag_memory_file tag_session untag_memory_file untag_session update_artifact |
      | notes    | create_note create_note_folder delete_note describe_note_folder duplicate_note edit_note list_note_folders list_notes move_note move_note_folder pin_note read_note remove_note_folder rename_note rename_note_folder search_notes tag_note untag_note |
      | contacts | delete_person sync_people |
      | delete   | delete_artifact delete_decision_comment delete_memory_file delete_decision_option delete_event delete_journal_entry delete_note delete_person delete_post delete_posts delete_saved_view delete_share delete_share_group delete_social_post delete_task delete_task_comment delete_task_rule delete_tasks delete_work_entry delete_work_session remove_note_folder remove_share_group_file remove_tag remove_trusted_author |

  Scenario Outline: A token holding every scope but <scope> is offered none of its tools, the others still, and refused <first>
    Given an MCP client connected with every scope but "<scope>"
    When I ask MCP for "tools/list"
    Then the tools offered leave out "<tools>" and keep the rest of every guarded tool
    When I call the MCP tool "<first>"
    Then the MCP reply at "error.data" is '"<first> needs the <scope> permission, and this connection was never granted it. Connect the app again to grant it"'

    Examples:
      | scope    | first | tools |
      | read     | compose_announcement | compose_announcement list_api_tokens list_attention list_calendar list_clients list_commits list_decisions list_inbox list_journal_entries list_links list_people list_posts list_projects list_pull_requests list_saved_views list_share_groups list_shares list_short_links list_social_posts list_sprints list_suggestions list_tags list_task_rules list_task_series list_tasks list_trusted_authors list_webmentions list_work_entries read_activity read_analytics read_commit read_current_sprint read_decision read_journal_entry read_performance read_person read_photo read_post read_project read_pull_request read_review read_saved_view read_share read_share_group read_social_post read_sync_state read_tag read_task read_time_report read_webmention read_webmention_settings read_work_entry search search_accounts summarize_activity |
      | suggest  | suggest_edits | suggest_edits |
      | write    | accept_suggestion_edits | accept_suggestion_edits add_decision_comment add_decision_option add_task_comment add_work_session archive_project cancel_task cancel_tasks capture_task check_post_links check_short_link clear_inbox complete_task complete_tasks create_event create_journal_entry create_post create_saved_view create_social_post delete_event drop_decision drop_sprint edit_decision edit_decision_comment edit_decision_option edit_event edit_task_comment ignore_webmentions import_commits link_records link_tasks make_mail_task mark_task_seen mark_webmentions_spam moderate_webmention move_event move_task move_tasks open_decision pause_task pause_task_series plan_sprint reject_suggestion_edits reopen_decision reopen_task reorder_task resolve_decision restore_project resume_task_series run_link_check save_person save_project save_review_note save_tag save_task save_task_rule schedule_task set_task_total snooze_attention snooze_inbox snooze_inbox_row stage_task start_task sync_issues sync_people tag_decision tag_posts tag_tasks unlink_records unlink_task untag_decision untag_tasks update_journal_entry update_post update_saved_view update_social_post update_work_session upload_photo wake_inbox_row write_post_seo |
      | publish  | add_shares_to_group | add_shares_to_group add_work_entry approve_webmentions create_short_link delete_share delete_share_group group_shares publish_post remove_share_group_file send_social_post ungroup_share_file update_post_edit_note update_share update_share_group update_share_group_file update_short_link update_webmention_settings upload_share upload_share_group |
      | health   | read_health_days | read_health_days |
      | mail     | delete_mail_threads | delete_mail_threads list_mail_threads make_mail_task mark_mail_thread mark_mail_threads_read mark_mail_threads_unread read_mail_thread save_mail_draft snooze_mail_threads tag_mail_threads untag_mail_threads |
      | agents   | add_memory_fact | add_memory_fact create_artifact create_memory_file delete_artifact delete_memory_file describe_memory_file edit_memory_fact end_session list_artifacts list_sessions move_memory_file read_artifact read_memory read_memory_file remove_memory_fact restore_artifact_version revert_memory_event search_memory start_session tag_memory_file tag_session untag_memory_file untag_session update_artifact |
      | notes    | create_note | create_note create_note_folder delete_note describe_note_folder duplicate_note edit_note list_note_folders list_notes move_note move_note_folder pin_note read_note remove_note_folder rename_note rename_note_folder search_notes tag_note untag_note |
      | contacts | delete_person | delete_person sync_people |
      | delete   | delete_artifact | delete_artifact delete_decision_comment delete_memory_file delete_decision_option delete_event delete_journal_entry delete_note delete_person delete_post delete_posts delete_saved_view delete_share delete_share_group delete_social_post delete_task delete_task_comment delete_task_rule delete_tasks delete_work_entry delete_work_session remove_note_folder remove_share_group_file remove_tag remove_trusted_author |

  Scenario Outline: A token holding every scope but <missing> is refused <tool>, naming <named>
    Given an MCP client connected with <grant>
    When I call the MCP tool "<tool>" with:
      """
      <arguments>
      """
    Then the MCP reply at "error.data" starts with "<tool> needs the <named> permission,"

    Examples:
      | missing  | grant                                 | tool                    | arguments                  | named              |
      | mail     | every scope but "mail"                | make_mail_task          | { "id": 1, "title": "Reply" } | mail            |
      | write    | every scope but "write"               | make_mail_task          | { "id": 1, "title": "Reply" } | write           |
      | delete   | every scope but "delete"              | delete_memory_file      | { "id": 1 }                | delete             |
      | delete   | every scope but "delete"              | delete_note             | { "id": 1 }                | delete             |
      | delete   | every scope but "delete"              | remove_note_folder      | { "id": 1 }                | delete             |
      | notes    | every scope but "notes"               | remove_note_folder      | { "id": 1 }                | notes              |
      | delete   | every scope but "delete"              | delete_share_group      | { "id": 1 }                | delete             |
      | publish  | every scope but "publish"             | delete_share            | { "id": 1 }                | publish            |
      | publish  | every scope but "publish"             | remove_share_group_file | { "id": 1, "file_id": 2 }  | publish            |
      | publish  | every scope but "publish"             | update_share            | { "id": 1, "code": "resume" } | publish         |
      | agents   | the scopes "read write"               | delete_memory_file      | { "id": 1 }                | agents and delete  |
