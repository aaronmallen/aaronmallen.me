Feature: Restoring a backup to check it
  The restore script loads a dump into a scratch database, counts the rows in
  its key tables, then drops the scratch database.

  Scenario: The restore loads a dump file and counts the rows in each key table
    Given these backup key table rows: a post and a task
    And the job "Backups::Jobs::BackUpDatabase" runs
    When I restore the newest backup from a file
    Then the restore succeeds and counts:
      | posts: 1                |
      | tasks: 1                |
      | schema_migrations: [1-9]\d* |
    And no scratch restore database is left

  Scenario: The restore fetches a dump by name from the backups bucket
    Given these backup key table rows: a post and a task
    And the job "Backups::Jobs::BackUpDatabase" runs
    When I restore the newest backup by name
    Then the restore succeeds and counts:
      | posts: 1 |

  Scenario: The restore fails and drops the scratch database when a key table comes back empty
    Given only a post in the backup key tables
    And the job "Backups::Jobs::BackUpDatabase" runs
    When I restore the newest backup from a file
    Then the restore fails saying "restore_failed: tasks came back empty"
    And no scratch restore database is left

  Scenario: The restore fails on a file that is not a dump
    When I restore a file that is not a dump
    Then the restore fails saying one of "not a valid archive | input file"

  Scenario: The restore fails when the bucket holds no dump by that name
    When I restore the dump "database-missing.dump" by name
    Then the restore fails saying "not_found: database-missing.dump"

  Scenario: The restore fails when neither a file nor a backups bucket holds the dump
    When I restore the dump "database-missing.dump" with no backups bucket
    Then the restore fails saying "not_found: database-missing.dump"
