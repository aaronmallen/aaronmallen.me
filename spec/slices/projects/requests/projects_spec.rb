# frozen_string_literal: true

RSpec.describe "Projects", type: :request do
  let(:missing_id) { 999_999 }
  let(:repo) { Projects::Slice["repos.project_repo"] }

  before { sign_in_to_admin }

  def names = repo.live.map(&:name)

  def save(name) = Projects::Slice["operations.save_project"].call({ name:, tags: "" })

  describe "placing a new project" do
    it "puts a saved project after the ones already listed" do
      create(:project, name: "older", position: 1)
      create(:project, :archived, name: "gone", position: 2)
      save("new")

      expect(names).to eq(%w[older new])
    end
  end

  describe "two projects saved at once", :commits do
    def database = Projects::Slice["db.rom"].gateways[:default].connection

    def held_by_another_session
      other = Sequel.connect(database.opts.merge(max_connections: 1))
      other.get(Sequel.function(:pg_advisory_lock, Sequel.function(:hashtext, "projects")))
      yield
    ensure
      other&.disconnect
    end

    def saved_together(*names)
      held_by_another_session do
        names.map { |name| Thread.new { save(name) } }.tap { wait_until_all_wait(names.size) }
      end.map(&:value)
    end

    def wait_until_all_wait(count)
      here = database[:pg_database].where(datname: Sequel.function(:current_database)).select(:oid)
      waiting = database[:pg_locks].where(locktype: "advisory", granted: false, database: here)
      Timeout.timeout(5) { sleep(0.01) until waiting.count == count }
    end

    it "saves both", :aggregate_failures do
      results = saved_together("one", "two")

      expect(results).to all(be_success)
      expect(repo.live.map(&:position).uniq.size).to eq(2)
    end
  end

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
    it "keeps the repo, the stars and the position" do
      project = create(:project, repo: "aaronmallen/kept", stars: 12, position: 4)
      post "/admin/projects/#{project.id}/archive", _csrf_token: admin_csrf_token

      expect(repo.by_id(project.id)).to have_attributes(repo: "aaronmallen/kept", stars: 12, position: 4)
    end
  end

  describe "restoring" do
    it "keeps a project that was featured before it was archived off the featured list" do
      project = create(:project, :featured)
      post "/admin/projects/#{project.id}/archive", _csrf_token: admin_csrf_token
      post "/admin/projects/#{project.id}/restore", _csrf_token: admin_csrf_token

      expect(repo.by_id(project.id)).to have_attributes(status: "active", featured: false)
    end
  end
end
