Feature: The nightly database backup
  Each night the backup job uploads a pg_dump of the database to the backups
  bucket and keeps the 7 newest dumps.

  Scenario: The backup uploads a custom format pg_dump and keeps the 7 newest dumps
    Given the backup store holds the dumps:
      | database-20260901T053000Z.dump |
      | database-20260902T053000Z.dump |
      | database-20260903T053000Z.dump |
      | database-20260904T053000Z.dump |
      | database-20260905T053000Z.dump |
      | database-20260906T053000Z.dump |
      | database-20260907T053000Z.dump |
      | database-20260908T053000Z.dump |
      | database-20260909T053000Z.dump |
    When the job "Backups::Jobs::BackUpDatabase" runs
    Then the newest backup is a custom format pg_dump of the database
    And the backup store holds 7 dumps
    And the backup store keeps these older dumps:
      | database-20260904T053000Z.dump |
      | database-20260905T053000Z.dump |
      | database-20260906T053000Z.dump |
      | database-20260907T053000Z.dump |
      | database-20260908T053000Z.dump |
      | database-20260909T053000Z.dump |

  Scenario: The backup deletes nothing while the bucket holds 7 or fewer
    Given the backup store holds the dumps:
      | database-20260904T053000Z.dump |
      | database-20260905T053000Z.dump |
      | database-20260906T053000Z.dump |
      | database-20260907T053000Z.dump |
      | database-20260908T053000Z.dump |
      | database-20260909T053000Z.dump |
    When the job "Backups::Jobs::BackUpDatabase" runs
    Then the backup store holds 7 dumps

  Scenario: The backup clears a failure an earlier run left
    Given the sync "backups" failed with "upload_failed"
    When the job "Backups::Jobs::BackUpDatabase" runs
    Then no sync failure of "backups" is left

  Scenario: The backup signs its upload with the backup key
    When the job "Backups::Jobs::BackUpDatabase" runs
    Then the backup upload was signed with the backup access key

  Scenario: An upload that fails is left for Today and leaves the dumps alone
    Given the backup store holds the dumps:
      | database-20260901T053000Z.dump |
      | database-20260902T053000Z.dump |
      | database-20260903T053000Z.dump |
      | database-20260904T053000Z.dump |
      | database-20260905T053000Z.dump |
      | database-20260906T053000Z.dump |
      | database-20260907T053000Z.dump |
      | database-20260908T053000Z.dump |
    And the web answers PUT "/s3/backups/*" with status 500
    When the job "Backups::Jobs::BackUpDatabase" runs
    Then the sync failure of "backups" is "upload_failed"
    And the backup store got no DELETE requests
    And the backup store holds 8 dumps
    And the performance_jobs rows where "job = 'Backups::Jobs::BackUpDatabase'" are:
      | outcome |
      | failed  |

  Scenario: A prune that fails is left for Today
    Given the backup store holds the dumps:
      | database-20260901T053000Z.dump |
      | database-20260902T053000Z.dump |
      | database-20260903T053000Z.dump |
      | database-20260904T053000Z.dump |
      | database-20260905T053000Z.dump |
      | database-20260906T053000Z.dump |
      | database-20260907T053000Z.dump |
      | database-20260908T053000Z.dump |
    And the web answers DELETE "/s3/backups/*" with status 500
    When the job "Backups::Jobs::BackUpDatabase" runs
    Then the sync failure of "backups" is "prune_backups_failed"
    And the performance_jobs rows where "job = 'Backups::Jobs::BackUpDatabase'" are:
      | outcome |
      | failed  |
