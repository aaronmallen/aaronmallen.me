# frozen_string_literal: true

RSpec.describe "Admin task record links", type: :request do
  let(:i18n) { Admin::Slice["i18n"] }
  let(:page) { Capybara.string(last_response.body) }
  let(:task) { create(:task, title: "Move the server") }
  let(:post_record) { create(:post, title: "On hosting the site") }
  let(:scope) { "task-#{task.id}-record" }

  def error = page.find("##{scope}-other-id-error").text

  def field_error(code) = i18n.t(["ui.components.record_links.field_error.other_id", code].join("."))

  def find_records(query, **) = get("/admin/tasks/#{task.id}", filter: "next", record_q: query, **)

  def group(kind) = section.find(".record-link-kind", exact_text: kind_name(kind)).ancestor(".record-link-group")

  def kind_name(kind) = i18n.t(["ui.components.record_links.kinds", kind].join("."))

  def link(other_kind: "post", other_id: post_record.id, **)
    send_to("/admin/tasks/#{task.id}/records", filter: "next", record: { other_kind:, other_id: other_id.to_s }, **)
  end

  def link_records(kind, id)
    Links::Slice["operations.link_records"].call("task", task.id, { other_kind: kind, other_id: id }).value!
  end

  def links = Links::Slice["relations.record_links"]

  def picks = section.all(".record-picker-target").map { it.find(".record-link-title").text }

  def section = page.find(".record-links")

  def send_to(path, **params)
    post path, { _csrf_token: admin_csrf_token, **params }
  end

  def unlink(kind = "post", id = post_record.id)
    send_to("/admin/tasks/#{task.id}/records/#{kind}/#{id}/delete", filter: "next")
  end

  describe "the Linked section" do
    before { sign_in_to_admin }

    it "says nothing is linked yet on a task with no links" do
      get "/admin/tasks/#{task.id}"

      expect(section).to have_css(".hint", text: i18n.t("ui.components.record_links.section.empty"))
    end

    it "groups the links by kind in the order of the kinds" do
      %w[commit project post].each { link_records(it, linkable_record(it).id) }
      get "/admin/tasks/#{task.id}"

      expect(section.all(".card-body > .record-link-group .record-link-kind").map(&:text))
        .to eq(%w[post commit project].map { kind_name(it) })
    end

    it "links a post to its editor" do
      link_records("post", post_record.id)
      get "/admin/tasks/#{task.id}"

      expect(group("post")).to have_link("On hosting the site", href: "/admin/posts/#{post_record.id}/edit")
    end

    it "links a project to its editor" do
      project = create(:project, name: "aaronmallen.me")
      link_records("project", project.id)
      get "/admin/tasks/#{task.id}"

      expect(group("project")).to have_link("aaronmallen.me", href: "/admin/projects/#{project.id}/edit")
    end

    it "shows a link stored from the other side" do
      Links::Slice["operations.link_records"].call("post", post_record.id, { other_kind: "task", other_id: task.id })
      get "/admin/tasks/#{task.id}"

      expect(group("post")).to have_link("On hosting the site")
    end

    it "offers a remove on each link that keeps the tab" do
      link_records("post", post_record.id)
      get "/admin/tasks/#{task.id}", filter: "upcoming"
      form = section.find("form[action='/admin/tasks/#{task.id}/records/post/#{post_record.id}/delete']")

      expect(form.find("input[name='filter']", visible: :all).value).to eq("upcoming")
    end

    it "names the record on its remove button" do
      link_records("post", post_record.id)
      get "/admin/tasks/#{task.id}"

      expect(section).to have_button(i18n.t("ui.components.record_links.section.remove", title: "On hosting the site"))
    end

    it "keeps task to task links out of it" do
      create(:task_link, from_task_id: task.id, to_task_id: create(:task, title: "Order the rack").id)
      get "/admin/tasks/#{task.id}"

      expect(section).to have_no_text("Order the rack")
    end
  end

  describe "the picker" do
    before do
      sign_in_to_admin
      post_record
    end

    it "finds a record of each kind but a task by its text" do
      (Blog::Types::RecordKind.values - %w[post]).each { linkable_record(it, "server #{it}") }
      find_records("server")

      expect(section.all(".record-picker-results .record-link-kind").map(&:text))
        .to eq((Blog::Types::RecordKind.values - %w[task post]).map { kind_name(it) })
    end

    it "finds a post by its title" do
      find_records("hosting")

      expect(picks).to eq(["On hosting the site"])
    end

    it "leaves out a record it already links to" do
      link_records("post", post_record.id)
      find_records("hosting")

      expect(section).to have_css(".hint", text: i18n.t("ui.components.record_links.picker.no_match"))
    end

    it "leaves out tasks, which link from the Links section" do
      create(:task, title: "Rack the server")
      find_records("server")

      expect(picks).to be_empty
    end

    it "keeps the query in the field" do
      find_records("hosting")

      expect(page.find("##{scope}-other-id").value).to eq("hosting")
    end

    describe "the find" do
      def form = section.find("form.record-picker-find")

      before { get "/admin/tasks/#{task.id}", filter: "upcoming", origin: "today" }

      it "gets the task's page with the query", :aggregate_failures do
        expect([form["method"], form["action"]]).to eq(["get", "/admin/tasks/#{task.id}"])
        expect(form).to have_field("record_q", type: "search")
      end

      it "keeps the tab and where the task opened from" do
        expect(%w[filter origin].map { form.find("input[name='#{it}']", visible: :all).value })
          .to eq(%w[upcoming today])
      end
    end

    it "posts the link from each match", :aggregate_failures do
      find_records("hosting")
      form = section.find(".record-picker-pick")

      expect(form["action"]).to eq("/admin/tasks/#{task.id}/records")
      expect(form.find("input[name='record[other_kind]']", visible: :all).value).to eq("post")
      expect(form.find("input[name='record[other_id]']", visible: :all).value).to eq(post_record.id.to_s)
    end

    it "says nothing for a blank query" do
      find_records("  ")

      expect(section).to have_no_css(".record-picker-results, .record-picker .hint")
    end
  end

  describe "adding a link" do
    before { sign_in_to_admin }

    it "stores it" do
      link

      expect(Links::Slice["queries.record_links"].call("task", task.id).fetch("post").map(&:id)).to eq([post_record.id])
    end

    it "comes back to the list that was open" do
      link

      expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin/tasks?filter=next"))
    end

    it "comes back to Today when it was added there" do
      link(filter: "today", origin: "today")

      expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin"))
    end

    it "says so" do
      link
      follow_redirect!

      expect(page).to have_css("[data-toast]", text: i18n.t("tasks_page.toasts.record_linked"))
    end

    it "shows on the post's side" do
      link

      expect(Links::Slice["queries.record_links"].call("post", post_record.id).fetch("task").map(&:id)).to eq([task.id])
    end

    it "answers 404 for a task that isn't there" do
      send_to("/admin/tasks/0/records", filter: "next", record: { other_kind: "post", other_id: post_record.id.to_s })

      expect(last_response.status).to eq(404)
    end

    describe "a record already linked" do
      before do
        link_records("post", post_record.id)
        link(record_q: "hosting")
      end

      it "answers 422" do
        expect(last_response.status).to eq(422)
      end

      it "says the two are already linked beside the picker" do
        expect(section.find(".record-picker ##{scope}-other-id-error").text).to eq(field_error(:taken))
      end

      it "points the field at the error" do
        expect(page.find("##{scope}-other-id")["aria-describedby"]).to eq("#{scope}-other-id-error")
      end

      it "keeps the query" do
        expect(page.find("##{scope}-other-id").value).to eq("hosting")
      end

      it "shows the task's page" do
        expect(page).to have_css("[data-task-read='#{task.id}']")
      end

      it "writes nothing" do
        expect(links.to_a.size).to eq(1)
      end
    end

    it "refuses a record that is gone" do
      link(other_id: 999_999)

      expect(error).to eq(field_error(:missing))
    end

    it "refuses a task, which links from the Links section" do
      link(other_kind: "task", other_id: create(:task).id)

      expect(error).to eq(field_error(:task_pair))
    end

    it "refuses a kind it does not know" do
      link(other_kind: "person")

      expect(page.find("##{scope}-other-kind-error").text)
        .to eq(i18n.t("ui.components.record_links.field_error.other_kind.format"))
    end
  end

  describe "removing a link" do
    before do
      sign_in_to_admin
      link_records("post", post_record.id)
    end

    it "clears it" do
      unlink

      expect(links.to_a).to be_empty
    end

    it "says so" do
      unlink
      follow_redirect!

      expect(page).to have_css("[data-toast]", text: i18n.t("tasks_page.toasts.record_unlinked"))
    end

    it "comes back to the list that was open" do
      unlink

      expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin/tasks?filter=next"))
    end

    it "answers 404 for a link that isn't there" do
      unlink("project", create(:project).id)

      expect(last_response.status).to eq(404)
    end
  end

  describe "signed out" do
    it "adds no link" do
      post "/admin/tasks/#{task.id}/records", record: { other_kind: "post", other_id: post_record.id.to_s }

      expect(links.to_a).to be_empty
    end

    it "removes no link" do
      link_records("post", post_record.id)
      post "/admin/tasks/#{task.id}/records/post/#{post_record.id}/delete"

      expect(links.to_a.size).to eq(1)
    end
  end
end
