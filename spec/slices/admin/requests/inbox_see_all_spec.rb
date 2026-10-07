# frozen_string_literal: true

RSpec.describe "Admin inbox Mark All As Seen", type: :request do
  let(:page) { Capybara.string(last_response.body) }

  def button = "form[action='/admin/inbox/seen'] button[type=submit]"

  def inbox
    get "/admin/inbox"
    page.all(".li .li-title").map(&:text)
  end

  def posted
    page.all(".page-head-actions input[type=hidden]:not([name=_csrf_token])", visible: :all)
        .to_h { [it[:name], it[:value]] }
  end

  def see_all(**ids)
    post "/admin/inbox/seen", { _csrf_token: admin_csrf_token, **ids }
    follow_redirect!
  end

  def synced(title: "An issue") = create(:task, :external, title:).tap { create(:task_source, task: it) }

  def toast = page.find("[data-toast] .toast", visible: :all).text(:all).strip

  before { sign_in_to_admin }

  it "shows the button in the head when rows wait, asking to confirm" do
    create(:message)
    get "/admin/inbox"

    form = page.find(".page-head-actions form[action='/admin/inbox/seen']")

    expect([form["data-confirm-styled"], form["data-confirm"], form.find("button[type=submit]").text])
      .to eq(["", Admin::Slice["i18n"].t("ui.components.inbox.see_all.confirm"), "Mark All As Seen"])
  end

  it "hides the button when nothing waits" do
    get "/admin/inbox"

    expect(page).to have_no_css(button)
  end

  it "posts every row's id under its kind" do
    ids = { "tasks[]" => synced.id, "messages[]" => create(:message).id, "webmentions[]" => create(:webmention).id }
    get "/admin/inbox"

    expect(posted).to eq(ids.transform_values(&:to_s))
  end

  it "clears the rows it posts, leaving the webmention pending", :aggregate_failures do
    ids = { tasks: [synced.id], messages: [create(:message).id], webmentions: [create(:webmention).id] }
    see_all(**ids)

    expect([toast, inbox]).to eq(["Marked 3 rows seen", []])
    expect(Social::Slice["repos.webmention_repo"].by_id(ids[:webmentions].first).status).to eq("pending")
  end

  it "keeps a row that arrived after the page rendered" do
    shown = create(:message).id
    create(:message, subject: "Later")
    see_all(messages: [shown])

    expect(inbox).to eq(["Later"])
  end

  it "changes nothing when one row is gone and names it", :aggregate_failures do
    gone = create(:message).id.tap { Contact::Slice["repos.message_mutations"].delete(it) }
    see_all(tasks: [synced(title: "Kept").id], messages: [gone])

    expect(toast).to eq("Nothing changed · message #{gone} is gone")
    expect(inbox).to eq(["Kept"])
  end

  it "names a row that would not change" do
    unsourced = create(:task).id
    see_all(tasks: [unsourced])

    expect(toast).to eq("Nothing changed · issue #{unsourced} would not change")
  end
end
