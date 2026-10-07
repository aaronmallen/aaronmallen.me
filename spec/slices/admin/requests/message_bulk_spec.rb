# frozen_string_literal: true

RSpec.describe "Admin bulk message actions", type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:repo) { Contact::Slice["repos.message_queries"] }

  def act(name, messages, **params)
    ids = messages.map { it.is_a?(Integer) ? it : it.id }
    post "/admin/messages/bulk", { _csrf_token: admin_csrf_token, act: name, ids:, status: "unread", **params }
  end

  def gone_id = create(:message).id.tap { Contact::Slice["repos.message_mutations"].delete(it) }

  def messages(count, **) = Array.new(count) { create(:message, **) }

  def status(message) = repo.by_id(message.id)&.status

  def toast = page.find("[data-toast] .toast", visible: :all).text(:all)

  describe "signed in" do
    before { sign_in_to_admin }

    describe "the list" do
      before { messages(2) }

      it "draws one bar that posts to the bulk route" do
        get "/admin/messages"

        expect(page).to have_css("form#message-bulk[action='/admin/messages/bulk'][method='post']", count: 1)
      end

      {
        "unread" => %w[read delete],
        "read" => %w[unread delete],
        "spam" => %w[read unread delete],
      }.each do |filter, acts|
        it "offers #{acts.join(', ')} on the #{filter} list" do
          messages(1, status: filter)
          get "/admin/messages", status: filter

          expect(page.all("form#message-bulk button[name='act']").map(&:value)).to eq(acts)
        end
      end

      it "gives each row a box that joins the bar" do
        get "/admin/messages"

        expect(page.all(".li input[type='checkbox'][name='ids[]'][form='message-bulk']").size).to eq(2)
      end

      it "names the message on each box" do
        message = create(:message, subject: "A question")
        get "/admin/messages"

        expect(page).to have_css("input[value='#{message.id}'][aria-label='Select A question']")
      end

      it "shows the actions in the markup, so they work with scripts off" do
        get "/admin/messages"

        expect(page).to have_css("[data-bulk-acts]:not([hidden])")
      end

      it "asks before deleting" do
        get "/admin/messages"

        expect(page).to have_css("button[value='delete'][data-confirm]")
      end

      it "keeps the filter and the page in the bar", :aggregate_failures do
        messages(2, status: "read")
        lower_page_size(:admin, to: 1)
        get "/admin/messages", status: "read", page: 2

        expect(page).to have_css("form#message-bulk input[name='status'][value='read']", visible: :all)
        expect(page).to have_css("form#message-bulk input[name='page'][value='2']", visible: :all)
      end
    end

    describe "an empty list" do
      it "draws no bar" do
        get "/admin/messages", status: "spam"

        expect(page).to have_no_css("form#message-bulk")
      end
    end

    {
      "read" => ["unread", "read", "Marked 2 messages read"],
      "unread" => ["read", "unread", "Moved 2 messages back to unread"],
    }.each do |name, (from, to, said)|
      describe "#{name} on the ticked messages" do
        let!(:ticked) { messages(2, status: from) }
        let!(:left) { create(:message, status: from) }

        before { act(name, ticked) }

        it "marks them" do
          expect(ticked.map { status(it) }).to eq([to, to])
        end

        it "leaves the rest alone" do
          expect(status(left)).to eq(from)
        end

        it "says how many changed" do
          follow_redirect!

          expect(toast).to eq(said)
        end
      end
    end

    describe "read on spam" do
      it "clears the sender's spam flag as a single mark does" do
        message = create(:message, :spam)
        Contact::Slice["relations.spam_senders"].flag(message.reply_to, at: Time.now)
        act("read", [message])

        expect(repo.sender_status(message.reply_to)).to eq("unread")
      end
    end

    describe "delete on the ticked messages" do
      let!(:ticked) { messages(2) }
      let!(:left) { create(:message) }

      before { act("delete", ticked) }

      it "takes them away" do
        expect(ticked.map { status(it) }).to eq([nil, nil])
      end

      it "leaves the rest alone" do
        expect(status(left)).to eq("unread")
      end

      it "says how many went" do
        follow_redirect!

        expect(toast).to eq("Deleted 2 messages")
      end
    end

    describe "delete on one ticked message" do
      before { act("delete", messages(1)) }

      it "says one went" do
        follow_redirect!

        expect(toast).to eq("Deleted 1 message")
      end
    end

    describe "a batch refused for a reason the bar does not name" do
      let(:message) { create(:message, subject: "Hello") }

      before do
        replace_component(
          "contact.operations.act_on_messages",
          ->(_params) { Dry::Monads::Result::Failure.new([:record, message.id, :locked]) },
        )
        act("read", [message])
      end

      it "names the message in the toast" do
        follow_redirect!

        expect(toast).to eq("Nothing changed · message ##{message.id} Hello would not change")
      end
    end

    describe "a batch with a message that is gone" do
      let!(:ticked) { messages(2) }
      let(:missing) { gone_id }

      %w[read delete].each do |name|
        it "#{name} changes nothing" do
          act(name, [*ticked, missing])

          expect(ticked.map { status(it) }).to eq(%w[unread unread])
        end

        it "#{name} names the message" do
          act(name, [*ticked, missing])
          follow_redirect!

          expect(toast).to eq("Nothing changed · message ##{missing} is gone")
        end
      end

      it "unread changes nothing" do
        read = messages(2, status: "read")
        act("unread", [*read, missing], status: "read")

        expect(read.map { status(it) }).to eq(%w[read read])
      end
    end

    describe "where it lands" do
      it "goes back to the list it came from" do
        act("unread", [create(:message, :read)], status: "read")

        expect(last_response.headers["location"]).to eq("/admin/messages?status=read")
      end

      it "falls back to unread for a filter it doesn't know" do
        act("read", [create(:message)], status: "junk")

        expect(last_response.headers["location"]).to eq("/admin/messages?status=unread")
      end

      it "keeps the page while it still has rows" do
        lower_page_size(:admin, to: 1)
        messages(3)
        act("read", [repo.by_status("unread").last], page: 2)

        expect(last_response.headers["location"]).to eq("/admin/messages?status=unread&page=2")
      end

      it "steps back a page when the batch emptied the last one" do
        lower_page_size(:admin, to: 1)
        messages(2)
        act("read", [repo.by_status("unread").last], page: 2)

        expect(last_response.headers["location"]).to eq("/admin/messages?status=unread")
      end

      it "goes back the same way after a failure" do
        act("read", [gone_id], status: "spam")

        expect(last_response.headers["location"]).to eq("/admin/messages?status=spam")
      end
    end

    describe "a refused batch" do
      it "asks for a tick when none came" do
        post "/admin/messages/bulk", { _csrf_token: admin_csrf_token, act: "read", status: "unread" }
        follow_redirect!

        expect(toast).to eq("Tick a message first")
      end

      it "refuses more than 100 messages before it changes any", :aggregate_failures do
        ticked = messages(101)
        act("read", ticked)
        follow_redirect!

        expect(toast).to eq("Tick 100 messages or fewer")
        expect(repo.count_with_status("unread")).to eq(101)
      end

      it "counts a repeated message once" do
        message = create(:message)
        act("read", Array.new(101, message.id))
        follow_redirect!

        expect(toast).to eq("Marked 1 message read")
      end

      it "refuses an action off the bar", :aggregate_failures do
        message = create(:message)
        act("spam", [message])
        follow_redirect!

        expect(toast).to eq("Nothing changed · pick an action from the bar")
        expect(status(message)).to eq("unread")
      end
    end
  end

  describe "signed out" do
    it "changes nothing" do
      message = create(:message)
      post "/admin/messages/bulk", { act: "delete", ids: [message.id] }

      expect(status(message)).to eq("unread")
    end
  end
end
