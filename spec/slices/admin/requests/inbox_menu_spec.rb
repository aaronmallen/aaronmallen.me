# frozen_string_literal: true

RSpec.describe "Admin inbox and webmention row menus", type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:now) { Time.utc(2026, 10, 7, 15, 10) }

  def act(path, **params) = post(path, { _csrf_token: admin_csrf_token, **params })

  def items = page.all(".ctx-label", visible: :all).map { it.text(:all) }

  def snoozes(kind, id) = page.all("form[action='/admin/inbox/#{kind}/#{id}/snooze']", visible: :all)

  def toast = page.find("[data-toast] .toast", visible: :all).text(:all)

  before do
    allow(Time).to receive(:now).and_return(now)
    sign_in_to_admin
  end

  describe "a task row in the inbox" do
    let(:task) { create(:task, :external, title: "Triage me").tap { create(:task_source, task: it) } }

    it "carries the task menu from the inbox" do
      task
      get "/admin/inbox"

      expect(page).to have_css("#issue-#{task.id}[data-menu='/admin/tasks/#{task.id}/menu?origin=inbox']")
    end

    it "adds Snooze to the task menu with the quick picks", :aggregate_failures do
      get "/admin/tasks/#{task.id}/menu", origin: "inbox", return_to: "/admin/inbox"

      expect(items).to include("Open", "Mark seen", "Snooze", "Later today", "Tomorrow morning", "Next week")
      expect(snoozes("task", task.id).map { it.find("input[name=pick]", visible: :all).value })
        .to eq(%w[2026-10-07T13:00 2026-10-08T08:00 2026-10-12T08:00])
    end

    it "leaves Snooze out of the task menu elsewhere" do
      get "/admin/tasks/#{task.id}/menu", origin: "tasks"

      expect(items).not_to include("Snooze")
    end
  end

  describe "a webmention row" do
    let(:mention) { create(:webmention, author_name: "Ada", source_url: "https://example.com/reply") }

    it "answers 404 for a webmention that is gone" do
      get "/admin/webmentions/0/menu"

      expect(last_response.status).to eq(404)
    end

    it "carries its menu in the inbox and on the webmentions screen", :aggregate_failures do
      mention
      get "/admin/inbox"
      expect(page).to have_css("#webmention-#{mention.id}[data-menu='/admin/webmentions/#{mention.id}/menu']")

      get "/admin/webmentions"
      expect(page).to have_css("#webmention-#{mention.id}[data-menu='/admin/webmentions/#{mention.id}/menu']")
    end

    describe "its menu" do
      before { get "/admin/webmentions/#{mention.id}/menu", return_to: "/admin/webmentions?status=pending" }

      it "holds every action a pending webmention takes" do
        expected = ["Open source", "Approve", "Ignore", "Mark spam", "Snooze", "Later today", "Tomorrow morning",
                    "Next week", "Copy source link", "Go to post"]

        expect(items).to eq(expected)
      end

      it "opens, copies and goes to the right places", :aggregate_failures do
        expect(page).to have_css("a.ctx-item[href='https://example.com/reply'][target=_blank]")
        expect(page).to have_css("[data-copy='https://example.com/reply']")
        expect(page).to have_css("a.ctx-item[href='/admin/posts/#{mention.post_id}/edit']")
      end

      it "posts every action by fetch and morph back to the page it opened on", :aggregate_failures do
        forms = page.all("[data-context-menu] form", visible: :all)

        expect(page).to have_no_css("[data-context-menu] form:not([data-morph])", visible: :all)
        expect(forms.map { it.find("input[name=return_to]", visible: :all).value }.uniq)
          .to eq(["/admin/webmentions?status=pending"])
      end
    end

    it "leaves out the status it holds and Snooze once moderated", :aggregate_failures do
      approved = create(:webmention, :approved)
      get "/admin/webmentions/#{approved.id}/menu"

      expect(items).to include("Ignore", "Mark spam")
      expect(items).not_to include("Approve", "Snooze")
    end

    it "lands a verdict back on the page the menu opened on with today's toast", :aggregate_failures do
      act("/admin/webmentions/#{mention.id}/approve", return_to: "/admin/inbox")

      expect(last_response.location).to eq("/admin/inbox")
      follow_redirect!
      expect(toast).to eq(Admin::Slice["i18n"].t("webmentions_page.toasts.approved"))
    end

    it "lands a snooze back on the page the menu opened on" do
      act("/admin/inbox/webmention/#{mention.id}/snooze", pick: "2026-10-08T08:00", return_to: "/admin/webmentions")

      expect(last_response.location).to eq("/admin/webmentions")
    end
  end
end
