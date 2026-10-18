# frozen_string_literal: true

RSpec.describe "API reading a tag", type: :request do
  def ids(answer, kind) = records(answer, kind).map { it.fetch("id") }

  def kinds = %w[posts projects tasks journal_entries decisions]

  def read(name, **query)
    headers = { "HTTP_ACCEPT" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{api_token}" }
    get "/api/v1/tags/#{name}", query, headers
    JSON.parse(last_response.body)
  end

  def records(answer, kind) = answer.fetch(kind).fetch("records")

  def titles(answer, kind) = records(answer, kind).map { it.fetch("title") }

  describe "GET /api/v1/tags/:name" do
    describe "a name both scopes hold" do
      let!(:records_by_kind) do
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

        expect(records_by_kind.to_h { |kind, _| [kind, ids(answer, kind)] })
          .to eq(records_by_kind.transform_values { [it.id] })
      end

      it "counts each kind" do
        expect(read("ruby").fetch("counts")).to eq(records_by_kind.transform_values { 1 })
      end

      it "gives the opening of each journal entry" do
        expect(records(read("ruby"), "journal_entries").map { it.fetch("opening") }).to eq(["Wrote some ruby"])
      end

      it "reads the name however it is cased" do
        expect(titles(read("Ruby"), "posts")).to eq(["Ruby on a Pi"])
      end

      it "answers one kind when asked for it" do
        expect(read("ruby", kind: "tasks").slice("posts", "tasks").keys).to eq(["tasks"])
      end

      it "answers the same JSON as read_tag" do
        expect(trusted(mcp_answer("read_tag", name: "ruby"))).to eq(read("ruby"))
      end
    end

    describe "a tag on more records than a page holds" do
      before do
        lower_page_size(:mcp, to: 2)
        %w[One Two Three].each { create(:task, title: it, tags: %w[ruby]) }
        create(:decision, title: "Pick a ruby", tags: %w[ruby])
      end

      it "counts every record while it pages" do
        expect(read("ruby").fetch("counts")).to include("tasks" => 3, "decisions" => 1)
      end

      it "marks a kind with more partial and names the next page", :aggregate_failures do
        answer = read("ruby")

        expect(answer.fetch("tasks").except("records")).to eq("partial" => true, "next_page" => 2)
        expect(answer.fetch("decisions").except("records")).to eq("partial" => false)
      end

      it "reaches every record by paging one kind" do
        first = read("ruby", kind: "tasks")
        rest = read("ruby", kind: "tasks", page: first.dig("tasks", "next_page"))

        expect(titles(first, "tasks") + titles(rest, "tasks")).to contain_exactly("One", "Two", "Three")
      end

      it "ends the last page" do
        expect(read("ruby", kind: "tasks", page: 2).fetch("tasks")).to include("partial" => false)
      end
    end

    describe "drafts and closed records" do
      def statuses(kind, field = "title") = records(read("ruby"), kind).map { it.values_at(field, "status") }

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
      create(:tag, :private, name: "unused", description: "kept for later")

      expect(read("unused")).to eq(
        "name" => "unused", "descriptions" => { "public" => nil, "private" => "kept for later" },
        "counts" => kinds.to_h { [it, 0] }, **kinds.to_h { [it, { "records" => [], "partial" => false }] },
      )
    end

    it "refuses a kind it does not know" do
      create(:tag, name: "ruby")

      expect([read("ruby", kind: "people").fetch("error"), status]).to eq(["invalid", 422])
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
