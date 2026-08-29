# frozen_string_literal: true

RSpec.describe "Projects", type: :request do
  let(:missing_id) { 999_999 }
  let(:repo) { Projects::Slice["repos.project_repo"] }

  before { sign_in_to_admin }

  def names = repo.live.map(&:name)

  describe "moving" do
    before do
      create(:project, name: "one", position: 1)
      create(:project, :archived, name: "gone", position: 2)
      create(:project, name: "two", position: 3)
    end

    def move(id, direction) = post("/admin/projects/#{id}/move/#{direction}", _csrf_token: admin_csrf_token)

    it "answers 404 for an id no project has", :aggregate_failures do
      move(missing_id, "up")

      expect(last_response.status).to eq(404)
      expect(names).to eq(%w[one two])
    end

    it "answers 404 for a direction that only starts with one it knows", :aggregate_failures do
      move(repo.live.last.id, "upward")

      expect(last_response.status).to eq(404)
      expect(names).to eq(%w[one two])
    end

    it "steps over an archived project sitting between two live ones" do
      move(repo.live.last.id, "up")

      expect(names).to eq(%w[two one])
    end
  end

  describe "archiving" do
    it "answers 404 for an id no project has" do
      post "/admin/projects/#{missing_id}/archive", _csrf_token: admin_csrf_token

      expect(last_response.status).to eq(404)
    end

    it "keeps the repo, the stars and the position" do
      project = create(:project, repo: "aaronmallen/kept", stars: 12, position: 4)
      post "/admin/projects/#{project.id}/archive", _csrf_token: admin_csrf_token

      expect(repo.by_id(project.id)).to have_attributes(repo: "aaronmallen/kept", stars: 12, position: 4)
    end
  end

  describe "restoring" do
    it "answers 404 for an id no project has" do
      post "/admin/projects/#{missing_id}/restore", _csrf_token: admin_csrf_token

      expect(last_response.status).to eq(404)
    end

    it "keeps a project that was featured before it was archived off the featured list" do
      project = create(:project, :featured)
      post "/admin/projects/#{project.id}/archive", _csrf_token: admin_csrf_token
      post "/admin/projects/#{project.id}/restore", _csrf_token: admin_csrf_token

      expect(repo.by_id(project.id)).to have_attributes(status: "active", featured: false)
    end
  end

  describe "removing a role" do
    it "answers 404 for an id no role has" do
      post "/admin/projects/work/#{missing_id}/delete", _csrf_token: admin_csrf_token

      expect(last_response.status).to eq(404)
    end
  end
end
