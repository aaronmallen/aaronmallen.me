# frozen_string_literal: true

RSpec.describe "API attention", :frozen_clock, type: :request do
  let(:today) { Blog::TimeZone.today }

  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def card_titles
    sign_in_to_admin
    get "/admin"
    Capybara.string(last_response.body).all("section.card[data-attention] .li-title").map(&:text)
  end

  def read
    headers = { "HTTP_ACCEPT" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{api_token}" }
    get "/api/v1/attention", {}, headers
    JSON.parse(last_response.body)
  end

  def rows = read.fetch("attention")

  def snooze(**body)
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json" }
    headers["HTTP_AUTHORIZATION"] = "Bearer #{api_token}"
    post "/api/v1/attention/snooze", JSON.generate(body), headers
    JSON.parse(last_response.body)
  end

  def snoozes = Activity::Slice["db.rom"].relations[:attention_snoozes]

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

  it "leaves out a task carried twice" do
    create(:task, :carried)

    expect(rows).to eq([])
  end

  it "leaves out a done task, however often it was carried" do
    create(:task, :done, carried_count: 5)

    expect(rows).to eq([])
  end

  it "leaves out a draft edited yesterday" do
    create(:post, :draft, updated_at: days_ago(1))

    expect(rows).to eq([])
  end

  it "leaves out a published post, however old" do
    create(:post, :published, updated_at: days_ago(60))

    expect(rows).to eq([])
  end

  it "leaves out a someday task once closed" do
    create(:task, :someday, :done, updated_at: days_ago(120))

    expect(rows).to eq([])
  end

  it "leaves out an old task on the next list" do
    create(:task, updated_at: days_ago(120))

    expect(rows).to eq([])
  end

  it "leaves out the journal when it has no entries" do
    expect(rows).to eq([])
  end

  it "follows the limits in settings" do
    create(:task, :carried, title: "Carried twice")
    change_attention_limit(:carried_count, to: 2)

    expect(rows.map { it.fetch("title") }).to eq(["Carried twice"])
  end

  describe "snoozing a row" do
    let!(:draft) { create(:post, :draft, title: "Old draft", updated_at: days_ago(60)) }

    before { create(:journal_entry, entry_date: today - 3) }

    it "snoozes the row for seven days" do
      reply = snooze(kind: "draft", record_id: draft.id)
      ends_at = Time.iso8601(reply.fetch("ends_at"))

      expect([status, reply.slice("kind", "record_id"), ends_at - Time.now])
        .to match([200, { "kind" => "draft", "record_id" => draft.id }, be_within(60).of(7 * 24 * 60 * 60)])
    end

    it "takes the row off the list" do
      snooze(kind: "draft", record_id: draft.id)

      expect(rows.map { it.fetch("kind") }).to eq(["journal"])
    end

    it "snoozes the journal with no record_id" do
      snooze(kind: "journal")

      expect([status, rows.map { it.fetch("kind") }]).to eq([200, ["draft"]])
    end

    it "moves the end out a week when the row is snoozed again" do
      snoozes.insert(kind: "draft", record_id: draft.id, ends_at: days_ago(1))
      snooze(kind: "draft", record_id: draft.id)

      expect(snoozes.to_a.map { it[:ends_at] - Time.now }).to match([be_within(60).of(7 * 24 * 60 * 60)])
    end

    it "answers an unknown kind with a 422" do
      expect([snooze(kind: "comet", record_id: draft.id).fetch("error"), status]).to eq(["invalid", 422])
    end

    it "answers a row not on the card with a 404" do
      reply = snooze(kind: "draft", record_id: draft.id + 1)

      expect([reply, status]).to eq(
        [{ "error" => "not_found", "message" => "no draft row on the card has the record_id #{draft.id + 1}" }, 404],
      )
    end

    it "answers a draft named with no record_id with a 404" do
      snooze(kind: "draft")

      expect(status).to eq(404)
    end

    it "answers the MCP tool with the same JSON" do
      tool = mcp_answer("snooze_attention", kind: "draft", record_id: draft.id)
      reply = snooze(kind: "draft", record_id: draft.id)

      expect(tool.except("ends_at")).to eq(reply.except("ends_at"))
    end

    it "refuses in the tool with the message the endpoint gives" do
      missing = snooze(kind: "draft", record_id: draft.id + 1)
      refused = mcp_call("snooze_attention", kind: "draft", record_id: draft.id + 1)

      expect([refused.fetch("isError"), refused.dig("content", 0, "text")]).to eq([true, missing.fetch("message")])
    end

    it "refuses an unknown kind in the tool" do
      refused = mcp_call("snooze_attention", kind: "comet")

      expect([refused.fetch("isError"), snoozes.count]).to eq([true, 0])
    end
  end

  it "answers the MCP tool with the same JSON" do
    create(:task, carried_count: 3, title: "Carried task")
    create(:post, :draft, title: "Old draft", updated_at: days_ago(45))
    create(:journal_entry, entry_date: today - 5)

    expect(mcp_answer("list_attention")).to eq(read)
  end
end
