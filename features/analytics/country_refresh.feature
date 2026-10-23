Feature: Refreshing the country database
  Each week the site downloads the GeoLite2 database from MaxMind with its
  account and key, and keeps the copy it had when the download goes wrong.

  Scenario: The refresh writes the database inside the archive MaxMind sends
    Given the country database folder is empty
    And MaxMind answers the download with "the test networks"
    And these analytics posts:
      | slug  | published |
      | hello | today-30  |
    When the job "Analytics::Jobs::RefreshCountryDatabase" runs
    Then the country database file is the test networks
    And MaxMind got 1 download request with the account and key
    When "Chrome" from "1.2.3.4" sends the beacon:
      """
      {"kind": "view", "path": "/writing/hello"}
      """
    Then the analytics_events rows are:
      | country_code |
      | US           |

  Scenario: The refresh replaces a database the lookup already had open
    Given the country database holds "1.2.3.0/24" as "CA"
    And MaxMind answers the download with "the test networks"
    And these analytics posts:
      | slug  | published |
      | hello | today-30  |
    When "Chrome" from "1.2.3.4" sends the beacon:
      """
      {"kind": "view", "path": "/writing/hello"}
      """
    And the job "Analytics::Jobs::RefreshCountryDatabase" runs
    And "Chrome" from "1.2.3.5" sends the beacon:
      """
      {"kind": "view", "path": "/writing/hello"}
      """
    Then the analytics_events rows are:
      | country_code |
      | CA           |
      | US           |

  Scenario: The refresh follows MaxMind's redirect and keeps the credentials off its host
    Given the country database folder is empty
    And MaxMind sends the download on to a mirror on another host that answers with the test networks archive
    When the job "Analytics::Jobs::RefreshCountryDatabase" runs
    Then the country database file is the test networks
    And the mirror got the download with no credentials

  Scenario: A refresh that gets through clears the failure an earlier one left
    Given the country database folder is empty
    And the sync "country_database" failed with "download_failed"
    And MaxMind answers the download with "the test networks"
    When the job "Analytics::Jobs::RefreshCountryDatabase" runs
    Then no sync failure of "country_database" is left

  Scenario: A download MaxMind refuses fails the run, leaves the reason and keeps the copy
    Given the country database holds the test networks
    And MaxMind answers the download with status 401
    When the job "Analytics::Jobs::RefreshCountryDatabase" runs
    Then the sync failure of "country_database" is "download_failed" with a message holding "MaxMind answered 401 for GeoLite2-City"
    And the performance_jobs table holds 1 rows where "outcome = 'failed' AND error_message = 'download_failed: MaxMind answered 401 for GeoLite2-City'"
    And the country database file is the test networks

  Scenario: A download that fails asks MaxMind once
    Given the country database folder is empty
    And MaxMind answers the download with status 503
    When the job "Analytics::Jobs::RefreshCountryDatabase" runs
    Then MaxMind got 1 download request with the account and key
    And the sync failure of "country_database" is "download_failed"

  Scenario: A download that never arrives says the download failed
    Given the country database folder is empty
    And MaxMind sends the download on to "http://127.0.0.1:1/GeoLite2-City.tar.gz"
    When the job "Analytics::Jobs::RefreshCountryDatabase" runs
    Then the sync failure of "country_database" is "download_failed" with a message holding "GeoLite2-City download failed"

  Scenario Outline: An archive that will not unpack fails the run
    Given the country database folder is empty
    And MaxMind answers the download with "<archive>"
    When the job "Analytics::Jobs::RefreshCountryDatabase" runs
    Then the sync failure of "country_database" is "download_failed" with a message holding "<message>"

    Examples:
      | archive                           | message              |
      | an archive cut short              | archive is unreadable |
      | something not an archive          | archive is unreadable |
      | an archive that holds no database | holds no database    |

  Scenario: A download that is no database fails the run and leaves no half-written file
    Given the country database folder is empty
    And MaxMind answers the download with "an archive of something not a database"
    When the job "Analytics::Jobs::RefreshCountryDatabase" runs
    Then the sync failure of "country_database" is "invalid_database" with a message holding "not a MaxMind database"
    And the country database folder holds nothing

  Scenario: A download that is no database keeps the copy it had
    Given the country database holds the test networks
    And MaxMind answers the download with "an archive of something not a database"
    When the job "Analytics::Jobs::RefreshCountryDatabase" runs
    Then the country database file is the test networks

  Scenario: A database folder that cannot be written fails the run and keeps the copy
    Given the country database holds the test networks
    And MaxMind answers the download with "1.2.3.0/24" as "CA"
    And the country database folder cannot be written
    When the job "Analytics::Jobs::RefreshCountryDatabase" runs
    Then the sync failure of "country_database" is "write_failed" with a message holding "Permission denied"
    And the country database file is the test networks
