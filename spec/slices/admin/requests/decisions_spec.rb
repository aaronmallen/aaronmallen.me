# frozen_string_literal: true

RSpec.describe "Admin decisions", type: :request do
  let(:i18n) { Admin::Slice["i18n"] }
  let(:page) { Capybara.string(last_response.body) }
  let(:decision) { create(:decision, title: "Pick a queue", problem: "Jobs **pile** up") }
  let(:option) { create(:decision_option, decision_id: decision.id, title: "Sidekiq", body: "Runs *today*") }

  def close(kind, **fields) = send_to("/admin/decisions/#{decision.id}/#{kind}", decision: fields)

  def events(id = decision.id) = Decisions::Slice["relations.decision_events"].where(decision_id: id).order(:id).to_a

  def reload(id = decision.id) = Decisions::Slice["repos.decision_repo"].by_id(id)

  def send_to(path, **params) = post(path, { _csrf_token: admin_csrf_token, **params })

  def t(key, **) = i18n.t(key, **)

  def titles = page.all(".li .li-title").map(&:text)

  describe "signed out" do
    it "sends the list to sign in" do
      get "/admin/decisions"

      expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin/sign-in"))
    end

    it "opens nothing" do
      post "/admin/decisions", decision: { title: "Pick", problem: "Why" }

      expect(Decisions::Slice["relations.decisions"].count).to eq(0)
    end
  end

  describe "signed in" do
    before { sign_in_to_admin }

    describe "the list" do
      before do
        create(:decision, title: "Older open", created_at: Time.now - 3600)
        create(:decision, title: "Newer open")
        dropped = create(:decision, title: "Gone")
        Decisions::Slice["operations.drop_decision"].call(dropped.id, { reason: "No need" })
      end

      it "lists the open decisions without a filter, newest first" do
        get "/admin/decisions"

        expect(titles).to eq(["Newer open", "Older open"])
      end

      it "shows each decision's key beside its title" do
        get "/admin/decisions"

        keys = Decisions::Slice["relations.decisions"].where(title: ["Newer open", "Older open"]).pluck(:id)

        expect(page.all(".li .li-head button.record-key").map { it["data-record-key"] })
          .to match_array(keys.map { "##{it}" })
      end

      it "lists the dropped decisions with the dropped filter" do
        get "/admin/decisions", status: "dropped"

        expect(titles).to eq(["Gone"])
      end

      it "says when no decision has the status" do
        get "/admin/decisions", status: "resolved"

        expect(page).to have_css(".empty", text: t("ui.views.decisions.index.empty.resolved"))
      end

      it "lists the open decisions for a status it doesn't know" do
        get "/admin/decisions", status: "junk"

        expect(titles).to eq(["Newer open", "Older open"])
      end

      it "checks the chosen segment" do
        get "/admin/decisions", status: "dropped"

        expect(page).to have_css(".seg input[name='status'][value='dropped'][checked]")
      end

      it "counts every status" do
        get "/admin/decisions", status: "dropped"

        expect(page).to have_css(".page-head-sub", exact_text: "2 open · 0 resolved · 1 dropped")
      end

      it "links each row to its page" do
        get "/admin/decisions"

        expect(page.find(".li-title", text: "Newer open")[:href]).to match(%r{\A/admin/decisions/\d+\z})
      end

      it "counts each decision's options" do
        option
        get "/admin/decisions"

        expect(page.find(".li", text: "Pick a queue")).to have_css(".li-sub", text: "1 option")
      end

      it "puts when each decision opened in a time tag" do
        create(:decision, title: "Dated", created_at: Time.utc(2026, 9, 7, 17, 30))
        get "/admin/decisions"

        expect(page.find(".li", text: "Dated").find(".li-sub time")[:datetime]).to eq("2026-09-07T12:30:00-05:00")
      end

      it "says decisions is where you are" do
        get "/admin/decisions"

        expect(page).to have_css(".ctx-where", text: %r{Daily\s+/\s+decisions})
      end

      it "answers 404 past the last page" do
        get "/admin/decisions", page: 2

        expect(last_response.status).to eq(404)
      end
    end

    describe "the nav" do
      before { get "/admin" }

      it "offers decisions in the palette" do
        expect(page).to have_css(
          "#command-palette-decisions[data-palette-href='/admin/decisions'] i.fa-scale-balanced", visible: :all,
        )
      end
    end

    describe "opening a decision" do
      it "shows the form" do
        get "/admin/decisions/new"

        expect(page).to have_css("form[action='/admin/decisions'] textarea[name='decision[problem]']")
      end

      it "links back to the list with a hidden arrow before the label", :aggregate_failures do
        get "/admin/decisions/new"
        back = page.find("a.btn[href='/admin/decisions']", text: "All decisions")

        expect(back).to have_css("i.fa-solid.fa-arrow-left[aria-hidden='true']:first-child", visible: :all)
        expect(back[:type]).to be_nil
        expect(back[:disabled]).to be_nil
      end

      it "saves it and goes to its page", :aggregate_failures do
        send_to("/admin/decisions", decision: { title: "Pick a host", problem: "The Pi is slow" })
        opened = Decisions::Slice["relations.decisions"].to_a.last

        expect(opened).to include(title: "Pick a host", problem: "The Pi is slow", status: "open")
        expect(last_response.location).to end_with("/admin/decisions/#{opened[:id]}")
      end

      it "saves its tags" do
        send_to("/admin/decisions", decision: { title: "Pick a host", problem: "The Pi is slow", tags: "hosting" })

        expect(reload(Decisions::Slice["relations.decisions"].to_a.last[:id]).tags.map(&:name)).to eq(%w[hosting])
      end

      it "says so" do
        send_to("/admin/decisions", decision: { title: "Pick a host", problem: "The Pi is slow" })
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: t("decisions_page.toasts.opened"))
      end

      it "refuses a blank problem beside the field", :aggregate_failures do
        send_to("/admin/decisions", decision: { title: "Pick a host", problem: " " })

        expect(last_response.status).to eq(422)
        expect(page.find_by_id("decision-problem-error").text)
          .to eq(t("ui.components.decisions.field_error.problem.blank"))
        expect(page).to have_field("decision[title]", with: "Pick a host")
      end
    end

    describe "the decision page" do
      before do
        option
        get "/admin/decisions/#{decision.id}"
      end

      it "shows the title, the status and the problem as Markdown", :aggregate_failures do
        expect(page).to have_css("h1", text: "Pick a queue")
        expect(page).to have_css(".pill", text: "open")
        expect(page).to have_css(".markdown-body strong", text: "pile")
      end

      it "shows the decision's key" do
        expect(page).to have_css(
          ".read-meta button.record-key[data-record-key='##{decision.id}']", text: "##{decision.id}",
        )
      end

      it "lists the options with their bodies as Markdown" do
        expect(page.find("[data-decision-option='#{option.id}']")).to have_css(".markdown-body em", text: "today")
      end

      it "offers a form to add an option" do
        expect(page).to have_css("form[action='/admin/decisions/#{decision.id}/options'] input[name='option[title]']")
      end

      it "offers an edit form for each option, without a note while open", :aggregate_failures do
        form = page.find("form[action='/admin/decisions/#{decision.id}/options/#{option.id}']", visible: :all)

        expect(form).to have_field("option[title]", with: "Sidekiq", visible: :all)
        expect(form).to have_no_css("[name='option[note]']", visible: :all)
      end

      it "offers only this decision's options to resolve with" do
        create(:decision_option, title: "Elsewhere")
        get "/admin/decisions/#{decision.id}"

        expect(page.all("select[name='decision[option_id]'] option").map(&:text)).to eq(["Pick an option", "Sidekiq"])
      end

      it "offers to drop it and not to reopen it", :aggregate_failures do
        expect(page).to have_css("form[action='/admin/decisions/#{decision.id}/drop']")
        expect(page).to have_no_css("form[action='/admin/decisions/#{decision.id}/reopen']")
      end

      it "shows its tags" do
        Decisions::Slice["repos.decision_repo"].replace_tags(decision.id, %w[queues])
        get "/admin/decisions/#{decision.id}"

        expect(page.find(".read-meta")).to have_css(".tag", text: "#queues")
      end

      it "links its tags to their summaries" do
        Decisions::Slice["repos.decision_repo"].replace_tags(decision.id, %w[queues])
        get "/admin/decisions/#{decision.id}"

        expect(page.find(".read-meta")).to have_link("#queues", href: "/admin/tags/queues")
      end

      it "answers 404 for a decision that isn't there" do
        get "/admin/decisions/999999"

        expect(last_response.status).to eq(404)
      end
    end

    it "says to add an option before it resolves" do
      get "/admin/decisions/#{decision.id}"

      expect(page).to have_no_css("form[action='/admin/decisions/#{decision.id}/resolve']")
        .and have_css(".hint", text: t("ui.components.decisions.closing.no_options"))
    end

    describe "adding an option" do
      it "saves it and comes back to the decision", :aggregate_failures do
        send_to("/admin/decisions/#{decision.id}/options", option: { title: "Good Job", body: "Uses Postgres" })

        expect(reload.options.map { [it.title, it.body] }).to eq([["Good Job", "Uses Postgres"]])
        expect(last_response.location).to end_with("/admin/decisions/#{decision.id}")
      end

      it "refuses a blank title on the page and keeps what was typed", :aggregate_failures do
        send_to("/admin/decisions/#{decision.id}/options", option: { title: " ", body: "Uses Postgres" })

        expect(last_response.status).to eq(422)
        expect(page).to have_css("#decision-option-new-title-error")
        expect(page).to have_field("option[body]", with: "Uses Postgres")
      end

      it "turns away a closed decision" do
        close(:drop, reason: "No need")
        send_to("/admin/decisions/#{decision.id}/options", option: { title: "Late", body: "" })
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: t("decisions_page.toasts.closed"))
      end
    end

    describe "editing an option" do
      def edit(**fields) = send_to("/admin/decisions/#{decision.id}/options/#{option.id}", option: fields)

      it "saves it on an open decision without a note" do
        edit(title: "Sidekiq 8", body: "Runs today")

        expect(reload.options.map(&:title)).to eq(["Sidekiq 8"])
      end

      it "answers 404 for an option on another decision" do
        other = create(:decision_option, title: "Elsewhere")
        send_to("/admin/decisions/#{decision.id}/options/#{other.id}", option: { title: "Mine", body: "" })

        expect(last_response.status).to eq(404)
      end
    end

    describe "editing an option on a closed decision" do
      def edit(**fields) = send_to("/admin/decisions/#{decision.id}/options/#{option.id}", option: fields)

      before { close(:resolve, option_id: option.id, reason: "It runs") }

      it "asks for a note in the form" do
        get "/admin/decisions/#{decision.id}"

        expect(page.find("form[action='/admin/decisions/#{decision.id}/options/#{option.id}']", visible: :all))
          .to have_css("textarea[name='option[note]']", visible: :all)
      end

      it "refuses the save without a note" do
        edit(title: "Sidekiq 8", body: "Runs today")

        expect([last_response.status, reload.options.map(&:title)]).to eq([422, ["Sidekiq"]])
      end

      it "says why beside the note and keeps what was typed", :aggregate_failures do
        edit(title: "Sidekiq 8", body: "Runs today")

        expect(page.find("#decision-option-#{option.id}-note-error").text)
          .to eq(t("ui.components.decisions.field_error.note.blank"))
        expect(page).to have_css("details[open] input[name='option[title]'][value='Sidekiq 8']")
      end

      it "saves it with a note and keeps the note", :aggregate_failures do
        edit(title: "Sidekiq 8", body: "Runs today", note: "Renamed it")

        expect(reload.options.map(&:title)).to eq(["Sidekiq 8"])
        expect(events.last).to include(kind: "option_edited", note: "Renamed it")
      end
    end

    describe "editing the decision" do
      def update(**fields) = send_to("/admin/decisions/#{decision.id}", decision: fields)

      it "shows the form with no note while open", :aggregate_failures do
        get "/admin/decisions/#{decision.id}/edit"

        expect(page).to have_field("decision[title]", with: "Pick a queue")
        expect(page).to have_no_css("[name='decision[note]']")
      end

      it "saves it and comes back to the decision", :aggregate_failures do
        update(title: "Pick a queue", problem: "Jobs pile up fast")

        expect(reload.problem).to eq("Jobs pile up fast")
        expect(last_response.location).to end_with("/admin/decisions/#{decision.id}")
      end

      it "answers 404 for a decision that isn't there" do
        send_to("/admin/decisions/999999", decision: { title: "Pick a queue", problem: "Jobs pile up" })

        expect(last_response.status).to eq(404)
      end

      it "fills the tags field with its tags" do
        update(title: "Pick a queue", problem: "Jobs pile up", tags: "queues, ruby")
        get "/admin/decisions/#{decision.id}/edit"

        expect(page).to have_field("decision[tags]", with: "queues, ruby")
      end

      it "adds and removes its tags", :aggregate_failures do
        update(title: "Pick a queue", problem: "Jobs pile up", tags: "queues, ruby")
        update(title: "Pick a queue", problem: "Jobs pile up", tags: "ruby")

        expect(reload.tags.map(&:name)).to eq(%w[ruby])
        expect(reload.tags.map(&:scope)).to eq(%w[private])
      end

      it "refuses a tag that is not a slug beside the field", :aggregate_failures do
        update(title: "Pick a queue", problem: "Jobs pile up", tags: "two words!")

        expect(last_response.status).to eq(422)
        expect(page.find_by_id("decision-tags-error").text).to eq(t("ui.components.decisions.field_error.tags.format"))
        expect(page).to have_field("decision[tags]", with: "two words!")
      end
    end

    describe "editing a closed decision" do
      def update(**fields) = send_to("/admin/decisions/#{decision.id}", decision: fields)

      before { close(:drop, reason: "No need") }

      it "asks for a note" do
        get "/admin/decisions/#{decision.id}/edit"

        expect(page).to have_css("textarea[name='decision[note]']")
      end

      it "refuses a new problem without a note", :aggregate_failures do
        update(title: "Pick a queue", problem: "Jobs pile up fast")

        expect(last_response.status).to eq(422)
        expect(page.find_by_id("decision-note-error").text).to eq(t("ui.components.decisions.field_error.note.blank"))
        expect(reload.problem).to eq("Jobs **pile** up")
      end

      it "saves a new title without a note" do
        update(title: "Pick a job queue", problem: "Jobs **pile** up")

        expect(reload.title).to eq("Pick a job queue")
      end

      it "saves a new problem with a note", :aggregate_failures do
        update(title: "Pick a queue", problem: "Jobs pile up fast", note: "Measured it")

        expect(reload.problem).to eq("Jobs pile up fast")
        expect(events.last).to include(kind: "edited", note: "Measured it")
      end
    end

    describe "resolving" do
      it "saves the choice and the reason", :aggregate_failures do
        close(:resolve, option_id: option.id, reason: "It runs")

        expect(reload).to have_attributes(status: "resolved", resolved_option_id: option.id)
        expect(events.last).to include(kind: "resolved", option_id: option.id, reason: "It runs")
      end

      it "marks the chosen option on the page" do
        close(:resolve, option_id: option.id, reason: "It runs")
        follow_redirect!

        expect(page.find("[data-decision-option='#{option.id}']")).to have_css(".pill", text: "chosen")
      end

      it "refuses another decision's option", :aggregate_failures do
        option
        close(:resolve, option_id: create(:decision_option).id, reason: "It runs")

        expect(reload.status).to eq("open")
        expect(page.find_by_id("decision-resolve-option-id-error").text)
          .to eq(t("ui.components.decisions.field_error.option_id.missing"))
      end

      it "refuses a missing option" do
        option
        close(:resolve, option_id: "", reason: "It runs")

        expect([last_response.status, reload.status]).to eq([422, "open"])
      end

      it "refuses a blank reason and keeps the choice", :aggregate_failures do
        close(:resolve, option_id: option.id, reason: " ")

        expect(page.find_by_id("decision-resolve-reason-error").text)
          .to eq(t("ui.components.decisions.field_error.reason.blank"))
        expect(page).to have_select("decision[option_id]", selected: "Sidekiq")
        expect(reload.status).to eq("open")
      end
    end

    describe "dropping" do
      it "closes it with the reason", :aggregate_failures do
        close(:drop, reason: "No need")

        expect(reload.status).to eq("dropped")
        expect(events.last).to include(kind: "dropped", reason: "No need")
      end

      it "refuses a blank reason", :aggregate_failures do
        close(:drop, reason: "")

        expect(last_response.status).to eq(422)
        expect(page).to have_css("#decision-drop-reason-error")
        expect(reload.status).to eq("open")
      end

      it "turns away a closed decision" do
        close(:drop, reason: "No need")
        close(:drop, reason: "Again")
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: t("decisions_page.toasts.closed"))
      end
    end

    describe "reopening" do
      before { close(:drop, reason: "No need") }

      it "offers to reopen it and not to resolve or drop it", :aggregate_failures do
        get "/admin/decisions/#{decision.id}"

        expect(page).to have_css("form[action='/admin/decisions/#{decision.id}/reopen']")
        expect(page).to have_no_css("form[action$='/drop'], form[action$='/resolve']")
      end

      it "opens it again with the reason", :aggregate_failures do
        close(:reopen, reason: "It matters again")

        expect(reload.status).to eq("open")
        expect(events.last).to include(kind: "reopened", reason: "It matters again")
      end

      it "refuses a blank reason", :aggregate_failures do
        close(:reopen, reason: "")

        expect(last_response.status).to eq(422)
        expect(page).to have_css("#decision-reopen-reason-error")
        expect(reload.status).to eq("dropped")
      end

      it "turns away an open decision" do
        close(:reopen, reason: "It matters again")
        close(:reopen, reason: "Again")
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: t("decisions_page.toasts.open"))
      end
    end
  end
end
