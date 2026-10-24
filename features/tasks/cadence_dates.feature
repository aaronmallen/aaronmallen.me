Feature: When a series makes its next copy
  Closing a copy whose sprint day is still ahead plans the next copy for the cadence's next day after it.

  Background:
    Given an API token

  Scenario Outline: A <cadence> cadence after <on> plans the next copy on <next>
    Given the tasks:
      | title            | sprint |
      | Water the plants | <on>   |
    And the task "Water the plants" repeats on the cadence:
      | cadence   | every   | weekday   | week   | day   | month   | starts_on |
      | <cadence> | <every> | <weekday> | <week> | <day> | <month> | <starts>  |
    When I POST "/tasks/1/complete" through the API with:
      """
      {}
      """
    Then the next copy of "Water the plants" sits in the sprint on "<next>"

    Examples:
      | cadence       | every | weekday | week | day | month | starts     | on         | next       |
      | days          | 3     |         |      |     |       |            | 2027-10-14 | 2027-10-17 |
      | days          | 3     |         |      |     |       |            | 2027-10-30 | 2027-11-02 |
      | weeks         | 2     | 4       |      |     |       | 2027-10-07 | 2027-09-26 | 2027-10-07 |
      | weeks         | 2     | 4       |      |     |       | 2027-10-11 | 2027-09-26 | 2027-10-14 |
      | weeks         | 2     | 4       |      |     |       | 2027-10-07 | 2027-10-07 | 2027-10-21 |
      | weeks         | 2     | 4       |      |     |       | 2027-10-07 | 2027-11-04 | 2027-11-18 |
      | weeks         | 2     | 4       |      |     |       | 2027-10-07 | 2028-03-09 | 2028-03-23 |
      | weeks         | 1     | 4       |      |     |       | 2027-10-07 | 2027-10-21 | 2027-10-28 |
      | month_day     |       |         |      | 15  |       |            | 2027-10-14 | 2027-10-15 |
      | month_day     |       |         |      | 1   |       |            | 2027-10-14 | 2027-11-01 |
      | month_day     |       |         |      | 31  |       |            | 2027-10-31 | 2027-11-30 |
      | month_day     |       |         |      | 31  |       |            | 2027-01-31 | 2027-02-28 |
      | month_day     |       |         |      | 31  |       |            | 2028-01-31 | 2028-02-29 |
      | month_day     |       |         |      | 31  |       |            | 2027-02-28 | 2027-03-31 |
      | month_end     |       |         |      |     |       |            | 2027-10-14 | 2027-10-31 |
      | month_end     |       |         |      |     |       |            | 2027-10-31 | 2027-11-30 |
      | month_end     |       |         |      |     |       |            | 2027-01-31 | 2027-02-28 |
      | month_weekday |       | 3       | 3    |     |       |            | 2027-10-01 | 2027-10-20 |
      | month_weekday |       | 1       | 1    |     |       |            | 2027-10-14 | 2027-11-01 |
      | month_weekday |       | 5       | -1   |     |       |            | 2027-10-14 | 2027-10-29 |
      | month_weekday |       | 5       | -1   |     |       |            | 2027-10-29 | 2027-11-26 |
      | yearly        |       |         |      | 25  | 12    |            | 2027-10-14 | 2027-12-25 |
      | yearly        |       |         |      | 15  | 3     |            | 2027-10-14 | 2028-03-15 |
      | yearly        |       |         |      | 25  | 12    |            | 2027-12-25 | 2028-12-25 |
      | yearly        |       |         |      | 29  | 2     |            | 2028-10-14 | 2029-02-28 |
      | yearly        |       |         |      | 29  | 2     |            | 2027-03-01 | 2028-02-29 |
