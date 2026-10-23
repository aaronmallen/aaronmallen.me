Feature: Links between records
  Any two records can link. A link goes when either record goes, a task keeps its project on itself rather than
  as a link, and the database refuses a link that breaks these rules, whoever writes it.

  Scenario Outline: Deleting a record of any kind removes its links and keeps the rest
    Given a bare <kind> row linked to a bare decision and a bare post
    And a bare task row linked to a bare decision and a bare post
    When the <kind> row 1 is deleted
    Then the record_links table holds <left> rows

    Examples:
      | kind          | left |
      | task          | 2    |
      | post          | 2    |
      | social_post   | 2    |
      | journal_entry | 2    |
      | commit        | 2    |
      | project       | 2    |
      | work_entry    | 2    |
      | decision      | 2    |
      | pull_request  | 2    |
      | mail_thread   | 2    |
      | memory_file   | 2    |
      | artifact      | 2    |
      | note          | 2    |
      | note_folder   | 2    |

  Scenario: A link made by hand is related, and sits beside the task sourced from the same decision
    Given a bare task row
    And a bare task row
    And a bare decision row
    And an API token
    And the record_links table holds:
      | left_kind | left_id | right_kind | right_id | relation     |
      | task      | 1       | decision   | 1        | sourced_from |
    When I POST "/links/task/2" through the API with:
      """
      {"other_kind": "decision", "other_id": 1}
      """
    Then the record_links table has a row with:
      | left_id | relation     |
      | 1       | sourced_from |
    And the record_links table has a row with:
      | left_id | relation |
      | 2       | related  |

  Scenario: The database refuses links that break the rules
    Given a bare task row
    And a bare task row
    And a bare post row
    And a bare decision row
    And a bare project row
    And the record_links table holds:
      | left_kind | left_id | right_kind | right_id | relation     |
      | task      | 1       | decision   | 1        | sourced_from |
    When I write a raw record_links row:
      | left_kind | left_id | right_kind | right_id | relation     |
      | task      | 2       | decision   | 1        | sourced_from |
    Then the database refuses it with "record_links_one_source_key"
    When I write a raw record_links row:
      | left_kind | left_id | right_kind | right_id | relation     |
      | task      | 1       | post       | 1        | sourced_from |
    Then the database refuses it with "record_links_sourced_from_check"
    When I write a raw record_links row:
      | left_kind | left_id | right_kind | right_id |
      | post      | 999999  | decision   | 1        |
    Then the database refuses it with "a record link names a record that does not exist"
    When I write a raw record_links row:
      | left_kind | left_id | right_kind | right_id |
      | task      | 1       | project    | 1        |
    Then the database refuses it with "record_links_task_project_check"

  Scenario: A task keeps its project on itself, lists it from either side and moves to the next project it links
    Given a bare task row
    And a bare project row
    And a bare project row
    And an API token
    When I POST "/links/project/1" through the API with:
      """
      {"other_kind": "task", "other_id": 1}
      """
    Then task 1 sits in project 1
    And the record_links table holds 0 rows
    When I GET "/links/task/1" through the API
    Then the API answer holds:
      """
      {"links": {"project": [{"id": 1}]}}
      """
    When I GET "/links/project/1" through the API
    Then the API answer holds:
      """
      {"links": {"task": [{"id": 1}]}}
      """
    When I POST "/links/task/1" through the API with:
      """
      {"other_kind": "project", "other_id": 999999}
      """
    Then the API answers 422
    And task 1 sits in project 1
    When I POST "/links/task/1" through the API with:
      """
      {"other_kind": "project", "other_id": 2}
      """
    Then task 1 sits in project 2

  Scenario: Unlinking clears the task's project, and refuses a project the task is not in
    Given a bare task row
    And a bare project row
    And a bare project row
    And an API token
    When I POST "/links/task/1" through the API with:
      """
      {"other_kind": "project", "other_id": 1}
      """
    And I DELETE "/links/project/2/task/1" through the API
    Then the API answers 404
    And task 1 sits in project 1
    When I DELETE "/links/project/1/task/1" through the API
    Then the API answers 200
    And task 1 sits in no project

  Scenario: Deleting the project clears it from the task
    Given a bare task row
    And a bare project row
    And an API token
    When I POST "/links/task/1" through the API with:
      """
      {"other_kind": "project", "other_id": 1}
      """
    And the project row 1 is deleted
    Then task 1 sits in no project

  Scenario Outline: Unlinking a kind no record has is refused
    Given a bare task row
    And an API token
    When I DELETE "<path>" through the API
    Then the API answers 422
    And the API answer holds "`<field>` is not one of"

    Examples:
      | path                          | field       |
      | /links/task/1/person/1 | /other_kind |
      | /links/person/1/task/1 | /kind       |
