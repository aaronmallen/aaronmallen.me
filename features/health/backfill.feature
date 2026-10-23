Feature: Health backfill from Google Health
  A job reads Google Health 90 days at a time, walking back until Google holds nothing older.

  Scenario: The backfill stores the 90 days up to the day it starts from and stops once Google has no more
    Given Google Health is connected
    And Google Health holds:
      | type  | day | value |
      | steps | 89  | 5000  |
    When the health backfill runs from 0 days ago
    Then the health days stored are:
      | day | steps |
      | 89  | 5000  |
    And Google Health was asked for daily-resting-heart-rate with the filter:
      """
      daily_resting_heart_rate.date < "{179 ago}"
      """

  Scenario: The backfill asks Google for the 90 days before once those held data
    Given Google Health is connected
    And Google Health holds:
      | type  | day | value |
      | steps | 0   | 5000  |
    When the health backfill runs from 0 days ago
    Then Google Health was asked for the steps rollup ending on the health day "89"

  Scenario: The backfill stops once Google has no more data
    Given Google Health is connected
    And Google Health holds nothing
    When the health backfill runs from 0 days ago
    Then Google Health was asked for daily-resting-heart-rate with the filter:
      """
      daily_resting_heart_rate.date < "{89 ago}"
      """
    And Google Health was not asked for the steps rollup ending on the health day "89"

  Scenario: The backfill walks past 90 days with no data while Google holds older ones and imports them
    Given Google Health is connected
    And Google Health holds:
      | type    | day | value |
      | resting | 120 | 55    |
    When the health backfill runs from 0 days ago
    Then Google Health was asked for the steps rollup ending on the health day "89"
    And the health days stored are:
      | day | resting |
      | 120 | 55      |

  Scenario: The backfill fails the job when Google fails, so Sidekiq can try the chunk again
    Given Google Health is connected
    And Google Health holds nothing
    And Google Health answers 503 for sleep
    When the health backfill runs from 0 days ago
    Then a health job failed with "Google answered 503"

  Scenario: The backfill fails the job when Google fails while it looks for older data
    Given Google Health is connected
    And Google Health holds nothing
    And Google Health answers 503 for sleep when asked for one point
    When the health backfill runs from 0 days ago
    Then a health job failed with "Google answered 503"

  Scenario: The backfill stops while Google Health is not connected
    When the health backfill runs from 0 days ago
    Then Google was asked nothing about health
