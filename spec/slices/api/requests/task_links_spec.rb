# frozen_string_literal: true

RSpec.describe "API task links", type: :request do
  def link(id, **fields) = call_api(:post, "/tasks/#{id}/links", JSON.generate(fields))

  def status = last_response.status

  def tasks = Tasks::Slice["repos.task_queries"]

  def unlink(id, other_id) = call_api(:delete, "/tasks/#{id}/links/#{other_id}")

  let(:task) { create(:task, title: "Ship") }
  let(:other) { create(:task, title: "Migrate") }

  describe "POST /api/v1/tasks/:id/links" do
    it "answers 201 with the task and its new link" do
      answered = link(task.id, kind: "relates", other_id: other.id)

      linked = { "label" => "relates", "id" => other.id, "task_label" => tasks.by_id(other.id).label }

      expect([answered.fetch("links"), status]).to eq([[linked.merge("title" => "Migrate", "status" => "open")], 201])
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

    it "refuses a task on the other end past the integer range with a 422 naming the field" do
      expect([link(task.id, kind: "relates", other_id: 2**31).fetch("errors"), status])
        .to eq([{ "other_id" => ["number at `/other_id` is greater than: 2147483647"] }, 422])
    end

    it "stores the link as made by hand, not by the sync" do
      link(task.id, kind: "relates", other_id: other.id)

      expect(Tasks::Slice["relations.task_links"].between(task.id, other.id).pluck(:synced)).to eq([false])
    end

    it "refuses a parent kind, which only the sync writes, with a 422" do
      expect([link(task.id, kind: "parent", other_id: other.id).fetch("errors").keys, status])
        .to eq([%w[kind], 422])
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
  end

  describe "a parent link" do
    def read(id) = call_api(:get, "/tasks/#{id}")

    before { create(:task_link, :parent, from_task_id: task.id, to_task_id: other.id) }

    it "reads parent_of on the parent" do
      expect(read(task.id).fetch("links").map { it.values_at("label", "id") }).to eq([["parent_of", other.id]])
    end

    it "reads child_of on the child" do
      expect(read(other.id).fetch("links").map { it.values_at("label", "id") }).to eq([["child_of", task.id]])
    end

    it "reads the same over MCP" do
      expect(unstamped(trusted(mcp_answer("read_task", id: other.id)))).to eq(unstamped(read(other.id)))
    end
  end

  describe "the MCP tools" do
    it "link as link_tasks does" do
      linked = link(task.id, kind: "blocks", other_id: other.id)
      call_api(:delete, "/tasks/#{task.id}/links/#{other.id}")

      expect(unstamped(trusted(mcp_answer("link_tasks", id: task.id, kind: "blocks", other_id: other.id))))
        .to eq(unstamped(linked))
    end

    it "unlink as unlink_task does" do
      create(:task_link, from_task_id: other.id, to_task_id: task.id)
      unlinked = unlink(task.id, other.id)
      create(:task_link, from_task_id: other.id, to_task_id: task.id)

      expect(unstamped(trusted(mcp_answer("unlink_task", id: task.id, other_id: other.id)))).to eq(unstamped(unlinked))
    end

    it "refuse with the message the endpoint gives" do
      refused = link(task.id, kind: "relates", other_id: task.id)

      expect(mcp_text("link_tasks", id: task.id, kind: "relates", other_id: task.id)).to eq(refused.fetch("message"))
    end
  end
end
