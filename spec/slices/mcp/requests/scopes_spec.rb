# frozen_string_literal: true

RSpec.describe "MCP tool scopes", type: :request do
  def self.guarded
    {
      "read" => %w[
        compose_announcement list_commits list_journal_entries list_messages list_posts list_projects list_social_posts
        list_sprints list_suggestions list_tags list_tasks list_webmentions list_work_entries
        read_activity read_analytics read_current_sprint read_journal_entry read_message read_post read_social_post
        read_sync_state read_task read_webmention_settings summarize_activity
      ],
      "suggest" => %w[suggest_edits],
      "write" => %w[
        accept_suggestion_edits add_task_comment add_work_entry archive_project cancel_task capture_task complete_task
        create_journal_entry create_post create_social_post delete_journal_entry delete_post delete_social_post
        delete_task delete_work_entry drop_sprint import_commits link_tasks mark_message moderate_webmention
        move_project move_task plan_sprint publish_post reject_suggestion_edits remove_tag reopen_task
        reorder_task restore_project save_project save_tag save_task schedule_task
        send_social_post start_task unlink_task update_journal_entry update_post update_social_post
        update_webmention_settings write_post_seo
      ],
    }
  end

  def access_token
    @access_token ||= mcp_connect(
      Spec::DB::Factories[:mcp].create(:oauth_client), verifier: MCP::OAuth::Secret.generate, scope: scopes.join(" "),
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

    it "lists every tool the server carries, so no tool names a scope the server does not know" do
      expect(listed).to match_array(MCP::Protocol::Handler::TOOLS.map(&:name_value))
    end

    it "guards each tool with the scope this spec expects" do
      expect(listed).to match_array(guarded.values.flatten)
    end

    it "tells a client to summarize the feed before it reads the months" do
      summary = tools.find { it.fetch("name") == "summarize_activity" }

      expect(summary.fetch("description")).to include("read_activity")
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

      names.each do |name|
        it "refuses a call to #{name}, naming the #{scope} permission" do
          rpc("tools/call", { name:, arguments: {} })

          expect(document.dig("error", "data")).to start_with("#{name} needs the #{scope} permission")
        end
      end
    end
  end
end
