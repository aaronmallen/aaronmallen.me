Feature: Worker boot and shutdown
  At boot the worker queues a country database download when it has MaxMind credentials and no database
  file at the path the settings name, and it stops cleanly when told to.

  Scenario Outline: The worker queues the country database at boot only when it has credentials and no file
    Given MaxMind credentials are <credentials>
    And the country database file is <file>
    When a worker boots
    Then the worker has queued <queued> country database downloads

    Examples:
      | credentials | file    | queued |
      | set         | missing | 1      |
      | set         | present | 0      |
      | unset       | missing | 0      |

  Scenario: The worker stops cleanly when told to
    Given MaxMind credentials are unset
    When a worker boots
    And the worker is told to stop
    Then it succeeds
