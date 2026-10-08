# frozen_string_literal: true

RSpec.describe "API task comments", type: :request do
  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def body_of(comment) = Tasks::Slice["relations.task_comments"].by_pk(comment.id).one&.fetch(:body)

  def call_api(verb, path, fields = nil)
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json" }
    headers["HTTP_AUTHORIZATION"] = "Bearer #{api_token}"
    public_send(verb, "/api/v1/tasks/#{path}", fields && JSON.generate(fields), headers)
    JSON.parse(last_response.body)
  end

  def comment(id, **fields) = call_api(:post, "#{id}/comments", fields)

  def edit(id, comment_id, **fields)
    call_api(:patch, "#{id}/comments/#{comment_id}", fields)
  end

  def remove(id, comment_id) = call_api(:delete, "#{id}/comments/#{comment_id}")

  def stamps(saved) = { "created_at" => saved.created_at.utc.iso8601, "updated_at" => saved.updated_at.utc.iso8601 }

  def status = last_response.status

  def stored(task) = Tasks::Slice["repos.task_comment_queries"].for_task(task.id)

  let(:task) { create(:task) }

  describe "POST /api/v1/tasks/:id/comments" do
    it "adds a local comment to the task" do
      comment(task.id, body: "Blocked on review")

      expect(stored(task).map { [it.body, it.remote_id] }).to eq([["Blocked on review", nil]])
    end

    it "answers 201 with the comment, trimmed" do
      answered = comment(task.id, body: "  Blocked on review  ")
      saved = stored(task).first
      entry = { "id" => saved.id, "body" => "Blocked on review", "author" => Hanami.app.settings.owner_name,
                "source" => "local", "url" => nil, **stamps(saved) }

      expect([answered, status]).to eq([entry, 201])
    end

    it "refuses an empty body with a 422 naming the field and adds nothing", :aggregate_failures do
      refusal = { "error" => "invalid", "message" => "body: write the comment first",
                  "errors" => { "body" => ["write the comment first"] } }

      expect([comment(task.id, body: "   "), status]).to eq([refusal, 422])
      expect(stored(task)).to be_empty
    end

    it "refuses a body made only of Unicode spaces with a 422 and adds nothing", :aggregate_failures do
      expect([comment(task.id, body: "\u2003").fetch("errors"),
              status]).to eq([{ "body" => ["write the comment first"] }, 422])
      expect(stored(task)).to be_empty
    end

    it "refuses a body holding a control character with a 422" do
      expect(comment(task.id, body: "bad\u0000body").fetch("errors")).to eq("body" => ["holds a control character"])
    end

    it "refuses a request with no body" do
      expect([comment(task.id).fetch("errors"), status]).to eq([{ "body" => ["body is missing"] }, 422])
    end

    it "answers an unknown task with a 404" do
      expect([comment(999_999, body: "Hello"), status])
        .to eq([{ "error" => "not_found", "message" => "no task has the ID 999999" }, 404])
    end

    it "shows the comment when the task is read" do
      comment(task.id, body: "Blocked on review")

      expect(call_api(:get, task.id.to_s).fetch("comments").map { it.fetch("body") }).to eq(["Blocked on review"])
    end
  end

  describe "PATCH /api/v1/tasks/:id/comments/:comment_id" do
    let(:local) { create(:task_comment, task_id: task.id, body: "Blocked on review") }

    it "replaces the body" do
      edit(task.id, local.id, body: "Blocked on deploy")

      expect(body_of(local)).to eq("Blocked on deploy")
    end

    it "answers 200 with the comment, trimmed" do
      answered = edit(task.id, local.id, body: "  Blocked on deploy  ")
      saved = stored(task).first
      entry = { "id" => local.id, "body" => "Blocked on deploy", "author" => Hanami.app.settings.owner_name,
                "source" => "local", "url" => nil, **stamps(saved) }

      expect([answered, status]).to eq([entry, 200])
    end

    it "refuses an empty body with a 422 and keeps the comment", :aggregate_failures do
      expect([edit(task.id, local.id, body: " ").fetch("errors"), status])
        .to eq([{ "body" => ["write the comment first"] }, 422])
      expect(body_of(local)).to eq("Blocked on review")
    end

    it "answers a synced comment with a 404 and leaves it alone", :aggregate_failures do
      synced = create(:task_comment, :synced, task_id: task.id, body: "From GitHub")

      expect([edit(task.id, synced.id, body: "Mine"), status]).to eq(
        [{ "error" => "not_found", "message" => "task #{task.id} has no comment with the ID #{synced.id}" }, 404],
      )
      expect(body_of(synced)).to eq("From GitHub")
    end

    it "answers another task's comment with a 404" do
      stranger = create(:task_comment, body: "Elsewhere")
      edit(task.id, stranger.id, body: "Mine")

      expect([status, body_of(stranger)]).to eq([404, "Elsewhere"])
    end
  end

  describe "DELETE /api/v1/tasks/:id/comments/:comment_id" do
    let(:local) { create(:task_comment, task_id: task.id, body: "Blocked on review") }

    it "deletes the comment and says so", :aggregate_failures do
      expect([remove(task.id, local.id), status])
        .to eq([{ "id" => task.id, "comment_id" => local.id, "deleted" => true }, 200])
      expect(stored(task)).to be_empty
    end

    it "answers a synced comment with a 404 and keeps it", :aggregate_failures do
      synced = create(:task_comment, :synced, task_id: task.id, body: "From GitHub")

      expect([remove(task.id, synced.id), status]).to eq(
        [{ "error" => "not_found", "message" => "task #{task.id} has no comment with the ID #{synced.id}" }, 404],
      )
      expect(body_of(synced)).to eq("From GitHub")
    end

    it "answers another task's comment with a 404" do
      stranger = create(:task_comment, body: "Elsewhere")
      remove(task.id, stranger.id)

      expect([status, body_of(stranger)]).to eq([404, "Elsewhere"])
    end
  end

  describe "the MCP tool" do
    it "comments as add_task_comment does" do
      other = create(:task)
      answered = comment(task.id, body: "the same")

      expect(trusted(mcp_answer("add_task_comment", id: other.id, body: "the same")).except("id", "created_at",
                                                                                            "updated_at"))
        .to eq(answered.except("id", "created_at", "updated_at"))
    end

    it "refuses with the message the endpoint gives" do
      refused = comment(task.id, body: " ")

      expect(mcp_text("add_task_comment", id: task.id, body: " ")).to eq(refused.fetch("message"))
    end

    it "edits as edit_task_comment does" do
      local = create(:task_comment, task_id: task.id, body: "Blocked on review")
      answered = edit(task.id, local.id, body: "the same")

      edited_by_tool = trusted(mcp_answer("edit_task_comment", id: task.id, comment_id: local.id, body: "the same"))

      expect(edited_by_tool.except("updated_at")).to eq(answered.except("updated_at"))
    end

    it "deletes as delete_task_comment does" do
      first, second = Array.new(2) { create(:task_comment, task_id: task.id) }
      answered = remove(task.id, first.id)

      expect(mcp_answer("delete_task_comment", id: task.id, comment_id: second.id))
        .to eq(answered.merge("comment_id" => second.id))
    end

    it "refuses to edit a synced comment with the message the endpoint gives" do
      synced = create(:task_comment, :synced, task_id: task.id)
      refused = edit(task.id, synced.id, body: "Mine")

      expect(mcp_text("edit_task_comment", id: task.id, comment_id: synced.id, body: "Mine"))
        .to eq(refused.fetch("message"))
    end

    it "refuses to delete a synced comment with the message the endpoint gives" do
      synced = create(:task_comment, :synced, task_id: task.id)
      refused = remove(task.id, synced.id)

      expect(mcp_text("delete_task_comment", id: task.id, comment_id: synced.id)).to eq(refused.fetch("message"))
    end
  end
end
