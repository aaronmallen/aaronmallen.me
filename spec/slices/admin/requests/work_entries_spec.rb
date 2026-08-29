# frozen_string_literal: true

RSpec.describe "Admin work history", type: :request do
  let(:i18n) { Admin::Slice["i18n"] }
  let(:page) { Capybara.string(last_response.body) }
  let(:repo) { Projects::Slice["repos.work_entry_repo"] }

  def add(**fields)
    post "/admin/projects/work", _csrf_token: admin_csrf_token, work_entry: fields
  end

  def field_error(key) = i18n.t(["ui.components.work_entries.field_error", key].join("."))

  def fields(**changes)
    { org: "Rackspace", role: "Software Engineer", blurb: "Built things", from_year: "2018", to_year: "2021" }
      .merge(changes)
  end

  def roles = page.all(".li .li-title").map(&:text)

  def subs = page.all(".li .li-sub").map(&:text)

  describe "signed in" do
    before { sign_in_to_admin }

    describe "the tab" do
      it "offers work as a third segment" do
        get "/admin/projects"

        expect(page).to have_css(".seg input[name='filter'][value='work']", visible: :all)
      end

      it "keeps work chosen" do
        get "/admin/projects", filter: "work"

        expect(page).to have_css(".seg input[name='filter'][value='work'][checked]", visible: :all)
      end

      it "leaves the project list off the work tab" do
        create(:project, name: "live-one")
        get "/admin/projects", filter: "work"

        expect(roles).not_to include("live-one")
      end

      it "leaves the archive note off the work tab" do
        get "/admin/projects", filter: "work"

        expect(page).to have_no_css("p.hint", text: i18n.t("ui.views.projects.index.archive_note"))
      end

      it "labels the roles card", :aggregate_failures do
        get "/admin/projects", filter: "work"

        expect(page).to have_css(".card-label", text: "Work history")
        expect(page).to have_css(".card-title", text: "Shown under Work on /projects")
      end

      it "says when there are no roles" do
        get "/admin/projects", filter: "work"

        expect(page).to have_css(".empty", exact_text: i18n.t("ui.views.projects.index.empty.work"))
      end
    end

    describe "the rows" do
      it "lists the roles in position order" do
        create(:work_entry, role: "Second", position: 2)
        create(:work_entry, role: "First", position: 1)
        get "/admin/projects", filter: "work"

        expect(roles).to eq(%w[First Second])
      end

      it "names the organization and the years under the role" do
        create(:work_entry, org: "Rackspace", from_year: 2018, to_year: 2021)
        get "/admin/projects", filter: "work"

        expect(subs).to eq(["Rackspace · 2018–2021"])
      end

      it "reads a role with no end year as current" do
        create(:work_entry, :current, org: "Rackspace", from_year: 2021)
        get "/admin/projects", filter: "work"

        expect(subs).to eq(["Rackspace · 2021–Present"])
      end

      it "shows the blurb" do
        create(:work_entry, blurb: "Built things")
        get "/admin/projects", filter: "work"

        expect(page).to have_css(".proj-tagline", exact_text: "Built things")
      end

      it "leaves the blurb out when there is none" do
        create(:work_entry, blurb: nil)
        get "/admin/projects", filter: "work"

        expect(page).to have_no_css(".proj-tagline")
      end

      it "offers Remove on every row" do
        create(:work_entry)
        get "/admin/projects", filter: "work"

        expect(page).to have_button("Remove")
      end

      it "asks before removing" do
        create(:work_entry, org: "Rackspace", role: "Software Engineer")
        get "/admin/projects", filter: "work"

        confirm = i18n.t("ui.components.work_entries.row.confirm_remove", org: "Rackspace", role: "Software Engineer")

        expect(page.first("form[data-confirm]")[:"data-confirm"]).to eq(confirm)
      end

      it "offers no archive" do
        create(:work_entry)
        get "/admin/projects", filter: "work"

        expect(page).to have_no_button("Archive")
      end
    end

    describe "the add form" do
      before { get "/admin/projects", filter: "work" }

      it "posts to the work route" do
        expect(page).to have_css("form[action='/admin/projects/work']")
      end

      it "asks for the organization, the role, the years and the blurb", :aggregate_failures do
        expect(page).to have_field("work_entry[org]")
        expect(page).to have_field("work_entry[role]")
        expect(page).to have_field("work_entry[from_year]")
        expect(page).to have_field("work_entry[to_year]")
        expect(page).to have_field("work_entry[blurb]")
      end

      it "disables Add role on an empty form" do
        expect(page).to have_button("Add role", disabled: true)
      end
    end

    describe "adding" do
      it "stores the role" do
        add(**fields)

        expect(repo.all.first)
          .to have_attributes(org: "Rackspace", role: "Software Engineer", from_year: 2018, to_year: 2021)
      end

      it "shows the added toast" do
        add(**fields)
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: "Role added to /projects")
      end

      it "comes back to the work tab" do
        add(**fields)

        expect(last_response).to be_redirect
          .and have_attributes(location: end_with("/admin/projects?filter=work"))
      end

      it "shows the new role on the public page" do
        add(**fields)
        get "/about"

        expect(page.all(".rows .row h3").map(&:text)).to eq(["Software Engineer"])
      end

      it "keeps a role with no end year current on the public page" do
        add(**fields(to_year: ""))
        get "/about"

        expect(page).to have_css(".rows .row .yr", exact_text: "2018–Present")
      end

      it "adds each role to the end of the order" do
        add(**fields(role: "First"))
        add(**fields(role: "Second"))

        expect(repo.all.map(&:role)).to eq(%w[First Second])
      end

      [
        [{ org: " " }, "org.blank"],
        [{ role: " " }, "role.blank"],
        [{ from_year: "" }, "from_year.blank"],
        [{ from_year: "18" }, "from_year.format"],
        [{ from_year: "0000" }, "from_year.format"],
        [{ to_year: "21" }, "to_year.format"],
        [{ from_year: "2021", to_year: "2018" }, "to_year.before_from"],
      ].each do |changes, key|
        it "refuses #{changes} with #{key}", :aggregate_failures do
          add(**fields(**changes))

          expect(last_response.status).to eq(422)
          expect(page).to have_css(".field-error", text: field_error(key))
        end
      end

      it "stores nothing when it refuses" do
        add(**fields(org: " "))

        expect(repo.all).to be_empty
      end

      it "keeps what was typed when it refuses" do
        add(**fields(org: " ", role: "Software Engineer"))

        expect(page).to have_field("work_entry[role]", with: "Software Engineer")
      end

      it "still lists the roles when it refuses" do
        create(:work_entry, role: "Kept")
        add(**fields(org: " "))

        expect(roles).to eq(%w[Kept])
      end
    end

    describe "removing" do
      let!(:entry) { create(:work_entry, role: "Software Engineer") }

      def remove(id) = post("/admin/projects/work/#{id}/delete", _csrf_token: admin_csrf_token)

      it "removes the role" do
        remove(entry.id)

        expect(repo.all).to be_empty
      end

      it "shows the removed toast" do
        remove(entry.id)
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: "Role removed from /projects")
      end

      it "comes back to the work tab" do
        remove(entry.id)

        expect(last_response).to be_redirect
          .and have_attributes(location: end_with("/admin/projects?filter=work"))
      end

      it "takes the role off the public page" do
        remove(entry.id)
        get "/about"

        expect(page).to have_no_css(".rows .row")
      end

      it "leaves the other roles alone" do
        create(:work_entry, role: "Kept", position: 9)
        remove(entry.id)

        expect(repo.all.map(&:role)).to eq(%w[Kept])
      end

      it "answers 404 for a role that isn't there" do
        remove(0)

        expect(last_response.status).to eq(404)
      end
    end
  end

  it "refuses to add when signed out" do
    post "/admin/projects/work", work_entry: fields

    expect(repo.all).to be_empty
  end

  it "refuses to remove when signed out" do
    entry = create(:work_entry)
    post "/admin/projects/work/#{entry.id}/delete"

    expect(repo.all.map(&:id)).to eq([entry.id])
  end
end
