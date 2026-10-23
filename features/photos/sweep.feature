Feature: Photo sweep
  A daily job deletes each photo nothing claimed for a day, from the table and the store.

  Scenario: The sweep deletes a photo unclaimed for a day with its smaller widths and keeps the rest
    Given the photo "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg" uploaded 25 hours ago
    And the photo "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg" also kept at the widths "640 1280"
    And the photo "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg" uploaded 23 hours ago
    And the photo "cccccccccccccccccccccccccccccccc.jpg" uploaded 72 hours ago
    And a post claims the photo "cccccccccccccccccccccccccccccccc.jpg"
    When the photo sweep runs
    Then the photos left are "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg cccccccccccccccccccccccccccccccc.jpg"
    And the photo store holds "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg cccccccccccccccccccccccccccccccc.jpg"

  Scenario: The sweep keeps a photo whose store delete fails, for the next run
    Given the photo "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg" uploaded 25 hours ago
    And the photo store turns away the delete of "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg"
    When the photo sweep runs
    Then the photos left are "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg"
    When the photo sweep runs
    Then the photos left are "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg"
