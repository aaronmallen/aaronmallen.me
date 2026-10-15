# frozen_string_literal: true

RSpec.describe Mail::Jobs::SyncGmail do
  let(:address) { "aaron@example.com" }
  let(:receipts) { [{ id: "Label_1", name: "Receipts", type: "user" }] }
  let(:sync) { Blog::Types::SyncName["mail"] }

  def account = rows("mail_accounts").where(address:).one

  def asked_history_from(start)
    a_request(:get, %r{/gmail/v1/users/me/history\?}).with(query: hash_including("startHistoryId" => start))
  end

  def backfills = Mail::Jobs::BackfillGmail.jobs.map { it["args"] }

  def connect(**) = connect_google(account_id: address, scopes: Spec::GoogleAccounts::GMAIL_SCOPES, **)

  def failure = Record::Slice["repos.sync_state_queries"].failure(sync)

  def follow(history_id) = Mail::Slice["repos.gmail_mutations"].follow(account.id, history_id)

  def history_page(ids, **) = google_health_json({ history: [{ messages: ids.map { { threadId: it } } }], ** })

  def hour_passes = rows("mail_accounts").where(address:).dataset.update(settings_synced_at: Time.now - 3601)

  def label_names(thread)
    ids = rows("mail_thread_labels").where(mail_thread_id: thread.id).pluck(:mail_label_id)

    rows("mail_labels").where(id: ids).pluck(:name)
  end

  def message = messages(thread).first

  def messages(thread) = rows("mail_messages").where(mail_thread_id: thread.id).to_a

  def rows(name) = Mail::Slice["relations.#{name}"].with(auto_struct: true)

  def run = described_class.new.perform

  def run_an_hour_later = hour_passes.then { run }

  def sync_message(**)
    stub_gmail(history: %w[t1], threads: { "t1" => [gmail_message("m1", **)] })
    run
  end

  def sync_messages(*labels)
    sent = labels.each.with_index(1).map { |labels_of, index| gmail_message("m#{index}", labels: labels_of) }

    stub_gmail(history: %w[t1], threads: { "t1" => sent })
    run
  end

  def thread(gmail_id = "t1") = rows("mail_threads").where(gmail_id:).one

  def threads_in(folder) = rows("mail_threads").in_folder(Blog::Types::MailFolder[folder]).to_a.map(&:gmail_id)

  describe "an account syncing for the first time" do
    before do
      connect
      stub_gmail(profile: "100", labels: receipts)
      run
    end

    it "starts following its history from where Gmail is now" do
      expect(account).to have_attributes(provider: "gmail", name: address, history_id: "100")
    end

    it("queues a backfill of its mail") { expect(backfills).to eq([[address]]) }

    it "stores its labels" do
      expect(rows("mail_labels").to_a).to contain_exactly(have_attributes(gmail_id: "Label_1", name: "Receipts"))
    end
  end

  describe "an account's Gmail signature" do
    before { connect }

    it "stores it with script stripped" do
      stub_gmail(signature: "<div>Aaron<script>alert(1)</script></div>")
      run

      expect(account.signature).to eq("<div>Aaron</div>")
    end

    it "clears it when Gmail has none" do
      stub_gmail(signature: "<b>Old</b>")
      run
      stub_gmail
      run_an_hour_later

      expect(account.signature).to be_nil
    end
  end

  describe "an account it has synced before" do
    let(:sent_at) { Time.at(Time.now.to_i) }

    before do
      connect
      stub_gmail
      run
      Mail::Jobs::BackfillGmail.jobs.clear
    end

    describe "with new mail" do
      def stored_message
        {
          gmail_id: "m1", subject: "Engines", reply_to: "ada@example.com", from_name: "Ada Lovelace",
          body: "Hello there", html_body: "<p>Hello there</p>", received_at: sent_at, visitor_hash: nil,
        }
      end

      def stored_thread
        {
          mail_account_id: account.id, subject: "Engines", status: "unread", starred: true, archived: false,
          trashed: false, sent: false, important: false, category: "updates", received_at: sent_at,
        }
      end

      before do
        labels = %w[INBOX UNREAD STARRED CATEGORY_UPDATES Label_1]
        threads = { "t1" => [gmail_message("m1", labels:, at: sent_at)] }
        stub_gmail(history: %w[t1 t1], history_id: "250", labels: receipts, threads:)
        run
      end

      it("stores the thread with its state") { expect(thread).to have_attributes(stored_thread) }

      it "stores each message with its sender and bodies" do
        expect(messages(thread)).to contain_exactly(have_attributes(stored_message))
      end

      it("puts the thread under its labels") { expect(label_names(thread)).to eq(%w[Receipts]) }

      it("moves on to the history Gmail answered with") { expect(account.history_id).to eq("250") }

      it("asks for history from where it left off") { expect(asked_history_from("100")).to have_been_made }

      it("clears the failure") { expect(failure).to be_nil }

      it "keeps a snooze and tags when Gmail changes the thread" do
        Mail::Slice["repos.message_mutations"].snooze(thread.id, sent_at + 3600)
        Mail::Slice["repos.message_tag_mutations"].add(thread.id, "people")
        sync_message(labels: %w[INBOX])

        expect(Mail::Slice["repos.message_queries"].by_id(thread.id))
          .to have_attributes(status: "read", snoozed_until: sent_at + 3600, tags: [have_attributes(name: "people")])
      end
    end

    describe "labels and the signature" do
      before { stub_gmail(labels: receipts, signature: "<b>New</b>") }

      it "leaves them alone within the hour", :aggregate_failures do
        run

        expect(a_request(:get, "#{Spec::GoogleAccounts::GMAIL}/labels")).to have_been_made.once
        expect([rows("mail_labels").to_a, account.signature]).to eq([[], nil])
      end

      it "refreshes them once an hour has passed", :aggregate_failures do
        run_an_hour_later

        expect(rows("mail_labels").pluck(:name)).to eq(%w[Receipts])
        expect(account.signature).to eq("<b>New</b>")
      end

      it "refreshes them when new mail carries a label it doesn't hold" do
        stub_gmail(history: %w[t1], labels: receipts, threads: { "t1" => [gmail_message("m1", labels: %w[Label_1])] })
        run

        expect(label_names(thread)).to eq(%w[Receipts])
      end
    end

    it "reads each account's connection once per sync" do
      connect_google(account_id: "b@example.com", scopes: Spec::GoogleAccounts::GMAIL_SCOPES, token: "ya29.b")
      stub_gmail(history: %w[t1], threads: { "t1" => [gmail_message("m1")] })

      expect(counting { run }.grep(/"service_connections"/).size).to eq(1)
    end

    it "sends the admin no notice when Gmail has nothing new", :commits do
      stub_gmail(labels: receipts)
      run
      stub_gmail(history_id: "300", labels: receipts)

      expect(admin_notice { run }).to be_nil
    end

    describe "a change made in Gmail" do
      before do
        stub_gmail(history: %w[t1], threads: { "t1" => [gmail_message("m1"), gmail_message("m2")] })
        run
      end

      it "marks the thread read and unstarred, and archives it" do
        sync_message(labels: %w[CATEGORY_PERSONAL])

        expect(thread).to have_attributes(status: "read", starred: false, archived: true, category: "personal")
      end

      it "marks the thread as spam" do
        sync_message(labels: %w[SPAM])

        expect(thread).to have_attributes(status: "spam", marked_spam_at: be_within(5).of(Time.now))
      end

      it "marks a thread Gmail calls important" do
        sync_message(labels: %w[INBOX IMPORTANT])

        expect(thread.important).to be(true)
      end

      it "files a draft" do
        sync_message(labels: %w[DRAFT])

        expect(thread.draft).to be(true)
      end

      it "moves the thread to the trash" do
        sync_message(labels: %w[TRASH])

        expect(thread.trashed).to be(true)
      end

      it "keeps a sent thread as sent" do
        sync_message(labels: %w[SENT])

        expect(thread.sent).to be(true)
      end

      it "brings a trashed thread back to the inbox, unread, when a reply arrives", :aggregate_failures do
        sync_messages(%w[TRASH], %w[INBOX UNREAD])

        expect(threads_in("inbox")).to eq(%w[t1])
        expect(thread).to have_attributes(status: "unread", trashed: false)
      end

      it "keeps a thread in the inbox while a reply to it is a draft", :aggregate_failures do
        sync_messages(%w[INBOX], %w[DRAFT])

        expect(threads_in("inbox")).to eq(%w[t1])
        expect(thread.draft).to be(false)
      end

      it "keeps a thread out of spam while one of its messages is not" do
        sync_messages(%w[SPAM], %w[INBOX])

        expect(thread).to have_attributes(status: "read", marked_spam_at: nil)
      end

      it "files a thread in the trash, drafts and spam when every message is there", :aggregate_failures do
        sync_messages(%w[TRASH DRAFT SPAM], %w[TRASH DRAFT SPAM])

        expect(thread).to have_attributes(trashed: true, draft: true, status: "spam")
      end

      it "counts inbox, unread, starred, sent and important from any one message" do
        sync_messages(%w[INBOX UNREAD STARRED], %w[SENT IMPORTANT])

        expect(thread).to have_attributes(archived: false, status: "unread", starred: true, sent: true, important: true)
      end

      it "drops a message Gmail deleted" do
        sync_message(labels: %w[INBOX])

        expect(messages(thread).map(&:gmail_id)).to eq(%w[m1])
      end

      it "drops a thread Gmail deleted" do
        stub_gmail(history: %w[t1])
        stub_request(:get, %r{/threads/t1\?}).to_return(status: 404)
        run

        expect(thread).to be_nil
      end
    end

    it "strips script from a stored HTML body", :aggregate_failures do
      html = %(<p onclick="steal()">Hi</p><script>steal()</script><a href="javascript:steal()">x</a><style>*{}</style>)
      sync_message(parts: [gmail_part("text/html", html)])

      expect(message.html_body).to eq("<p>Hi</p><a>x</a>")
      expect(message.body).to eq("Hi x")
    end

    it "keeps the styling of a stored HTML body but not its position" do
      html = %(<div style="position: fixed; z-index: 9999; top: 0; color: red"><img src="https://example.com/a.png">Hi</div>)
      sync_message(parts: [gmail_part("text/html", html)])

      expect(message.html_body).to eq(%(<div style="  top: 0; color: red"><img src="https://example.com/a.png">Hi</div>))
    end

    it "reads a body in the charset its part names" do
      sync_message(parts: [gmail_part("text/plain", "Caf\xE9".b, charset: "ISO-8859-1")])

      expect(message.body).to eq("Café")
    end

    it "skips attachments and keeps an address it can't reply to out" do
      sync_message(parts: [gmail_part("text/plain", "Report", filename: "a.txt")], From: "root@localhost", Subject: "")

      expect(message).to have_attributes(body: nil, reply_to: nil, subject: "(no subject)")
    end

    it "treats a filename of only whitespace as no filename", :aggregate_failures do
      blank = { **gmail_part("application/pdf", "%PDF"), partId: "2", filename: "   　 " }
      sync_message(parts: [gmail_part("text/plain", "Report"), blank])

      expect(message.body).to eq("Report")
      expect(rows("mail_attachments").to_a).to be_empty
      expect(failure).to be_nil
    end

    it "treats a subject, sender name and body of only Unicode whitespace as blank", :aggregate_failures do
      sync_message(parts: [gmail_part("text/plain", "  \n")], Subject: "　 ", From: "  <ada@example.com>")

      expect(message).to have_attributes(body: nil, from_name: nil, subject: "(no subject)")
      expect(thread.subject).to eq("(no subject)")
      expect(failure).to be_nil
    end

    it "reads every page of history Gmail sends" do
      stub_gmail(threads: { "t1" => [gmail_message("m1")], "t2" => [gmail_message("m2")] })
      stub_request(:get, %r{/history\?}).to_return(history_page(%w[t1], nextPageToken: "page-2", historyId: "300"))
      stub_request(:get, %r{/history\?.*pageToken=page-2}).to_return(history_page(%w[t2], historyId: "300"))
      run

      expect(rows("mail_threads").pluck(:gmail_id)).to contain_exactly("t1", "t2")
    end

    it "starts over when Gmail no longer holds the history it left off at", :aggregate_failures do
      stub_gmail(profile: "900")
      stub_request(:get, %r{/history\?}).to_return(status: 404)
      run

      expect([account.history_id, backfills]).to eq(["900", [[address]]])
    end

    describe "after a run that failed" do
      before do
        follow("150")
        stub_gmail(history: %w[t1], threads: { "t1" => [gmail_message("m1")] })
        stub_request(:get, %r{/threads/t1\?}).to_return(status: 503)
        run
      end

      it "records the failure where read_sync_state finds it", :aggregate_failures do
        expect(failure).to include(reason: "gmail_failed", message: "Google answered 503", count: 1)
        expect(account.history_id).to eq("150")
      end

      it "catches up on the next run", :aggregate_failures do
        sync_message

        expect(asked_history_from("150")).to have_been_made.twice
        expect([thread&.subject, failure]).to eq(["Engines", nil])
      end
    end
  end

  describe "a run Gmail rate limits" do
    before do
      connect
      stub_gmail
      run
      follow("150")
      stub_gmail(history: %w[t1], history_id: "250", threads: { "t1" => [gmail_message("m1")] })
      stub_request(:get, %r{/threads/t1\?}).to_return(
        google_health_json({ error: { code: 403, errors: [{ reason: "userRateLimitExceeded" }] } }).merge(status: 403),
      )
      run
    end

    it("keeps the history it left off at") { expect(account.history_id).to eq("150") }

    it "records the failure and catches up on the next run" do
      expect(failure).to include(reason: "gmail_failed", message: "Google answered 403", count: 1)
    end
  end

  it "syncs every account that granted Gmail and leaves the others alone", :aggregate_failures do
    connect
    connect_google(account_id: "health@example.com", token: "ya29.health")
    stub_gmail.then { run }

    expect(rows("mail_accounts").where(provider: "gmail").pluck(:address)).to eq([address])
    expect(a_request(:any, /gmail/).with(headers: { "Authorization" => "Bearer ya29.health" })).not_to have_been_made
  end

  it "records a revoked token as needing a reconnect" do
    connect(revoked_at: Time.now)
    run

    expect(failure).to include(reason: "gmail_failed", message: "#{address} needs a reconnect")
  end

  describe "a revoked account that sorts first" do
    before do
      connect_google(account_id: "aa@example.com", scopes: Spec::GoogleAccounts::GMAIL_SCOPES, revoked_at: Time.now)
      connect
      stub_gmail(profile: "100")
      run
    end

    it("still syncs the next account") { expect(account.history_id).to eq("100") }

    it "records the revoked one as needing a reconnect" do
      expect(failure).to include(reason: "gmail_failed", message: "aa@example.com needs a reconnect")
    end
  end

  describe "a failing account that sorts first" do
    before do
      connect_google(account_id: "aa@example.com", scopes: Spec::GoogleAccounts::GMAIL_SCOPES, token: "ya29.failing")
      connect
      stub_gmail(profile: "100")
      stub_request(:get, "#{Spec::GoogleAccounts::GMAIL}/labels")
        .with(headers: { "Authorization" => "Bearer ya29.failing" }).to_return(status: 503)
      run
    end

    it("still syncs the next account") { expect(account.history_id).to eq("100") }

    it "records the failure" do
      expect(failure).to include(reason: "gmail_failed", message: "Google answered 503")
    end
  end

  it "asks Google nothing and records nothing while no account granted Gmail", :aggregate_failures do
    run

    expect(a_request(:any, /gmail\.googleapis\.com/)).not_to have_been_made
    expect(failure).to be_nil
  end

  describe "a run that crashes" do
    before { replace_component("operations.sync_gmail", ->(*) { raise KeyError, "key not found: :id" }) }

    def run_crashing
      run
    rescue KeyError
      nil
    end

    it "records the crash where the admin reads it" do
      run_crashing

      expect(failure).to include(reason: "crashed", message: "key not found: :id")
    end

    it "still raises, so the error reaches error tracking" do
      expect { run }.to raise_error(KeyError, /key not found/)
    end
  end
end
