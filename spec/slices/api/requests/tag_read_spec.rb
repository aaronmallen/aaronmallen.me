# frozen_string_literal: true

RSpec.describe "API reading a tag", type: :request do
  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def ids(answer, kind) = answer.fetch(kind).map { it.fetch("id") }

  def read(name)
    headers = { "HTTP_ACCEPT" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{api_token}" }
    get "/api/v1/tags/#{name}", nil, headers
    JSON.parse(last_response.body)
  end

  def status = last_response.status

  def titles(answer, kind) = answer.fetch(kind).map { it.fetch("title") }

  describe "GET /api/v1/tags/:name" do
    describe "a name both scopes hold" do
      let!(:records) do
        {
          "posts" => create(:post, :published, title: "Ruby on a Pi", tags: %w[ruby]),
          "projects" => create(:project, name: "ruby-gem", tags: %w[ruby]),
          "tasks" => create(:task, title: "Bump ruby", tags: %w[ruby]),
          "journal_entries" => create(:journal_entry, body: "Wrote some ruby", tags: %w[ruby]),
          "decisions" => create(:decision, title: "Pick a ruby", tags: %w[ruby]),
        }
      end

      before do
        create(:post, :published, title: "Rust on a Pi", tags: %w[rust])
        create(:task, title: "Bump rust", tags: %w[rust])
      end

      it "answers 200 with the name" do
        expect([read("ruby").fetch("name"), status]).to eq(["ruby", 200])
      end

      it "groups every kind with the name and nothing else" do
        answer = read("ruby")

        expect(records.to_h { |kind, _| [kind, ids(answer, kind)] }).to eq(records.transform_values { [it.id] })
      end

      it "reads the name however it is cased" do
        expect(titles(read("Ruby"), "posts")).to eq(["Ruby on a Pi"])
      end

      it "answers the same JSON as read_tag" do
        expect(trusted(mcp_answer("read_tag", name: "ruby"))).to eq(read("ruby"))
      end
    end

    describe "drafts and closed records" do
      def statuses(kind, field = "title") = read("ruby").fetch(kind).map { it.values_at(field, "status") }

      before do
        create(:post, :draft, title: "A ruby draft", tags: %w[ruby])
        create(:project, :archived, name: "old-gem", tags: %w[ruby])
        create(:task, :done, title: "Shipped ruby", tags: %w[ruby])
        create(:task, :canceled, title: "Dropped ruby", tags: %w[ruby])
        create(:decision, title: "Ruby or not", status: "dropped", tags: %w[ruby])
      end

      it "gives each its status", :aggregate_failures do
        expect(statuses("posts")).to eq([["A ruby draft", "draft"]])
        expect(statuses("projects", "name")).to eq([%w[old-gem archived]])
        expect(statuses("decisions")).to eq([["Ruby or not", "dropped"]])
      end

      it "lists done and canceled tasks" do
        expect(statuses("tasks")).to contain_exactly(["Shipped ruby", "done"], ["Dropped ruby", "canceled"])
      end
    end

    it "answers a tag nothing carries with empty kinds" do
      create(:tag, :private, name: "unused")

      expect(read("unused")).to eq(
        "name" => "unused", "posts" => [], "projects" => [], "tasks" => [], "journal_entries" => [], "decisions" => [],
      )
    end

    it "answers a blank name with a 404" do
      expect([read("%20").fetch("error"), status]).to eq(["not_found", 404])
    end

    it "answers a name no tag holds with a 404" do
      expect([read("nothing"), status])
        .to eq([{ "error" => "not_found", "message" => "no tag has the name nothing" }, 404])
    end
  end
end
