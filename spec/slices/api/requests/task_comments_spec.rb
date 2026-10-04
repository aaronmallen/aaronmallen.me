# frozen_string_literal: true

RSpec.describe "API task comments", type: :request do
  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def comment(id, token: api_token, **fields)
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json" }
    headers["HTTP_AUTHORIZATION"] = "Bearer #{token}" if token
    post "/api/v1/tasks/#{id}/comments", JSON.generate(fields), headers
    JSON.parse(last_response.body)
  end

  def status = last_response.status

  def stored(task) = Tasks::Slice["repos.task_comment_repo"].for_task(task.id)

  let(:task) { create(:task) }

  describe "POST /api/v1/tasks/:id/comments" do
    it "adds a local comment to the task" do
      comment(task.id, body: "Blocked on review")

      expect(stored(task).map { [it.body, it.remote_id] }).to eq([["Blocked on review", nil]])
    end

    it "answers 201 with the comment, trimmed" do
      answered = comment(task.id, body: "  Blocked on review  ")
      saved = stored(task).first
      entry = { "id" => saved.id, "body" => "Blocked on review", "author" => Blog::Owner.full_name,
                "source" => "local", "url" => nil, "created_at" => saved.created_at.utc.iso8601 }

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

    it "refuses a request with no token" do
      comment(task.id, body: "Hello", token: nil)

      expect([status, stored(task)]).to eq([401, []])
    end
  end

  describe "the MCP tool" do
    it "comments as add_task_comment does" do
      other = create(:task)
      answered = comment(task.id, body: "the same")

      expect(mcp_answer("add_task_comment", id: other.id, body: "the same").except("id", "created_at"))
        .to eq(answered.except("id", "created_at"))
    end

    it "refuses with the message the endpoint gives" do
      refused = comment(task.id, body: " ")

      expect(mcp_text("add_task_comment", id: task.id, body: " ")).to eq(refused.fetch("message"))
    end
  end
end
