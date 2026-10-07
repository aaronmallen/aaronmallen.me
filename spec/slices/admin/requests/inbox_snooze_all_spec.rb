# frozen_string_literal: true

RSpec.describe "Admin inbox Snooze All", type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:now) { Time.utc(2026, 10, 7, 15, 10) }

  def dialog = page.find("dialog#inbox-snooze-all", visible: :all)

  def inbox
    get "/admin/inbox"
    page.all(".li .li-title").map(&:text)
  end

  def snooze_all(**params)
    post "/admin/inbox/snooze/all", { _csrf_token: admin_csrf_token, **params }
    follow_redirect!
  end

  def synced(title: "An issue") = create(:task, :external, title:).tap { create(:task_source, task: it) }

  def toast = page.find("[data-toast] .toast", visible: :all).text(:all).strip

  before do
    allow(Time).to receive(:now).and_return(now)
    sign_in_to_admin
  end

  it "shows the button beside Mark All As Seen, opening the snooze dialog", :aggregate_failures do
    create(:message)
    get "/admin/inbox"

    expect(page.all(".page-head-actions button").map(&:text)).to eq(["Mark All As Seen", "Snooze All"])
    expect(dialog.all("button[name=pick]", visible: :all).map(&:text))
      .to eq(["Later today", "Tomorrow morning", "Next week"])
  end

  it "hides the button when nothing waits" do
    get "/admin/inbox"

    expect(page).to have_no_css("[data-dialog-open='inbox-snooze-all']")
  end

  it "posts every row's id under its kind" do
    ids = { "tasks[]" => synced.id, "messages[]" => create(:message).id, "webmentions[]" => create(:webmention).id }
    get "/admin/inbox"

    posted = dialog.all("input[type=hidden]:not([name=_csrf_token])", visible: :all).to_h { [it[:name], it[:value]] }
    expect(posted).to eq(ids.transform_values(&:to_s))
  end

  it "snoozes the rows it posts until the time picked", :aggregate_failures do
    ids = { tasks: [synced.id], messages: [create(:message).id], webmentions: [create(:webmention).id] }
    snooze_all(**ids, pick: "2026-10-08T08:00")

    expect(toast).to eq("Snoozed 3 rows until Oct 8, 2026 at 08:00")
    expect(inbox).to be_empty
  end

  it "keeps a row that arrived after the page rendered" do
    shown = create(:message).id
    create(:message, subject: "Later")
    snooze_all(messages: [shown], snoozed_until: "2026-10-08T08:00")

    expect(inbox).to eq(["Later"])
  end

  it "changes nothing when one row is gone and names it", :aggregate_failures do
    gone = create(:message).id.tap { Contact::Slice["repos.message_mutations"].delete(it) }
    snooze_all(tasks: [synced(title: "Kept").id], messages: [gone], pick: "2026-10-08T08:00")

    expect(toast).to eq("Nothing changed · message #{gone} is gone")
    expect(inbox).to eq(["Kept"])
  end

  it "refuses a time in the past" do
    snooze_all(messages: [create(:message).id], snoozed_until: "2026-10-01T08:00")

    expect(toast).to eq("A snooze ends after now")
  end
end
