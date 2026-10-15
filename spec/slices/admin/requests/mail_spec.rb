# frozen_string_literal: true

RSpec.describe "Admin mail", type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:work) { create(:mail_account, name: "aaron@work.example", address: "aaron@work.example") }

  def act(path, **params) = post(path, { _csrf_token: admin_csrf_token, **params })

  def acts = page.all(".mail-acts button, .mail-acts a").map(&:text)

  def gmail(**) = create(:message, mail_account_id: work.id, **)

  def index(key, **) = Admin::Slice["i18n"].t(key, scope: "ui.views.mail.index", **)

  def label(thread, name)
    found = Mail::Slice["relations.mail_labels"].where(mail_account_id: work.id, name:).pluck(:id).first
    id = found || create(:mail_label, mail_account_id: work.id, name:).id
    create(:mail_thread_label, mail_thread_id: thread.id, mail_label_id: id)
  end

  def repo = Mail::Slice["repos.thread_queries"]

  def status(thread) = repo.by_id(thread.id)&.status

  def subjects = page.all(".mail-row-subject").map { it.text.sub(/ · \d+\z/, "") }

  def tag(thread, name) = Mail::Slice["repos.message_tag_mutations"].add(thread.id, name)

  def toast = page.find("[data-toast] .toast", visible: :all).text(:all)

  it "sends a visitor who isn't signed in to sign in" do
    get "/admin/mail"

    expect(last_response).to be_redirect
  end

  describe "signed in" do
    before { sign_in_to_admin }

    it "leaves no Messages screen behind" do
      get "/admin/messages"

      expect(last_response).to be_not_found
    end

    describe "the list" do
      before do
        gmail(subject: "From work", received_at: Time.now - 60)
        create(:message, subject: "From the form", received_at: Time.now)
      end

      it "lists threads from every account and the contact form, newest first" do
        get "/admin/mail"

        expect(subjects).to eq(["From the form", "From work"])
      end

      it "reads accounts and settings once and counts folders in one query", :aggregate_failures do
        sql = logged_sql { get "/admin/mail" }

        expect(sql.scan('SELECT "mail_accounts"."id"').size).to eq(1)
        expect(sql.scan('FROM "mail_settings"').size).to eq(1)
        expect(sql.scan("SELECT count(*) FILTER").size).to eq(1)
      end

      it "narrows to one account" do
        get "/admin/mail", account: work.id

        expect(subjects).to eq(["From work"])
      end

      it "offers every account in the picker with its unread count" do
        get "/admin/mail"

        expect(page.all("#mail-account option").map(&:text))
          .to eq(["All accounts · 2", "aaron@work.example · 1", "Contact form · 1"])
      end

      it "counts what is unread across the sources in the head" do
        get "/admin/mail"

        sub = index("sub", count: 2, sources: index("with_form", count: 1))

        expect(page).to have_css(".page-head-sub", exact_text: sub)
      end

      it "chips each row with its account when every account shows" do
        get "/admin/mail"

        expect(page).to have_css(".mail-row .mail-account.gr", text: "aaron@work.example")
      end

      it "drops the chip once one account is picked" do
        get "/admin/mail", account: work.id

        expect(page).to have_no_css(".mail-row .mail-account")
      end

      it "says the folder is empty" do
        get "/admin/mail", folder: "sent"

        expect(page).to have_css(".empty", exact_text: index("empty", name: "Sent"))
      end

      it "returns 404 for a page past the end" do
        get "/admin/mail", page: "2"

        expect(last_response).to be_not_found
      end
    end

    describe "folders" do
      before do
        gmail(subject: "Plain")
        gmail(subject: "Primary", category: "personal")
        gmail(subject: "Newsletter", category: "updates")
        gmail(subject: "Kept", starred: true, archived: true, status: "read")
        gmail(subject: "Later", snoozed_until: Time.now + 3600)
        gmail(subject: "Filed", archived: true)
        gmail(subject: "Unsent", draft: true)
        gmail(subject: "Junk", status: "spam", marked_spam_at: Time.now)
        gmail(subject: "Binned", trashed: true, starred: true)
        gmail(subject: "Replied", status: "read", archived: true, sent: true)
      end

      {
        "inbox" => %w[Plain Primary],
        "updates" => %w[Newsletter],
        "starred" => %w[Kept],
        "snoozed" => %w[Later],
        "sent" => %w[Replied],
        "drafts" => %w[Unsent],
        "all" => %w[Plain Primary Newsletter Kept Later Filed Replied],
        "spam" => %w[Junk],
        "trash" => %w[Binned],
      }.each do |folder, held|
        it "holds #{held.join(', ')} in #{folder}" do
          get "/admin/mail", folder:, account: work.id

          expect(subjects).to match_array(held)
        end
      end

      it "falls back to the inbox for a folder it doesn't know" do
        get "/admin/mail", folder: "junk", account: work.id

        expect(subjects).to match_array(%w[Plain Primary])
      end

      it "counts unread in the inbox and every thread in drafts, snoozed and spam on the sidebar" do
        get "/admin/mail", account: work.id

        counts = page.all(".mail-folders > a").to_h { [it.find(".mail-folder-name").text, it.text] }
        expect(counts.values_at("Inbox", "Updates", "Snoozed", "Drafts", "Spam", "Starred"))
          .to eq(%w[Inbox2 Updates1 Snoozed1 Drafts1 Spam1 Starred])
      end

      it "marks the open folder current" do
        get "/admin/mail", folder: "spam"

        expect(page).to have_css(".mail-folders a.on[aria-current='page'] .mail-folder-name", exact_text: "Spam")
      end

      it "offers the same folders in the select for narrow screens", :aggregate_failures do
        get "/admin/mail", folder: "drafts"

        expect(page).to have_css("select.mail-folder-select option[value='drafts'][selected]")
        expect(page.all("select.mail-folder-select optgroup:first-child option").map(&:value))
          .to eq(Blog::Types::MailFolder.values)
      end
    end

    describe "labels" do
      before do
        label(gmail(subject: "Plan it"), "planning")
        label(gmail(subject: "Plan it again", status: "read"), "planning")
        label(gmail(subject: "Planned junk", status: "spam", marked_spam_at: Time.now), "planning")
        tag(create(:message, subject: "Billing question"), "billing")
        gmail(subject: "Unlabeled")
      end

      it "lists a Gmail label's threads, spam aside" do
        get "/admin/mail", folder: "label:planning"

        expect(subjects).to contain_exactly("Plan it", "Plan it again")
      end

      it "lists a contact form tag as a label" do
        get "/admin/mail", folder: "label:billing"

        expect(subjects).to eq(["Billing question"])
      end

      it "groups labels under each account on the sidebar with their unread counts", :aggregate_failures do
        get "/admin/mail"

        groups = page.all(".mail-folder-group").map { it.all("a").map(&:text) }
        expect(groups).to eq([%w[planning1], %w[billing1]])
        expect(page.all(".mail-folder-head").map(&:text)).to eq(["aaron@work.example", "Contact form"])
      end

      it "shows only the picked account's labels" do
        get "/admin/mail", account: work.id

        expect(page.all(".mail-folder-group a").map { it.find(".mail-folder-name").text }).to eq(%w[planning])
      end

      it "offers labels in the select with their account" do
        get "/admin/mail"

        expect(page.all("select.mail-folder-select optgroup:last-child option").map(&:text))
          .to eq(["#planning · aaron@work.example", "#billing · Contact form"])
      end

      it "shows a row's labels" do
        get "/admin/mail"

        expect(page).to have_css(".mail-row .mail-label", text: "#planning")
      end

      it "leaves out the label the list is filed under" do
        get "/admin/mail", folder: "label:planning"

        expect(page).to have_no_css(".mail-label", text: "#planning")
      end
    end

    describe "unread and search" do
      before do
        gmail(subject: "Invoice overdue", body: "please pay", from_name: "Ada Lovelace",
              reply_to: "ada@engines.example")
        gmail(subject: "Lighthouse", body: "a question", status: "read")
        tag(create(:message, subject: "Tagged", status: "read"), "billing")
      end

      it "shows only unread threads with the unread switch" do
        get "/admin/mail", show: "unread"

        expect(subjects).to eq(["Invoice overdue"])
      end

      it "says nothing is unread in the folder" do
        get "/admin/mail", show: "unread", folder: "label:billing"

        expect(page).to have_css(".empty", exact_text: index("nothing_unread", name: "#billing"))
      end

      {
        "subject" => ["ighthou", %w[Lighthouse]],
        "body" => ["leas", ["Invoice overdue"]],
        "sender" => ["ovelac", ["Invoice overdue"]],
        "reply-to address" => ["engines.ex", ["Invoice overdue"]],
        "tag" => ["illin", %w[Tagged]],
      }.each do |field, (query, listed)|
        it "finds a thread by part of its #{field}" do
          get "/admin/mail", search: query

          expect(subjects).to eq(listed)
        end
      end

      it "says nothing matches when nothing does" do
        get "/admin/mail", search: "zebra"

        expect(page).to have_css(".empty", exact_text: index("no_match"))
      end

      it "keeps the search and switch in the form", :aggregate_failures do
        get "/admin/mail", search: "invoice", show: "unread"

        expect(page).to have_field("mail-search", with: "invoice")
        expect(page).to have_css(".seg input[name='show'][value='unread'][checked]")
      end
    end

    describe "a row" do
      describe "a snoozed, starred thread with a reply" do
        let(:row) { page.find("#thread-#{thread.id}") }
        let(:thread) do
          gmail(subject: "Release notes", from_name: "Sean Collins", body: "First", starred: true,
                snoozed_until: Time.now + 86_400, received_at: Time.now - 60)
        end

        before do
          create(:mail_message, mail_thread_id: thread.id, subject: "Re", body: "Latest word",
                                from_name: "Sean Collins")
          get "/admin/mail", folder: "snoozed"
        end

        it "names the sender and counts the messages beside the subject", :aggregate_failures do
          expect(row).to have_css(".mail-row-from", text: "Sean Collins")
          expect(row).to have_css(".mail-row-subject", exact_text: "Release notes · 2")
        end

        it "stars it" do
          expect(row).to have_css(".mail-row-when [aria-label='Starred']")
        end

        it "previews the latest message" do
          expect(row).to have_css(".mail-row-preview", text: "Latest word")
        end

        it "previews only the start of a long message" do
          create(:mail_message, mail_thread_id: thread.id, body: "#{'b' * 500}TAIL", received_at: Time.now + 60)
          get "/admin/mail", folder: "snoozed"

          expect(row).to have_css(".mail-row-preview", exact_text: "b" * 500)
        end

        it "dims it and says when it wakes", :aggregate_failures do
          expect(row[:class]).to include("snoozed")
          expect(row).to have_css(".mail-row-meta", text: "wakes")
        end
      end

      it "marks a draft and who it goes to" do
        gmail(subject: "Reply later", draft: true, reply_to: "jo@example.com")
        get "/admin/mail", folder: "drafts"

        expect(page).to have_css(".mail-row-from", text: "Draft to jo@example.com")
      end

      it "posts the open with the list it came from" do
        thread = gmail(subject: "Hello")
        get "/admin/mail", folder: "inbox", show: "unread", account: work.id

        form = page.find("form[action='/admin/mail/#{thread.id}/open']")
        expect(form.all("input[type='hidden']", visible: :all).to_h { [it[:name], it[:value]] })
          .to include("account" => work.id.to_s, "folder" => "inbox", "show" => "unread")
      end
    end

    describe "the why chips" do
      it "marks a row that waits in Waiting", :aggregate_failures do
        create(:message, subject: "Hi there")
        gmail(subject: "Quiet", status: "read")
        get "/admin/mail"

        expect(page.find(".mail-row", text: "Hi there")).to have_css(".mail-why", exact_text: "in waiting")
        expect(page.find(".mail-row", text: "Quiet")).to have_no_css(".mail-why")
      end

      it "leaves the chip off a snoozed row" do
        create(:message, subject: "Later", snoozed_until: Time.now + 86_400)
        get "/admin/mail", folder: "snoozed"

        expect(page.find(".mail-row", text: "Later")).to have_no_css(".mail-why")
      end

      it "names why the open thread waits" do
        thread = create(:message, subject: "Hi there")
        get "/admin/mail", thread: thread.id

        expect(page.find(".mail-reader > .inbox-meta")).to have_css(".mail-why", exact_text: "contact form")
      end
    end

    describe "opening a thread" do
      let(:thread) { gmail(subject: "Hello", from_name: "Ada Lovelace", received_at: Time.now - 120) }

      before do
        create(:mail_message, mail_thread_id: thread.id, subject: "Re", body: "My reply", reply_to: work.address,
                              received_at: Time.now - 60)
        create(:mail_message, mail_thread_id: thread.id, subject: "Re", body: "Her answer",
                              from_name: "Ada Lovelace", received_at: Time.now)
      end

      it "marks it read and lands on it in the same list", :aggregate_failures do
        act("/admin/mail/#{thread.id}/open", folder: "inbox", show: "all")

        expect(last_response.location).to eq("/admin/mail?folder=inbox&show=all&thread=#{thread.id}#read-#{thread.id}")
        expect(status(thread)).to eq("read")
      end

      it "answers 404 for a thread that is gone" do
        act("/admin/mail/999999/open")

        expect(last_response).to be_not_found
      end

      describe "the reader" do
        before do
          label(thread, "urgent")
          get "/admin/mail", thread: thread.id
        end

        it "shows the account, the address and the labels above the subject", :aggregate_failures do
          meta = page.find(".mail-reader > .inbox-meta")
          expect(meta).to have_css(".mail-account", text: "aaron@work.example")
          expect(meta).to have_css(".mail-label", exact_text: "#urgent")
          expect(page).to have_css(".mail-reader h2.mail-title", text: "Hello")
        end

        it "shows the subject and the latest message" do
          expect(page).to have_css(".mail-reader > .mail-message .mail-message-body", text: "Her answer")
        end

        it "shows a plain message as text" do
          expect(page).to have_css(".mail-reader > .mail-message p.msg-body.mail-message-body", text: "Her answer")
        end

        it "folds the earlier messages and names who wrote them", :aggregate_failures do
          earlier = page.find(".mail-reader details.mail-earlier")
          expect(earlier).to have_css("summary", text: "2 earlier messages · Ada Lovelace, you")
          expect(earlier).to have_css(".mail-message.me", text: "My reply", visible: :all)
        end

        it "highlights the open row" do
          expect(page).to have_css("#thread-#{thread.id}.on")
        end

        it "says the sender isn't in People and offers to add them", :aggregate_failures do
          expect(page).to have_css(".mail-who", text: "Ada Lovelace isn’t in People")
          expect(page).to have_link("Add to People", href: "/admin/people/new")
        end

        it "offers Trash and links a Gmail thread out to Gmail, keeping spam and delete for the contact form" do
          expect(acts).to eq(["Archive", "Snooze", "Make a task", "Star", "Mark read", "Trash", "Gmail"])
        end
      end

      describe "a message with HTML" do
        let(:body) { page.find(".mail-reader > .mail-message div.mail-message-body.mail-rich") }

        before do
          html = %(<p><a href="https://example.com/n">notes</a></p><ul><li>One</li></ul><img src="https://example.com/a.png">)
          create(:mail_message, mail_thread_id: thread.id, subject: "Re", body: "notes", html_body: html,
                                received_at: Time.now + 60)
          get "/admin/mail", thread: thread.id
        end

        it "shows its links inline" do
          expect(body).to have_link("notes", href: "https://example.com/n")
        end

        it "shows its lists" do
          expect(body).to have_css("ul > li", text: "One")
        end

        it "loads its remote images" do
          expect(body).to have_css("img[src='https://example.com/a.png']")
        end
      end

      it "shows the person's card when the sender is in People", :aggregate_failures do
        person = create(:person, name: "Ada Lovelace")
        get "/admin/mail", thread: thread.id

        expect(page).to have_css(".mail-who .mail-who-name", text: "Ada Lovelace")
        expect(page).to have_link("Open person", href: "/admin/people/#{person.id}/edit")
      end
    end

    describe "a contact form thread" do
      it "offers spam and delete" do
        thread = create(:message, :read)
        get "/admin/mail", thread: thread.id

        expect(acts).to eq(["Archive", "Snooze", "Make a task", "Star", "Mark unread", "Spam", "Delete"])
      end

      it "offers Not spam and Delete forever on spam" do
        thread = create(:message, :spam)
        get "/admin/mail", folder: "spam", thread: thread.id

        expect(acts).to eq(["Not spam", "Delete forever"])
      end

      it "offers Wake on a snoozed thread" do
        thread = create(:message, :read, snoozed_until: Time.now + 3600)
        get "/admin/mail", folder: "snoozed", thread: thread.id

        expect(acts).to eq(["Archive", "Wake", "Make a task", "Star", "Mark unread", "Spam", "Delete"])
      end

      it "says a stranger wrote through the contact form" do
        thread = create(:message, reply_to: "visitor@example.com")
        get "/admin/mail", thread: thread.id

        expect(page).to have_css(".mail-who", text: "visitor@example.com isn’t in People · via the contact form")
      end
    end

    describe "reader actions" do
      let(:thread) { create(:message) }

      it "marks a thread spam and lands back on it", :aggregate_failures do
        act("/admin/mail/#{thread.id}/change/spam", folder: "inbox", show: "all")

        expect(last_response.location).to eq("/admin/mail?folder=inbox&show=all&thread=#{thread.id}#read-#{thread.id}")
        expect(status(thread)).to eq("spam")
      end

      it "deletes a thread and keeps the list" do
        act("/admin/mail/#{thread.id}/delete", folder: "spam", show: "all")

        expect([last_response.location, repo.by_id(thread.id)]).to eq(["/admin/mail?folder=spam&show=all", nil])
      end

      it "snoozes a thread from the reader", :aggregate_failures do
        act("/admin/mail/#{thread.id}/snooze", pick: (Time.now + 86_400).strftime("%Y-%m-%dT%H:%M"), folder: "inbox")

        expect(last_response.location).to start_with("/admin/mail?folder=inbox&show=all&thread=#{thread.id}")
        expect(repo.by_id(thread.id).snoozed_until).to be > Time.now
      end

      describe "on a later page" do
        before { lower_page_size(:admin, to: 1) }

        def archive_on_page_three(count)
          thread = Array.new(count) { create(:message) }.first
          get "/admin/mail", page: "3", thread: thread.id
          form = page.find(".mail-acts form", text: "Archive")
          post(form[:action], form.all("input[type=hidden]", visible: :all).to_h { [it[:name], it[:value]] })
          last_response.location[/page=(\d+)/, 1]
        end

        it "keeps the page" do
          expect(archive_on_page_three(4)).to eq("3")
        end

        it "steps back a page when the archive empties the last one" do
          expect(archive_on_page_three(3)).to eq("2")
        end
      end

      it "wakes a snoozed thread" do
        thread = create(:message, snoozed_until: Time.now + 3600)
        act("/admin/mail/#{thread.id}/wake", folder: "snoozed")

        expect(repo.by_id(thread.id).snoozed_until).to be <= Time.now
      end
    end

    describe "writing to Gmail" do
      let(:threads) { "#{Spec::GoogleAccounts::GMAIL}/threads" }

      def bulk(name, picked, **) = act("/admin/mail/bulk", act: name, ids: picked.map(&:id), folder: "inbox", **)

      def change(thread, name) = act("/admin/mail/#{thread.id}/change/#{name}", folder: "inbox")

      def changed(gmail_id, verb = "modify", **body)
        a_request(:post, "#{threads}/#{gmail_id}/#{verb}").with { body.empty? || JSON.parse(it.body) == body }
      end

      def stored(thread) = repo.by_id(thread.id)

      def trash_from_reader(thread)
        get "/admin/mail", folder: "inbox", show: "all", thread: thread.id
        form = Capybara.string(last_response.body).find(".mail-acts form", text: "Trash")
        post(form[:action], form.all("input[type=hidden]", visible: :all).to_h { [it[:name], it[:value]] })
        follow_redirect!
        form[:action]
      end

      before do
        connect_google(account_id: work.address, scopes: Spec::GoogleAccounts::GMAIL_SCOPES)
        stub_request(:post, %r{\A#{threads}/}o).to_return(google_health_json({}))
        stub_request(:post, "#{threads}/refused/modify").to_return(status: 500)
        stub_request(:delete, %r{\A#{threads}/}o).to_return(status: 204)
        stub_request(:delete, "#{threads}/refused").to_return(status: 500)
      end

      it "archives a thread in Gmail and here", :aggregate_failures do
        thread = gmail(gmail_id: "t1")
        change(thread, "archive")

        expect(changed("t1", "removeLabelIds" => %w[INBOX])).to have_been_made
        expect(stored(thread).archived).to be(true)
      end

      it "stars a thread in Gmail", :aggregate_failures do
        thread = gmail(gmail_id: "t1")
        change(thread, "star")

        expect(changed("t1", "addLabelIds" => %w[STARRED])).to have_been_made
        expect(stored(thread).starred).to be(true)
      end

      it "unstars a thread in Gmail", :aggregate_failures do
        thread = gmail(gmail_id: "t1", starred: true)
        change(thread, "unstar")

        expect(changed("t1", "removeLabelIds" => %w[STARRED])).to have_been_made
        expect(stored(thread).starred).to be(false)
      end

      it "marks a thread read in Gmail", :aggregate_failures do
        thread = gmail(gmail_id: "t1")
        change(thread, "read")

        expect(changed("t1", "removeLabelIds" => %w[UNREAD])).to have_been_made
        expect(status(thread)).to eq("read")
      end

      it "takes a thread out of spam in Gmail when it marks it read", :aggregate_failures do
        thread = gmail(gmail_id: "t1", status: "spam", marked_spam_at: Time.now, archived: true)
        change(thread, "read")

        expect(changed("t1", "addLabelIds" => %w[INBOX], "removeLabelIds" => %w[UNREAD SPAM])).to have_been_made
        expect(stored(thread)).to have_attributes(status: "read", archived: false)
      end

      it "says Gmail refused and changes nothing here", :aggregate_failures do
        thread = gmail(gmail_id: "refused")
        change(thread, "archive")
        follow_redirect!

        expect(toast).to eq("Nothing changed · Gmail refused the change")
        expect(stored(thread).archived).to be(false)
      end

      it "deletes a Gmail thread forever in Gmail and here", :aggregate_failures do
        thread = gmail(gmail_id: "t1", trashed: true)
        act("/admin/mail/#{thread.id}/delete", folder: "trash")

        expect(a_request(:delete, "#{threads}/t1")).to have_been_made.once
        expect(stored(thread)).to be_nil
      end

      it "keeps a thread Gmail refuses to delete and says so", :aggregate_failures do
        thread = gmail(gmail_id: "refused", trashed: true)
        act("/admin/mail/#{thread.id}/delete", folder: "trash")
        follow_redirect!

        expect(toast).to eq("Nothing changed · Gmail refused the change")
        expect(stored(thread)).not_to be_nil
      end

      it "moves a Gmail thread to trash from the reader as the menu does and lands on the list", :aggregate_failures do
        thread = gmail(gmail_id: "t1")

        expect(trash_from_reader(thread)).to eq("/admin/mail/bulk")
        expect(changed("t1", "trash")).to have_been_made
        expect(stored(thread).trashed).to be(true)
        expect([last_request.fullpath, toast]).to eq(["/admin/mail?folder=inbox&show=all", "Moved 1 thread to Trash"])
      end

      it "keeps Restore and Delete forever on a Gmail thread in trash" do
        get "/admin/mail", folder: "trash", thread: gmail(gmail_id: "t1", trashed: true).id

        expect(acts).to eq(["Restore", "Delete forever"])
      end

      it "keeps Not spam and Delete forever on a Gmail thread in spam" do
        get "/admin/mail", folder: "spam", thread: gmail(gmail_id: "t1", status: "spam").id

        expect(acts).to eq(["Not spam", "Delete forever"])
      end

      it "offers Delete forever on a trashed Gmail thread" do
        thread = gmail(gmail_id: "t1", trashed: true)
        get "/admin/mail", folder: "trash", thread: thread.id

        expect(page.find(".mail-acts-far")).to have_button("Delete forever")
      end

      it "still opens a thread when Gmail refuses to mark it read", :aggregate_failures do
        thread = gmail(gmail_id: "refused")
        act("/admin/mail/#{thread.id}/open")

        expect(last_response).to be_redirect
        expect(status(thread)).to eq("unread")
      end

      it "changes a contact form thread here only", :aggregate_failures do
        thread = create(:message)
        change(thread, "star")

        expect(stored(thread).starred).to be(true)
        expect(a_request(:post, /gmail/)).not_to have_been_made
      end

      describe "from the bulk bar" do
        let(:picked) { [gmail(gmail_id: "t1"), gmail(gmail_id: "t2")] }

        {
          "archive" => [{ "removeLabelIds" => %w[INBOX] }, { archived: true }, "Archived 2 threads"],
          "read" => [{ "removeLabelIds" => %w[UNREAD] }, { status: "read" }, "Marked 2 threads read"],
          "unread" => [{ "addLabelIds" => %w[UNREAD] }, { status: "unread" }, "Moved 2 threads back to unread"],
        }.each do |name, (body, columns, said)|
          it "#{name}s every ticked thread in Gmail", :aggregate_failures do
            bulk(name, picked)
            follow_redirect!

            expect(picked.map { changed(it.gmail_id, **body) }).to all(have_been_made)
            expect(picked.map { stored(it) }).to all(have_attributes(columns))
            expect(toast).to eq(said)
          end
        end

        spammed = { "addLabelIds" => %w[SPAM], "removeLabelIds" => %w[INBOX] }
        {
          "star" => [{ "addLabelIds" => %w[STARRED] }, { starred: true }, "Starred 2 threads"],
          "spam" => [spammed, { status: "spam" }, "Moved 2 threads to Spam"],
        }.each do |to, (body, columns, said)|
          it "moves every ticked thread to #{to} in Gmail", :aggregate_failures do
            bulk("move", picked, to:)
            follow_redirect!

            expect(picked.map { changed(it.gmail_id, **body) }).to all(have_been_made)
            expect(picked.map { stored(it) }).to all(have_attributes(columns))
            expect(toast).to eq(said)
          end
        end

        it "trashes every ticked thread in Gmail", :aggregate_failures do
          bulk("trash", picked)
          follow_redirect!

          expect(%w[t1 t2].map { changed(it, "trash") }).to all(have_been_made)
          expect(picked.map { stored(it).trashed }).to eq([true, true])
          expect(toast).to eq("Moved 2 threads to Trash")
        end

        it "restores a trashed thread to the inbox and wakes it", :aggregate_failures do
          thread = gmail(gmail_id: "t3", trashed: true, archived: true, snoozed_until: Time.now + 3600)
          bulk("inbox", [thread])

          expect(changed("t3", "untrash")).to have_been_made
          expect(changed("t3", "addLabelIds" => %w[INBOX], "removeLabelIds" => %w[SPAM])).to have_been_made
          expect(stored(thread)).to have_attributes(trashed: false, archived: false, snoozed_until: nil)
        end

        describe "a label from one account" do
          let(:form) { create(:message) }

          before do
            create(:mail_label, mail_account_id: work.id, name: "Receipts", gmail_id: "Label_9")
            bulk("label", [*picked, form], label: "#{work.id}:Receipts")
            follow_redirect!
          end

          it "labels the threads it fits in Gmail and here", :aggregate_failures do
            expect(picked.map { changed(it.gmail_id, "addLabelIds" => %w[Label_9]) }).to all(have_been_made)
            expect(picked.map { stored(it).mail_labels.map(&:gmail_id) }).to eq([%w[Label_9], %w[Label_9]])
          end

          it "skips the threads it doesn't fit and says how many", :aggregate_failures do
            expect(stored(form).mail_labels).to be_empty
            expect(toast).to eq("Labeled 2 threads #Receipts · 1 skipped (label is on another account)")
          end
        end

        it "says nothing was labeled when the label fits none" do
          bulk("label", [create(:message)], label: "#{work.id}:Receipts")
          follow_redirect!

          expect(toast).to eq("#Receipts is on another account · nothing labeled")
        end

        it "tags a contact form thread with a contact form label" do
          form = create(:message)
          bulk("label", [form], label: "#{form.mail_account_id}:billing")

          expect(stored(form).tags.map(&:name)).to eq(%w[billing])
        end

        it "tags a Gmail thread here alone with a new tag", :aggregate_failures do
          thread = gmail(gmail_id: "t4")
          bulk("tag", [thread], tag: "later")

          expect(stored(thread).tags.map(&:name)).to eq(%w[later])
          expect(a_request(:post, %r{\A#{threads}/}o)).not_to have_been_made
        end

        it "deletes every ticked thread forever in Gmail and here", :aggregate_failures do
          bulk("delete", picked)
          follow_redirect!

          expect(%w[t1 t2].map { a_request(:delete, "#{threads}/#{it}") }).to all(have_been_made.once)
          expect(picked.map { stored(it) }).to eq([nil, nil])
          expect(toast).to eq("Deleted 2 threads forever")
        end

        it "names the thread Gmail refuses to delete and deletes none", :aggregate_failures do
          refused = gmail(gmail_id: "refused")
          bulk("delete", [refused, *picked])
          follow_redirect!

          expect([refused, *picked].map { stored(it) }).not_to include(nil)
          expect(toast).to eq("Nothing changed · Gmail refused thread ##{refused.id} #{refused.subject}")
        end

        it "offers Restore and Delete forever in the trash" do
          picked
          get "/admin/mail", folder: "trash"

          expect(page.all("form#mail-bulk button[name='act']").map(&:value)).to eq(%w[inbox delete])
        end

        it "offers each account's labels and the folders to move to", :aggregate_failures do
          create(:mail_label, mail_account_id: work.id, name: "Receipts")
          get "/admin/mail"

          expect(page.all("form#mail-bulk select[name='to'] option").map(&:value)).to eq(["", "star", "spam"])
          expect(page.all("form#mail-bulk select[name='label'] option").map(&:text))
            .to eq(["Label…", "#Receipts · aaron@work.example"])
        end
      end

      it "snoozes a Gmail thread here only and hides it until it wakes", :aggregate_failures do
        thread = gmail(gmail_id: "t1", subject: "Later")
        act("/admin/mail/#{thread.id}/snooze", pick: (Time.now + 86_400).strftime("%Y-%m-%dT%H:%M"))
        get "/admin/mail", account: work.id

        expect(subjects).not_to include("Later")
        expect(a_request(:post, /gmail/)).not_to have_been_made
      end
    end

    describe "Make a task" do
      let(:thread) { create(:message, subject: "Re: Fwd: Lunch on Friday") }

      def links = Links::Slice["repos.record_link_queries"]

      def make(**fields)
        act("/admin/mail/#{thread.id}/task", folder: "inbox", task: { title: "Book lunch", **fields })
      end

      def task_of(thread) = links.partner_ids("mail_thread", [thread.id], "task")[thread.id]

      it "offers a title from the subject without Re: or Fwd:", :aggregate_failures do
        get "/admin/mail", thread: thread.id

        dialog = page.find("dialog#mail-task-#{thread.id}", visible: :all)
        expect(dialog.find("input[name='task[title]']", visible: :all).value).to eq("Lunch on Friday")
        expect(dialog.all("input[name='task[list]']", visible: :all).map(&:value)).to eq(%w[today next someday])
        expect(dialog).to have_css("input[name='task[archive]'][checked]", visible: :all)
      end

      it "saves the task on the list it names, linked to the thread", :aggregate_failures do
        make(list: "someday", archive: "0")
        task = Tasks::Slice["repos.task_queries"].by_id(task_of(thread))

        expect([task.title, task.list]).to eq(["Book lunch", "someday"])
        expect(repo.by_id(thread.id).archived).to be(false)
        expect(last_response.location).to eq("/admin/mail?folder=inbox&show=all&thread=#{thread.id}#read-#{thread.id}")
      end

      it "labels the task dialog by its heading and saves from its foot", :aggregate_failures do
        get "/admin/mail", thread: thread.id

        id = "mail-task-#{thread.id}"
        expect(page).to have_css("dialog##{id}[aria-labelledby='#{id}-heading'] form##{id}-form", visible: :all)
        expect(page).to have_css("##{id} > .dialog-box > .dialog-foot [type=submit][form='#{id}-form']", visible: :all)
      end

      it "says the task keeps a link back to the thread" do
        get "/admin/mail", thread: thread.id

        expect(page.find("dialog#mail-task-#{thread.id}", visible: :all).text(:all))
          .to include(Admin::Slice["i18n"].t("ui.components.mail.task_dialog.linked"))
      end

      it "archives the thread when asked" do
        make(list: "next", archive: "1")

        expect(repo.by_id(thread.id).archived).to be(true)
      end

      it "says so with the task's number" do
        make(list: "next", archive: "1")
        follow_redirect!

        expect(toast).to eq("Made task ##{task_of(thread)}")
      end

      it "refuses a second task for the same thread", :aggregate_failures do
        make(list: "next")
        make(list: "next", title: "Again")
        follow_redirect!

        expect(Tasks::Slice["relations.tasks"].where(title: "Again").count).to eq(0)
        expect(toast).to eq("This thread already has a task")
      end

      describe "from two tabs at once", :commits do
        def database = Mail::Slice["db.rom"].gateways[:default].connection

        def held_by_another_session
          other = Sequel.connect(database.opts.merge(max_connections: 1))
          other.transaction do
            other[:mail_threads].where(id: thread.id).for_update.all
            yield
          end
        ensure
          other&.disconnect
        end

        def make_in_thread
          cookie = "#{Blog::SessionCookie::KEY}=#{Spec::AdminSession.cookie(csrf_token: admin_csrf_token)}"
          params = { _csrf_token: admin_csrf_token, folder: "inbox", task: { title: "Book lunch", list: "next" } }

          Thread.new { Rack::MockRequest.new(app).post("/admin/mail/#{thread.id}/task", params:, "HTTP_COOKIE" => cookie) }
        end

        def wait_until_both_wait
          waiting = database[:pg_stat_activity].where(datname: Sequel.function(:current_database),
                                                      wait_event_type: "Lock")
          Timeout.timeout(5) { sleep(0.01) until waiting.count == 2 }
        end

        it "makes one task" do
          tabs = held_by_another_session { Array.new(2) { make_in_thread }.tap { wait_until_both_wait } }
          tabs.each(&:join)

          expect(Tasks::Slice["relations.tasks"].where(title: "Book lunch").count).to eq(1)
        end
      end

      it "refuses a blank title and makes nothing", :aggregate_failures do
        make(title: " ")
        follow_redirect!

        expect([task_of(thread), toast]).to eq([nil, "Give the task a title"])
      end

      describe "on a Gmail thread" do
        let(:threads) { "#{Spec::GoogleAccounts::GMAIL}/threads" }

        before do
          connect_google(account_id: work.address, scopes: Spec::GoogleAccounts::GMAIL_SCOPES)
          stub_request(:post, %r{\A#{threads}/}o).to_return(google_health_json({}))
          stub_request(:post, "#{threads}/refused/modify").to_return(status: 500)
        end

        def make_on(thread) = act("/admin/mail/#{thread.id}/task", task: { title: "Reply", list: "next", archive: "1" })

        it "archives the thread in Gmail too", :aggregate_failures do
          thread = gmail(gmail_id: "t1")
          make_on(thread)

          expect(a_request(:post, "#{threads}/t1/modify").with(body: { removeLabelIds: %w[INBOX] }.to_json))
            .to have_been_made
          expect(repo.by_id(thread.id).archived).to be(true)
        end

        it "keeps the task and says so when Gmail refuses to archive", :aggregate_failures do
          thread = gmail(gmail_id: "refused")
          make_on(thread)
          follow_redirect!

          expect(toast).to eq("Made task ##{task_of(thread)} · Gmail refused to archive the thread")
          expect(repo.by_id(thread.id).archived).to be(false)
        end
      end

      it "answers 404 for a thread that is gone" do
        act("/admin/mail/999999/task", task: { title: "Book lunch" })

        expect(last_response).to be_not_found
      end

      describe "once the thread has a task" do
        before do
          make(list: "next")
          get "/admin/mail", folder: "all", thread: thread.id
        end

        it "trades Make a task for a link to the task", :aggregate_failures do
          expect(acts).not_to include("Make a task")
          expect(page).to have_link("Task ##{task_of(thread)}", href: "/admin/tasks/#{task_of(thread)}")
        end

        it "shows the task chip on the thread row" do
          expect(page).to have_css("#thread-#{thread.id} .mail-task", text: "task ##{task_of(thread)}")
        end

        it "lists the thread among the task's links" do
          get "/admin/tasks/#{task_of(thread)}"

          expect(page).to have_link("Re: Fwd: Lunch on Friday",
                                    href: "/admin/mail?folder=all&thread=#{thread.id}#read-#{thread.id}")
        end
      end
    end

    describe "select mode" do
      let(:threads) { Array.new(2) { create(:message) } }

      def bulk(name, **) = act("/admin/mail/bulk", act: name, ids: threads.map(&:id), folder: "inbox", **)

      it "draws a Select toggle and a bar the row boxes join", :aggregate_failures do
        threads
        get "/admin/mail"

        expect(page).to have_css("button[data-bulk-toggle='mail-bulk']", text: "Select")
        expect(page.all("form#mail-bulk button[name='act']").map(&:value)).to eq(%w[archive read unread move trash])
        expect(page.all(".mail-row input[name='ids[]'][form='mail-bulk']").size).to eq(2)
      end

      describe "dragging" do
        before do
          threads
          label(gmail(subject: "Receipt"), "Receipts")
          get "/admin/mail"
        end

        it "says rows drag onto a folder or a label" do
          expect(page.find("form#mail-bulk .bulk-hint", visible: :all).text(:all))
            .to eq(Admin::Slice["i18n"].t("ui.components.mail.bulk.hint"))
        end

        it "lets every row drag onto the folders and the label", :aggregate_failures do
          expect(page.all("[data-mail-drop]", visible: :all).map { it["data-mail-drop"] })
            .to include("inbox", "star", "archive", "spam", "trash", "label")
          expect(page.all("[data-mail-drag]", visible: :all).size).to eq(3)
        end

        it "acts on every ticked row, as a drop does" do
          bulk("archive")

          expect(threads.map { repo.by_id(it.id).archived }).to eq([true, true])
        end
      end

      it "starts with select mode off, so the list shows Select with scripts off", :aggregate_failures do
        threads
        get "/admin/mail"

        expect(page).to have_css("button[data-bulk-toggle='mail-bulk'][aria-pressed='false']", text: "Select")
        expect(page).to have_css("form#mail-bulk[data-bulk-off]")
      end

      it "keeps the browser from restoring ticks on reload", :aggregate_failures do
        threads
        get "/admin/mail"

        expect(page.all(".mail-row input[name='ids[]'][autocomplete='off']").size).to eq(2)
        expect(page).to have_css("form#mail-bulk [data-bulk-all] input[autocomplete='off']", visible: :all)
      end

      it "marks every ticked thread read", :aggregate_failures do
        bulk("read")

        expect(threads.map { status(it) }).to eq(%w[read read])
        expect(last_response.location).to eq("/admin/mail?folder=inbox&show=all")
      end

      it "deletes every ticked thread forever", :aggregate_failures do
        bulk("delete")
        follow_redirect!

        expect(threads.map { repo.by_id(it.id) }).to eq([nil, nil])
        expect(toast).to eq("Deleted 2 threads forever")
      end

      it "names a thread that is gone" do
        gone = create(:message).tap { Mail::Slice["repos.message_mutations"].delete(it.id) }
        act("/admin/mail/bulk", act: "read", ids: [gone.id])
        follow_redirect!

        expect(toast).to eq("Nothing changed · thread ##{gone.id} is gone")
      end
    end
  end
end
