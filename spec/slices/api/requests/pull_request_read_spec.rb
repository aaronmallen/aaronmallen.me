# frozen_string_literal: true

RSpec.describe "API reading a pull request", type: :request do
  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def read(id)
    headers = { "HTTP_ACCEPT" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{api_token}" }
    get "/api/v1/pull_requests/#{id}", nil, headers
    JSON.parse(last_response.body)
  end

  def shown(pull_request)
    {
      "id" => pull_request.id, "repo" => "aaronmallen/blog", "number" => 4, "title" => "Fix the feed",
      "description" => "It broke", "url" => "https://github.com/aaronmallen/blog/pull/4", "state" => "merged",
      "ready_at" => "2026-03-02T14:05:00Z", "merged_at" => "2026-03-03T09:00:00Z", "closed_at" => nil,
    }
  end

  def status = last_response.status

  def whole_pull_request
    create(
      :pull_request,
      repo: "aaronmallen/blog", number: 4, title: "Fix the feed", body: "It broke",
      ready_at: Time.utc(2026, 3, 2, 14, 5), merged_at: Time.utc(2026, 3, 3, 9),
    )
  end

  describe "GET /api/v1/pull_requests/:id" do
    it "answers the pull request with its state and times" do
      merged = whole_pull_request

      expect([read(merged.id), status]).to eq([shown(merged), 200])
    end

    it "answers the same JSON as read_pull_request" do
      opened = create(:pull_request)

      expect(read(opened.id)).to eq(mcp_answer("read_pull_request", id: opened.id))
    end

    it "answers an unknown ID with a 404" do
      expect([read(999_999), status])
        .to eq([{ "error" => "not_found", "message" => "no pull request has the ID 999999" }, 404])
    end
  end
end
