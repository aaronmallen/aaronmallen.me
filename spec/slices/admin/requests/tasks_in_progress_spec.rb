# frozen_string_literal: true

RSpec.describe "Admin tasks in progress", type: :request do
  def ask(params = {}) = get("/admin/tasks/in-progress", params, { "HTTP_ACCEPT" => "application/json" })

  def rows = JSON.parse(last_response.body).fetch("rows")

  describe "signed in" do
    before { sign_in_to_admin }

    describe "with tasks in progress" do
      let!(:first) { create(:task, :in_progress, :in_sprint, title: "Ship the palette", position: 1) }
      let!(:second) { create(:task, :in_progress, :in_sprint, title: "Write the record", position: 2) }

      before do
        create(:task, title: "Not started")
        create(:task, :done, title: "Done already")
        ask
      end

      it "answers with JSON", :aggregate_failures do
        expect(last_response.status).to eq(200)
        expect(last_response.media_type).to eq("application/json")
      end

      it "lists each one by title, in list order, with the complete it posts to" do
        expect(rows).to eq(
          [[first, "Ship the palette"], [second, "Write the record"]].map do |task, title|
            { "id" => task.id, "title" => title, "href" => "/admin/tasks/#{task.id}/complete" }
          end,
        )
      end

      it "points each one at the pause it posts to when asked to pause" do
        ask(act: "pause")

        expect(rows.map { it["href"] }).to eq([first, second].map { "/admin/tasks/#{it.id}/stop" })
      end

      it "falls back to complete for an act it does not know" do
        ask(act: "delete")

        expect(rows.map { it["href"] }).to eq([first, second].map { "/admin/tasks/#{it.id}/complete" })
      end

      it "keeps the answer out of every cache" do
        expect(last_response.headers["Cache-Control"]).to include("no-store")
      end
    end

    describe "with none in progress" do
      before do
        create(:task)
        ask
      end

      it "lists none" do
        expect(rows).to be_empty
      end
    end
  end

  describe "signed out" do
    before { ask }

    it "answers 401 rather than sending me to sign in", :aggregate_failures do
      expect(last_response.status).to eq(401)
      expect(last_response.location).to be_nil
    end
  end
end
