# frozen_string_literal: true

RSpec.describe "MCP mail tools", type: :request do
  def message_queries = Mail::Slice["repos.message_queries"]

  def week = { from: (today - 6).iso8601, to: today.iso8601 }

  describe "list_mail_threads" do
    def listed(from: today - 6, to: today, **)
      mcp_answer("list_mail_threads", from: from.iso8601, to: to.iso8601, **).fetch("mail_threads")
    end

    def listed_ids(**) = mcp_answer("list_mail_threads", **).fetch("mail_threads").map { it.fetch("id") }

    it "lists the messages in the range, newest first" do
      older = create(:message, received_at: at(today - 3, 9))
      newer = create(:message, received_at: at(today - 1, 9))

      expect(listed.map { it.fetch("id") }).to eq([newer.id, older.id])
    end

    it "keeps both edge days whole" do
      late = create(:message, received_at: at(today - 1, 23, 59))
      create(:message, received_at: at(today, 0))
      create(:message, received_at: at(today - 3, 23, 59))

      expect(listed(from: today - 2, to: today - 1).map { it.fetch("id") }).to eq([late.id])
    end

    it "says what the admin list shows" do
      message = create(:message, :read, subject: "Hello", reply_to: "someone@example.com", received_at: at(today, 0, 5))
      shown = { "subject" => marked("Hello"), "reply_to" => marked("someone@example.com"), "status" => "read" }
      stamps = { "received_at" => at(today, 0, 5).utc.iso8601, "snoozed_until" => nil }

      expect(listed.first).to eq("id" => message.id, "account" => "Contact form", **shown, "tags" => [], **stamps)
    end

    it "lists each message's tags in name order" do
      message = create(:message)
      %w[urgent billing].each { Mail::Slice["repos.message_tag_mutations"].add(message.id, it) }

      expect(listed.first.fetch("tags")).to eq(%w[billing urgent])
    end

    it "says when a snooze ends" do
      create(:message, received_at: at(today, 0), snoozed_until: Time.utc(2099, 1, 2, 3))

      expect(listed.first.fetch("snoozed_until")).to eq("2099-01-02T03:00:00Z")
    end

    it "narrows to one status" do
      create(:message, received_at: at(today, 0))
      spam = create(:message, :spam, received_at: at(today, 0))

      expect(listed(status: "spam").map { it.fetch("id") }).to eq([spam.id])
    end

    it "lists every message, newest first, when given no range" do
      older = create(:message, received_at: at(today - 900, 9))
      newer = create(:message, received_at: at(today, 0))

      answer = mcp_answer("list_mail_threads")

      expect([answer.fetch("mail_threads").map { it.fetch("id") }, answer.values_at("from", "to")])
        .to eq([[newer.id, older.id], [nil, nil]])
    end

    it "pages through every message in one status when given no range" do
      kept = 1.upto(3).map { create(:message, :spam, received_at: at(today - 900 - it, 9)) }
      create(:message, received_at: at(today, 0))
      lower_page_size(:mcp, to: 2)

      expect([1, 2].flat_map { listed_ids(status: "spam", page: it) }).to eq(kept.map(&:id))
    end

    it "lists every message up to a day when given only to" do
      kept = create(:message, received_at: at(today - 900, 9))
      create(:message, received_at: at(today, 0))

      expect(listed_ids(to: (today - 1).iso8601)).to eq([kept.id])
    end

    it "counts the messages in the range by status, whatever the status asked for" do
      create(:message, received_at: at(today, 0))
      create(:message, :spam, received_at: at(today - 1, 9))
      create(:message, :spam, received_at: at(today - 30, 9))

      expect(mcp_answer("list_mail_threads", **week, status: "spam").fetch("counts"))
        .to eq("unread" => 1, "read" => 0, "spam" => 1)
    end

    it "counts every message when given no range" do
      create(:message, :read, received_at: at(today - 900, 9))
      create(:message, :spam)

      expect(mcp_answer("list_mail_threads").fetch("counts")).to eq("unread" => 0, "read" => 1, "spam" => 1)
    end

    it "refuses a status the admin does not have" do
      expect(mcp_text("list_mail_threads", from: today.iso8601, to: today.iso8601, status: "archived"))
        .to include("/status")
    end

    it "refuses a range that runs backwards" do
      expect(mcp_text("list_mail_threads", from: today.iso8601, to: (today - 1).iso8601)).to eq("from comes after to")
    end
  end

  describe "read_mail_thread" do
    def gmail(name) = Mail::Slice["relations.mail_accounts"].dataset.insert(provider: "gmail", name:)

    it "reads the thread and its first message" do
      thread = create(:message, subject: "Hi", body: "I liked the post", reply_to: "a@example.com")

      expect(mcp_answer("read_mail_thread", id: thread.id)).to include(
        "id" => thread.id, "account" => "Contact form", "subject" => marked("Hi"), "status" => "unread",
        "messages" => [include("body" => marked("I liked the post"), "reply_to" => marked("a@example.com"))],
      )
    end

    it "reads every message in a thread from another account, oldest first" do
      thread = create(:message, mail_account_id: gmail("Work"), body: "First", received_at: at(today, 9))
      create(:mail_message, mail_thread_id: thread.id, body: "Second", visitor_hash: nil, received_at: at(today, 10))

      answer = mcp_answer("read_mail_thread", id: thread.id)

      expect([answer.fetch("account"), trusted(answer.fetch("messages")).map { it.fetch("body") }])
        .to eq(["Work", %w[First Second]])
    end

    it "keeps the sender's visitor hash back" do
      answer = mcp_answer("read_mail_thread", id: create(:message).id)
      thread_keys = %w[account id messages received_at snoozed_until status subject tags]

      expect([answer.keys.sort, answer.fetch("messages").first.keys.sort])
        .to eq([thread_keys, %w[body id received_at reply_to subject]])
    end

    it "says which tags it carries" do
      thread = create(:message)
      Mail::Slice["repos.message_tag_mutations"].add(thread.id, "billing")

      expect(mcp_answer("read_mail_thread", id: thread.id).fetch("tags")).to eq(%w[billing])
    end

    it "says when a snooze ends" do
      thread = create(:message, snoozed_until: Time.utc(2099, 1, 2, 3))

      expect(mcp_answer("read_mail_thread", id: thread.id).fetch("snoozed_until")).to eq("2099-01-02T03:00:00Z")
    end

    it "calls an unknown ID an error" do
      expect(mcp_text("read_mail_thread", id: 999_999)).to eq("no mail thread has the ID 999999")
    end
  end

  describe "make_mail_task" do
    let(:thread) { create(:message, subject: "Lunch on Friday") }

    def made(**) = mcp_answer("make_mail_task", id: thread.id, title: "Book lunch", **)

    def task_of(thread) = Links::Slice["repos.record_link_queries"].partner_ids("mail_thread", [thread.id], "task")

    def thread_queries = Mail::Slice["repos.thread_queries"]

    it "makes the task on the list it names, linked to the thread", :aggregate_failures do
      answer = made(list: "someday", archive: false)

      expect(answer).to include("title" => "Book lunch", "list" => "someday", "archived" => false)
      expect(task_of(thread)).to eq(thread.id => answer.fetch("id"))
      expect(thread_queries.by_id(thread.id).archived).to be(false)
    end

    it "puts the task on next and archives the thread when told nothing", :aggregate_failures do
      expect(made).to include("list" => "next", "archived" => true)
      expect(thread_queries.by_id(thread.id).archived).to be(true)
    end

    it "refuses a second task for the same thread", :aggregate_failures do
      made

      expect(mcp_text("make_mail_task", id: thread.id, title: "Again"))
        .to eq("mail thread #{thread.id} already has a task")
      expect(Tasks::Slice["relations.tasks"].where(title: "Again").count).to eq(0)
    end

    it "refuses a blank title and makes nothing", :aggregate_failures do
      expect(mcp_text("make_mail_task", id: thread.id, title: " ")).to eq("title: write the task down first")
      expect(task_of(thread)).to be_empty
    end

    it "calls an unknown ID an error" do
      expect(mcp_text("make_mail_task", id: 999_999, title: "Book lunch")).to eq("no mail thread has the ID 999999")
    end

    describe "on a Gmail thread" do
      let(:threads) { "#{Spec::GoogleAccounts::GMAIL}/threads" }
      let(:work) { create(:mail_account, name: "Work", address: "aaron@work.example") }

      before do
        connect_google(account_id: work.address, scopes: Spec::GoogleAccounts::GMAIL_SCOPES)
        stub_request(:post, "#{threads}/refused/modify").to_return(status: 500)
      end

      it "keeps the task and says archived is false when Gmail refuses to archive", :aggregate_failures do
        thread = create(:message, mail_account_id: work.id, gmail_id: "refused")
        answer = mcp_answer("make_mail_task", id: thread.id, title: "Reply")

        expect(answer).to include("archived" => false)
        expect(task_of(thread)).to eq(thread.id => answer.fetch("id"))
        expect(thread_queries.by_id(thread.id).archived).to be(false)
      end
    end
  end

  describe "mark_mail_thread" do
    it "marks a message read" do
      message = create(:message)
      mcp_call("mark_mail_thread", id: message.id, status: "read")

      expect(message_queries.by_id(message.id).status).to eq("read")
    end

    it "marks a message spam and says so" do
      message = create(:message, :read)

      expect(mcp_answer("mark_mail_thread", id: message.id,
                                            status: "spam")).to eq("id" => message.id, "status" => "spam")
    end

    it "calls an unknown ID an error" do
      expect(mcp_text("mark_mail_thread", id: 999_999, status: "read")).to eq("no mail thread has the ID 999999")
    end

    it "refuses a status the admin does not have" do
      message = create(:message)

      expect(mcp_text("mark_mail_thread", id: message.id, status: "archived")).to include("/status")
    end

    it "leaves the message alone when it refuses" do
      message = create(:message)
      mcp_call("mark_mail_thread", id: message.id, status: "archived")

      expect(message_queries.by_id(message.id).status).to eq("unread")
    end
  end

  describe "save_mail_draft" do
    let(:gmail) { Spec::GoogleAccounts::GMAIL }
    let(:requests) { [] }
    let(:scopes) { [*Spec::GoogleAccounts::GMAIL_SCOPES, "https://www.googleapis.com/auth/gmail.send"] }
    let(:work) { create(:mail_account, name: "Work", address: "aaron@work.example") }

    def raw = Base64.urlsafe_decode64(requests.last.dig("message", "raw"))

    def saved(**)
      mcp_answer("save_mail_draft", from: "Work", to: "ada@example.com", subject: "Plans", body: "Soon", **)
    end

    def stub_draft(verb, url)
      stub_request(verb, url).to_return do |request|
        requests << JSON.parse(request.body)
        google_health_json({ id: "r1", message: { id: "d1", threadId: "t5" } })
      end
    end

    before do
      connect_google(account_id: work.address, scopes:)
      stub_gmail_thread("t5", [gmail_message("d1", labels: %w[DRAFT], From: work.address, Subject: "Plans")])
    end

    it "saves a new draft to Gmail and answers with its id", :aggregate_failures do
      stub_draft(:post, "#{gmail}/drafts")

      expect(saved).to eq("draft" => "r1")
      expect(raw).to include("From: aaron@work.example", "To: ada@example.com", "Subject: Plans")
    end

    it "files it in the admin's Drafts" do
      stub_draft(:post, "#{gmail}/drafts")
      saved

      expect(Mail::Slice["relations.mail_threads"].where(gmail_id: "t5").one).to include(draft: true)
    end

    it "replaces the draft it names" do
      update = stub_draft(:put, "#{gmail}/drafts/r1")
      saved(draft: "r1")

      expect(update).to have_been_requested
    end

    it "refuses an account that cannot send" do
      create(:mail_account, name: "Home", address: "aaron@home.example")

      expect(mcp_text("save_mail_draft", from: "Home")).to include("names no account that can send")
    end

    it "says when Gmail would not save it" do
      stub_request(:post, "#{gmail}/drafts").to_return(status: 500)

      expect(mcp_text("save_mail_draft", from: "Work")).to eq("Gmail would not save the draft; try again")
    end
  end
end
