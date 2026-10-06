# frozen_string_literal: true

RSpec.describe "MCP tool scopes", type: :request do
  def self.guarded
    {
      "read" => %w[
        compose_announcement list_api_tokens list_attention list_calendar list_clients list_commits list_decisions
        list_inbox list_journal_entries list_links list_messages list_people list_posts list_projects list_saved_views
        list_social_posts list_sprints list_suggestions list_tags list_task_tag_rules list_tasks list_webmentions
        list_work_entries read_activity read_analytics read_commit read_current_sprint read_decision read_journal_entry
        read_message read_person read_photo read_post read_project read_review read_saved_view read_social_post
        read_sync_state read_tag read_task read_time_report read_webmention read_webmention_settings read_work_entry
        search search_accounts summarize_activity
      ],
      "suggest" => %w[suggest_edits],
      "write" => %w[
        accept_suggestion_edits add_decision_comment add_decision_option add_task_comment add_work_entry
        approve_webmentions archive_project cancel_task cancel_tasks capture_task complete_task complete_tasks
        create_journal_entry create_post create_saved_view create_social_post drop_decision drop_sprint edit_decision
        edit_decision_comment edit_decision_option edit_task_comment ignore_webmentions import_commits link_records
        link_tasks mark_message mark_messages_read mark_messages_unread mark_task_seen mark_webmentions_spam
        moderate_webmention move_project move_task move_tasks open_decision pause_task plan_sprint
        reject_suggestion_edits reopen_decision reopen_task reorder_task resolve_decision restore_project save_person
        save_project save_review_note save_tag save_task save_task_tag_rule schedule_task set_task_total
        snooze_attention start_task sync_issues tag_decision tag_posts tag_tasks unlink_records unlink_task
        untag_decision untag_tasks update_journal_entry update_post update_post_edit_note update_saved_view
        update_social_post update_webmention_settings update_work_session upload_photo write_post_seo
      ],
      "publish" => %w[publish_post send_social_post],
      "delete" => %w[
        delete_decision_comment delete_decision_option delete_journal_entry delete_messages delete_person delete_post
        delete_posts delete_saved_view delete_social_post delete_task delete_task_comment delete_task_tag_rule
        delete_tasks delete_work_entry delete_work_session remove_tag
      ],
    }
  end

  def access_token
    @access_token ||= mcp_connect(
      Spec::DB::Factories[:mcp].create(:oauth_client), verifier: Blog::SecretToken.generate, scope: scopes.join(" "),
    ).fetch("access_token")
  end

  def document = JSON.parse(last_response.body)

  def guarded = self.class.guarded

  def listed = tools.map { it.fetch("name") }

  def rpc(method, params = nil)
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{access_token}" }
    post "/mcp", JSON.generate({ jsonrpc: "2.0", id: 1, method:, params: }.compact), headers
  end

  def tools
    rpc("tools/list")
    document.dig("result", "tools")
  end

  describe "a token holding every scope" do
    def scopes = guarded.keys

    it "guards each tool with the scope this spec expects" do
      expect(listed).to match_array(guarded.values.flatten)
    end
  end

  guarded.each do |scope, names|
    describe "a token holding every scope but #{scope}" do
      define_method(:scopes) { guarded.keys - [scope] }

      it "lists none of the tools #{scope} guards" do
        expect(listed).not_to include(*names)
      end

      it "still lists the tools the other scopes guard" do
        expect(listed).to match_array(guarded.values.flatten - names)
      end

      it "refuses a call to a tool #{scope} guards, naming the #{scope} permission" do
        rpc("tools/call", { name: names.first, arguments: {} })

        expect(document.dig("error", "data")).to eq(
          "#{names.first} needs the #{scope} permission, and this connection was never granted it. " \
          "Connect the app again to grant it",
        )
      end
    end
  end
end
