# frozen_string_literal: true

RSpec.describe "Broken links on the attention list", :frozen_clock, type: :request do
  let(:dead) { "https://bob.example/gone" }
  let(:live) { "https://ada.example/notes/1" }
  let!(:post_record) { create(:post, :published, title: "Linky post", body: body_linking(live, dead)) }

  before do
    resolves_publicly("ada.example", "bob.example")
    stub_request(:get, live).to_return(status: 200)
    stub_request(:get, dead).to_return(status: 404)
  end

  def body_linking(*urls) = urls.map { "See [a note](#{it})." }.join("\n\n")

  def card_row
    sign_in_to_admin
    get "/admin"
    Capybara.string(last_response.body).find("section.card[data-attention] .li", text: "Linky post")
  end

  def check(times = 1) = times.times { Posts::Jobs::CheckPostLinks.new.perform }

  def link_check_id = Posts::Slice["relations.post_link_checks"].where(url: dead).one[:id]

  def listed
    {
      "kind" => "broken_link", "record_id" => link_check_id, "title" => "Linky post", "carried_count" => nil,
      "days" => nil, "post_id" => post_record.id, "url" => dead, "reason" => "HTTP 404", "failures" => 2,
    }
  end

  def rows = Activity::Slice["repos.attention_queries"].stalled.select { it.kind == "broken_link" }

  def snooze(now: Time.now) = Activity::Slice["operations.snooze_attention"].call("broken_link", link_check_id, now:)

  def snoozes = Activity::Slice["db.rom"].relations[:attention_snoozes]

  def unlink
    Posts::Slice["repos.post_mutations"].update(post_record.id, body: body_linking(live))
    check
  end

  it "adds nothing for a link that failed once" do
    check

    expect(rows).to eq([])
  end

  it "adds a row for a link that failed twice in a row" do
    check(2)

    expect(rows.map { it.to_h.slice(:title, :post_id, :url, :reason, :days) })
      .to eq([{ title: "Linky post", post_id: post_record.id, url: dead, reason: "HTTP 404", days: 2 }])
  end

  it "follows the failure limit in settings" do
    change_attention_limit(:broken_link_failures, to: 3)
    check(2)

    expect(rows).to eq([])
  end

  it "drops the row once the link answers again" do
    check(2)
    stub_request(:get, dead).to_return(status: 200)
    check

    expect(rows).to eq([])
  end

  it "drops the row and its snooze once the link leaves the post" do
    check(2)
    snooze
    unlink

    expect([rows, snoozes.count]).to eq([[], 0])
  end

  it "drops the row once the post goes back to a draft" do
    check(2)
    Posts::Slice["repos.post_mutations"].update(post_record.id, status: "draft")

    expect(rows).to eq([])
  end

  it "hides a snoozed row" do
    check(2)
    snooze

    expect(rows).to eq([])
  end

  it "shows the row again once the snooze ends" do
    check(2)
    snooze(now: days_ago(8))

    expect(rows.map(&:url)).to eq([dead])
  end

  it "shows the row on the admin card with the post, the URL, the reason and a snooze", :aggregate_failures do
    check(2)
    row = card_row

    expect(row.find(".li-title")[:href]).to eq("/admin/posts/#{post_record.id}/edit")
    expect(row.all(".li-sub").map(&:text)).to eq([dead, "HTTP 404"])
    expect(row).to have_css("input[value=broken_link]", visible: :all)
  end

  it "returns the row from list_attention" do
    check(2)

    expect(mcp_answer("list_attention").fetch("attention")).to eq([listed])
  end
end
