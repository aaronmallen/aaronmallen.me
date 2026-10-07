# frozen_string_literal: true

RSpec.describe "API search", type: :request do
  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def find(**params)
    headers = { "HTTP_ACCEPT" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{api_token}" }
    get "/api/v1/search", params, headers
    JSON.parse(last_response.body)
  end

  def results(**) = find(**).fetch("results")

  def screen_titles(**params)
    sign_in_to_admin
    get "/admin/search", params
    Capybara.string(last_response.body).all(".li-title").map(&:text)
  end

  def status = last_response.status

  describe "a phrase several kinds hold" do
    let!(:task) { create(:task, :done, title: "Track the zeppelin") }

    before do
      create(:post, :published, title: "Zeppelins", body: "A post")
      create(:message, :read, subject: "Zeppelin sighting")
      create(:task, title: "Call the plumber")
    end

    it "lists every match and nothing else" do
      expect(results(query: "zeppelin").map { it.fetch("title") })
        .to contain_exactly("Track the zeppelin", "Zeppelins", "Zeppelin sighting")
    end

    it "gives each result its kind, id, title, short match and date" do
      expect(results(query: "zeppelin").map(&:keys).uniq).to eq([%w[kind id title match date]])
    end

    it "gives a result the values search found for it" do
      page = Blog::Page.new(number: 1, size: 1)
      hit = Search::Slice["repos.search_queries"].search(text: "track", page:).rows.first

      expect(results(query: "track").map { it.values_at("kind", "id", "title", "match", "date") })
        .to eq([["task", task.id, "Track the zeppelin", hit.match, hit.day.iso8601]])
    end

    it "lists the records the search screen lists, in the same order" do
      expect(results(query: "zeppelin").map { it.fetch("title") }).to eq(screen_titles(q: "zeppelin"))
    end

    it "narrows to one kind, as the screen does" do
      expect(results(query: "zeppelin", kind: "message").map { it.fetch("title") })
        .to eq(screen_titles(q: "zeppelin", kind: "message"))
    end

    it "gives an id the kind's read tool takes" do
      id = results(query: "track").first.fetch("id")

      expect(mcp_answer("read_task", id:).fetch("title")).to eq("Track the zeppelin")
    end

    it "answers the MCP tool with the same JSON" do
      expect(trusted(mcp_answer("search", query: "zeppelin",
                                          kind: "task"))).to eq(find(query: "zeppelin", kind: "task"))
    end
  end

  describe "paging" do
    before do
      lower_page_size(:admin, to: 2)
      3.times { create(:task, title: "Call the plumber #{it}") }
      create(:message, subject: "Plumber invoice")
    end

    it "answers a page and the number of the next", :aggregate_failures do
      found = find(query: "plumber", kind: "task")

      expect(found.fetch("count")).to eq(2)
      expect(found.values_at("partial", "next_page")).to eq([true, 2])
    end

    it "answers the last page with nothing more to read", :aggregate_failures do
      found = find(query: "plumber", kind: "task", page: 2)

      expect(found.fetch("count")).to eq(1)
      expect(found).to include("partial" => false)
      expect(found).not_to have_key("next_page")
    end

    it "lists on each page the records the screen lists on it" do
      [1, 2].each do |page|
        expect(results(query: "plumber", page:).map { it.fetch("title") })
          .to eq(screen_titles(q: "plumber", page:))
      end
    end

    it "answers the MCP tool with the same page" do
      expect(trusted(mcp_answer("search", query: "plumber", page: 2))).to eq(find(query: "plumber", page: 2))
    end
  end

  describe "a record the admin keeps private or closed" do
    def found(query) = results(query:).map { it.values_at("kind", "id") }

    it "finds a journal entry" do
      entry = create(:journal_entry, body: "Walked the levee at dawn")

      expect(found("levee")).to eq([["journal", entry.id]])
    end

    it "finds a closed task" do
      task = create(:task, :done, title: "Renew the passport")

      expect(found("passport")).to eq([["task", task.id]])
    end

    it "finds a canceled task" do
      task = create(:task, :canceled, title: "Repaint the porch")

      expect(found("porch")).to eq([["task", task.id]])
    end

    it "finds a commit from a private repo" do
      commit = create(:commit, repo: "aaronmallen/secret-lab", message: "Wire the thermostat relay")

      expect(found("thermostat")).to eq([["commit", commit.id]])
    end

    it "finds a read message" do
      message = create(:message, :read, subject: "Hello", body: "Loved your piece on sourdough")

      expect(found("sourdough")).to eq([["message", message.id]])
    end

    it "finds a draft post" do
      post = create(:post, :draft, title: "Notes on kayaks", body: "Half done")

      expect(found("kayaks")).to eq([["post", post.id]])
    end
  end

  describe "a phrase every kind holds" do
    before do
      create(:task, title: "Open task", note: "about zeppelins")
      create(:post, :published, title: "Zeppelins", body: "A post")
      create(:social_post_part, social_post_id: create(:social_post, :posted).id, body: "Saw a zeppelin")
      create(:journal_entry, body: "Dreamt of zeppelins")
      create(:commit, message: "Draw the zeppelin")
      create(:project, name: "airship", tagline: "Zeppelin tracker")
      create(:work_entry, org: "Zeppelin Works", role: "Pilot")
      create(:person, name: "Zeppelin Fan")
      create(:message, subject: "Zeppelins", body: "Hi there")
      create(:webmention, excerpt: "Nice zeppelin")
    end

    it "finds one of each" do
      expect(results(query: "zeppelin").map { it.fetch("kind") }).to match_array(Blog::Types::SearchKind.values)
    end
  end

  describe "what a result carries" do
    def only(query) = results(query:).tap { expect(it.length).to eq(1) }.first

    describe "a long post" do
      let!(:post) { create(:post, :published, title: "Bread", body: "#{'flour ' * 200}crumb #{'salt ' * 200}") }

      it "carries its title" do
        expect(only("crumb").fetch("title")).to eq("Bread")
      end

      it "carries a short match around the phrase" do
        expect(only("crumb").fetch("match")).to include("crumb")
      end

      it "carries the day it went out" do
        expect(only("crumb").fetch("date")).to eq(Blog::TimeZone.local(post.published_at).to_date.iso8601)
      end
    end

    it "keeps the match short" do
      create(:journal_entry, body: "#{'rain ' * 100}garden")

      expect(only("garden").fetch("match").split.length).to be <= 24
    end

    it "leaves markup out of the match" do
      create(:journal_entry, body: "Fed the ducks")

      expect(only("ducks").fetch("match")).to eq("Fed the ducks")
    end

    it "takes the date of a journal entry from its day" do
      create(:journal_entry, body: "Bought a canoe", entry_date: Blog::TimeZone.today - 30)

      expect(only("canoe").fetch("date")).to eq((Blog::TimeZone.today - 30).iso8601)
    end

    it "takes the date of an open task from when it was made" do
      create(:task, title: "Find the ladder")

      expect(only("ladder").fetch("date")).to eq(Blog::TimeZone.today.iso8601)
    end

    it "gives the first line of a commit as its title" do
      create(:commit, message: "Fix the gutter\n\nIt leaked")

      expect(only("leaked").fetch("title")).to eq("Fix the gutter")
    end
  end

  describe "a social post with several parts" do
    let(:social_post) { create(:social_post, :posted) }

    before do
      create(:social_post_part, social_post_id: social_post.id, body: "Otters are out")
      create(:social_post_part, social_post_id: social_post.id, body: "Otters otters otters")
    end

    it "comes back once, as the part that matches best" do
      expect(results(query: "otters").map { it.values_at("id", "title") })
        .to eq([[social_post.id, "Otters otters otters"]])
    end
  end

  describe "the order" do
    it "ranks a title match above a match in the text" do
      create(:task, title: "Errands", note: "Pick up the mangoes")
      create(:task, title: "Mangoes")

      expect(results(query: "mangoes").map { it.fetch("title") }).to eq(%w[Mangoes Errands])
    end

    it "puts the newer one first on a tie" do
      today = Blog::TimeZone.today
      create(:journal_entry, body: "Lemons", entry_date: today - 2)
      create(:journal_entry, body: "Lemons", entry_date: today - 1)

      expect(results(query: "lemons").map { it.fetch("date") }).to eq([today - 1, today - 2].map(&:iso8601))
    end
  end

  describe "the phrase" do
    it "matches a word by its stem" do
      create(:journal_entry, body: "Running at noon")

      expect(results(query: "runs").length).to eq(1)
    end

    it "leaves out a word the phrase rules out" do
      create(:journal_entry, body: "Plums and figs")
      create(:journal_entry, body: "Plums alone")

      expect(results(query: "plums -figs").map { it.fetch("title") }).to eq(["Plums alone"])
    end
  end

  it "answers nothing for a blank query" do
    create(:task, title: "Track the zeppelin")

    expect(find(query: "  ")).to eq("count" => 0, "results" => [], "partial" => false)
  end

  it "answers nothing for a phrase of stop words" do
    create(:journal_entry, body: "The and of")

    expect(find(query: "the").fetch("results")).to eq([])
  end

  it "refuses a request with no query", :aggregate_failures do
    find

    expect(status).to eq(422)
    expect(JSON.parse(last_response.body).dig("errors", "query")).to eq(["query is missing"])
  end

  it "refuses a kind it does not know" do
    find(query: "zeppelin", kind: "spaceship")

    expect(status).to eq(422)
  end
end
