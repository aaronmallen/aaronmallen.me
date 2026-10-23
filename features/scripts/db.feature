Feature: Database console and explain
  mise run db:console runs SQL on the database the settings name, and db:explain prints a statement's plan
  in a transaction it rolls back.

  Scenario: db:console runs a query on the database the settings name
    When I run "scripts/db/console 'select current_database()'"
    Then it succeeds
    And the output names this worker's database

  Scenario: db:console runs a file of SQL
    Given the file "query.sql":
      """
      select 'from a file' as source;
      """
    When I run "scripts/db/console $SCRATCH/query.sql"
    Then it succeeds
    And the output includes "from a file"

  Scenario: db:console fails when the query fails
    When I run "scripts/db/console 'select no_such_column'"
    Then it fails
    And the output includes "no_such_column"

  Scenario: db:explain prints the plan with timings and buffers
    When I run "scripts/db/explain 'select count(*) from tags;'"
    Then it succeeds
    And the output includes "Execution Time"
    And the output includes "Buffers"

  Scenario: db:explain explains a statement from a file
    Given the file "query.sql":
      """
      select 1
      """
    When I run "scripts/db/explain $SCRATCH/query.sql"
    Then it succeeds
    And the output includes "Execution Time"

  Scenario: db:explain drops trailing semicolons and whitespace from a file
    When I run "printf 'select 1 ;  \n;\n\n' > $SCRATCH/query.sql && scripts/db/explain $SCRATCH/query.sql"
    Then it succeeds
    And the output includes "Execution Time"

  Scenario: db:explain rolls back a statement that writes
    When I run "scripts/db/explain \"insert into tags (name, color, scope) values ('explain-probe', 'mk-pink', 'public')\""
    Then it succeeds
    And the database answers "0" for:
      """
      SELECT count(*) FROM tags WHERE name = 'explain-probe'
      """
