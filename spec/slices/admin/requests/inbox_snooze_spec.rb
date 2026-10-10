# frozen_string_literal: true

RSpec.describe "Admin inbox snooze", type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:now) { Time.utc(2026, 10, 7, 15, 10) }
  let(:records) do
    {
      "message" => create(:message, subject: "message"),
      "webmention" => create(:webmention, author_name: "webmention"),
      "task" => create(:task, :external, title: "task").tap { create(:task_source, task: it) },
    }
  end

  def act(path, **params) = post(path, { _csrf_token: admin_csrf_token, **params })

  def dialog
    get "/admin/inbox"
    page.find("dialog#snooze-message-#{records['message'].id}", visible: :all)
  end

  def inbox
    get "/admin/inbox"
    page.all(".inbox-row-title").map(&:text)
  end

  def snooze(kind, **params) = act("/admin/inbox/#{kind}/#{records.fetch(kind).id}/snooze", **params)

  before do
    allow(Time).to receive(:now).and_return(now)
    records
    sign_in_to_admin
  end

  it "gives each row a Snooze button that opens its own dialog" do
    get "/admin/inbox"

    opened = page.all("[data-dialog-open^='snooze-']").map { it["data-dialog-open"] }
    expect(opened.map { page.has_css?("dialog##{it}[data-dialog]", visible: :all) }).to eq([true] * 3)
  end

  def snoozed_until(kind)
    record = records.fetch(kind)
    case kind
      when "message" then Contact::Slice["repos.message_queries"].by_id(record.id)
      when "webmention" then Social::Slice["repos.webmention_queries"].by_id(record.id)
      else Tasks::Slice["repos.task_queries"].by_id(record.id).source
    end.snoozed_until
  end

  it "offers later today, tomorrow morning and next week" do
    expect(dialog.all("button[name=pick]", visible: :all).map { [it.text, it[:value]] })
      .to eq([["Later today", "2026-10-07T13:00"], ["Tomorrow morning", "2026-10-08T08:00"],
              ["Next week", "2026-10-12T08:00"]])
  end

  context "when later today would land on tomorrow" do
    let(:now) { Blog::TimeZone.local_time(2026, 10, 7, 22, 15) }

    it "leaves later today out" do
      expect(dialog.all("button[name=pick]", visible: :all).map(&:text)).to eq(["Tomorrow morning", "Next week"])
    end
  end

  it "offers a date and time field that starts now" do
    expect(dialog.find("input[type=datetime-local]", visible: :all)[:min]).to eq("2026-10-07T10:10")
  end

  %w[message webmention task].each do |kind|
    it "snoozes a #{kind} from a quick pick and drops it", :aggregate_failures do
      snooze(kind, pick: "2026-10-08T08:00")
      follow_redirect!

      expect(page).to have_css("[data-toast]", text: "Snoozed until")
      expect(snoozed_until(kind)).to eq(Time.utc(2026, 10, 8, 13))
      expect(inbox).to match_array(records.keys - [kind])
    end
  end

  it "snoozes until the time in the field" do
    snooze("message", snoozed_until: "2026-10-09T17:30")

    expect(snoozed_until("message")).to eq(Time.utc(2026, 10, 9, 22, 30))
  end

  { "a past time" => "2026-10-07T10:00", "no time" => "" }.each do |name, value|
    it "refuses #{name} and keeps the row", :aggregate_failures do
      snooze("message", snoozed_until: value)
      follow_redirect!

      expect(page).to have_css("[data-toast]", text: value.empty? ? "Pick a time first" : "A snooze ends after now")
      expect(snoozed_until("message")).to be_nil
      expect(inbox).to include("message")
    end
  end

  it "answers 404 for a kind or a row that isn't there", :aggregate_failures do
    act("/admin/inbox/post/#{records['message'].id}/snooze", pick: "2026-10-08T08:00")
    expect(last_response.status).to eq(404)

    act("/admin/inbox/message/0/snooze", pick: "2026-10-08T08:00")
    expect(last_response.status).to eq(404)
  end
end
