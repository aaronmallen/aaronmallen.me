# frozen_string_literal: true

RSpec.describe "Admin project tags", type: :request do
  let(:project) { create(:project, name: "blog") }
  let(:other) { create(:project, name: "pod") }
  let(:tag_queries) { Tags::Slice["repos.tag_queries"] }

  def add(name, project_id = project.id, **fields)
    post("/admin/projects/#{project_id}/project_tags", _csrf_token: admin_csrf_token, tag: { name:, **fields })
  end

  def own(project_id = project.id) = tag_queries.all_in("project", project_id:)

  def project_tag(name, owner = project, **) = create(:tag, name:, scope: "project", project_id: owner.id, **)

  def update(tag, **fields)
    post("/admin/projects/#{project.id}/project_tags/#{tag.id}", _csrf_token: admin_csrf_token, tag: fields)
  end

  it "sends a signed out visitor to sign in" do
    add("bug")

    expect(own).to be_empty
  end

  describe "signed in" do
    before { sign_in_to_admin }

    describe "the project page" do
      before do
        project_tag("bug", description: "something broke")
        project_tag("docs")
        project_tag("lonely", other)
        get "/admin/projects/#{project.id}"
      end

      it "counts the project's own tags on its Tags button" do
        expect(page.find("button[commandfor='project-tags']").text).to eq("Tags2")
      end

      it "lists the project's own tags in its manager, and no other project's" do
        expect(page.all("#project-tags .project-tags-name .tag", visible: :all).map { it.text(:all) })
          .to eq(%w[#bug #docs])
      end

      it "shows each tag's description" do
        expect(page.find_by_id("project-tags", visible: :all)).to have_css(
          ".project-tags-description", text: "something broke", visible: :all,
        )
      end

      it "keeps the manager shut until a change sends it back open", :aggregate_failures do
        expect(page.find_by_id("project-tags", visible: :all)["data-dialog-show"]).to be_nil

        get "/admin/projects/#{project.id}", tags: "open"
        expect(page.find_by_id("project-tags", visible: :all)["data-dialog-show"]).not_to be_nil
      end
    end

    it "adds a project tag with a description", :aggregate_failures do
      add("Bug", description: "something broke")

      expect(own.map { [it.name, it.description] }).to eq([["bug", "something broke"]])
      expect(last_response.headers["location"]).to eq("/admin/projects/#{project.id}?tags=open")
      expect(toast).to eq("Tag added")
    end

    it "takes a name another project or the global list holds", :aggregate_failures do
      project_tag("bug", other)
      create(:tag, :private, name: "bug")
      add("bug")

      expect(own.map(&:name)).to eq(%w[bug])
      expect(own(other.id).map(&:name)).to eq(%w[bug])
    end

    it "refuses a name the project already holds", :aggregate_failures do
      project_tag("bug")
      add("bug")

      expect(own.size).to eq(1)
      expect(toast).to eq("Nothing saved · this project already holds that tag")
    end

    it "refuses a name that is not a slug", :aggregate_failures do
      add("not a tag!")

      expect(own).to be_empty
      expect(toast).to eq("Nothing saved · a tag takes lowercase letters, numbers and dashes")
    end

    it "refuses a blank name" do
      add(" ")

      expect(toast).to eq("Nothing added · give the tag a name first")
    end

    it "answers 404 for a project that is gone" do
      add("bug", 0)

      expect(last_response.status).to eq(404)
    end

    it "renames, describes and recolours a project tag", :aggregate_failures do
      tag = project_tag("bug", color: "mk-pink")
      update(tag, name: "defect", description: "fix it", color: "mk-green")

      expect(own.map { [it.name, it.description, it.color] }).to eq([["defect", "fix it", "mk-green"]])
      expect(toast).to eq("Tag saved")
    end

    it "answers 404 for another project's tag" do
      tag = project_tag("bug", other)
      update(tag, name: "defect")

      expect(last_response.status).to eq(404)
    end

    it "removes a project tag", :aggregate_failures do
      tag = project_tag("bug")
      post "/admin/projects/#{project.id}/project_tags/#{tag.id}/delete", _csrf_token: admin_csrf_token

      expect(own).to be_empty
      expect(toast).to eq("Tag removed")
    end

    describe "the global tag screens" do
      before { project_tag("bug") }

      it "leave project tags off the tag list", :aggregate_failures do
        %w[public private].each do |scope|
          get("/admin/settings/tagging", scope:)
          expect(page).to have_no_css(".tag-name", text: "#bug")
        end
      end

      it "leave project tags off the private picker" do
        get "/admin/tags/private/choices", {}, { "HTTP_ACCEPT" => "application/json" }

        expect(last_response.body).not_to include("bug")
      end

      it "ignore a project scope asked for by hand" do
        get "/admin/settings/tagging", scope: "project"

        expect(page).to have_no_css(".tag-name", text: "#bug")
      end
    end
  end
end
