# frozen_string_literal: true

RSpec.describe "MCP task tools", type: :request do
  def access_token
    @access_token ||= mcp_connect(create(:oauth_client), verifier: Blog::SecretToken.generate, scope: "read write")
                      .fetch("access_token")
  end

  def call_tool(name, **arguments)
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{access_token}" }
    body = { jsonrpc: "2.0", id: 1, method: "tools/call", params: { name:, arguments: } }
    post "/mcp", JSON.generate(body), headers
  end

  def message = result.fetch("content").first.fetch("text")

  def refused? = result["isError"] == true

  def result = JSON.parse(last_response.body).fetch("result")

  it "refuses a list_tasks list it does not know as an error" do
    call_tool("list_tasks", lists: %w[nowhere])

    expect(refused?).to be(true)
  end

  it "lists the tasks planned into a sprint day with the total that match" do
    sprint = create(:sprint, sprint_date: Blog::TimeZone.today + 2)
    task = create(:task, :in_sprint, sprint_id: sprint.id)
    create(:task)
    call_tool("list_tasks", sprint_on: sprint.sprint_date.iso8601)

    expect(JSON.parse(message)).to include("total" => 1, "tasks" => [include("id" => task.id)])
  end

  %w[start_task complete_task reopen_task cancel_task delete_task].each do |name|
    it "refuses #{name} on a task that is not there as an error", :aggregate_failures do
      call_tool(name, id: 999_999)

      expect(refused?).to be(true)
      expect(message).to eq("no task has the ID 999999")
    end
  end
end
