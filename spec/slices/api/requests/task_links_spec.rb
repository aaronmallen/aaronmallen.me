# frozen_string_literal: true

RSpec.describe "API task links", type: :request do
  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def call_api(verb, path, body = nil, token: api_token)
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json" }
    headers["HTTP_AUTHORIZATION"] = "Bearer #{token}" if token
    public_send(verb, "/api/v1/tasks#{path}", body, headers)
    JSON.parse(last_response.body)
  end

  def link(id, token: api_token, **fields) = call_api(:post, "/#{id}/links", JSON.generate(fields), token:)

  def status = last_response.status

  def tasks = Tasks::Slice["repos.task_repo"]

  def unlink(id, other_id) = call_api(:delete, "/#{id}/links/#{other_id}")

  let(:task) { create(:task, title: "Ship") }
  let(:other) { create(:task, title: "Migrate") }

  describe "POST /api/v1/tasks/:id/links" do
    it "answers 201 with the task and its new link" do
      answered = link(task.id, kind: "relates", other_id: other.id)

      expect([answered.fetch("links"), status]).to eq(
        [[{ "label" => "relates", "id" => other.id, "title" => "Migrate", "status" => "open" }], 201],
      )
    end

    it "stores a blocked_by link from the other end" do
      link(task.id, kind: "blocked_by", other_id: other.id)

      expect(tasks.by_id(other.id).links.map(&:label)).to eq(%w[blocks])
    end

    it "refuses a link to itself with a 422 naming the field" do
      expect([link(task.id, kind: "relates", other_id: task.id).fetch("errors"), status])
        .to eq([{ "other_id" => ["a task cannot link to itself"] }, 422])
    end

    it "refuses a second link between the same pair with a 422" do
      create(:task_link, from_task_id: other.id, to_task_id: task.id)

      expect(link(task.id, kind: "relates", other_id: other.id).fetch("message"))
        .to eq("other_id: these two tasks are already linked")
    end

    it "refuses a task on the other end that is gone with a 422" do
      expect([link(task.id, kind: "relates", other_id: 999_999).fetch("errors"), status])
        .to eq([{ "other_id" => ["that task is gone, so find another"] }, 422])
    end

    it "refuses a task on the other end past the integer range as one that is gone" do
      expect([link(task.id, kind: "relates", other_id: 2**31).fetch("errors"), status])
        .to eq([{ "other_id" => ["that task is gone, so find another"] }, 422])
    end

    it "refuses a kind it does not know with a 422" do
      expect([link(task.id, kind: "follows", other_id: other.id).fetch("errors").keys, status])
        .to eq([%w[kind], 422])
    end

    it "refuses a request with no other task" do
      expect(link(task.id, kind: "relates").fetch("errors")).to eq("other_id" => ["other_id is missing"])
    end

    it "answers an unknown task with a 404" do
      expect([link(999_999, kind: "relates", other_id: other.id).fetch("message"), status])
        .to eq(["no task has the ID 999999", 404])
    end

    it "refuses a request with no token" do
      link(task.id, kind: "relates", other_id: other.id, token: nil)

      expect([status, tasks.by_id(task.id).links]).to eq([401, []])
    end
  end

  describe "DELETE /api/v1/tasks/:id/links/:other_id" do
    it "removes the link from whichever end" do
      create(:task_link, from_task_id: other.id, to_task_id: task.id)

      expect([unlink(task.id, other.id).fetch("links"), status]).to eq([[], 200])
    end

    it "answers a pair with no link with a 404" do
      expect([unlink(task.id, other.id).fetch("message"), status])
        .to eq(["task #{task.id} has no link to task #{other.id}", 404])
    end

    it "refuses another task ID that is not a number with a 422" do
      expect([unlink(task.id, "abc").fetch("errors").keys, status]).to eq([%w[other_id], 422])
    end
  end

  describe "the MCP tools" do
    it "link as link_tasks does" do
      linked = link(task.id, kind: "blocks", other_id: other.id)
      call_api(:delete, "/#{task.id}/links/#{other.id}")

      expect(mcp_answer("link_tasks", id: task.id, kind: "blocks", other_id: other.id)).to eq(linked)
    end

    it "unlink as unlink_task does" do
      create(:task_link, from_task_id: other.id, to_task_id: task.id)
      unlinked = unlink(task.id, other.id)
      create(:task_link, from_task_id: other.id, to_task_id: task.id)

      expect(mcp_answer("unlink_task", id: task.id, other_id: other.id)).to eq(unlinked)
    end

    it "refuse with the message the endpoint gives" do
      refused = link(task.id, kind: "relates", other_id: task.id)

      expect(mcp_text("link_tasks", id: task.id, kind: "relates", other_id: task.id)).to eq(refused.fetch("message"))
    end
  end
end
