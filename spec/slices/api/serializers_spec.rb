# frozen_string_literal: true

RSpec.describe "API serializers", type: :request do
  def access_token
    @access_token ||= mcp_connect(create(:oauth_client), verifier: MCP::OAuth::Secret.generate, scope: "read write")
                      .fetch("access_token")
  end

  def call_tool(name, **arguments)
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{access_token}" }
    body = { jsonrpc: "2.0", id: 1, method: "tools/call", params: { name:, arguments: } }
    post "/mcp", JSON.generate(body), headers
  end

  def content = trusted(JSON.parse(JSON.parse(last_response.body).dig("result", "content", 0, "text")))

  def serialized(serializer, object, **params) = JSON.parse(serializer.new(object, params:).serialize)

  def today = Blog::TimeZone.today

  describe API::Serializers::JournalEntry do
    it "gives the JSON read_journal_entry returns, less its record links" do
      entry = create(:journal_entry, entry_time: "21:15", body: "a **bold** day")
      Record::Slice["repos.journal_entry_repo"].replace_tags(entry.id, %w[health ruby])
      call_tool("read_journal_entry", id: entry.id)

      expect(serialized(described_class, Record::Slice["queries.journal_entry_by_id"].call(entry.id)))
        .to eq(content.except("record_links"))
    end
  end

  describe API::Serializers::Task do
    def read(id)
      call_tool("read_task", id:)
      serialized(described_class, Tasks::Slice["queries.task_by_id"].call(id))
    end

    it "gives the JSON read_task returns, less its comments, record links and timeline" do
      done = create(:task, :done, :carried, title: "finished", note: "a note", tags: %w[admin])
      create(:task_link, from_task_id: create(:task, title: "blocker").id, to_task_id: done.id)
      create(:task_link, :relates, from_task_id: done.id, to_task_id: create(:task, :in_sprint).id)

      expect(read(done.id)).to eq(content.except("comments", "record_links", "timeline"))
    end

    it "gives the sprint day of a task in a sprint" do
      task = create(:task, :in_sprint, sprint_id: create(:sprint, sprint_date: today).id)

      expect(read(task.id)).to eq(content.except("comments", "record_links", "timeline"))
    end

    it "gives the sprint day it is handed, as read_current_sprint lists tasks" do
      sprint = create(:sprint, sprint_date: today)
      create(:task, :in_sprint, sprint_id: sprint.id, title: "today's work")
      call_tool("read_current_sprint")
      tasks = Tasks::Slice["queries.tasks_in_sprint"].call(sprint.id)

      expect(serialized(described_class, tasks, sprint_on: today)).to eq(content.fetch("tasks"))
    end
  end

  describe API::Serializers::TaskComment do
    def read(id)
      call_tool("read_task", id:)
      serialized(described_class, Tasks::Slice["queries.task_comments"].call(id))
    end

    it "gives the JSON read_task returns for each comment, local and synced" do
      task = create(:task)
      create(:task_comment, task_id: task.id, body: "mine")
      create(:task_comment, :synced, task_id: task.id, body: "theirs")

      expect(read(task.id)).to eq(content.fetch("comments"))
    end
  end

  describe API::Serializers::Sprint do
    def first_page = Blog::Page.new(number: 1, size: 50)

    it "gives the JSON read_current_sprint returns, less its tasks" do
      create(:sprint, sprint_date: today, carried_in: 3)
      call_tool("read_current_sprint")

      expect(serialized(described_class, Tasks::Slice["repos.sprint_repo"].on(today))).to eq(content.except("tasks"))
    end

    it "gives the JSON list_sprints returns for each sprint" do
      [today, today + 1].each { create(:sprint, sprint_date: it) }
      call_tool("list_sprints")
      found = Tasks::Slice["queries.sprints_between"].call(from: today, to: nil, page: first_page)

      expect(serialized(described_class, found.rows)).to eq(content.fetch("sprints"))
    end
  end
end
