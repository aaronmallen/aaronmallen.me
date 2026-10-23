Feature: API guarded rows
  Workouts, mail and notes stay out of every answer to a token that lacks the health, mail and notes scopes.

  Background:
    Given the table workouts holds:
      | google_id | kind | started_at  | minutes | device       |
      | w-1       | run  | 1 day ago   | 30      | zephyr watch |
    And the table mail_accounts holds:
      | provider | name  |
      | gmail    | Inbox |
    And the table mail_threads holds:
      | mail_account_id | subject       | received_at | status |
      | 1               | zephyr letter | 1 day ago   | unread |
      | 1               | zephyr reply  | 1 day ago   | read   |
    And the table mail_messages holds:
      | mail_thread_id | subject       | body        | received_at |
      | 1              | zephyr letter | zephyr body | 1 day ago   |
    And the table notes holds:
      | title           | body        |
      | zephyr sketches | zephyr body |
    And the table note_folders holds:
      | name          |
      | zephyr folder |
    And the table saved_views holds:
      | name     | screen   |
      | Activity | activity |

  @timeout:300_000
  Scenario: No operation shows a workout, mail or note row to a token with only read
    Then no operation the API document names shows a workout, mail or note row to a token with only read

  Scenario: A token with health, mail and notes sees those rows
    Then a token with read, health, mail and notes sees the workout, mail and note rows
