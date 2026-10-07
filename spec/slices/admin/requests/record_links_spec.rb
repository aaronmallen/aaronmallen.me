# frozen_string_literal: true

RSpec.describe "Admin record links", type: :request do
  let(:i18n) { Admin::Slice["i18n"] }
  let(:page) { Capybara.string(last_response.body) }
  let(:task) { create(:task, title: "Move the server") }

  def field_error(code) = i18n.t(["ui.components.record_links.field_error.other_id", code].join("."))

  def group(kind) = section.find(".record-link-kind", exact_text: kind_name(kind)).ancestor(".record-link-group")

  def kind_name(kind) = i18n.t(["ui.components.record_links.kinds", kind].join("."))

  def link(other_kind: "task", other_id: task.id, **)
    send_to(records_path, record: { other_kind:, other_id: other_id.to_s }, **fields, **)
  end

  def link_records(other_kind, other_id)
    Links::Slice["operations.link_records"].call(kind, record.id, { other_kind:, other_id: }).value!
  end

  def linked(other_kind)
    Links::Slice["repos.record_link_queries"].for_record(kind, record.id).fetch(other_kind, []).map(&:id)
  end

  def links = Links::Slice["relations.record_links"]

  def picks = section.all(".record-picker-target").map { it.find(".record-link-title").text }

  def section = page.find(".record-links")

  def send_to(path, **params) = post(path, { _csrf_token: admin_csrf_token, **params })

  def show(**query) = get(page_path, **fields, **query)

  def unlink(other_kind = "task", other_id = task.id)
    send_to("#{records_path}/#{other_kind}/#{other_id}/delete", **fields)
  end

  shared_examples "a page with a Linked section" do
    def scope = "#{kind.tr('_', '-')}-#{record.id}-record"

    describe "the Linked section" do
      before { sign_in_to_admin }

      it "says nothing is linked yet" do
        show

        expect(section).to have_css(".hint", text: i18n.t("ui.components.record_links.section.empty"))
      end

      it "groups its links by kind, each linking to its record", :aggregate_failures do
        link_records("task", task.id)
        link_records("decision", create(:decision, title: "Pick a host").id)
        show

        expect(group("task")).to have_link("Move the server", href: "/admin/tasks/#{task.id}")
        expect(group("decision")).to have_link("Pick a host")
      end

      it "offers a remove on each link" do
        link_records("task", task.id)
        show

        expect(section).to have_css("form[action='#{records_path}/task/#{task.id}/delete']")
      end
    end

    describe "the picker" do
      before do
        sign_in_to_admin
        task
      end

      it "finds a task by its title" do
        show(record_q: "server")

        expect(picks).to eq(["Move the server"])
      end

      it "leaves out a task it already links to" do
        link_records("task", task.id)
        show(record_q: "server")

        expect(picks).to be_empty
      end

      it "searches from the same page" do
        show

        expect(section.find("form.record-picker-find")["action"]).to eq(page_path)
      end

      it "posts the link from each match" do
        show(record_q: "server")

        expect(section.find(".record-picker-pick")["action"]).to eq(records_path)
      end
    end

    describe "adding a link" do
      before { sign_in_to_admin }

      it "links several records" do
        other = create(:post)
        link
        link(other_kind: "post", other_id: other.id)

        expect([linked("task"), linked("post")]).to eq([[task.id], [other.id]])
      end

      it "shows on the other record" do
        link

        partners = Links::Slice["repos.record_link_queries"].for_record("task", task.id)

        expect(partners.fetch(kind).map(&:id)).to eq([record.id])
      end

      it "comes back to the record and says so", :aggregate_failures do
        link

        expect(last_response).to be_redirect.and have_attributes(location: end_with(back_path))
        follow_redirect!
        expect(page).to have_css("[data-toast]", text: i18n.t("record_links.toasts.linked"))
      end

      it "answers 404 for a record that isn't there" do
        send_to(records_path.sub("/#{record.id}/", "/0/"), record: { other_kind: "task", other_id: task.id.to_s })

        expect(last_response.status).to eq(404)
      end

      describe "a record already linked" do
        before do
          link_records("task", task.id)
          link(record_q: "server")
        end

        it "answers 422" do
          expect(last_response.status).to eq(422)
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
    end

    describe "removing a link" do
      before do
        sign_in_to_admin
        link_records("task", task.id)
      end

      it "clears it and comes back to the record", :aggregate_failures do
        unlink

        expect(links.to_a).to be_empty
        expect(last_response).to be_redirect.and have_attributes(location: end_with(back_path))
      end

      it "says so" do
        unlink
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: i18n.t("record_links.toasts.unlinked"))
      end

      it "answers 404 for a link that isn't there" do
        unlink("task", create(:task).id)

        expect(last_response.status).to eq(404)
      end

      it "answers 404 for an ID too large to store" do
        unlink("task", 2**31)

        expect(last_response.status).to eq(404)
      end
    end

    describe "signed out" do
      it "adds no link" do
        post records_path, record: { other_kind: "task", other_id: task.id.to_s }

        expect(links.to_a).to be_empty
      end

      it "removes no link" do
        link_records("task", task.id)
        post "#{records_path}/task/#{task.id}/delete"

        expect(links.to_a.size).to eq(1)
      end
    end
  end

  describe "the picker on a post" do
    def create_past_titles
      create(:task, note: "Bring the zeppelin")
      create(:post, body: "All about the zeppelin")
      create(:social_post_part, social_post_id: create(:social_post, :thread).id, body: "And a zeppelin")
      create(:journal_entry, body: "Morning\nSaw a zeppelin")
      create(:commit, repo: "aaronmallen/zeppelin")
      create(:project, tagline: "Tracks a zeppelin")
      create(:work_entry, blurb: "Flew a zeppelin")
      create(:decision, problem: "Which zeppelin to buy")
    end

    def fields = {}

    def found = section.all(".record-picker-results .record-link-group").map { it.find(".record-link-kind").text }

    def page_path = "/admin/posts/#{record.id}/edit"

    def record = @record ||= create(:post, title: "On hosting")

    let(:kinds) { Blog::Types::RecordKind.values }

    before do
      sign_in_to_admin
      record
    end

    it "finds a record of every kind by its title" do
      kinds.each { linkable_record(it, "Zeppelin #{it}") }
      show(record_q: "zeppelin")

      expect(found).to eq(kinds.map { kind_name(it) })
    end

    it "finds a record of every kind by text beyond its title" do
      create_past_titles
      show(record_q: "zeppelin")

      expect(found).to eq(kinds.map { kind_name(it) })
    end

    it "keeps to a few of each kind, newest first" do
      today = Blog::TimeZone.today
      (1..6).each { create(:journal_entry, body: "Zeppelin #{it}", entry_date: today - it) }
      show(record_q: "zeppelin")

      expect(picks).to eq((1..5).map { "Zeppelin #{it}" })
    end

    it "reads the text as plain, not as a pattern" do
      create(:task, title: "Half done")
      show(record_q: "%")

      expect(picks).to be_empty
    end

    it "finds nothing for blank text" do
      create(:task, title: "Anything")
      show(record_q: "   ")

      expect(picks).to be_empty
    end
  end

  describe "on a post" do
    def back_path = page_path
    def fields = {}
    def kind = "post"
    def page_path = "/admin/posts/#{record.id}/edit"
    def record = @record ||= create(:post, title: "On hosting")
    def records_path = "/admin/posts/#{record.id}/records"

    it_behaves_like "a page with a Linked section"
  end

  describe "on a project" do
    def back_path = page_path
    def fields = {}
    def kind = "project"
    def page_path = "/admin/projects/#{record.id}/edit"
    def record = @record ||= create(:project, name: "homelab")
    def records_path = "/admin/projects/#{record.id}/records"

    it_behaves_like "a page with a Linked section"
  end

  describe "on a commit" do
    def back_path = page_path
    def fields = {}
    def kind = "commit"
    def page_path = "/admin/commits/#{record.id}"
    def record = @record ||= create(:commit, message: "app: move the server")
    def records_path = "/admin/commits/#{record.id}/records"

    it_behaves_like "a page with a Linked section"
  end

  describe "on a social post" do
    def back_path = "/admin/social?filter=drafts&edit=#{record.id}"
    def fields = { filter: "drafts", edit: record.id.to_s }
    def kind = "social_post"
    def page_path = "/admin/social"
    def record = @record ||= create(:social_post, :draft)
    def records_path = "/admin/social/#{record.id}/records"

    it_behaves_like "a page with a Linked section"

    it "leaves the section off the composer when it writes a new post" do
      sign_in_to_admin
      get "/admin/social"

      expect(page).to have_no_css(".record-links")
    end
  end

  describe "on a journal entry" do
    def back_path = "/admin/journal?to=2026-09-30&edit=#{record.id}"
    def day = Date.new(2026, 9, 30)
    def fields = { to: day.iso8601, edit: record.id.to_s }
    def kind = "journal_entry"
    def page_path = "/admin/journal"
    def record = @record ||= create(:journal_entry, entry_date: day, body: "Packed the rack")
    def records_path = "/admin/journal/#{record.id}/records"

    it_behaves_like "a page with a Linked section"

    describe "opening the entry's links" do
      before do
        sign_in_to_admin
        record
      end

      it "offers a way in from the entry" do
        get "/admin/journal"

        expect(page).to have_link(i18n.t("ui.components.journal.entry.links"), href: back_path)
      end

      it "opens the entry's edit form with the section", :aggregate_failures do
        show

        expect(page).to have_css("form.journal-edit[action='/admin/journal/#{record.id}']:not([hidden])")
        expect(page).to have_css(".journal-entry .journal-links .record-links")
      end

      it "keeps the section on a refused edit" do
        send_to("/admin/journal/#{record.id}", entry: { body: " " })

        expect(page).to have_css(".journal-entry .journal-links .record-links")
      end

      it "keeps the section off an entry it isn't editing" do
        get "/admin/journal"

        expect(page).to have_no_css(".record-links")
      end
    end
  end

  describe "on a work entry" do
    def back_path = "/admin/projects?filter=work&edit=#{record.id}"
    def fields = { filter: "work", edit: record.id.to_s }
    def kind = "work_entry"
    def page_path = "/admin/projects"
    def record = @record ||= create(:work_entry, org: "Rackspace", role: "Engineer")
    def records_path = "/admin/projects/work/#{record.id}/records"

    it_behaves_like "a page with a Linked section"

    describe "opening the entry's links" do
      before do
        sign_in_to_admin
        record
      end

      it "offers a way in from the row" do
        get "/admin/projects", filter: "work"

        expect(page).to have_link(i18n.t("ui.components.work_entries.row.links"), href: back_path)
      end

      it "names the entry on the section" do
        show

        expect(section).to have_text("Engineer at Rackspace")
      end

      it "marks the row it links" do
        show

        expect(page).to have_css("a[aria-current='true'][href='#{back_path}']")
      end
    end
  end
end
