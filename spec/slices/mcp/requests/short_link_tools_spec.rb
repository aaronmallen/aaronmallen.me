# frozen_string_literal: true

RSpec.describe "MCP short link tools", type: :request do
  def link(destination = "https://example.com/talk", clicks: 0, **)
    Shares::Slice["operations.create_short_link"].call({ destination:, ** }).value!.tap do |made|
      relation.by_pk(made.id).update(click_count: clicks)
    end
  end

  def links = relation.with_code.to_a

  def refusal(name, **) = mcp_call(name, **).values_at("isError", "content").then { [it[0], it[1].first["text"]] }

  def refused?(name, scope)
    mcp_rpc("tools/call", { name:, arguments: {} })
    mcp_reply.dig("error", "data").start_with?("#{name} needs the #{scope} permission,")
  end

  def relation = Shares::Slice["relations.short_links"]

  describe "list_short_links" do
    def titles(**) = mcp_answer("list_short_links", **).fetch("short_links").map { it.dig("title", "text") }

    it "lists each link with its short link, destination and marked title" do
      made = link(code: "talk-now", title: "My talk", clicks: 3)
      row = { "id" => made.id, "code" => "talk-now", "url" => "http://shares.localhost/talk-now",
              "destination" => "https://example.com/talk", "title" => marked("My talk"), "click_count" => 3 }

      expect(mcp_answer("list_short_links")).to include("count" => 1, "short_links" => [include(row)])
    end

    context "with several links" do
      before do
        link("https://example.com/a", title: "Alpha", clicks: 1)
        link("https://example.com/b", title: "Beta", clicks: 9)
        link("https://example.org/c", title: "Gamma", clicks: 5)
      end

      it "sorts by clicks" do
        expect(titles(sort: "clicks")).to eq(%w[Beta Gamma Alpha])
      end

      it "finds words in the destination" do
        expect(titles(query: "example.com")).to eq(%w[Beta Alpha])
      end
    end
  end

  describe "create_short_link" do
    it "makes a link to the destination" do
      made = mcp_answer("create_short_link", destination: " https://example.com/new ")

      expect([made.fetch("destination"), links.map { it[:id] }]).to eq(["https://example.com/new", [made.fetch("id")]])
    end

    it "answers with the link a destination already has and makes no second one", :aggregate_failures do
      made = link("https://example.com/talk", code: "talk-now")

      expect(mcp_answer("create_short_link", destination: "https://example.com/talk"))
        .to include("id" => made.id, "code" => "talk-now")
      expect(links.size).to eq(1)
    end

    it "refuses a destination that is not a web address", :aggregate_failures do
      expect(refusal("create_short_link", destination: "ftp://example.com"))
        .to eq([true, "destination: destination is a web address that starts with http:// or https://"])
      expect(links).to be_empty
    end
  end

  describe "update_short_link" do
    let!(:made) { link("https://example.com/talk", code: "talk-now", title: "My talk") }

    it "changes only the fields it is given" do
      expect(mcp_answer("update_short_link", id: made.id, destination: "https://example.com/v2")).to include(
        "destination" => "https://example.com/v2", "code" => "talk-now", "title" => marked("My talk"),
        "retargeted_at" => be_a(String),
      )
    end

    it "gives the link a new code and title" do
      answered = mcp_answer("update_short_link", id: made.id, code: "talk-later", title: "Later")

      expect(answered.values_at("code", "url", "title"))
        .to eq(["talk-later", "http://shares.localhost/talk-later", marked("Later")])
    end

    it "refuses a code another link holds" do
      link("https://example.com/other", code: "taken")

      expect(refusal("update_short_link", id: made.id, code: "taken"))
        .to eq([true, "code: another share or short link already has this code"])
    end

    it "refuses a link that does not exist" do
      expect(refusal("update_short_link", id: 999_999, title: "Gone")).to eq([true, "no short link has the ID 999999"])
    end
  end

  describe "with read but not publish" do
    def mcp_scopes = %w[read write delete]

    it "lists links" do
      expect(mcp_answer("list_short_links").fetch("count")).to eq(0)
    end

    it "refuses each change, naming publish" do
      expect(%w[create_short_link update_short_link].map { refused?(it, "publish") }).to all(be(true))
    end
  end

  describe "with publish but not read" do
    def mcp_scopes = %w[publish]

    it "refuses list_short_links, naming read" do
      expect(refused?("list_short_links", "read")).to be(true)
    end
  end
end
