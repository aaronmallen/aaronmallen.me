# frozen_string_literal: true

RSpec.describe "Admin mail menus", type: :request do
  def act(path, **params) = post(path, { _csrf_token: admin_csrf_token, **params })

  def bulk
    [
      "Archive 2", "Mark read", "Mark unread", "Star", "Snooze", "Later today", "Tomorrow morning", "Next week",
      "Move to", "Archive", "Spam", "Trash", "Label", "#ops", "Delete 2",
    ]
  end

  let(:page) { Capybara.string(last_response.body) }
  let(:now) { Time.utc(2026, 10, 7, 15, 10) }
  let(:work) { create(:mail_account, name: "aaron@work.example", address: "aaron@work.example") }

  def fields(form) = form.all("input", visible: :all).to_h { [it[:name], it.value] }

  def head = page.find("[data-context-menu] > .ctx-head").text

  def items = page.all(".ctx-label", visible: :all).map { it.text(:all) }

  def menu_form(label, within: page)
    within.find(".ctx-label", exact_text: label, visible: :all).ancestor("form", visible: :all)
  end

  def repo = Mail::Slice["repos.thread_queries"]

  def single
    [
      "Open", "Reply", "Mark read", "Star", "Archive", "Snooze", "Later today", "Tomorrow morning", "Next week",
      "Move to", "Archive", "Spam", "Trash", "Label", "#billing", "#ops", "Make a task", "Copy address", "Delete",
    ]
  end

  def submenu(label) = page.find("[aria-haspopup]", text: label, visible: :all).sibling("[role=menu]", visible: :all)

  before { allow(Time).to receive(:now).and_return(now) }

  it "sends a visitor who isn't signed in to sign in" do
    get "/admin/mail/#{create(:message).id}/menu"

    expect(last_response).to be_redirect
  end

  describe "signed in" do
    before { sign_in_to_admin }

    it "answers 404 for a thread that is gone" do
      get "/admin/mail/0/menu"

      expect(last_response.status).to eq(404)
    end

    it "answers 404 for a bulk menu with nothing picked" do
      get "/admin/mail/bulk/menu", ids: ["nope"]

      expect(last_response.status).to eq(404)
    end

    it "hangs the menu on each row with the list's place, and the bulk menu on the bar", :aggregate_failures do
      thread = create(:message, subject: "Hello")
      get "/admin/mail", folder: "inbox", show: "unread"

      menu = "/admin/mail/#{thread.id}/menu?folder=inbox&show=unread"

      expect(page).to have_css("#thread-#{thread.id}[data-menu='#{menu}']")
      expect(page).to have_css("#mail-bulk[data-bulk-menu='/admin/mail/bulk/menu?folder=inbox&show=unread']")
    end

    it "hangs the menu on mail rows in the inbox" do
      thread = create(:message)
      get "/admin/inbox"

      expect(page).to have_css("#message-#{thread.id}[data-menu='/admin/mail/#{thread.id}/menu?origin=inbox']")
    end

    describe "an unread thread in the inbox" do
      let(:thread) do
        create(:message, mail_account_id: work.id, subject: "Release notes", from_name: "Sean", reply_to: "sean@ex.com")
      end

      before do
        label = create(:mail_label, mail_account_id: work.id, name: "ops")
        create(:mail_label, mail_account_id: work.id, name: "billing")
        create(:mail_thread_label, mail_thread_id: thread.id, mail_label_id: label.id)
        get "/admin/mail/#{thread.id}/menu", folder: "inbox", page: "2", return_to: "/admin/mail?page=2"
      end

      it "names the sender and subject" do
        expect(head).to eq("Sean · Release notes")
      end

      it "holds every action an unread thread in the inbox takes" do
        expect(items).to eq(single)
      end

      it "posts list actions to the bulk route with the list's place in place of return_to", :aggregate_failures do
        form = menu_form("Mark read")

        expect(form[:action]).to eq("/admin/mail/bulk")
        expect(fields(form)).to include("ids[]" => thread.id.to_s, "act" => "read", "folder" => "inbox",
                                        "page" => "2")
        expect(fields(form)).not_to have_key("return_to")
      end

      it "snoozes back to the page the menu opened on" do
        form = menu_form("Tomorrow morning", within: submenu("Snooze"))

        expect(fields(form)).to include("return_to" => "/admin/mail?page=2", "pick" => "2026-10-08T08:00")
      end

      it "labels with the account's labels and holds the one it wears as ticked but fixed", :aggregate_failures do
        labels = submenu("Label")

        expect(fields(menu_form("#billing", within: labels)))
          .to include("act" => "label", "label" => "#{work.id}:billing")
        expect(labels).to have_css("button[aria-checked=true][disabled]", text: "#ops", visible: :all)
      end

      it "opens the task dialog from the menu", :aggregate_failures do
        expect(page).to have_css("a.ctx-item[data-dialog-open='mail-task-#{thread.id}']")
        dialog = "dialog#mail-task-#{thread.id} form[action='/admin/mail/#{thread.id}/task']"

        expect(page).to have_css(dialog, visible: :all)
      end

      it "copies the address and replies in the reader", :aggregate_failures do
        expect(page).to have_css("[data-copy='sean@ex.com']")
        reply = "/admin/mail?folder=inbox&show=all&page=2&thread=#{thread.id}#"

        expect(page).to have_css("a.ctx-item[href^='#{reply}']", text: "Reply")
      end

      it "asks before it deletes" do
        expect(page).to have_css("button[data-confirm-inline='Click again to delete']", text: "Delete")
      end
    end

    it "offers Wake, Unstar and Mark unread for a read, starred, snoozed thread", :aggregate_failures do
      thread = create(:message, :read, starred: true, snoozed_until: now + 3600)
      get "/admin/mail/#{thread.id}/menu"

      expect(items).to include("Mark unread", "Unstar", "Wake now")
      expect(items).not_to include("Snooze")
    end

    it "moves an archived thread back to the inbox and opens its task", :aggregate_failures do
      thread = create(:message, archived: true)
      task = create(:task).tap { Links::Slice["repos.record_link_mutations"].link(["mail_thread", thread.id], ["task", it.id]) }
      get "/admin/mail/#{thread.id}/menu"

      expect(items).to include("Move to Inbox", "Open task ##{task.id}")
      expect(items).not_to include("Make a task")
    end

    it "deletes a trashed thread forever after a second click", :aggregate_failures do
      thread = create(:message, trashed: true)
      get "/admin/mail/#{thread.id}/menu"

      expect(items).not_to include("Reply")
      expect(fields(menu_form("Delete forever"))).to include("act" => "delete")
      expect(page).to have_css("button[data-confirm-inline=\"Click again · can't undo\"]", text: "Delete forever")
    end

    it "offers a new label for a contact form thread" do
      thread = create(:message)
      get "/admin/mail/#{thread.id}/menu"

      expect(submenu("Label")).to have_field("tag", type: "text", visible: :all)
    end

    it "offers a new tag for a Gmail thread on an account with no labels" do
      thread = create(:message, mail_account_id: work.id)
      get "/admin/mail/#{thread.id}/menu"

      expect(fields(submenu("Label").find_field("tag", visible: :all).ancestor("form", visible: :all)))
        .to include("act" => "tag")
    end

    describe "from the inbox" do
      let(:thread) { create(:message, subject: "Ping") }

      it "keeps return_to on every action" do
        get "/admin/mail/#{thread.id}/menu", origin: "inbox", return_to: "/admin/inbox"

        expect(fields(menu_form("Mark read"))).to include("return_to" => "/admin/inbox")
      end

      it "lands a bulk-route action back on the inbox with its toast", :aggregate_failures do
        act("/admin/mail/bulk", "ids[]": thread.id, act: "star", return_to: "/admin/inbox")

        expect(last_response.location).to eq("/admin/inbox")
        follow_redirect!
        expect(toast).to eq("Starred 1 thread")
      end
    end

    it "unstars a thread with its toast", :aggregate_failures do
      thread = create(:message, starred: true)
      act("/admin/mail/bulk", "ids[]": thread.id, act: "unstar", folder: "inbox")

      follow_redirect!
      expect(toast).to eq("Unstarred 1 thread")
      expect(repo.by_id(thread.id).starred).to be(false)
    end

    it "wakes a thread back to the page the menu opened on" do
      thread = create(:message, snoozed_until: now + 3600)
      act("/admin/mail/#{thread.id}/wake", return_to: "/admin/mail?folder=snoozed")

      expect(last_response.location).to eq("/admin/mail?folder=snoozed")
    end

    describe "the bulk menu" do
      let(:threads) { %w[one two].map { create(:message, mail_account_id: work.id, subject: it) } }

      before do
        create(:mail_label, mail_account_id: work.id, name: "ops")
        get "/admin/mail/bulk/menu", ids: threads.map(&:id), folder: "inbox", page: "2"
      end

      it "names how many threads it acts on" do
        expect(head).to eq("2 threads picked")
      end

      it "holds every bulk action" do
        expect(items).to eq(bulk)
      end

      it "posts to the bulk route with every picked thread and the list's place", :aggregate_failures do
        form = menu_form("Archive 2")

        expect(form[:action]).to eq("/admin/mail/bulk")
        expect(form.all("input[name='ids[]']", visible: :all).map(&:value)).to eq(threads.map { it.id.to_s })
        expect(fields(form)).to include("act" => "archive", "folder" => "inbox", "page" => "2")
      end

      it "labels with the account's label" do
        form = menu_form("#ops", within: submenu("Label"))

        expect(fields(form)).to include("act" => "label", "label" => "#{work.id}:ops")
      end

      it "snoozes every picked thread through the bulk snooze route" do
        expect(menu_form("Next week", within: submenu("Snooze"))[:action]).to eq("/admin/mail/bulk/snooze")
      end

      it "asks before it deletes" do
        expect(page).to have_css("button[data-confirm-inline='Click again to delete']", text: "Delete 2")
      end
    end

    it "offers Restore and Delete forever in the trash" do
      ids = [create(:message, trashed: true), create(:message, trashed: true)].map(&:id)
      get "/admin/mail/bulk/menu", ids:, folder: "trash"

      expect(items).to eq(["Restore 2", "Delete 2 forever"])
    end

    describe "snoozing picked threads" do
      let(:ids) { [create(:message), create(:message)].map(&:id) }

      it "snoozes every one with a toast", :aggregate_failures do
        act("/admin/mail/bulk/snooze", "ids[]": ids, pick: "2026-10-08T08:00", folder: "inbox")

        expect(ids.map { repo.by_id(it).snoozed_until }).to all(be > now)
        follow_redirect!
        expect(toast).to eq("Snoozed 2 threads until Oct 8, 2026")
      end

      it "refuses a time in the past with a toast that names the time", :aggregate_failures do
        act("/admin/mail/bulk/snooze", "ids[]": ids, pick: "2020-01-01T08:00", folder: "inbox")

        expect(ids.map { repo.by_id(it).snoozed_until }).to all(be_nil)
        follow_redirect!
        expect(toast).to eq("Nothing changed · a snooze ends after now")
      end

      it "refuses a time it cannot read with the same toast", :aggregate_failures do
        act("/admin/mail/bulk/snooze", "ids[]": ids, pick: "soon", folder: "inbox")

        expect(ids.map { repo.by_id(it).snoozed_until }).to all(be_nil)
        follow_redirect!
        expect(toast).to eq("Nothing changed · a snooze ends after now")
      end
    end
  end
end
