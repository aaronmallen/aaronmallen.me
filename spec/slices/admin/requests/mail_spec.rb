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
        gmail(subject: "Invoice overdue", body: "please pay", from_name: "Ada Lovelace")
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
        "subject" => ["lighthouse", %w[Lighthouse]],
        "body" => ["please", ["Invoice overdue"]],
        "sender" => ["lovelace", ["Invoice overdue"]],
        "tag" => ["billing", %w[Tagged]],
      }.each do |field, (query, listed)|
        it "finds a thread by its #{field}" do
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

        it "links a Gmail thread out to Gmail and keeps spam and delete for the contact form" do
          expect(acts).to eq(["Mark read", "Snooze", "Gmail"])
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

        expect(acts).to eq(["Mark unread", "Snooze", "Spam", "Delete"])
      end

      it "offers Not spam and Delete forever on spam" do
        thread = create(:message, :spam)
        get "/admin/mail", folder: "spam", thread: thread.id

        expect(acts).to eq(["Not spam", "Delete forever"])
      end

      it "offers Wake on a snoozed thread" do
        thread = create(:message, :read, snoozed_until: Time.now + 3600)
        get "/admin/mail", folder: "snoozed", thread: thread.id

        expect(acts).to eq(["Mark unread", "Wake", "Spam", "Delete"])
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
        act("/admin/mail/#{thread.id}/mark/spam", folder: "inbox", show: "all")

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

      it "wakes a snoozed thread" do
        thread = create(:message, snoozed_until: Time.now + 3600)
        act("/admin/mail/#{thread.id}/wake", folder: "snoozed")

        expect(repo.by_id(thread.id).snoozed_until).to be <= Time.now
      end
    end

    describe "select mode" do
      let(:threads) { Array.new(2) { create(:message) } }

      def bulk(name, **) = act("/admin/mail/bulk", act: name, ids: threads.map(&:id), folder: "inbox", **)

      it "draws a Select toggle and a bar the row boxes join", :aggregate_failures do
        threads
        get "/admin/mail"

        expect(page).to have_css("button[data-bulk-toggle='mail-bulk']", text: "Select", visible: :all)
        expect(page.all("form#mail-bulk button[name='act']").map(&:value)).to eq(%w[read unread delete])
        expect(page.all(".mail-row input[name='ids[]'][form='mail-bulk']").size).to eq(2)
      end

      it "marks every ticked thread read", :aggregate_failures do
        bulk("read")

        expect(threads.map { status(it) }).to eq(%w[read read])
        expect(last_response.location).to eq("/admin/mail?folder=inbox&show=all")
      end

      it "deletes every ticked thread", :aggregate_failures do
        bulk("delete")
        follow_redirect!

        expect(threads.map { repo.by_id(it.id) }).to eq([nil, nil])
        expect(toast).to eq("Deleted 2 threads")
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
