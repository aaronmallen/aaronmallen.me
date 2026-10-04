# frozen_string_literal: true

RSpec.describe "API attention", type: :request do
  let(:today) { Blog::TimeZone.today }

  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def card_titles
    sign_in_to_admin
    get "/admin"
    Capybara.string(last_response.body).all("section.card[data-attention] .li-title").map(&:text)
  end

  def days_ago(days) = Time.now - (days * 24 * 60 * 60)

  def read(token: api_token)
    headers = { "HTTP_ACCEPT" => "application/json" }
    headers["HTTP_AUTHORIZATION"] = "Bearer #{token}" if token
    get "/api/v1/attention", {}, headers
    JSON.parse(last_response.body)
  end

  def rows = read.fetch("attention")

  def status = last_response.status

  describe "with one row of each kind" do
    let!(:records) do
      {
        carried: create(:task, carried_count: 4, title: "Carried task"),
        draft: create(:post, :draft, title: "Old draft", updated_at: days_ago(60)),
        someday: create(:task, :someday, title: "Someday task", updated_at: days_ago(100)),
      }
    end

    before { create(:journal_entry, entry_date: today - 3) }

    it "lists each row worst first" do
      ids = records.values_at(:draft, :carried, :someday).map(&:id)

      expect(rows.map { it.values_at("kind", "record_id") })
        .to eq([["draft", ids[0]], ["journal", nil], ["carried", ids[1]], ["someday", ids[2]]])
    end

    it "gives a carried task its count and every other row its days" do
      expect(rows.map { it.values_at("title", "carried_count", "days") })
        .to eq([["Old draft", nil, 60], [nil, nil, 3], ["Carried task", 4, nil], ["Someday task", nil, 100]])
    end

    it "lists the rows the admin card shows, in the same order" do
      expect(rows.map { it.fetch("title") || "Journal" }).to eq(card_titles)
    end

    it "leaves out a snoozed row, as the card does" do
      Activity::Slice["operations.snooze_attention"].call("draft", records[:draft].id)

      expect(rows.map { it.fetch("kind") }).to eq(%w[journal carried someday])
    end
  end

  it "returns no rows when nothing is stale" do
    create(:task, :carried)
    create(:post, :draft)
    create(:journal_entry, entry_date: today)

    expect(rows).to eq([])
  end

  it "follows the limits in settings" do
    create(:task, :carried, title: "Carried twice")
    change_attention_limit(:carried_count, to: 2)

    expect(rows.map { it.fetch("title") }).to eq(["Carried twice"])
  end

  it "refuses a request with no token" do
    read(token: nil)

    expect(status).to eq(401)
  end

  it "answers the MCP tool with the same JSON" do
    create(:task, carried_count: 3, title: "Carried task")
    create(:post, :draft, title: "Old draft", updated_at: days_ago(45))
    create(:journal_entry, entry_date: today - 5)

    expect(mcp_answer("list_attention")).to eq(read)
  end
end
