# frozen_string_literal: true

RSpec.describe "MCP tool scopes", type: :request do
  def self.guarded
    {
      "read" => %w[
        compose_announcement list_api_tokens list_attention list_calendar list_clients list_commits list_decisions
        list_inbox list_journal_entries list_links list_people list_posts list_projects list_pull_requests
        list_saved_views
        list_share_groups list_shares
        list_social_posts list_sprints list_suggestions list_tags list_task_rules list_task_series list_tasks
        list_trusted_authors
        list_webmentions list_work_entries read_activity read_analytics read_commit read_current_sprint read_decision
        read_journal_entry read_performance read_person read_photo read_post read_project read_pull_request read_review
        read_saved_view
        read_share read_share_group
        read_social_post read_sync_state read_tag read_task read_time_report read_webmention
        read_webmention_settings read_work_entry search search_accounts summarize_activity
      ],
      "suggest" => %w[suggest_edits],
      "write" => %w[
        accept_suggestion_edits add_decision_comment add_decision_option add_task_comment add_work_session
        archive_project cancel_task cancel_tasks capture_task
        clear_inbox
        complete_task complete_tasks
        create_event
        create_journal_entry create_post create_saved_view create_social_post
        delete_event
        drop_decision drop_sprint edit_decision
        edit_decision_comment edit_decision_option edit_event edit_task_comment ignore_webmentions import_commits
        link_records
        link_tasks mark_task_seen mark_webmentions_spam
        moderate_webmention move_event move_task move_tasks open_decision pause_task pause_task_series plan_sprint
        reject_suggestion_edits reopen_decision reopen_task reorder_task resolve_decision restore_project
        resume_task_series save_person
        save_project save_review_note save_tag save_task save_task_rule schedule_task set_task_total
        snooze_attention
        snooze_inbox
        snooze_inbox_row
        stage_task start_task sync_issues tag_decision tag_posts tag_tasks unlink_records unlink_task
        untag_decision untag_tasks update_journal_entry update_post update_saved_view
        update_social_post update_work_session upload_photo
        wake_inbox_row write_post_seo
      ],
      "publish" => %w[
        add_shares_to_group add_work_entry approve_webmentions group_shares publish_post send_social_post
        ungroup_share_file update_post_edit_note update_share update_share_group update_share_group_file
        update_webmention_settings upload_share upload_share_group
      ],
      "health" => %w[read_health_days],
      "mail" => %w[
        delete_mail_threads list_mail_threads mark_mail_thread mark_mail_threads_read mark_mail_threads_unread
        read_mail_thread snooze_mail_threads tag_mail_threads untag_mail_threads
      ],
      "agents" => %w[
        add_memory_fact create_artifact create_memory_file delete_artifact delete_memory_file describe_memory_file
        edit_memory_fact end_session list_artifacts list_sessions move_memory_file read_artifact read_memory
        read_memory_file remove_memory_fact restore_artifact_version revert_memory_event search_memory start_session
        update_artifact
      ],
      "delete" => %w[
        delete_artifact delete_decision_comment delete_memory_file delete_decision_option delete_event
        delete_journal_entry delete_person delete_post delete_posts delete_saved_view delete_social_post delete_task
        delete_task_comment
        delete_task_rule delete_tasks delete_work_entry delete_work_session remove_tag remove_trusted_author
      ],
    }
  end

  def guarded = self.class.guarded

  def listed = tools.map { it.fetch("name") }

  def tools
    mcp_rpc("tools/list")
    mcp_result.fetch("tools")
  end

  describe "a token holding every scope" do
    def mcp_scopes = guarded.keys

    it "guards each tool with the scope this spec expects" do
      expect(listed).to match_array(guarded.values.flatten.uniq)
    end
  end

  guarded.each do |scope, names|
    describe "a token holding every scope but #{scope}" do
      define_method(:mcp_scopes) { guarded.keys - [scope] }

      it "lists none of the tools #{scope} guards" do
        expect(listed).not_to include(*names)
      end

      it "still lists the tools the other scopes guard" do
        expect(listed).to match_array(guarded.values.flatten.uniq - names)
      end

      it "refuses a call to a tool #{scope} guards, naming the #{scope} permission" do
        mcp_rpc("tools/call", { name: names.first, arguments: {} })

        expect(mcp_reply.dig("error", "data")).to eq(
          "#{names.first} needs the #{scope} permission, and this connection was never granted it. " \
          "Connect the app again to grant it",
        )
      end
    end
  end

  describe "a token holding agents and every scope but delete" do
    def mcp_scopes = guarded.keys - ["delete"]

    it "refuses delete_memory_file, naming delete alone" do
      mcp_rpc("tools/call", { name: "delete_memory_file", arguments: { id: 1 } })

      expect(mcp_reply.dig("error", "data")).to start_with("delete_memory_file needs the delete permission,")
    end
  end

  describe "a token holding neither agents nor delete" do
    def mcp_scopes = %w[read write]

    it "refuses delete_memory_file, naming both" do
      mcp_rpc("tools/call", { name: "delete_memory_file", arguments: { id: 1 } })

      expect(mcp_reply.dig("error", "data")).to start_with("delete_memory_file needs the agents and delete permission,")
    end
  end
end
