# frozen_string_literal: true

require "open3"
require "tempfile"

RSpec.describe "mise run db:console and db:explain", type: :script do
  def script(name, *) = Open3.capture2e(Hanami.app.root.join("scripts/db", name).to_s, *, chdir: Hanami.app.root)

  def sql_file(sql)
    Tempfile.create(["query", ".sql"]) do |file|
      file.write(sql)
      file.flush
      yield file.path
    end
  end

  describe "db:console" do
    it "runs a query on the database the settings name", :aggregate_failures do
      output, status = script("console", "select current_database()")

      expect(status).to be_success
      expect(output).to include(Hanami.app["settings"].database[:name])
    end

    it "runs a file of SQL", :aggregate_failures do
      output, status = sql_file("select 'from a file' as source;") { script("console", it) }

      expect(status).to be_success
      expect(output).to include("from a file")
    end

    it "fails when the query fails", :aggregate_failures do
      output, status = script("console", "select no_such_column")

      expect(status).not_to be_success
      expect(output).to include("no_such_column")
    end
  end

  describe "db:explain" do
    it "prints the plan with timings and buffers", :aggregate_failures do
      output, status = script("explain", "select count(*) from tags;")

      expect(status).to be_success
      expect(output).to include("Execution Time", "Buffers")
    end

    it "explains a statement from a file", :aggregate_failures do
      output, status = sql_file("select 1") { script("explain", it) }

      expect(status).to be_success
      expect(output).to include("Execution Time")
    end

    it "drops trailing semicolons and whitespace from a file", :aggregate_failures do
      output, status = sql_file("select 1 ;  \n;\n\n") { script("explain", it) }

      expect(status).to be_success
      expect(output).to include("Execution Time")
    end

    it "rolls back a statement that writes", :aggregate_failures do
      insert = "insert into tags (name, color, scope) values ('explain-probe', 'mk-pink', 'public')"
      _, status = script("explain", insert)
      output, = script("console", "select count(*) from tags where name = 'explain-probe'")

      expect(status).to be_success
      expect(output).to match(/^\s+0$/)
    end
  end
end
