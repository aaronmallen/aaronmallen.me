Feature: Settings checks
  The app refuses to start on a setting out of bounds, and names the setting. Each scenario starts the app
  through mise run db:console. A value such as "64 × d" means 64 d characters, "$APP_SECRET" means the value
  APP_SECRET holds, "committed for test" means the value config/settings/test.yml holds, and "unset" leaves
  the variable out.

  Scenario Outline: The app refuses to start on a bad setting
    Given the app runs in <environment> with secrets of its own
    And the setting <name> is "<value>"
    When I start the app
    Then it fails
    And the output includes "<complaint>"

    Examples:
      | environment | name                           | value                  | complaint                                      |
      | production  | APP_SECRET                     | committed for development | app_secret: must not use a value committed   |
      | production  | APP_SECRET                     | committed for test     | app_secret: must not use a value committed     |
      | production  | ANALYTICS_SALT                 | committed for development | analytics_salt: must not use a value committed |
      | production  | ANALYTICS_SALT                 | committed for test     | analytics_salt: must not use a value committed |
      | production  | DATA_KEY                       | committed for development | data_key: must not use a value committed     |
      | production  | DATA_KEY                       | committed for test     | data_key: must not use a value committed       |
      | production  | READER_SALT                    | committed for development | reader_salt: must not use a value committed  |
      | production  | READER_SALT                    | committed for test     | reader_salt: must not use a value committed    |
      | production  | DATA_KEY                       | 63 × d                 | data_key                                       |
      | production  | DATA_KEY                       | $APP_SECRET            | must not repeat                                |
      | production  | DATA_KEY                       | unset                  | data_key                                       |
      | production  | READER_SALT                    | 63 × r                 | reader_salt                                    |
      | production  | READER_SALT                    | $ANALYTICS_SALT        | reader_salt: must not repeat analytics_salt    |
      | production  | READER_SALT                    | $APP_SECRET            | reader_salt: must not repeat app_secret        |
      | production  | ANALYTICS_SALT                 | $APP_SECRET            | analytics_salt: must not repeat app_secret     |
      | production  | PREVIOUS_DATA_KEY              | 63 × p                 | previous_data_key                              |
      | production  | PREVIOUS_DATA_KEY              | $DATA_KEY              | must not repeat previous_data_key              |
      | test        | HANAMI_MAX_THREADS             | 0                      | web_threads                                    |
      | production  | SHARE_TRANSFERS                | 0                      | share_site                                     |
      | test        | CONTACT_MINIMUM_SUBMIT_SECONDS | -1                     | contact                                        |
      | test        | CONTACT_STAMP_EXPIRY_HOURS     | 0                      | contact                                        |
      | test        | REDIS_TIMEOUT                  | 0                      | redis                                          |
      | test        | REDIS_RECONNECT_ATTEMPTS       | -1                     | redis                                          |
      | test        | REDIS_RECONNECT_ATTEMPTS       | 0.5, x                 | redis                                          |

  Scenario Outline: The app starts on a good setting
    Given the app runs in <environment> with secrets of its own
    And the setting <name> is "<value>"
    When I start the app
    Then it succeeds

    Examples:
      | environment | name                           | value                     |
      | production  | APP_SECRET                     | 64 × a                    |
      | production  | DATA_KEY                       | 64 × d                    |
      | production  | READER_SALT                    | 64 × r                    |
      | production  | PREVIOUS_DATA_KEY              | 64 × p                    |
      | production  | PREVIOUS_DATA_KEY              |                           |
      | development | APP_SECRET                     | committed for development |
      | test        | APP_SECRET                     | committed for development |
      | test        | CONTACT_MINIMUM_SUBMIT_SECONDS | 0                         |
      | test        | REDIS_RECONNECT_ATTEMPTS       | 0                         |
      | test        | REDIS_RECONNECT_ATTEMPTS       | 0.5, 1                    |
      | production  | SHARE_TRANSFERS                |                           |
