Feature: Reaping expired OAuth credentials
  A job deletes spent codes and tokens, and clients that never connected or went idle with nothing live.

  Rule: Codes and tokens go once they expire

    Background:
      Given the MCP clients:
        | name   | tokens |
        | Claude | none   |

    Scenario Outline: The job <does> <row>
      Given the database runs "<insert>"
      When the job "MCP::Jobs::ReapExpiredCredentials" runs
      And the job "MCP::Jobs::ReapExpiredCredentials" has run
      Then the database answers "<left>" for:
        """
        SELECT (SELECT count(*) FROM oauth_codes) + (SELECT count(*) FROM oauth_tokens)
        """

      Examples:
        | does    | row                                           | left | insert                                                                                                                                                                                    |
        | deletes | a code past its expiry                        | 0    | INSERT INTO oauth_codes (oauth_client_id, code_digest, redirect_uri, code_challenge, expires_at) VALUES (1, 'a', 'https://claude.ai/cb', repeat('a', 43), now() - interval '1 second')                    |
        | deletes | a used code once it has expired               | 0    | INSERT INTO oauth_codes (oauth_client_id, code_digest, redirect_uri, code_challenge, expires_at, used_at) VALUES (1, 'a', 'https://claude.ai/cb', repeat('a', 43), now() - interval '1 second', now())    |
        | keeps   | a code that has not expired                   | 1    | INSERT INTO oauth_codes (oauth_client_id, code_digest, redirect_uri, code_challenge, expires_at) VALUES (1, 'a', 'https://claude.ai/cb', repeat('a', 43), now() + interval '1 minute')                    |
        | keeps   | a used code that has not expired              | 1    | INSERT INTO oauth_codes (oauth_client_id, code_digest, redirect_uri, code_challenge, expires_at, used_at) VALUES (1, 'a', 'https://claude.ai/cb', repeat('a', 43), now() + interval '1 minute', now())    |
        | deletes | an access token past its expiry               | 0    | INSERT INTO oauth_tokens (oauth_client_id, type, token_digest, expires_at) VALUES (1, 'access', 'a', now() - interval '1 second')                                                         |
        | deletes | a refresh token past its expiry               | 0    | INSERT INTO oauth_tokens (oauth_client_id, type, token_digest, expires_at) VALUES (1, 'refresh', 'a', now() - interval '1 second')                                                        |
        | deletes | a revoked refresh token once it has expired   | 0    | INSERT INTO oauth_tokens (oauth_client_id, type, token_digest, expires_at, revoked_at) VALUES (1, 'refresh', 'a', now() - interval '1 second', now() - interval '1 hour')                 |
        | keeps   | a live token                                  | 1    | INSERT INTO oauth_tokens (oauth_client_id, type, token_digest, expires_at) VALUES (1, 'access', 'a', now() + interval '1 hour')                                                           |
        | keeps   | a revoked refresh token that has not expired  | 1    | INSERT INTO oauth_tokens (oauth_client_id, type, token_digest, expires_at, revoked_at) VALUES (1, 'refresh', 'a', now() + interval '30 days', now())                                     |

    Scenario: Another client's live rows stay
      Given the MCP clients:
        | name  | tokens |
        | Other | access |
      And the database runs "INSERT INTO oauth_tokens (oauth_client_id, type, token_digest, expires_at) VALUES (1, 'access', 'a', now() - interval '1 second')"
      When the job "MCP::Jobs::ReapExpiredCredentials" runs
      And the job "MCP::Jobs::ReapExpiredCredentials" has run
      Then the database answers "2" for:
        """
        SELECT string_agg(oauth_client_id::text, ', ') FROM oauth_tokens
        """

  Rule: A replayed code or refresh token still revokes the client after the job runs

    Background:
      Given an MCP client approved for "read"

    Scenario: A kept code replayed after the job revokes the client
      When the MCP client exchanges its code
      And the job "MCP::Jobs::ReapExpiredCredentials" runs
      And the job "MCP::Jobs::ReapExpiredCredentials" has run
      And the MCP client exchanges its code
      Then the database soon answers "0" for:
        """
        SELECT count(*) FROM oauth_tokens WHERE revoked_at IS NULL AND expires_at > now()
        """

    Scenario: A kept refresh token replayed after the job revokes the client
      When the MCP client exchanges its code
      And I keep the answer's "refresh_token" as "spent"
      And the MCP client refreshes with the token kept as "spent"
      And the job "MCP::Jobs::ReapExpiredCredentials" runs
      And the job "MCP::Jobs::ReapExpiredCredentials" has run
      And the MCP client refreshes with the token kept as "spent"
      Then the database soon answers "0" for:
        """
        SELECT count(*) FROM oauth_tokens WHERE revoked_at IS NULL AND expires_at > now()
        """

    Scenario: An idle client the owner has just approved still trades its code
      Given the database runs "UPDATE oauth_clients SET created_at = now() - interval '91 days'"
      When the job "MCP::Jobs::ReapExpiredCredentials" runs
      And the job "MCP::Jobs::ReapExpiredCredentials" has run
      Then the table oauth_clients holds 1 row
      When the MCP client exchanges its code
      Then the answer is 200

  Rule: Clients go once they never connect or go idle with nothing live

    Scenario: The job deletes and keeps clients by age, use and what they hold
      Given the MCP clients:
        | name                | connected    | last used    | tokens          | codes |
        | Never connected     | 91 days ago  |              | none            | 0     |
        | Idle, expired       | 91 days ago  | 91 days ago  | none            | 0     |
        | Idle, revoked       | 91 days ago  |              | none            | 0     |
        | Unclaimed           | 2 days ago   |              | none            | 0     |
        | Fresh               | 23 hours ago |              | none            | 0     |
        | Holds a code        | 2 days ago   |              | none            | 1     |
        | Holds a revoked     | 2 days ago   |              | none            | 0     |
        | Lapsed              | 89 days ago  | 60 days ago  | none            | 0     |
        | Used lately         | 91 days ago  | 89 days ago  | none            | 0     |
        | Idle, live access   | 91 days ago  | 91 days ago  | access          | 0     |
        | Idle, live refresh  | 91 days ago  | 91 days ago  | refresh         | 0     |
      And the database runs:
        """
        INSERT INTO oauth_tokens (oauth_client_id, type, token_digest, expires_at)
        SELECT id, 'refresh', 'expired', now() - interval '1 second' FROM oauth_clients WHERE client_name = 'Idle, expired';
        INSERT INTO oauth_tokens (oauth_client_id, type, token_digest, expires_at, revoked_at)
        SELECT id, 'refresh', 'revoked-' || id, now() + interval '30 days', now() FROM oauth_clients WHERE client_name IN ('Idle, revoked', 'Holds a revoked');
        UPDATE oauth_codes SET used_at = now()
        """
      When the job "MCP::Jobs::ReapExpiredCredentials" runs
      And the job "MCP::Jobs::ReapExpiredCredentials" has run
      Then the database answers "Fresh, Holds a code, Holds a revoked, Lapsed, Used lately, Idle, live access, Idle, live refresh" for:
        """
        SELECT string_agg(client_name, ', ' ORDER BY id) FROM oauth_clients
        """
      And the database answers "1" for:
        """
        SELECT count(*) FROM oauth_tokens WHERE revoked_at IS NOT NULL
        """
