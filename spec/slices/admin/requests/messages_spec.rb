# frozen_string_literal: true

RSpec.describe "Admin messages", type: :request do
  let(:i18n) { Admin::Slice["i18n"] }
  let(:page) { Capybara.string(last_response.body) }
  let(:repo) { Contact::Slice["repos.message_repo"] }

  def empty_text(status) = i18n.t(["ui.views.messages.index.empty", status].join("."))

  def subjects = page.all(".li-title").map(&:text)

  describe "signed in" do
    before { sign_in_to_admin }

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
    end

    it "lists the newest message first" do
      create(:message, subject: "Older", received_at: Time.utc(2026, 9, 1))
      create(:message, subject: "Newer", received_at: Time.utc(2026, 9, 8))
      get "/admin/messages"

      expect(subjects).to eq(%w[Newer Older])
    end

    describe "a row" do
      let(:arrived) { Time.utc(2026, 9, 7, 17, 30) }

      before do
        create(:message, reply_to: "ada@example.com", subject: "A question", body: "How?", received_at: arrived)
        get "/admin/messages"
      end

      it "shows the subject, the body, the reply address and when it arrived", :aggregate_failures do
        expect(page).to have_css(".li-title", text: "A question")
        expect(page).to have_css(".msg-body", text: "How?")
        expect(page).to have_css(".li-sub", text: "ada@example.com · Sep 7, 2026, 12:30")
      end
    end

    it "counts the messages it lists" do
      2.times { create(:message) }
      get "/admin/messages"

      expect(page).to have_css(".page-head-sub", exact_text: "2 messages")
    end

    %w[unread read spam].each do |status|
      it "says something useful when #{status} holds nothing" do
        get "/admin/messages", status: status

        expect(page).to have_css(".empty", exact_text: empty_text(status))
      end
    end

    describe "a body holding HTML" do
      let(:markup) { "<script>alert('x')</script> and <b>bold</b>" }

      before do
        create(:message, body: markup)
        get "/admin/messages"
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

      { "unread" => %w[read spam], "read" => %w[unread spam], "spam" => %w[unread] }.each do |from, targets|
        targets.each do |to|
          it "marks a #{from} message #{to}" do
            message = create(:message, status: from)
            mark(message.id, to)

            expect(repo.by_id(message.id).status).to eq(to)
          end
        end

        it "offers only #{targets.join(' and ')} on a #{from} message" do
          create(:message, status: from)
          get "/admin/messages", status: from

          expect(page.all(".li-side button").map(&:text)).to eq(targets.map(&:capitalize))
        end
      end

      it "keeps the list that was open on the way back" do
        message = create(:message, :read)
        mark(message.id, "spam", filter: "read")

        expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin/messages?status=read"))
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

      it "answers 404 for a message that isn't there" do
        mark(0, "read")

        expect(last_response.status).to eq(404)
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

      it "carries the token and the open list in the form", :aggregate_failures do
        create(:message, :read)
        get "/admin/messages", status: "read"

        expect(page).to have_css(".li-side form input[name='_csrf_token']", visible: :all)
        expect(page).to have_css(".li-side form input[name='filter'][value='read']", visible: :all)
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
