# frozen_string_literal: true

RSpec.describe "Admin messages", type: :request do
  let(:i18n) { Admin::Slice["i18n"] }
  let(:page) { Capybara.string(last_response.body) }
  let(:repo) { Contact::Slice["repos.message_queries"] }

  def empty_text(status) = i18n.t(["ui.views.messages.index.empty", status].join("."))

  def pick_text = i18n.t("ui.views.messages.index.pick")

  def subjects = page.all(".msg-item-title").map(&:text)

  describe "signed in" do
    before { sign_in_to_admin }

    describe "paging" do
      before do
        lower_page_size(:admin, to: 2)
        %w[First Second Third].each_with_index do |subject, index|
          create(:message, :read, subject:, received_at: Time.utc(2026, 9, 1 + index))
        end
        create(:message, subject: "Waiting")
      end

      it "shows the newest page and links to older messages", :aggregate_failures do
        get "/admin/messages", status: "read"

        expect(subjects).to eq(%w[Third Second])
        expect(page).to have_css("nav.pager a[rel='next'][href='/admin/messages?status=read&page=2']", text: "Older")
      end

      it "keeps the filter on a later page", :aggregate_failures do
        get "/admin/messages", status: "read", page: "2"

        expect(subjects).to eq(%w[First])
        expect(page).to have_css("nav.pager a[rel='prev'][href='/admin/messages?status=read']", text: "Newer")
        expect(page).to have_css(".seg input[value='read'][checked]")
      end

      it "counts every message under the filter, not the page" do
        get "/admin/messages", status: "read"

        expect(page).to have_css(".page-head-sub", exact_text: "3 messages")
      end

      it "draws no pager when one page holds every message" do
        get "/admin/messages"

        expect(page).to have_no_css("nav.pager")
      end

      it "returns 404 for a page past the end" do
        get "/admin/messages", status: "read", page: "3"

        expect(last_response).to be_not_found
      end
    end

    describe "the inbox" do
      before do
        create(:message, subject: "Waiting")
        create(:message, :read, subject: "Answered")
        create(:message, :spam, subject: "Junk")
      end

      { "unread" => "Waiting", "read" => "Answered", "spam" => "Junk" }.each do |status, listed|
        it "shows only #{status} messages with the #{status} filter" do
          get "/admin/messages", status: status

          expect(subjects).to eq([listed])
        end

        it "checks the #{status} filter" do
          get "/admin/messages", status: status

          expect(page).to have_css(".seg input[name='status'][value='#{status}'][checked]")
        end
      end

      it "shows unread messages without a filter" do
        get "/admin/messages"

        expect(subjects).to eq(%w[Waiting])
      end

      it "shows unread messages for a filter it doesn't know" do
        get "/admin/messages", status: "junk"

        expect(subjects).to eq(%w[Waiting])
      end

      it "shows every message but spam with the inbox filter" do
        get "/admin/messages", status: "inbox"

        expect(subjects).to contain_exactly("Waiting", "Answered")
      end

      it "offers inbox, unread, read and spam in that order" do
        get "/admin/messages"

        expect(page.all(".seg input[name='status']", visible: :all).map(&:value)).to eq(%w[inbox unread read spam])
      end
    end

    describe "searching" do
      def tagging = Contact::Slice["repos.message_tag_mutations"]

      before do
        create(:message, subject: "Invoice overdue", reply_to: "ada@example.com", body: "please pay")
        create(:message, subject: "Hello", reply_to: "grace@example.com", body: "a lighthouse question")
        tagging.add(create(:message, subject: "Tagged", body: "nothing here").id, "billing")
        create(:message, :spam, subject: "Invoice scam")
      end

      {
        "subject" => ["invoice", ["Invoice overdue"]],
        "sender" => ["grace@", %w[Hello]],
        "body" => ["lighthouse", %w[Hello]],
        "tag" => ["billing", %w[Tagged]],
      }.each do |field, (query, listed)|
        it "finds a message by its #{field}" do
          get "/admin/messages", status: "inbox", search: query

          expect(subjects).to eq(listed)
        end
      end

      it "searches within the filter" do
        get "/admin/messages", status: "spam", search: "invoice"

        expect(subjects).to eq(["Invoice scam"])
      end

      it "counts only what matches" do
        get "/admin/messages", search: "invoice"

        expect(page).to have_css(".page-head-sub", exact_text: "1 message")
      end

      it "says nothing matches when nothing does" do
        get "/admin/messages", search: "zebra"

        expect(page).to have_css(".empty", exact_text: i18n.t("ui.views.messages.index.no_match"))
      end

      it "keeps the search in the box" do
        get "/admin/messages", search: "invoice"

        expect(page).to have_field("messages-search", with: "invoice")
      end

      it "treats a wildcard as plain text" do
        get "/admin/messages", status: "inbox", search: "%"

        expect(subjects).to be_empty
      end

      it "keeps the search on the pager" do
        lower_page_size(:admin, to: 1)
        create(:message, subject: "Invoice again")
        get "/admin/messages", search: "invoice"

        expect(page).to have_css("nav.pager a[rel='next'][href='/admin/messages?status=unread&search=invoice&page=2']")
      end

      it "keeps the search in a row's open form" do
        get "/admin/messages", search: "invoice"

        expect(page).to have_css(".msg-item-form input[name='search'][value='invoice']", visible: :all)
      end

      it "keeps the search in the bulk bar" do
        get "/admin/messages", search: "invoice"

        expect(page).to have_css("#message-bulk input[name='search'][value='invoice']", visible: :all)
      end
    end

    describe "the tag select" do
      def tagging = Contact::Slice["repos.message_tag_mutations"]

      it "hides when no message has tags" do
        create(:message)
        get "/admin/messages"

        expect(page).to have_no_select("tag")
      end

      describe "with tagged messages" do
        before do
          tagging.add(create(:message, subject: "Bill").id, "billing")
          tagging.add(create(:message, subject: "Urgent bill").id, "billing")
          tagging.add(create(:message, subject: "Hurry").id, "urgent")
          create(:message, subject: "Plain")
          create(:tag, name: "unused")
        end

        it "offers the tags messages carry" do
          get "/admin/messages"

          expect(page.all("select[name='tag'] option").map(&:value)).to eq(["", "billing", "urgent"])
        end

        it "lists only messages with that tag" do
          get "/admin/messages", tag: "billing"

          expect(subjects).to contain_exactly("Bill", "Urgent bill")
        end

        it "selects the chosen tag" do
          get "/admin/messages", tag: "urgent"

          expect(page).to have_select("messages-tag", selected: "urgent")
        end

        it "lists everything with no tag chosen" do
          get "/admin/messages", tag: ""

          expect(subjects).to contain_exactly("Bill", "Urgent bill", "Hurry", "Plain")
        end
      end
    end

    it "lists the newest message first" do
      create(:message, subject: "Older", received_at: Time.utc(2026, 9, 1))
      create(:message, subject: "Newer", received_at: Time.utc(2026, 9, 8))
      get "/admin/messages"

      expect(subjects).to eq(%w[Newer Older])
    end

    describe "a row" do
      let(:arrived) { Time.utc(2026, 9, 7, 17, 30) }
      let(:id) { repo.by_status("unread").first.id }

      before do
        create(:message, reply_to: "ada@example.com", subject: "A question", body: "How?", received_at: arrived)
        get "/admin/messages"
      end

      it "shows the subject, the body and the reply address", :aggregate_failures do
        expect(page).to have_css(".msg-item-title", text: "A question")
        expect(page).to have_css(".msg-item-preview", text: "How?")
        expect(page).to have_css(".msg-item-from", text: "ada@example.com")
      end

      it "posts to open the message, keeping the list" do
        expect(page).to have_css(
          "form[action='/admin/messages/#{id}/open'] input[name='status'][value='unread']", visible: :all,
        )
      end

      it "holds no action button" do
        expect(page).to have_no_css(".msg-item button:not(.msg-item-open)")
      end

      it "puts when it arrived in a time tag" do
        expect(page.find(".msg-item-head time")[:datetime]).to eq("2026-09-07T12:30:00-05:00")
      end
    end

    describe "the reading pane" do
      let(:arrived) { Time.utc(2026, 9, 7, 17, 30) }

      def acts = page.all(".msg-letter-acts button").map(&:text)

      it "asks for a pick with nothing open" do
        create(:message)
        get "/admin/messages"

        expect(page).to have_css(".msg-pane .empty", exact_text: pick_text)
      end

      describe "an open message" do
        let(:message) do
          create(:message, reply_to: "ada@example.com", subject: "A question", body: "How?", received_at: arrived)
        end

        before { get "/admin/messages", open: message.id }

        it "shows the sender and the full date and time", :aggregate_failures do
          expect(page).to have_css(".msg-letter .inbox-meta", text: "ada@example.com")
          expect(page).to have_css(".msg-letter time", text: "Sep 7, 2026, 12:30")
        end

        it "shows the subject and the body", :aggregate_failures do
          expect(page).to have_css("article#read-#{message.id} h2", text: "A question")
          expect(page).to have_css(".msg-letter-body", text: "How?")
        end

        it "draws no spam badge" do
          expect(page).to have_no_css(".msg-letter .pill")
        end
      end

      it "badges spam" do
        message = create(:message, :spam)
        get "/admin/messages", status: "spam", open: message.id

        expect(page).to have_css(".msg-letter .inbox-meta", text: "spam")
      end

      it "shows a message the list no longer holds" do
        message = create(:message, :read, subject: "Answered")
        get "/admin/messages", status: "unread", open: message.id

        expect(page).to have_css(".msg-letter h2", text: "Answered")
      end

      it "asks for a pick when the open message is gone" do
        create(:message)
        get "/admin/messages", open: "0"

        expect(page).to have_css(".msg-pane .empty", exact_text: pick_text)
      end

      {
        "unread" => ["Mark read", "Snooze", "Label", "Spam", "Delete"],
        "read" => ["Mark unread", "Snooze", "Label", "Spam", "Delete"],
        "spam" => ["Not spam", "Delete forever"],
      }.each do |status, labels|
        it "offers #{labels.join(', ')} on a #{status} message" do
          message = create(:message, status:)
          get "/admin/messages", status:, open: message.id

          expect(acts).to eq(labels)
        end
      end

      it "puts Spam and Delete on the far side" do
        message = create(:message)
        get "/admin/messages", open: message.id

        expect(page.all(".msg-letter-far button").map(&:text)).to eq(%w[Spam Delete])
      end

      it "marks a spam message read with Not spam" do
        message = create(:message, :spam)
        get "/admin/messages", status: "spam", open: message.id

        expect(page).to have_css("form[action='/admin/messages/#{message.id}/mark/read'] button", text: "Not spam")
      end

      { "read" => "confirm_delete", "spam" => "confirm_delete_forever" }.each do |status, key|
        it "asks before it deletes a #{status} message" do
          message = create(:message, status:)
          ask = i18n.t(key, scope: "ui.components.message_letter")
          get "/admin/messages", status:, open: message.id

          expect(page).to have_css("form[action='/admin/messages/#{message.id}/delete'] button[data-confirm='#{ask}']")
        end
      end

      it "keeps the message open after a move" do
        message = create(:message)
        get "/admin/messages", open: message.id

        expect(page).to have_css(".msg-letter-acts input[name='open'][value='#{message.id}']", visible: :all)
      end
    end

    describe "opening a message" do
      def open_message(id, **params) = post("/admin/messages/#{id}/open", { _csrf_token: admin_csrf_token, **params })

      it "marks an unread message read" do
        message = create(:message)
        open_message(message.id)

        expect(repo.by_id(message.id).status).to eq("read")
      end

      it "leaves a spam message spam" do
        message = create(:message, :spam)
        open_message(message.id, status: "spam")

        expect(repo.by_id(message.id).status).to eq("spam")
      end

      it "returns to the list with the message open" do
        message = create(:message, :read)
        open_message(message.id, status: "read")

        expect(last_response).to be_redirect.and have_attributes(
          location: end_with("/admin/messages?status=read&open=#{message.id}#read-#{message.id}"),
        )
      end

      it "keeps the search and the tag on the way back" do
        message = create(:message)
        open_message(message.id, status: "inbox", search: "invoice", tag: "billing")

        expect(last_response.location)
          .to end_with("/admin/messages?status=inbox&search=invoice&tag=billing&open=#{message.id}#read-#{message.id}")
      end

      it "steps back a page the open emptied" do
        lower_page_size(:admin, to: 1)
        message = [2, 1].map { create(:message, received_at: Time.utc(2026, 9, it)) }.last
        open_message(message.id, status: "unread", page: "2")

        expect(last_response.location)
          .to end_with("/admin/messages?status=unread&open=#{message.id}#read-#{message.id}")
      end

      it "answers 404 for a message that isn't there" do
        open_message(0)

        expect(last_response.status).to eq(404)
      end

      it "refuses a post with a forged CSRF token" do
        message = create(:message)
        post "/admin/messages/#{message.id}/open", _csrf_token: "forged"

        expect(repo.by_id(message.id).status).to eq("unread")
      end
    end

    describe "deleting a message" do
      def delete(id, **params) = post("/admin/messages/#{id}/delete", { _csrf_token: admin_csrf_token, **params })

      it "removes it for good" do
        message = create(:message)
        delete(message.id)

        expect(repo.by_id(message.id)).to be_nil
      end

      it "returns to the list that was open with a toast", :aggregate_failures do
        message = create(:message, :spam)
        delete(message.id, status: "spam")

        expect(last_response.location).to end_with("/admin/messages?status=spam")
        follow_redirect!
        expect(page).to have_css("[data-toast]", text: "Message deleted")
      end

      it "answers 404 for a message that isn't there" do
        delete(0)

        expect(last_response.status).to eq(404)
      end

      it "refuses a post with a forged CSRF token" do
        message = create(:message)
        post "/admin/messages/#{message.id}/delete", _csrf_token: "forged"

        expect(repo.by_id(message.id)).not_to be_nil
      end
    end

    it "counts the messages it lists" do
      2.times { create(:message) }
      get "/admin/messages"

      expect(page).to have_css(".page-head-sub", exact_text: "2 messages")
    end

    %w[inbox unread read spam].each do |status|
      it "says something useful when #{status} holds nothing" do
        get "/admin/messages", status: status

        expect(page).to have_css(".empty", exact_text: empty_text(status))
      end
    end

    describe "a body holding HTML" do
      let(:markup) { "<script>alert('x')</script> and <b>bold</b>" }

      before do
        message = create(:message, body: markup)
        get "/admin/messages", open: message.id
      end

      it "reads it back as the text it is" do
        expect(page).to have_css(".msg-body", text: markup)
      end

      it "escapes it rather than serving it as markup", :aggregate_failures do
        expect(last_response.body).to include("&lt;script&gt;alert(&#39;x&#39;)&lt;/script&gt;")
        expect(last_response.body).to include("&lt;b&gt;bold&lt;/b&gt;")
        expect(last_response.body).not_to include("<script>alert")
        expect(last_response.body).not_to include("<b>bold</b>")
      end
    end

    it "leaves the reply address as text rather than a link" do
      create(:message, reply_to: "ada@example.com")
      get "/admin/messages"

      expect(page).to have_no_css("a[href*='ada@example.com']")
    end

    describe "moving a message" do
      def mark(id, status, **params)
        post("/admin/messages/#{id}/mark/#{status}", { _csrf_token: admin_csrf_token, **params })
      end

      { "unread" => %w[read spam], "read" => %w[unread spam], "spam" => %w[unread read] }.each do |from, targets|
        targets.each do |to|
          it "marks a #{from} message #{to}" do
            message = create(:message, status: from)
            mark(message.id, to)

            expect(repo.by_id(message.id).status).to eq(to)
          end
        end
      end

      it "keeps the list that was open on the way back" do
        message = create(:message, :read)
        mark(message.id, "spam", filter: "read")

        expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin/messages?status=read"))
      end

      it "keeps the search on the way back" do
        message = create(:message)
        mark(message.id, "read", filter: "inbox", search: "invoice")

        expect(last_response.location).to end_with("/admin/messages?status=inbox&search=invoice")
      end

      it "falls back to unread for a filter it doesn't know" do
        message = create(:message)
        mark(message.id, "read", filter: "junk")

        expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin/messages?status=unread"))
      end

      { "read" => "Marked read", "spam" => "Marked as spam", "unread" => "Moved back to unread" }
        .each do |status, toast|
        it "shows the #{status} toast" do
          message = create(:message, :read)
          mark(message.id, status)
          follow_redirect!

          expect(page).to have_css("[data-toast]", text: toast)
        end
      end

      it "writes nothing for a message that isn't there" do
        message = create(:message)
        mark(0, "read")

        expect(repo.by_id(message.id).status).to eq("unread")
      end

      it "answers 404 for a status outside the enum" do
        message = create(:message)
        mark(message.id, "archived")

        expect(last_response.status).to eq(404)
      end

      it "refuses a post with a forged CSRF token" do
        message = create(:message)
        post "/admin/messages/#{message.id}/mark/read", _csrf_token: "forged"

        expect(last_response.status).to eq(403)
      end

      it "writes nothing for a post with a forged CSRF token" do
        message = create(:message)
        post "/admin/messages/#{message.id}/mark/read", _csrf_token: "forged"

        expect(repo.by_id(message.id).status).to eq("unread")
      end

      it "returns with the message open when the pane sends it" do
        message = create(:message)
        mark(message.id, "unread", filter: "read", open: message.id)

        expect(last_response.location)
          .to end_with("/admin/messages?status=read&open=#{message.id}#read-#{message.id}")
      end

      it "carries the token and the open list in the pane form", :aggregate_failures do
        message = create(:message, :read)
        get "/admin/messages", status: "read", open: message.id

        expect(page).to have_css(".msg-letter-acts form input[name='_csrf_token']", visible: :all)
        expect(page).to have_css(".msg-letter-acts form input[name='filter'][value='read']", visible: :all)
      end
    end
  end

  describe "signed out" do
    let(:record) { create(:message, reply_to: "ada@example.com", subject: "A question", body: "How?") }

    it "redirects to sign-in" do
      record
      get "/admin/messages"

      expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin/sign-in"))
    end

    it "sends neither the address, the subject nor the body", :aggregate_failures do
      record
      get "/admin/messages"

      expect(last_response.body).not_to include("ada@example.com")
      expect(last_response.body).not_to include("A question")
      expect(last_response.body).not_to include("How?")
    end

    it "refuses to mark a message" do
      post "/admin/messages/#{record.id}/mark/read"

      expect(repo.by_id(record.id).status).to eq("unread")
    end
  end
end
