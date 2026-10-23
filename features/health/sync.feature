Feature: Health sync from Google Health
  A job reads the last few days of sleep, heart rate, steps and workouts from Google Health and stores them by day.

  Scenario: The sync stores a day Google holds and its workout, and changes nothing when it runs again
    Given Google Health is connected
    And Google Health holds:
      | type    | day | from  | until | value | name  |
      | sleep   | 0   | 23:00 | 07:00 | 420   |       |
      | resting | 0   |       |       | 54    |       |
      | hrv     | 0   |       |       | 48.5  |       |
      | steps   | 0   |       |       | 8421  |       |
      | zones   | 0   |       |       | 22    |       |
      | workout | 0   | 06:00 |       |       | run-1 |
    When the health sync runs
    Then the health days stored are:
      | day | asleep | bed   | woke  | resting | hrv  | steps | zone |
      | 0   | 420    | 23:00 | 07:00 | 54      | 48.5 | 8421  | 22   |
    And the workout "run-1" is stored as a 30 minute run at "06:00" on the health day "0"
    And no health sync failure is recorded
    And the health sync sends the admin no notice when it runs again
    And the health days stored are:
      | day | asleep | bed   | woke  | resting | hrv  | steps | zone |
      | 0   | 420    | 23:00 | 07:00 | 54      | 48.5 | 8421  | 22   |
    And the workouts stored are "run-1"

  Scenario: The sync updates a day Google changed and deletes a workout Google no longer returns
    Given Google Health is connected
    And Google Health holds:
      | type    | day | from  | until | value | name  |
      | sleep   | 0   | 23:00 | 07:00 | 420   |       |
      | workout | 0   | 06:00 |       |       | run-1 |
    And the health sync runs
    And Google Health holds:
      | type  | day | value |
      | steps | 0   | 9000  |
    When the health sync runs
    Then the health days stored are:
      | day | steps |
      | 0   | 9000  |
    And the workouts stored are ""

  Scenario: The sync keeps the workouts Google still returns and deletes the rest of the window
    Given Google Health is connected
    And the workouts:
      | day | at    | kind    | name  |
      | 2   | 00:00 | WALKING | stale |
    And Google Health holds:
      | type    | day | from  | name  |
      | workout | 0   | 06:00 | run-1 |
    When the health sync runs
    Then the workouts stored are "run-1"

  Scenario: The sync keeps workouts that started before the window
    Given Google Health is connected
    And the workouts:
      | day | at    | kind    | name  |
      | 3   | 23:59 | WALKING | older |
    And Google Health holds nothing
    When the health sync runs
    Then the workouts stored are "older"

  Scenario: A workout from the day before the window that started on its first day in Chicago survives the sync
    Given Google Health is connected
    And Google Health holds:
      | type    | day | from        | name   |
      | workout | 3   | 21:00-10:00 | hawaii |
    And the health sync runs
    When the health sync runs
    Then the workouts stored are "hawaii"

  Scenario: The sync puts the night's sleep on the day I woke
    Given Google Health is connected
    And Google Health holds:
      | type  | day | from  | until | value |
      | sleep | 0   | 22:00 | 06:00 | 450   |
    When the health sync runs
    Then the health days stored are:
      | day | asleep | bed   | woke  |
      | 0   | 450    | 22:00 | 06:00 |

  Scenario: The sync keeps the longest sleep for bed and wake and adds every nap to the minutes asleep
    Given Google Health is connected
    And Google Health holds:
      | type  | day | from  | until | value |
      | sleep | 0   | 14:00 | 15:00 | 40    |
      | sleep | 0   | 23:00 | 07:00 | 400   |
    When the health sync runs
    Then the health days stored are:
      | day | asleep | bed   | woke  |
      | 0   | 440    | 23:00 | 07:00 |

  Scenario: The sync reads every page of workouts Google sends
    Given Google Health is connected
    And Google Health holds:
      | type    | day | from  | name  | page |
      | workout | 0   | 06:00 | run-1 | 1    |
      | workout | 1   | 06:00 | run-2 | 2    |
    When the health sync runs
    Then the workouts stored are "run-1 run-2"

  Scenario: The sync asks Google for the last three days and a day either side, on the field names Google takes
    Given Google Health is connected
    And Google Health holds nothing
    When the health sync runs
    Then Google Health was asked for exercise with the filter:
      """
      exercise.interval.civil_start_time >= "{3 ago}" AND exercise.interval.civil_start_time < "{2 ahead}"
      """
    And Google Health was asked for daily-resting-heart-rate with the filter:
      """
      daily_resting_heart_rate.date >= "{2 ago}" AND daily_resting_heart_rate.date < "{1 ahead}"
      """
    And Google Health was asked for daily-heart-rate-variability with the filter:
      """
      daily_heart_rate_variability.date >= "{2 ago}" AND daily_heart_rate_variability.date < "{1 ahead}"
      """

  Scenario: The sync stores no row for a day Google holds nothing for
    Given Google Health is connected
    And Google Health holds:
      | type  | day | value |
      | steps | 1   |       |
    When the health sync runs
    Then no health day is stored

  Scenario: The sync records a failed run where the admin reads it
    Given Google Health is connected
    And Google Health holds nothing
    And Google Health answers 503 for sleep
    When the health sync runs
    Then the health sync failure reads "google_health_failed" with "Google answered 503" counted 1

  Scenario Outline: After runs that <failed>, the sync clears the failure and catches up from the day it began
    Given Google Health is connected
    And Google Health holds nothing
    And the health sync failed with "<reason>" since 10 days ago
    When the health sync runs
    Then no health sync failure is recorded
    And Google Health was asked for exercise with the filter:
      """
      exercise.interval.civil_start_time >= "{13 ago}" AND exercise.interval.civil_start_time < "{2 ahead}"
      """

    Examples:
      | failed  | reason               |
      | failed  | google_health_failed |
      | crashed | crashed              |

  Scenario: A run that crashes records the crash and still fails the job
    Given Google Health is connected
    And Google Health holds:
      | type         | day |
      | broken sleep | 0   |
    When the health sync runs
    Then the health sync failure reads "crashed"
    And a health job failed with "Health::Jobs::SyncHealth"

  Scenario: An account that also granted mail and calendar reads Health with one token narrowed to the Health scopes
    Given Google is connected as "aaron@example.com" with the scopes "mail calendar health"
    And Google Health holds nothing
    When the health sync runs
    Then Google was asked for 1 narrowed health token
    And Google Health never saw the token "ya29.token"
    And the stored Google token for "aaron@example.com" is still "ya29.token"
    When the health sync runs
    Then Google was asked for 1 narrowed health token

  Scenario: The sync narrows again once when Google turns the narrowed token away
    Given Google is connected as "aaron@example.com" with the scopes "mail calendar health"
    And Google Health holds nothing
    And Google Health turns the first sleep read away with 401
    When the health sync runs
    Then Google was asked for 2 narrowed health tokens
    And no health sync failure is recorded

  Scenario: The sync asks Google nothing and records nothing for an account that needs a reconnect
    Given Google Health is connected but needs a reconnect
    When the health sync runs
    Then Google was asked nothing about health
    And no health sync failure is recorded

  Scenario: The sync reads from the account that granted Health and leaves the others alone
    Given Google is connected as "work@example.com" with the scopes "openid" and the token "ya29.work"
    And Google Health is connected
    And Google Health holds nothing
    When the health sync runs
    Then Google Health never saw the token "ya29.work"

  Scenario: The sync asks Google nothing while no account granted Health
    Given Google is connected as "aaron@example.com" with the scopes "openid"
    When the health sync runs
    Then Google was asked nothing about health

  Scenario: The sync asks Google nothing and records nothing while Google Health is not connected
    When the health sync runs
    Then Google was asked nothing about health
    And no health sync failure is recorded

  Scenario: The sync steps aside while another run holds the lock and reports nothing about it
    Given Google Health is connected
    And the health sync failed with "rate_limited" since 1 days ago
    When another health sync holds the lock while the health sync runs
    Then Google was asked nothing about health
    And the health sync failure reads "rate_limited"
