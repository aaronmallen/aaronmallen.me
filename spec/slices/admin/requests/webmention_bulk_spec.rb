# frozen_string_literal: true

RSpec.describe "Admin bulk webmention actions", type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:target) { create(:post, :published) }

  def act(name, mentions, **params)
    ids = mentions.map { it.is_a?(Integer) ? it : it.id }
    post "/admin/webmentions/bulk", { _csrf_token: admin_csrf_token, act: name, ids:, status: "pending", **params }
  end

  def gone_id = mentions(1).first.id.tap { relation.by_pk(it).delete }

  def mentions(count, *traits, **) = Array.new(count) { create(:webmention, *traits, post_id: target.id, **) }

  def relation = Social::Slice["relations.webmentions"]

  def status(mention) = relation.by_pk(mention.id).one&.fetch(:status)

  def toast = page.find("[data-toast] .toast", visible: :all).text(:all)

  def webmention_queries = Social::Slice["repos.webmention_queries"]

  describe "signed in" do
    before { sign_in_to_admin }

    describe "the list" do
      before { mentions(2) }

      it "draws one bar that posts to the bulk route" do
        get "/admin/webmentions"

        expect(page).to have_css("form#webmention-bulk[action='/admin/webmentions/bulk'][method='post']", count: 1)
      end

      {
        "pending" => %w[approved ignored spam],
        "approved" => %w[ignored spam],
        "ignored" => %w[approved spam],
        "spam" => %w[approved ignored],
      }.each do |filter, acts|
        it "offers #{acts.join(', ')} on the #{filter} list" do
          mentions(1, status: filter)
          get "/admin/webmentions", status: filter

          expect(page.all("form#webmention-bulk button[name='act']").map(&:value)).to eq(acts)
        end
      end

      it "gives each row a box that joins the bar" do
        get "/admin/webmentions"

        expect(page.all(".wm-card input[type='checkbox'][name='ids[]'][form='webmention-bulk']").size).to eq(2)
      end

      it "names the author on each box" do
        mention = create(:webmention, post_id: target.id, author_name: "Ada Lovelace")
        get "/admin/webmentions"

        expect(page).to have_css("input[value='#{mention.id}'][aria-label='Select Ada Lovelace']")
      end

      it "shows the actions in the markup, so they work with scripts off" do
        get "/admin/webmentions"

        expect(page).to have_css("[data-bulk-acts]:not([hidden])")
      end

      it "puts no text field in the bar, so Enter never fires an action" do
        get "/admin/webmentions"

        expect(page).to have_no_css("form#webmention-bulk input:not([type='hidden']):not([type='checkbox'])")
      end

      it "keeps the filter and the page in the bar", :aggregate_failures do
        mentions(2, :approved)
        lower_page_size(:admin, to: 1)
        get "/admin/webmentions", status: "approved", page: 2

        expect(page).to have_css("form#webmention-bulk input[name='status'][value='approved']", visible: :all)
        expect(page).to have_css("form#webmention-bulk input[name='page'][value='2']", visible: :all)
      end
    end

    describe "an empty list" do
      it "draws no bar" do
        get "/admin/webmentions", status: "spam"

        expect(page).to have_no_css("form#webmention-bulk")
      end
    end

    {
      "approved" => "Approved 2 webmentions",
      "ignored" => "Ignored 2 webmentions",
      "spam" => "Marked 2 webmentions as spam",
    }.each do |name, said|
      describe "#{name} on the ticked webmentions" do
        let!(:ticked) { mentions(2) }
        let!(:left) { mentions(1).first }

        before { act(name, ticked) }

        it "moderates them" do
          expect(ticked.map { status(it) }).to eq([name, name])
        end

        it "leaves the rest alone" do
          expect(status(left)).to eq("pending")
        end

        it "says how many changed" do
          follow_redirect!

          expect(toast).to eq(said)
        end
      end
    end

    describe "approve on spam" do
      it "clears the spam reason as a single approve does" do
        mention = create(:webmention, :spam, post_id: target.id, spam_reason: "junk")
        act("approved", [mention], status: "spam")

        expect(relation.by_pk(mention.id).one.fetch(:spam_reason)).to be_nil
      end
    end

    describe "trust" do
      let(:author_url) { "https://ada.example/about" }

      it "trusts an author once a batch approves them" do
        act("approved", mentions(1, author_url:))

        expect(webmention_queries.known_author?(author_url)).to be(true)
      end

      it "takes trust away once a batch marks them spam" do
        create(:webmention, :approved, post_id: target.id, author_url:)
        act("spam", mentions(1, author_url:))

        expect(webmention_queries.known_author?(author_url)).to be(false)
      end

      it "leaves an author unknown when a batch ignores them" do
        act("ignored", mentions(1, author_url:))

        expect(webmention_queries.known_author?(author_url)).to be(false)
      end
    end

    describe "a batch with a webmention that is gone" do
      let!(:ticked) { mentions(2) }
      let(:missing) { gone_id }

      %w[approved ignored spam].each do |name|
        it "#{name} changes nothing" do
          act(name, [*ticked, missing])

          expect(ticked.map { status(it) }).to eq(%w[pending pending])
        end

        it "#{name} names the webmention" do
          act(name, [*ticked, missing])
          follow_redirect!

          expect(toast).to eq("Nothing changed · webmention ##{missing} is gone")
        end
      end
    end

    describe "a batch refused for a reason the bar does not name" do
      let(:mention) { mentions(1).first }

      before do
        replace_component(
          "social.operations.act_on_webmentions",
          ->(_params) { Dry::Monads::Result::Failure.new([:record, mention.id, :locked]) },
        )
        act("approved", [mention])
      end

      it "names the webmention in the toast" do
        follow_redirect!

        expect(toast).to eq("Nothing changed · webmention ##{mention.id} would not change")
      end
    end

    describe "where it lands" do
      it "goes back to the list it came from" do
        act("approved", mentions(1, :spam), status: "spam")

        expect(last_response.headers["location"]).to eq("/admin/webmentions?status=spam")
      end

      it "falls back to pending for a filter it doesn't know" do
        act("approved", mentions(1), status: "junk")

        expect(last_response.headers["location"]).to eq("/admin/webmentions?status=pending")
      end

      it "keeps the page while it still has rows" do
        lower_page_size(:admin, to: 1)
        ticked = mentions(3).first
        act("approved", [ticked], page: 2)

        expect(last_response.headers["location"]).to eq("/admin/webmentions?status=pending&page=2")
      end

      it "steps back a page when the batch emptied the last one" do
        lower_page_size(:admin, to: 1)
        ticked = mentions(2).first
        act("approved", [ticked], page: 2)

        expect(last_response.headers["location"]).to eq("/admin/webmentions?status=pending")
      end

      it "goes back the same way after a failure" do
        act("approved", [gone_id], status: "ignored")

        expect(last_response.headers["location"]).to eq("/admin/webmentions?status=ignored")
      end
    end

    describe "a refused batch" do
      it "asks for a tick when none came" do
        post "/admin/webmentions/bulk", { _csrf_token: admin_csrf_token, act: "approved", status: "pending" }
        follow_redirect!

        expect(toast).to eq("Tick a webmention first")
      end

      it "refuses more than 100 webmentions before it changes any", :aggregate_failures do
        ticked = mentions(101)
        act("approved", ticked)
        follow_redirect!

        expect(toast).to eq("Tick 100 webmentions or fewer")
        expect(webmention_queries.pending_count).to eq(101)
      end

      it "counts a repeated webmention once" do
        mention = mentions(1).first
        act("approved", Array.new(101, mention.id))
        follow_redirect!

        expect(toast).to eq("Approved 1 webmention")
      end

      it "refuses an action off the bar", :aggregate_failures do
        mention = mentions(1).first
        act("pending", [mention])
        follow_redirect!

        expect(toast).to eq("Nothing changed · pick an action from the bar")
        expect(status(mention)).to eq("pending")
      end
    end
  end

  describe "signed out" do
    it "changes nothing" do
      mention = mentions(1).first
      post "/admin/webmentions/bulk", { act: "spam", ids: [mention.id] }

      expect(status(mention)).to eq("pending")
    end
  end
end
