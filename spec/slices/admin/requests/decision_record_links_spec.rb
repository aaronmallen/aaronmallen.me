# frozen_string_literal: true

RSpec.describe "Admin decision record links", type: :request do
  let(:i18n) { Admin::Slice["i18n"] }
  let(:page) { Capybara.string(last_response.body) }
  let(:decision) { create(:decision, title: "Pick a host") }
  let(:task) { create(:task, title: "Move the server") }
  let(:scope) { "decision-#{decision.id}-record" }

  def field_error(code) = i18n.t(["ui.components.record_links.field_error.other_id", code].join("."))

  def group(kind) = section.find(".record-link-kind", exact_text: kind_name(kind)).ancestor(".record-link-group")

  def kind_name(kind) = i18n.t(["ui.components.record_links.kinds", kind].join("."))

  def link(other_kind: "task", other_id: task.id, **)
    send_to("/admin/decisions/#{decision.id}/records", record: { other_kind:, other_id: other_id.to_s }, **)
  end

  def link_records(kind, id)
    Links::Slice["operations.link_records"].call("decision", decision.id, { other_kind: kind, other_id: id }).value!
  end

  def linked(kind)
    Links::Slice["repos.record_link_queries"].for_record("decision", decision.id).fetch(kind, []).map(&:id)
  end

  def links = Links::Slice["relations.record_links"]

  def picks = section.all(".record-picker-target").map { it.find(".record-link-title").text }

  def section = page.find(".record-links")

  def send_to(path, **params) = post(path, { _csrf_token: admin_csrf_token, **params })

  def unlink(kind = "task", id = task.id) = send_to("/admin/decisions/#{decision.id}/records/#{kind}/#{id}/delete")

  describe "the Linked section" do
    before { sign_in_to_admin }

    it "says nothing is linked yet on a decision with no links" do
      get "/admin/decisions/#{decision.id}"

      expect(section).to have_css(".hint", text: i18n.t("ui.components.record_links.section.empty"))
    end

    it "lists its tasks, each linking to the task's page" do
      other = create(:task, title: "Order the rack")
      [task, other].each { link_records("task", it.id) }
      get "/admin/decisions/#{decision.id}"

      expect(group("task").all("a.record-link-title").map { [it.text, it[:href]] })
        .to match_array([task, other].map { [it.title, "/admin/tasks/#{it.id}"] })
    end

    it "lists any other linked record" do
      link_records("post", create(:post, title: "On hosting").id)
      get "/admin/decisions/#{decision.id}"

      expect(group("post")).to have_link("On hosting")
    end

    it "offers a remove on each link" do
      link_records("task", task.id)
      get "/admin/decisions/#{decision.id}"

      expect(section).to have_css("form[action='/admin/decisions/#{decision.id}/records/task/#{task.id}/delete']")
    end
  end

  describe "the picker" do
    before do
      sign_in_to_admin
      task
    end

    it "finds a task by its title" do
      get "/admin/decisions/#{decision.id}", record_q: "server"

      expect(picks).to eq(["Move the server"])
    end

    it "leaves out a task it already links to" do
      link_records("task", task.id)
      get "/admin/decisions/#{decision.id}", record_q: "server"

      expect(picks).to be_empty
    end

    it "gets the decision's page with the query" do
      get "/admin/decisions/#{decision.id}"

      expect(section.find("form.record-picker-find")["action"]).to eq("/admin/decisions/#{decision.id}")
    end

    it "posts the link from each match" do
      get "/admin/decisions/#{decision.id}", record_q: "server"

      expect(section.find(".record-picker-pick")["action"]).to eq("/admin/decisions/#{decision.id}/records")
    end
  end

  describe "adding a link" do
    before { sign_in_to_admin }

    it "links several tasks", :aggregate_failures do
      other = create(:task)
      link
      link(other_id: other.id)

      expect(linked("task")).to contain_exactly(task.id, other.id)
    end

    it "shows on the task's side" do
      link

      partners = Links::Slice["repos.record_link_queries"].for_record("task", task.id)

      expect(partners.fetch("decision").map(&:id)).to eq([decision.id])
    end

    it "comes back to the decision and says so", :aggregate_failures do
      link

      expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin/decisions/#{decision.id}"))
      follow_redirect!
      expect(page).to have_css("[data-toast]", text: i18n.t("decisions_page.toasts.record_linked"))
    end

    it "answers 404 for a decision that isn't there" do
      send_to("/admin/decisions/0/records", record: { other_kind: "task", other_id: task.id.to_s })

      expect(last_response.status).to eq(404)
    end

    describe "a task already linked" do
      before do
        link_records("task", task.id)
        link(record_q: "server")
      end

      it "answers 422 on the decision's page", :aggregate_failures do
        expect(last_response.status).to eq(422)
        expect(page).to have_css("[data-decision-read='#{decision.id}']")
      end

      it "says the two are already linked beside the picker" do
        expect(section.find("##{scope}-other-id-error").text).to eq(field_error(:taken))
      end

      it "keeps the query" do
        expect(page.find("##{scope}-other-id").value).to eq("server")
      end

      it "writes nothing" do
        expect(links.to_a.size).to eq(1)
      end
    end

    it "refuses a record that is gone" do
      link(other_id: 999_999)

      expect(section.find("##{scope}-other-id-error").text).to eq(field_error(:missing))
    end
  end

  describe "removing a link" do
    before do
      sign_in_to_admin
      link_records("task", task.id)
    end

    it "clears it and comes back to the decision", :aggregate_failures do
      unlink

      expect(links.to_a).to be_empty
      expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin/decisions/#{decision.id}"))
    end

    it "says so" do
      unlink
      follow_redirect!

      expect(page).to have_css("[data-toast]", text: i18n.t("decisions_page.toasts.record_unlinked"))
    end

    it "answers 404 for a link that isn't there" do
      unlink("task", create(:task).id)

      expect(last_response.status).to eq(404)
    end
  end

  describe "deleting a linked task" do
    before do
      sign_in_to_admin
      link_records("task", task.id)
    end

    it "drops the link" do
      send_to("/admin/tasks/#{task.id}/delete")

      expect(links.to_a).to be_empty
    end
  end

  describe "signed out" do
    it "adds no link" do
      post "/admin/decisions/#{decision.id}/records", record: { other_kind: "task", other_id: task.id.to_s }

      expect(links.to_a).to be_empty
    end

    it "removes no link" do
      link_records("task", task.id)
      post "/admin/decisions/#{decision.id}/records/task/#{task.id}/delete"

      expect(links.to_a.size).to eq(1)
    end
  end
end
