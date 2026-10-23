Feature: Held health backfills
  When the queue is down as the owner connects Google Health, the backfill waits in the database until a job
  queues it.

  Scenario: Connecting Google Health while Redis is down holds one backfill from today, then queues it once Redis is back
    Given I am signed in to the admin
    And Google Health holds nothing
    When Redis goes down
    And I connect Google Health as "aaron@example.com" in the admin
    And I connect Google Health as "work@example.com" in the admin
    And Redis comes back
    Then the held health backfills start from the health day "0"
    When the held health backfills are queued
    Then the held health backfills start from the health days ""
    And Google Health was asked for the steps rollup ending on the health day "-1"

  Scenario: The held backfills job queues nothing when nothing is held
    Given Google Health is connected
    And Google Health holds nothing
    When the held health backfills are queued
    Then Google was asked nothing about health
