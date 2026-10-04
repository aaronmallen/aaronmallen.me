# frozen_string_literal: true

RSpec.describe "Admin inbox", type: :request do
  let(:messages) { Contact::Slice["repos.message_repo"] }
  let(:page) { Capybara.string(last_response.body) }
  let(:tasks) { Tasks::Slice["repos.task_repo"] }
  let(:webmentions) { Social::Slice["repos.webmention_repo"] }

  def act(path, **params) = post(path, { _csrf_token: admin_csrf_token, **params })

  def inbox
    get "/admin/inbox"
    page.all(".li .li-title").map(&:text)
  end

  def synced(*traits, title: "A synced issue", list: "external", created_at: Time.now, seen_at: nil)
    create(:task, *traits, title:, list:, created_at:).tap { create(:task_source, task: it, seen_at:) }
  end

  describe "signed in" do
    before { sign_in_to_admin }

    it "lists an unread message, a pending webmention and an unseen synced issue, newest first" do
      synced(title: "Oldest", created_at: Time.now - 120)
      create(:message, subject: "Middle", received_at: Time.now - 60)
      create(:webmention, author_name: "Newest", received_at: Time.now)

      expect(inbox).to eq(%w[Newest Middle Oldest])
    end

    it "says what kind each row is" do
      synced
      create(:message)
      create(:webmention)
      get "/admin/inbox"

      expect(page.all(".li .pill").map(&:text)).to contain_exactly("issue", "message", "webmention")
    end

    it "counts the rows" do
      create(:message)
      synced
      get "/admin/inbox"

      expect(page).to have_css(".page-head-sub", exact_text: "2 waiting")
    end

    it "leaves out what no longer waits" do
      create(:message, :read)
      create(:webmention, :approved)
      synced(seen_at: Time.now)
      %i[done canceled].each { synced(it) }

      expect(inbox).to be_empty
    end

    it "says so when nothing waits" do
      get "/admin/inbox"

      expect(page).to have_css(".empty", exact_text: Admin::Slice["i18n"].t("ui.views.inbox.index.empty"))
    end

    describe "the nav count" do
      let(:paths) do
        {
          message: "/admin/inbox/messages/#{create(:message).id}/mark/read",
          webmention: "/admin/inbox/webmentions/#{create(:webmention).id}/moderate/approved",
          issue: "/admin/inbox/tasks/#{synced.id}/seen",
        }
      end

      def count_on(section)
        get "/admin"
        page.all("#command-palette-#{section} .pal-r-sub", visible: :all).map(&:text)
      end

      def no_longer_waiting
        create(:message, :read)
        create(:webmention, :approved)
        synced(seen_at: Time.now)
        %i[done canceled].each { synced(it) }
      end

      before { paths }

      it "counts the rows on Inbox and nothing that no longer waits", :aggregate_failures do
        no_longer_waiting

        expect(inbox).to have(3).items
        expect(count_on(:inbox)).to eq(["3 waiting"])
      end

      it "leaves Messages and Webmentions without a count", :aggregate_failures do
        expect(count_on(:messages)).to be_empty
        expect(count_on(:webmentions)).to be_empty
      end

      %i[message webmention issue].each do |kind|
        it "drops by one when a #{kind} is acted on" do
          act(paths.fetch(kind))

          expect(count_on(:inbox)).to eq(["2 waiting"])
        end
      end

      it "says nothing once nothing waits" do
        paths.each_value { act(it) }

        expect(count_on(:inbox)).to be_empty
      end
    end

    describe "a message" do
      let(:message) { create(:message, subject: "A question", body: "How?", reply_to: "ada@example.com") }

      before { message }

      it "reads out the body" do
        get "/admin/inbox"

        expect(page).to have_css(".msg-body", text: "How?")
      end

      it "offers a reply by mail" do
        get "/admin/inbox"

        expect(page).to have_link("Reply", href: "mailto:ada@example.com?subject=Re%3A%20A%20question")
      end

      it "keeps a reply address from adding fields to the mail" do
        create(:message, reply_to: "ada?cc=eve@example.com", subject: "Sneaky")
        get "/admin/inbox"

        expect(page).to have_link("Reply", href: "mailto:ada%3Fcc%3Deve@example.com?subject=Re%3A%20Sneaky")
      end

      %w[read spam].each do |status|
        it "marks it #{status} and drops it", :aggregate_failures do
          act("/admin/inbox/messages/#{message.id}/mark/#{status}")

          expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin/inbox"))
          expect(messages.by_id(message.id).status).to eq(status)
          expect(inbox).to be_empty
        end
      end

      it "says so" do
        act("/admin/inbox/messages/#{message.id}/mark/read")
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: "Marked read")
      end

      it "refuses to mark it unread" do
        act("/admin/inbox/messages/#{message.id}/mark/unread")

        expect(last_response.status).to eq(404)
      end

      it "answers 404 for a message that isn't there" do
        act("/admin/inbox/messages/0/mark/read")

        expect(last_response.status).to eq(404)
      end

      it "refuses a forged CSRF token", :aggregate_failures do
        post "/admin/inbox/messages/#{message.id}/mark/read", _csrf_token: "forged"

        expect(last_response.status).to eq(403)
        expect(messages.by_id(message.id).status).to eq("unread")
      end
    end

    describe "a webmention" do
      let(:mention) { create(:webmention, author_name: "Ada") }

      before { mention }

      { "approved" => "Approved", "ignored" => "Ignored", "spam" => "Marked as spam" }.each do |verdict, toast|
        it "moderates it #{verdict} and drops it", :aggregate_failures do
          act("/admin/inbox/webmentions/#{mention.id}/moderate/#{verdict}")
          follow_redirect!

          expect(page).to have_css("[data-toast]", text: toast)
          expect(webmentions.by_status(verdict).map(&:id)).to eq([mention.id])
          expect(inbox).to be_empty
        end
      end

      it "keeps the reason it was spam" do
        act("/admin/inbox/webmentions/#{mention.id}/moderate/spam", reason: "Selling pills")

        expect(webmentions.by_status("spam").map(&:spam_reason)).to eq(["Selling pills"])
      end

      it "keeps no reason when it holds only Unicode spaces", :aggregate_failures do
        act("/admin/inbox/webmentions/#{mention.id}/moderate/spam", reason: "\u3000\u00a0")

        expect(last_response).to be_redirect
        expect(webmentions.by_status("spam").map(&:spam_reason)).to eq([nil])
      end

      it "refuses to set it back to pending" do
        act("/admin/inbox/webmentions/#{mention.id}/moderate/pending")

        expect(last_response.status).to eq(404)
      end

      it "answers 404 for a webmention that isn't there" do
        act("/admin/inbox/webmentions/0/moderate/approved")

        expect(last_response.status).to eq(404)
      end
    end

    describe "a synced issue" do
      let(:task) { synced(title: "Fix the feed") }

      before { task }

      it "offers the lists it is not on" do
        get "/admin/inbox"

        expect(page.all(".li-side button").map(&:text)).to eq(%w[Today Next Someday Tag Seen])
      end

      it "moves it and drops it", :aggregate_failures do
        act("/admin/inbox/tasks/#{task.id}/move/next")
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: "Moved")
        expect(tasks.by_id(task.id).list).to eq("next")
        expect(inbox).to be_empty
      end

      it "tags it and drops it", :aggregate_failures do
        act("/admin/inbox/tasks/#{task.id}/tags", tags: "feeds, bugs")
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: "Tags saved")
        expect(tasks.by_id(task.id).tags.map(&:name)).to contain_exactly("feeds", "bugs")
        expect(inbox).to be_empty
      end

      it "keeps its title and list when tagged", :aggregate_failures do
        act("/admin/inbox/tasks/#{task.id}/tags", tags: "feeds")

        expect(tasks.by_id(task.id)).to have_attributes(title: "Fix the feed", list: "external")
      end

      it "keeps it when a tag will not save", :aggregate_failures do
        act("/admin/inbox/tasks/#{task.id}/tags", tags: "not/a/tag")
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: "Nothing saved")
        expect(inbox).to eq(["Fix the feed"])
      end

      it "marks it seen without moving it", :aggregate_failures do
        act("/admin/inbox/tasks/#{task.id}/seen")
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: "Marked seen")
        expect(tasks.by_id(task.id).list).to eq("external")
        expect(inbox).to be_empty
      end

      it "answers 404 when marking a task with no source seen" do
        act("/admin/inbox/tasks/#{create(:task).id}/seen")

        expect(last_response.status).to eq(404)
      end

      it "answers 404 for a task that isn't there", :aggregate_failures do
        %w[move/next seen tags].each do |verb|
          act("/admin/inbox/tasks/0/#{verb}")

          expect(last_response.status).to eq(404), verb
        end
      end
    end
  end

  describe "signed out" do
    it "redirects to sign-in and leaks nothing", :aggregate_failures do
      create(:message, subject: "A secret")
      get "/admin/inbox"

      expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin/sign-in"))
      expect(last_response.body).not_to include("A secret")
    end

    it "refuses to act on a row" do
      message = create(:message)
      post "/admin/inbox/messages/#{message.id}/mark/read"

      expect(messages.by_id(message.id).status).to eq("unread")
    end
  end
end
