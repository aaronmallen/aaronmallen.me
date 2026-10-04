# frozen_string_literal: true

RSpec.describe "API search", type: :request do
  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def find(token: api_token, **params)
    headers = { "HTTP_ACCEPT" => "application/json" }
    headers["HTTP_AUTHORIZATION"] = "Bearer #{token}" if token
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
      hit = Search::Slice["queries.search"].call(text: "track", page: Blog::Page.new(number: 1, size: 1)).rows.first

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

  it "answers nothing for a blank query" do
    create(:task, title: "Track the zeppelin")

    expect(find(query: "  ")).to eq("count" => 0, "results" => [], "partial" => false)
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

  it "refuses a request with no token" do
    find(query: "zeppelin", token: nil)

    expect(status).to eq(401)
  end
end
