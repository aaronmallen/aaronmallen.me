# frozen_string_literal: true

RSpec.describe "Admin decision timeline", type: :request do
  let(:i18n) { Admin::Slice["i18n"] }
  let(:page) { Capybara.string(last_response.body) }
  let(:decision) { create(:decision, title: "Pick a queue", problem: "Jobs pile up") }
  let(:ten) { Time.at(Time.now.to_i - 86_400) }

  def add(body, id: decision.id) = send_to("/admin/decisions/#{id}/comments", comment: { body: })

  def bodies = comments.order(:id).to_a.map { it[:body] }

  def comment_on_page(comment) = page.find("[data-decision-comment='#{comment.id}']")

  def comments = Decisions::Slice["relations.decision_comments"]

  def delete(comment) = send_to("/admin/decisions/#{decision.id}/comments/#{comment.id}/delete")

  def edit(comment, body) = send_to("/admin/decisions/#{decision.id}/comments/#{comment.id}", comment: { body: })

  def entries = page.all(".task-timeline > li")

  def event(kind, at: ten, **columns)
    Decisions::Slice["relations.decision_events"].insert(decision_id: decision.id, kind:, created_at: at, **columns)
  end

  def event_text(key, **) = i18n.t(key, scope: "ui.components.decisions.timeline_event", **)

  def operation(name) = Decisions::Slice["operations.#{name}"]

  def option_id(title) = create(:decision_option, decision_id: decision.id, title:).id

  def read = get("/admin/decisions/#{decision.id}")

  def send_to(path, **params) = post(path, { _csrf_token: admin_csrf_token, **params })

  def t(key, **) = i18n.t(key, **)

  describe "signed out" do
    it "adds nothing" do
      post "/admin/decisions/#{decision.id}/comments", comment: { body: "Hello" }

      expect(bodies).to be_empty
    end

    it "edits nothing" do
      comment = create(:decision_comment, decision_id: decision.id, body: "Before")
      post "/admin/decisions/#{decision.id}/comments/#{comment.id}", comment: { body: "After" }

      expect(bodies).to eq(["Before"])
    end

    it "deletes nothing" do
      comment = create(:decision_comment, decision_id: decision.id)
      post "/admin/decisions/#{decision.id}/comments/#{comment.id}/delete"

      expect(bodies.size).to eq(1)
    end
  end

  describe "signed in" do
    before { sign_in_to_admin }

    it "says when nothing has happened" do
      read

      expect(page).to have_css(".task-activity .hint", text: t("ui.components.decisions.timeline.empty"))
    end

    it "puts comments and events in time order" do
      create(:decision_comment, decision_id: decision.id, body: "Noon", created_at: ten + 7200)
      event("option_added", at: ten + 3600, option_id: option_id("Sidekiq"))
      create(:decision_comment, decision_id: decision.id, body: "Ten", created_at: ten)
      read

      expect(entries.map(&:text)).to match([/Ten/, /#{event_text('option_added', option: 'Sidekiq')}/, /Noon/])
    end

    it "leaves out another decision's comments and events" do
      other = create(:decision)
      create(:decision_comment, decision_id: other.id, body: "Elsewhere")
      operation(:drop_decision).call(other.id, { reason: "No need" })
      read

      expect(page).to have_no_css(".task-timeline")
    end

    it "shows an edit while open without a note" do
      operation(:edit_decision).call(decision.id, { title: "Pick a queue", problem: "Jobs pile up fast" })
      read

      expect(page.find("[data-decision-event='edited']")).to have_no_css(".task-body")
    end

    describe "every event, through its operation" do
      let(:decision) { at(0) { operation(:open_decision).call({ title: "Pick a host", problem: "The Pi is slow" }) } }

      def at(minute)
        result = yield.value!
        fresh = Sequel.lit("created_at > ?", ten + 43_200)
        %w[decision_events decision_comments].each do |name|
          Decisions::Slice["relations.#{name}"].where(fresh).update(created_at: ten + (minute * 60))
        end
        result
      end

      def event_bodies
        page.all("[data-decision-event] .task-body").to_h { [it.ancestor("li")["data-decision-event"], it.text] }
      end

      def steps(option_id)
        [
          [:add_decision_comment, { body: "Fly looks **cheap**" }],
          [:resolve_decision, { option_id:, reason: "It is *cheap*" }],
          [:edit_decision, { title: "Pick a host", problem: "Slower", note: "Timed it" }],
          [:edit_decision_option, option_id, { title: "Fly.io", body: "", note: "Renamed" }],
          [:reopen_decision, { reason: "Prices went up" }],
          [:drop_decision, { reason: "Stayed on the Pi" }],
        ]
      end

      def walk
        added = at(1) { operation(:add_decision_option).call(decision.id, { title: "Fly", body: "" }) }

        steps(added.id).each.with_index(2) do |(name, *args), minute|
          at(minute) { operation(name).call(decision.id, *args) }
        end
      end

      before do
        walk
        read
      end

      it "shows each one oldest first" do
        expect(entries.map { it["data-decision-event"] || "comment" })
          .to eq(%w[opened option_added comment resolved edited option_edited reopened dropped])
      end

      it "names the option on its events", :aggregate_failures do
        added = event_text("option_added", option: "Fly.io")

        expect(page).to have_css("[data-decision-event='option_added']", text: added)
        expect(page).to have_css("[data-decision-event='resolved']", text: event_text("resolved", option: "Fly.io"))
      end

      it "shows each reason and note" do
        expect(event_bodies).to eq(
          "resolved" => "It is cheap", "edited" => "Timed it", "option_edited" => "Renamed",
          "reopened" => "Prices went up", "dropped" => "Stayed on the Pi",
        )
      end

      it "renders a reason as Markdown" do
        expect(page).to have_css("[data-decision-event='resolved'] .task-body em", exact_text: "cheap")
      end

      it "renders a comment as Markdown" do
        expect(page).to have_css(".task-comment-body strong", exact_text: "cheap")
      end
    end

    describe "a comment on the page" do
      let!(:comment) { create(:decision_comment, decision_id: decision.id, body: "say **why**") }

      before { read }

      it "names the owner and the time", :aggregate_failures do
        expect(comment_on_page(comment)).to have_css(".task-comment-author", exact_text: Blog::Owner.full_name)
        expect(comment_on_page(comment).find("time")["datetime"]).to eq(comment.created_at.iso8601)
      end

      it "strips script from the body" do
        create(:decision_comment, decision_id: decision.id, body: "<script>alert(1)</script>")
        read

        expect(page).to have_no_css(".task-comment-body script")
      end

      it "offers an edit form that posts without script" do
        expect(comment_on_page(comment)).to have_css(
          "details form[method='post'][action='/admin/decisions/#{decision.id}/comments/#{comment.id}'] " \
          "textarea[name='comment[body]']",
          visible: :all,
        )
      end

      it "offers a delete form" do
        expect(comment_on_page(comment))
          .to have_css("form[method='post'][action='/admin/decisions/#{decision.id}/comments/#{comment.id}/delete']")
      end

      it "offers a form to add one" do
        expect(page).to have_css(
          "form[method='post'][action='/admin/decisions/#{decision.id}/comments'] textarea[name='comment[body]']",
        )
      end
    end

    describe "adding a comment" do
      it "saves it, trimmed, and comes back to the decision", :aggregate_failures do
        add("  Looked into it  ")

        expect(bodies).to eq(["Looked into it"])
        expect(last_response.location).to end_with("/admin/decisions/#{decision.id}")
      end

      it "says so" do
        add("Hello")
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: t("decisions_page.toasts.comment_added"))
      end

      it "shows it on the timeline" do
        add("Hello there")
        follow_redirect!

        expect(page).to have_css(".task-comment-body", exact_text: "Hello there")
      end

      it "takes one on a closed decision" do
        operation(:drop_decision).call(decision.id, { reason: "No need" })
        add("Still thinking")

        expect(bodies).to eq(["Still thinking"])
      end

      it "answers 404 for a decision that isn't there" do
        add("Hello", id: 999_999)

        expect(last_response.status).to eq(404)
      end
    end

    describe "adding an empty comment" do
      before { add("   ") }

      it "answers 422 and keeps nothing" do
        expect([last_response.status, bodies]).to eq([422, []])
      end

      it "says why beside the field" do
        expect(page.find("#decision-#{decision.id}-comment-body-error").text)
          .to eq(t("ui.components.decisions.field_error.body.blank"))
      end
    end

    describe "editing a comment" do
      let!(:comment) { create(:decision_comment, decision_id: decision.id, body: "Before") }

      it "saves the new body" do
        edit(comment, "After")

        expect(bodies).to eq(["After"])
      end

      it "says so" do
        edit(comment, "After")
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: t("decisions_page.toasts.comment_saved"))
      end

      it "answers 404 for a comment on another decision" do
        other = create(:decision_comment, body: "Elsewhere")
        edit(other, "Changed")

        expect([last_response.status, comments.by_pk(other.id).one[:body]]).to eq([404, "Elsewhere"])
      end
    end

    describe "editing a comment to nothing" do
      let!(:comment) { create(:decision_comment, decision_id: decision.id, body: "Before") }

      before { edit(comment, " ") }

      it "answers 422 with the error on that comment's form", :aggregate_failures do
        expect(last_response.status).to eq(422)
        expect(page.find("#decision-#{decision.id}-comment-#{comment.id}-body-error").text)
          .to eq(t("ui.components.decisions.field_error.body.blank"))
      end

      it "opens that comment's form" do
        expect(comment_on_page(comment)).to have_css("details.task-comment-edit[open]")
      end

      it "leaves the new comment field clean" do
        expect(page).to have_no_css("#decision-#{decision.id}-comment-body-error")
      end

      it "keeps the old body" do
        expect(bodies).to eq(["Before"])
      end
    end

    describe "deleting a comment" do
      let!(:comment) { create(:decision_comment, decision_id: decision.id) }

      it "removes it" do
        delete(comment)

        expect(bodies).to be_empty
      end

      it "says so" do
        delete(comment)
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: t("decisions_page.toasts.comment_deleted"))
      end

      it "answers 404 for a comment that isn't there" do
        delete(comment)
        delete(comment)

        expect(last_response.status).to eq(404)
      end
    end
  end
end
