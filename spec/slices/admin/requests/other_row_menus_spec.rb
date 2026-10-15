# frozen_string_literal: true

require "securerandom"

RSpec.describe "Admin menus for the remaining rows with actions", :frozen_clock, type: :request do
  def act(path, **params) = post(path, { _csrf_token: admin_csrf_token, **params })

  def copies = page.all("[data-copy]", visible: :all).to_h { [it.find(".ctx-label").text(:all), it["data-copy"]] }

  def form(route) = page.first("form[action='#{route}']", visible: :all)

  def head = page.find("[data-context-menu] > .ctx-head", visible: :all).text(:all)

  def inline_confirm(route) = form(route).find("button")["data-confirm-inline"]

  def items = page.all(".ctx-label", visible: :all).map { it.text(:all) }

  def menus = page.all("[data-menu]", visible: :all).map { it["data-menu"] }

  def page = Capybara.string(last_response.body)

  def return_to(form) = form.first("input[name=return_to]", visible: :all)&.value

  def returns = page.all("[data-context-menu] form", visible: :all).map { return_to(it) }.uniq

  def toast = page.find("[data-toast] .toast", visible: :all).text(:all)

  def translate(key, **) = Admin::Slice["i18n"].t(key, **)

  it "sends me to sign in when I am signed out" do
    get "/admin/tokens/1/menu"

    expect(last_response).to be_redirect
  end

  describe "signed in" do
    before { sign_in_to_admin }

    %w[
      /admin/tasks/0/comments/0/menu /admin/tasks/0/sessions/0/menu /admin/decisions/0/comments/0/menu
      /admin/tasks/sprints/0/menu /admin/commits/0/menu /admin/tasks/rules/0/menu /admin/tokens/0/menu
      /admin/clients/0/menu /admin/services/nothing/menu /admin/attention/menu?kind=carried&record_id=0
      /admin/attention/dead-jobs/abc123/menu
    ].each do |gone|
      it "answers 404 at #{gone}" do
        get gone

        expect(last_response.status).to eq(404)
      end
    end

    describe "a task comment" do
      let(:task) { create(:task) }
      let(:comment) { create(:task_comment, task_id: task.id, body: "Looks right\nmore") }
      let(:delete) { "/admin/tasks/#{task.id}/comments/#{comment.id}/delete" }

      before { get "/admin/tasks/#{task.id}/comments/#{comment.id}/menu", return_to: "/admin/tasks/#{task.id}" }

      it "holds every action a comment takes", :aggregate_failures do
        expect(head).to eq("Looks right")
        expect(items).to eq(["Edit", "Copy text", "Delete comment"])
        expect(copies["Copy text"]).to eq("Looks right\nmore")
        expect(returns).to eq(["/admin/tasks/#{task.id}"])
      end

      it "opens the comment's edit form on its page" do
        expect(page).to have_css(
          "a[data-dialog-open='task-comment-#{comment.id}'][href='/admin/tasks/#{task.id}#task-comment-#{comment.id}']",
          text: "Edit", visible: :all,
        )
      end

      it "asks before it deletes" do
        expect(inline_confirm(delete)).to eq(translate("ui.views.comments.menu.confirm_delete"))
      end

      it "lands a delete back on the page it opened on", :aggregate_failures do
        act(delete, return_to: "/admin/activity")

        expect(last_response.location).to eq("/admin/activity")
        follow_redirect!
        expect(toast).to eq(translate("tasks_page.toasts.comment_deleted"))
      end
    end

    it "offers only the source and a copy for a synced comment" do
      task = create(:task)
      comment = create(:task_comment, :synced, task_id: task.id)
      get "/admin/tasks/#{task.id}/comments/#{comment.id}/menu"

      expect(items).to eq(["View on source", "Copy text"])
    end

    it "answers 404 for a comment on another task" do
      comment = create(:task_comment, task_id: create(:task).id)
      get "/admin/tasks/#{create(:task).id}/comments/#{comment.id}/menu"

      expect(last_response.status).to eq(404)
    end

    it "answers 404 for a session asked for as a comment" do
      task = create(:task)
      session = create(:work_session, :closed, task_id: task.id)
      get "/admin/tasks/#{task.id}/comments/#{session.id}/menu"

      expect(last_response.status).to eq(404)
    end

    it "answers 404 for a comment asked for as a session" do
      task = create(:task)
      comment = create(:task_comment, task_id: task.id)
      get "/admin/tasks/#{task.id}/sessions/#{comment.id}/menu"

      expect(last_response.status).to eq(404)
    end

    it "answers 404 for a comment on another decision" do
      comment = create(:decision_comment, decision_id: create(:decision).id)
      get "/admin/decisions/#{create(:decision).id}/comments/#{comment.id}/menu"

      expect(last_response.status).to eq(404)
    end

    describe "a decision comment" do
      let(:decision) { create(:decision) }
      let(:comment) { create(:decision_comment, decision_id: decision.id, body: "Go with A") }
      let(:delete) { "/admin/decisions/#{decision.id}/comments/#{comment.id}/delete" }

      before { get "/admin/decisions/#{decision.id}/comments/#{comment.id}/menu" }

      it "holds every action a comment takes", :aggregate_failures do
        expect(items).to eq(["Edit", "Copy text", "Delete comment"])
        expect(form(delete)).not_to be_nil
      end

      it "lands a delete back on the page it opened on", :aggregate_failures do
        act(delete, return_to: "/admin/activity")

        expect(last_response.location).to eq("/admin/activity")
        follow_redirect!
        expect(toast).to eq(translate("decisions_page.toasts.comment_deleted"))
      end
    end

    describe "a work session" do
      let(:task) { create(:task) }

      it "edits and deletes a closed session", :aggregate_failures do
        session = create(:work_session, :closed, task_id: task.id)
        get "/admin/tasks/#{task.id}/sessions/#{session.id}/menu", return_to: "/admin/activity"

        expect(items).to eq(["Edit", "Delete session"])
        expect(page).to have_css("a[data-dialog-open='task-session-#{session.id}']", visible: :all)
        expect(returns).to eq(["/admin/activity"])
      end

      it "only edits a running one" do
        session = create(:work_session, task_id: task.id)
        get "/admin/tasks/#{task.id}/sessions/#{session.id}/menu"

        expect(items).to eq(["Edit"])
      end

      it "lands a delete back on the page it opened on", :aggregate_failures do
        session = create(:work_session, :closed, task_id: task.id)
        act("/admin/tasks/#{task.id}/sessions/#{session.id}/delete", return_to: "/admin/activity")

        expect(last_response.location).to eq("/admin/activity")
        follow_redirect!
        expect(toast).to eq(translate("tasks_page.toasts.session_deleted"))
      end
    end

    describe "a sprint" do
      let(:sprint) { create(:sprint, sprint_date: Date.new(2026, 10, 20)) }

      before { get "/admin/tasks/sprints/#{sprint.id}/menu" }

      it "opens it on the calendar", :aggregate_failures do
        expect(head).to eq("Sprint · Oct 20, 2026")
        expect(items).to eq(["Open on calendar", "Drop sprint"])
        expect(page).to have_link("Open on calendar", href: "/admin/calendar?day=2026-10-20", visible: :all)
      end

      it "drops it on the second click" do
        expect(inline_confirm("/admin/tasks/sprints/#{sprint.id}/delete")).to eq("Click again to drop")
      end
    end

    describe "a commit" do
      let(:sha) { "9f8e7d6#{'0' * 33}" }
      let(:commit) { create(:commit, repo: "aaronmallen/blog", sha:, message: "add the view\n\nbody") }

      before { get "/admin/commits/#{commit.id}/menu" }

      it "opens it here and on GitHub", :aggregate_failures do
        href = "https://github.com/aaronmallen/blog/commit/#{sha}"

        expect(items).to eq(["Open", "View on GitHub", "Copy SHA", "Copy message"])
        expect(page).to have_link("View on GitHub", href:, visible: :all)
      end

      it "copies its SHA and subject" do
        expect(copies).to eq("Copy SHA" => sha, "Copy message" => "add the view")
      end
    end

    describe "a task rule" do
      let(:rule) { Tasks::Slice["operations.save_task_rule"].call({ pattern: "aaronmallen/*", tags: "ruby" }).value! }

      before { get "/admin/tasks/rules/#{rule.id}/menu" }

      it "opens its editor and deletes it in place", :aggregate_failures do
        expect(items).to eq(["Edit", "Delete rule"])
        expect(page).to have_css("a[data-dialog-open='rule-#{rule.id}-edit']", visible: :all)
        expect(form("/admin/tasks/rules/#{rule.id}/delete")["data-morph"]).not_to be_nil
      end
    end

    describe "a token" do
      let(:token) do
        API::Slice["operations.mint_token"].call(name: "Terminal")
        API::Slice["repos.api_token_queries"].live.first
      end

      it "revokes on the second click", :aggregate_failures do
        get "/admin/tokens/#{token.id}/menu"

        expect(items).to eq(["Revoke"])
        expect(inline_confirm("/admin/tokens/#{token.id}/revoke")).to eq("Click again to revoke")
      end

      it "shows the toast it shows today" do
        act("/admin/tokens/#{token.id}/revoke")
        follow_redirect!

        expect(toast).to eq(translate("tokens_page.toasts.revoked"))
      end
    end

    describe "a client" do
      let(:client) do
        Spec::DB::Factories[:mcp].create(:oauth_client, client_name: "Desk").tap do |client|
          Spec::DB::Factories[:mcp].create(:oauth_token, oauth_client: client)
        end
      end

      before { get "/admin/clients/#{client.id}/menu" }

      it "opens sign-ins and revokes it", :aggregate_failures do
        expect(head).to eq("Desk")
        expect(items).to eq(%w[Sign-ins Revoke])
        expect(form("/admin/clients/#{client.id}/revoke")).not_to be_nil
      end
    end

    describe "a service" do
      let(:connection) do
        Services::Slice["repos.connection_mutations"].add(
          provider: "linear", account_id: "a1", label: "Work", credentials: { api_key: "lin_api_secret" },
        )
      end

      before { get "/admin/services/#{connection.id}/menu" }

      it "shows its details and disconnects on the second click", :aggregate_failures do
        expect(items).to include("Details", "Disconnect")
        expect(page).to have_link("Details", href: "/admin/services?selected=#{connection.id}", visible: :all)
        expect(inline_confirm("/admin/services/#{connection.id}/disconnect")).to eq("Click again to disconnect")
      end

      it "tests it in place" do
        expect(form("/admin/services/#{connection.id}/test")["data-morph"]).not_to be_nil
      end
    end

    describe "a carried task on the attention card" do
      let(:task) { create(:task, carried_count: 4, title: "Carried task") }

      before { get "/admin/attention/menu", kind: "carried", record_id: task.id }

      it "opens, moves, cancels and snoozes it", :aggregate_failures do
        expect(head).to eq("Carried task")
        expect(items).to eq(["Open", "Move to Next", "Cancel task", "Snooze"])
        expect(form("/admin/tasks/#{task.id}/move/next")).to have_field("origin", type: :hidden, with: "today")
      end

      it "cancels on the second click and snoozes this row", :aggregate_failures do
        expect(inline_confirm("/admin/tasks/#{task.id}/cancel")).to eq("Click again to cancel")
        expect(form("/admin/attention/snooze")).to have_field("record_id", type: :hidden, with: task.id.to_s)
      end
    end

    describe "the attention card" do
      it "writes and snoozes the journal row", :aggregate_failures do
        create(:journal_entry, entry_date: Blog::TimeZone.today - 3)
        get "/admin/attention/menu", kind: "journal"

        expect(items).to eq(%w[Write Snooze])
        expect(form("/admin/attention/snooze")).to have_no_field("record_id", type: :hidden)
      end

      it "snoozes in place with the toast it shows today" do
        task = create(:task, carried_count: 4)
        act("/admin/attention/snooze", kind: "carried", record_id: task.id)
        follow_redirect!

        expect(toast).to eq(translate("today_page.toasts.snoozed"))
      end
    end

    describe "a dead job" do
      let(:dead_set) { Spec::FakeJobSet.new("dead") }
      let(:jid) { SecureRandom.hex(12) }

      before do
        allow(Sidekiq::DeadSet).to receive(:new).and_return(dead_set)
        dead_set.add(
          Time.now - 60,
          { "class" => "Social::Jobs::SendWebmention", "args" => [], "jid" => jid, "queue" => "default",
            "error_class" => "RuntimeError", "error_message" => "boom" },
        )
        get "/admin/attention/dead-jobs/#{jid}/menu"
      end

      it "retries, copies and discards it", :aggregate_failures do
        expect(items).to eq(["Retry", "Copy error", "Discard"])
        expect(copies["Copy error"]).to eq("RuntimeError: boom")
        expect(inline_confirm("/admin/attention/dead-jobs/#{jid}/discard")).to eq("Click again to discard")
      end
    end

    describe "the rows" do
      let(:today) { Blog::TimeZone.today }

      def comment_menu(task, comment) = "/admin/tasks/#{task.id}/comments/#{comment.id}/menu"

      def rule = Tasks::Slice["operations.save_task_rule"].call({ pattern: "aaronmallen/*", tags: "ruby" }).value!

      def token
        API::Slice["operations.mint_token"].call(name: "Terminal")
        API::Slice["repos.api_token_queries"].live.first
      end

      it "carry menus on the task page's comments and sessions" do
        task = create(:task)
        comment = create(:task_comment, task_id: task.id)
        session = create(:work_session, :closed, task_id: task.id)
        get "/admin/tasks/#{task.id}"

        expect(menus).to include(comment_menu(task, comment), "/admin/tasks/#{task.id}/sessions/#{session.id}/menu")
      end

      it "carry a menu on a token" do
        id = token.id
        get "/admin/tokens"

        expect(menus).to include("/admin/tokens/#{id}/menu")
      end

      it "carry a menu on a task rule" do
        id = rule.id
        get "/admin/tasks/rules"

        expect(menus).to include("/admin/tasks/rules/#{id}/menu")
      end

      it "carry a menu on an upcoming sprint" do
        sprint = create(:sprint, sprint_date: today + 2)
        get "/admin/tasks", filter: "upcoming"

        expect(menus).to include("/admin/tasks/sprints/#{sprint.id}/menu")
      end

      it "carry menus on the Today attention card and commits" do
        attention = "/admin/attention/menu?kind=carried&record_id=#{create(:task, carried_count: 4).id}"
        commit = create(:commit, commit_date: today)
        get "/admin"

        expect(menus).to include(attention, "/admin/commits/#{commit.id}/menu")
      end

      it "carry the menu of each record on the activity timeline" do
        commit = create(:commit, commit_date: today)
        entry = create(:journal_entry, entry_date: today, entry_time: "09:00")
        get "/admin/activity"

        expect(menus).to include("/admin/commits/#{commit.id}/menu", "/admin/journal/#{entry.id}/menu")
      end

      it "carry the social post menu on the calendar day" do
        day = today + 1
        social = create(:social_post, :scheduled, posted_at: Blog::TimeZone.local_time(day.year, day.month, day.day))
        get "/admin/calendar", day: day.iso8601

        expect(menus).to include("/admin/social/#{social.id}/menu")
      end
    end
  end
end
