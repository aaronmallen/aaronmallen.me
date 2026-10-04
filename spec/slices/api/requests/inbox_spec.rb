# frozen_string_literal: true

RSpec.describe "API inbox", type: :request do
  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def issue_url = "https://github.com/aaronmallen/aaronmallen.me/issues/1"

  def read
    headers = { "HTTP_ACCEPT" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{api_token}" }
    get "/api/v1/inbox", {}, headers
    JSON.parse(last_response.body)
  end

  def rows = read.fetch("inbox")

  def screen_titles
    sign_in_to_admin
    get "/admin/inbox"
    Capybara.string(last_response.body).all(".li .li-title").map(&:text)
  end

  def source_url = "https://example.com/a"

  def status = last_response.status

  def synced(*traits, title: "A synced issue", created_at: Time.now, seen_at: nil)
    create(:task, *traits, title:, list: "external", created_at:).tap do |task|
      create(:task_source, task:, seen_at:, url: issue_url)
    end
  end

  describe "with one row of each kind" do
    let!(:records) do
      {
        task: synced(title: "Oldest", created_at: Time.now - 120),
        message: create(:message, subject: "Middle", body: "Hello there", received_at: Time.now - 60),
        webmention: create(:webmention, author_name: "Newest", excerpt: "Nice post", source_url:,
                                        received_at: Time.now),
      }
    end

    it "lists each row newest first with its kind and the id its tools take" do
      ids = records.values_at(:webmention, :message, :task).map(&:id)

      expect(rows.map { it.values_at("kind", "id") })
        .to eq([["webmention", ids[0]], ["message", ids[1]], ["task", ids[2]]])
    end

    it "gives each row its title, excerpt and link" do
      expect(rows.map { it.values_at("title", "excerpt", "url") })
        .to eq([["Newest", "Nice post", source_url], ["Middle", "Hello there", nil],
                ["Oldest", nil, issue_url]])
    end

    it "gives each row its time" do
      expect(Time.iso8601(rows[1].fetch("at"))).to be_within(1).of(records[:message].received_at)
    end

    it "lists the rows the Inbox screen shows, in the same order" do
      expect(rows.map { it.fetch("title") }).to eq(screen_titles)
    end
  end

  it "leaves out what no longer waits, as the screen does" do
    create(:message, :read)
    create(:webmention, :approved)
    synced(seen_at: Time.now)
    %i[done canceled].each { synced(it) }

    expect(rows).to eq([])
  end

  it "answers the MCP tool with the same JSON" do
    synced
    create(:message)
    create(:webmention)

    expect(mcp_answer("list_inbox")).to eq(read)
  end
end
