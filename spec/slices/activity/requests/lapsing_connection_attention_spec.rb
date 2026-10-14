# frozen_string_literal: true

RSpec.describe "Lapsing connections on the attention list", :frozen_clock, type: :request do
  def card_row
    sign_in_to_admin
    get "/admin"
    Capybara.string(last_response.body).find("section.card[data-attention] .li", text: "Ada Lovelace")
  end

  def listed(id)
    {
      "kind" => "lapsing", "record_id" => id, "title" => "Ada Lovelace", "carried_count" => nil, "days" => 3,
      "post_id" => nil, "url" => nil, "reason" => nil, "failures" => nil,
    }
  end

  def rows = Activity::Slice["repos.attention_queries"].stalled.select { it.kind == "lapsing" }

  def snooze(id) = Activity::Slice["operations.snooze_attention"].call("lapsing", id)

  def snoozes = Activity::Slice["db.rom"].relations[:attention_snoozes]

  it "adds nothing for a connection that never lapses" do
    connect_linkedin

    expect(rows).to eq([])
  end

  it "adds nothing for a connection more than a week from lapsing" do
    connect_linkedin(lapses_at: days_ahead(8))

    expect(rows).to eq([])
  end

  it "adds a row a week before the connection lapses, with the days left" do
    held = connect_linkedin(lapses_at: days_ahead(7))

    expect(rows.map { it.to_h.slice(:record_id, :title, :days) })
      .to eq([{ record_id: held.id, title: "Ada Lovelace", days: 7 }])
  end

  it "follows the window in settings" do
    change_attention_limit(:lapsing_days, to: 3)
    connect_linkedin(lapses_at: days_ahead(4))

    expect(rows).to eq([])
  end

  it "keeps the row once the connection has lapsed, below zero days" do
    connect_linkedin(lapses_at: days_ago(2))

    expect(rows.map(&:days)).to eq([-2])
  end

  it "ranks a lapsed connection above stalled work" do
    create(:task, carried_count: 9)
    connect_linkedin(lapses_at: days_ago(1))

    expect(Activity::Slice["repos.attention_queries"].stalled.map(&:kind)).to eq(%w[lapsing carried])
  end

  it "hides a snoozed row" do
    held = connect_linkedin(lapses_at: days_ahead(2))
    snooze(held.id)

    expect(rows).to eq([])
  end

  it "drops the row and its snooze when the connection goes" do
    held = connect_linkedin(lapses_at: days_ahead(2))
    snooze(held.id)
    Services::Slice["repos.connection_mutations"].delete(held.id)

    expect([rows, snoozes.count]).to eq([[], 0])
  end

  it "shows the row on the admin card with the days left, a link to the connection and a snooze", :aggregate_failures do
    held = connect_linkedin(lapses_at: days_ahead(3))
    row = card_row

    expect(row.find(".li-title")[:href]).to eq("/admin/services?selected=#{held.id}")
    expect(row.find(".li-sub").text).to eq("Connection lapses in 3 days")
    expect(row).to have_css("input[value=lapsing]", visible: :all)
  end

  it "says so on the admin card once the connection has lapsed" do
    connect_linkedin(lapses_at: days_ago(1))

    expect(card_row.find(".li-sub").text).to eq("Connection lapsed, reconnect it to post again")
  end

  it "returns the row from list_attention" do
    held = connect_linkedin(lapses_at: days_ahead(3))

    expect(mcp_answer("list_attention").fetch("attention")).to eq([listed(held.id)])
  end
end
