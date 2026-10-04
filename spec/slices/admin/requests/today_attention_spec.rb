# frozen_string_literal: true

RSpec.describe "Admin today needs attention", type: :request do
  let(:today) { Blog::TimeZone.today }

  def card = page.find("section.card[data-attention]")

  def page = Capybara.string(last_response.body)

  def row(title) = card.find(".li", text: title)

  def sub(title) = row(title).find(".li-sub").text

  def submit(form)
    fields = form.all("input[type=hidden]", visible: :all).to_h { [it["name"], it["value"]] }
    post form["action"], { _csrf_token: admin_csrf_token, **fields }
    follow_redirect!
  end

  def titles = card.all(".li-title").map(&:text)

  before { sign_in_to_admin }

  describe "with one row of each kind" do
    before do
      create(:task, carried_count: 4, title: "Carried task")
      create(:post, :draft, title: "Old draft", updated_at: days_ago(60))
      create(:task, :someday, title: "Someday task", updated_at: days_ago(100))
      create(:journal_entry, entry_date: today - 3)
      get "/admin"
    end

    it "lists each stalled row, worst first" do
      expect(titles).to eq(["Old draft", "Journal", "Carried task", "Someday task"])
    end

    it "shows each row's count", :aggregate_failures do
      expect(sub("Carried task")).to eq("Carried over 4 days")
      expect(sub("Old draft")).to eq("Untouched for 60 days")
      expect(sub("Someday task")).to eq("Untouched for 100 days")
      expect(sub("Journal")).to eq("No entry in 3 days")
    end
  end

  it "leaves the card out when nothing is stale" do
    create(:task, :carried)
    create(:post, :draft)
    create(:journal_entry, entry_date: today)
    get "/admin"

    expect(page).to have_no_css("section.card[data-attention]")
  end

  describe "a task row" do
    let!(:task) { create(:task, :in_sprint, carried_count: 3, title: "Carried task") }

    before do
      create(:post, :draft, title: "Old draft", updated_at: days_ago(60))
      get "/admin"
    end

    it "links to the task" do
      expect(row("Carried task").find("a.li-title")["href"]).to eq("/admin/tasks/#{task.id}?origin=today")
    end

    it "moves the task to next and drops off the card", :aggregate_failures do
      submit(row("Carried task").find("form[action$='/move/next']"))

      expect(last_request.path).to eq("/admin")
      expect(titles).to eq(["Old draft"])
      expect(Tasks::Slice["repos.task_repo"].by_id(task.id).list).to eq("next")
    end

    it "cancels the task and drops off the card", :aggregate_failures do
      submit(row("Carried task").find("form[action$='/cancel']"))

      expect(last_request.path).to eq("/admin")
      expect(titles).to eq(["Old draft"])
      expect(Tasks::Slice["repos.task_repo"].by_id(task.id).status).to eq("canceled")
    end

    it "asks before it cancels" do
      expect(row("Carried task").find("form[action$='/cancel']")["data-confirm"])
        .to eq(Admin::Slice["i18n"].t("ui.components.attention_card.confirm_cancel", task: "Carried task"))
    end
  end

  it "moves a someday task to next and drops it off the card" do
    create(:task, :someday, title: "Someday task", updated_at: days_ago(100))
    create(:post, :draft, title: "Old draft", updated_at: days_ago(60))
    get "/admin"
    submit(row("Someday task").find("form[action$='/move/next']"))

    expect(titles).to eq(["Old draft"])
  end

  it "opens a draft row in the post editor" do
    post = create(:post, :draft, title: "Old draft", updated_at: days_ago(60))
    get "/admin"

    expect(row("Old draft").all("a").map { it["href"] }.uniq).to eq(["/admin/posts/#{post.id}/edit"])
  end

  it "takes the journal row to the journal form on today", :aggregate_failures do
    create(:journal_entry, entry_date: today - 3)
    get "/admin"

    expect(row("Journal").all("a").map { it["href"] }.uniq).to eq(["#today-journal-entry"])
    expect(page).to have_css("form#today-journal-entry")
  end

  describe "snoozing" do
    let(:week) { 7 * 24 * 60 * 60 }
    let!(:draft) { create(:post, :draft, title: "Old draft", updated_at: days_ago(60)) }

    def snooze(title) = submit(row(title).find("form[action='/admin/attention/snooze']"))

    def snoozed(kind, record_id = nil, at:)
      Activity::Slice["operations.snooze_attention"].call(kind, record_id, now: at)
    end

    def snoozes = Activity::Slice["relations.attention_snoozes"].to_a

    it "takes a task row off the card", :aggregate_failures do
      create(:task, carried_count: 4, title: "Carried task")
      get "/admin"
      snooze("Carried task")

      expect(last_request.path).to eq("/admin")
      expect(titles).to eq(["Old draft"])
    end

    it "takes a draft row off the card" do
      create(:task, :someday, title: "Someday task", updated_at: days_ago(100))
      get "/admin"
      snooze("Old draft")

      expect(titles).to eq(["Someday task"])
    end

    it "takes the journal row off the card" do
      create(:journal_entry, entry_date: today - 3)
      get "/admin"
      snooze("Journal")

      expect(titles).to eq(["Old draft"])
    end

    it "ends the snooze a week out", :aggregate_failures do
      before = Time.now
      get "/admin"
      snooze("Old draft")

      expect(snoozes.map { it[:kind] }).to eq(["draft"])
      expect(snoozes.first[:ends_at]).to be_between(before + week, Time.now + week)
    end

    it "moves the end out a week when snoozed again" do
      snoozed("draft", draft.id, at: days_ago(6))
      snoozed("draft", draft.id, at: Time.now)

      expect(snoozes.map { it[:ends_at] }).to all(be > Time.now + week - 60)
    end

    it "keeps a row off the card for seven days" do
      create(:journal_entry, entry_date: today - 3)
      snoozed("journal", at: days_ago(6))
      get "/admin"

      expect(titles).to eq(["Old draft"])
    end

    it "brings a row back after seven days while it stays stalled" do
      create(:journal_entry, entry_date: today - 10)
      snoozed("journal", at: days_ago(8))
      get "/admin"

      expect(titles).to eq(["Journal", "Old draft"])
    end

    it "leaves no snooze behind when a snoozed task goes" do
      task = create(:task, :someday, title: "Someday task", updated_at: days_ago(100))
      snoozed("someday", task.id, at: Time.now)
      post "/admin/tasks/#{task.id}/delete", _csrf_token: admin_csrf_token

      expect(snoozes).to be_empty
    end

    it "leaves no snooze behind when a snoozed draft goes" do
      snoozed("draft", draft.id, at: Time.now)
      post "/admin/posts/#{draft.id}/delete", _csrf_token: admin_csrf_token

      expect(snoozes).to be_empty
    end

    it "refuses a row that is not on the list" do
      post "/admin/attention/snooze", _csrf_token: admin_csrf_token, kind: "carried", record_id: "1"

      expect(last_response.status).to eq(404)
    end

    it "refuses a kind it does not know" do
      post "/admin/attention/snooze", _csrf_token: admin_csrf_token, kind: "nope"

      expect(last_response.status).to eq(404)
    end
  end
end
