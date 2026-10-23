Feature: API review note
  POST /api/v1/review/note writes the note on a week or a month, and GET /api/v1/review gives it back with the rest
  of the review. The save_review_note and read_review MCP tools answer the same.

  Background:
    Given an API token

  Scenario: A period with no note gives a null note
    When I call the API with "GET /api/v1/review?day=2026-09-16"
    Then the call answers 200
    And the answer's "note" is:
      """
      null
      """

  Scenario: Saving a note answers 200 with the note, trimmed, and the week that holds the day
    When I call the review API with "POST /api/v1/review/note" and:
      """
      {"day": "2026-09-16", "body": "  good week  "}
      """
    Then the review API answers 200
    And the review API answer, less its stamps, is:
      """
      {"period": "week", "from": "2026-09-14", "to": "2026-09-20", "body": "good week"}
      """
    And the review API answer's "." carries the stored week note of "2026-09-14"
    And the database answers "week, 2026-09-14, good week" for:
      """
      select period, to_char(starts_on, 'YYYY-MM-DD'), body from review_notes
      """

  Scenario: The week's note comes back on any day of the week, and the month does not take it
    When I call the API with "POST /api/v1/review/note" and:
      """
      {"day": "2026-09-16", "body": "good week"}
      """
    And I call the review API with "GET /api/v1/review?day=2026-09-20"
    Then the review API answer's "note" carries the stored week note of "2026-09-14"
    When I call the API with "GET /api/v1/review?period=month&day=2026-09-16"
    Then the answer's "note" is:
      """
      null
      """

  Scenario: A month's note lands on the month
    When I call the API with "POST /api/v1/review/note" and:
      """
      {"period": "month", "day": "2026-09-16", "body": "good month"}
      """
    Then the call answers 200
    And the answer matches:
      """
      {"period": "month", "from": "2026-09-01", "to": "2026-09-30", "body": "good month"}
      """
    And the database answers "month, 2026-09-01, good month" for:
      """
      select period, to_char(starts_on, 'YYYY-MM-DD'), body from review_notes
      """

  Scenario: The API gives the note the admin saved
    Given I am signed in to the admin
    When I post the review note "good month" for the month ending "2026-09-30"
    And I call the API with "GET /api/v1/review?period=month&day=2026-09-02"
    Then the answer's "note.body" is "good month"

  Scenario: A second note for the period replaces the first
    When I call the API with "POST /api/v1/review/note" and:
      """
      {"day": "2026-09-14", "body": "good week"}
      """
    And I call the API with "POST /api/v1/review/note" and:
      """
      {"day": "2026-09-20", "body": "great week"}
      """
    Then the database answers "great week" for:
      """
      select body from review_notes
      """

  Scenario: A blank note answers 422 and keeps the old one
    When I call the review API with "POST /api/v1/review/note" and:
      """
      {"day": "2026-09-16", "body": "good week"}
      """
    And I call the review API with "POST /api/v1/review/note" and:
      """
      {"day": "2026-09-16", "body": " \n "}
      """
    Then the review API answers 422
    And the review API answer, less its stamps, is:
      """
      {"error": "invalid", "message": "body needs a character that is not a space",
        "errors": {"body": ["body needs a character that is not a space"]}}
      """
    And the database answers "good week" for:
      """
      select body from review_notes
      """

  Scenario: An empty note answers 422
    When I call the review API with "POST /api/v1/review/note" and:
      """
      {"day": "2026-09-16", "body": ""}
      """
    Then the review API answers 422
    And the review API answer, less its stamps, is:
      """
      {"error": "invalid", "message": "body needs a character that is not a space",
        "errors": {"body": ["body needs a character that is not a space"]}}
      """

  Scenario: A note with a control character is refused
    When I call the review API with "POST /api/v1/review/note" and:
      """
      {"day": "2026-09-16", "body": "good\u0007week"}
      """
    Then the review API answers 422
    And the review API answer, less its stamps, is:
      """
      {"error": "invalid", "message": "body holds a control character",
        "errors": {"body": ["body holds a control character"]}}
      """

  Scenario: A day it cannot read answers 422 and saves nothing
    When I call the review API with "POST /api/v1/review/note" and:
      """
      {"day": "2026-13-40", "body": "good week"}
      """
    Then the review API answers 422
    And the review API answer, less its stamps, is:
      """
      {"error": "invalid", "message": "give the day as a date, such as 2026-01-01",
        "errors": {"day": ["give the day as a date, such as 2026-01-01"]}}
      """
    And the database answers "0" for:
      """
      select count(*) from review_notes
      """

  Scenario: A period other than week or month is refused
    When I call the API with "POST /api/v1/review/note" and:
      """
      {"period": "year", "day": "2026-09-16", "body": "good"}
      """
    Then the call answers 422
    And the answer's "errors" is:
      """
      {"period": ["value at `/period` is not one of: [\"week\", \"month\"]"]}
      """

  Scenario: A request with no day or body is refused
    When I call the API with "POST /api/v1/review/note" and:
      """
      {}
      """
    Then the call answers 422
    And the answer's "errors" is:
      """
      {"day": ["day is missing"], "body": ["body is missing"]}
      """

  Scenario: A request with no token answers 401 and saves nothing
    When I call the API with "POST /api/v1/review/note" and no token
    Then the call answers 401
    And the database answers "0" for:
      """
      select count(*) from review_notes
      """

  Scenario: The MCP tools save and read the note as the endpoints do
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read write"
    Then the review MCP tool "save_review_note" answers as "POST /api/v1/review/note" does but for its stamps, given:
      """
      {"period": "month", "day": "2026-09-16", "body": "the same"}
      """
    When I call the MCP tool "save_review_note" with:
      """
      {"day": "2026-09-16", "body": "good week"}
      """
    And I call the MCP tool "read_review" with:
      """
      {"day": "2026-09-16"}
      """
    Then the answer's "note.body" is "good week"
    And the review MCP tool "save_review_note" refuses with the message "POST /api/v1/review/note" gives, given:
      """
      {"day": "2026-09-16", "body": " "}
      """
