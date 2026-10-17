# frozen_string_literal: true

RSpec.describe "API reading a commit", type: :request do
  def link(id, other_kind, other_id)
    Links::Slice["operations.link_records"].call("commit", id, { other_kind:, other_id: }).value!
  end

  def read(id)
    headers = { "HTTP_ACCEPT" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{api_token}" }
    get "/api/v1/commits/#{id}", nil, headers
    JSON.parse(last_response.body)
  end

  def shown(commit)
    {
      "id" => commit.id, "sha" => "a" * 40, "repo" => "aaronmallen/blog", "branch" => "main",
      "message" => "fix the feed\n\nthe body runs on", "date" => "2026-03-02", "time" => "14:05",
      "additions" => 12, "deletions" => 3, "record_links" => {},
    }
  end

  def whole_commit
    create(
      :commit,
      sha: "a" * 40, repo: "aaronmallen/blog", branch: "main", message: "fix the feed\n\nthe body runs on",
      commit_date: Date.new(2026, 3, 2), commit_time: "14:05", additions: 12, deletions: 3,
    )
  end

  describe "GET /api/v1/commits/:id" do
    it "answers the commit with its whole message" do
      commit = whole_commit

      expect([read(commit.id), status]).to eq([shown(commit), 200])
    end

    it "answers the records linked to the commit, grouped by kind" do
      commit = create(:commit)
      task = create(:task, title: "Move the server")
      link(commit.id, "task", task.id)

      expect(read(commit.id).fetch("record_links"))
        .to match("task" => [include("kind" => "task", "id" => task.id, "title" => "Move the server")])
    end

    it "answers what read_commit answers, less the untrusted marks" do
      commit = create(:commit)
      link(commit.id, "post", create(:post).id)

      expect(read(commit.id)).to eq(trusted(mcp_answer("read_commit", id: commit.id)))
    end
  end
end
