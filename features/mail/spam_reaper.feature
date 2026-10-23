Feature: The spam reaper
  The reaper deletes mail threads marked as spam more than 30 days ago. It counts from the first
  mark, and keeps every thread that is not spam whatever its age.

  Scenario: The reaper deletes only spam marked more than 30 days ago
    Given the mail threads:
      | subject     | minutes ago |
      | Cheap pills | 0           |
      | New spam    | 0           |
      | Old arrival | 129600      |
      | Hello       | 576000      |
      | Thanks      | 576000      |
    And the mail thread "Cheap pills" was marked spam 43201 minutes ago
    And the mail thread "New spam" was marked spam 43199 minutes ago
    And the mail thread "Old arrival" was marked spam 0 minutes ago
    And an API token with the scopes "read write mail"
    When I call the mail API with POST "/mail/threads/#[Thanks]/mark" and:
      """
      {"status": "read"}
      """
    And the spam reaper runs
    Then the mail threads kept are "New spam, Old arrival, Hello, Thanks"

  Scenario: The reaper keeps the first mark when a spam thread is marked spam again
    Given the mail threads:
      | subject     |
      | Cheap pills |
    And the mail thread "Cheap pills" was marked spam 43199 minutes ago
    And an API token with the scopes "read write mail"
    When I call the mail API with POST "/mail/threads/#[Cheap pills]/mark" and:
      """
      {"status": "spam"}
      """
    And the spam marks age by 2 minutes
    And the spam reaper runs
    Then the mail threads kept are ""

  Scenario: The reaper keeps a thread moved back out of spam
    Given the mail threads:
      | subject            |
      | Not spam after all |
    And the mail thread "Not spam after all" was marked spam 43201 minutes ago
    And an API token with the scopes "read write mail"
    When I call the mail API with POST "/mail/threads/#[Not spam after all]/mark" and:
      """
      {"status": "read"}
      """
    And the spam reaper runs
    Then the mail threads kept are "Not spam after all"
