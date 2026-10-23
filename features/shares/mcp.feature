Feature: Shares through MCP
  An agent shares files and keeps the share list in order through the share tools.

  Background:
    Given an MCP client connected with the scopes "read write publish delete"

  Scenario: upload_share shares a file and answers its link
    When I call the MCP tool "upload_share" with:
      """
      {"data": "aGVsbG8=", "filename": "hello.txt", "content_type": "text/plain"}
      """
    Then the MCP answer holds:
      """
      {"id": 1, "url": "http://shares.localhost/1", "filename": "hello.txt", "content_type": "text/plain", "byte_size": 5}
      """

  Scenario: upload_share refuses data that is not base64 and shares nothing
    When I call the MCP tool "upload_share" with:
      """
      {"data": "not*base64!", "filename": "a.txt"}
      """
    Then the share tool refused
    And no shares or share groups are left

  Scenario: upload_share_group shares the files under one link, each with its own link under it
    When I call the MCP tool "upload_share_group" with:
      """
      {"files": [{"data": "YQ==", "filename": "a.txt", "content_type": "text/plain"}, {"data": "YmI=", "filename": "b.txt"}]}
      """
    Then the MCP answer holds:
      """
      {"url": "http://shares.localhost/1",
        "files": [{"filename": "a.txt", "url": "http://shares.localhost/1/1"}, {"filename": "b.txt", "url": "http://shares.localhost/1/2"}]}
      """
    When I call the MCP tool "upload_share_group" with:
      """
      {"files": []}
      """
    Then the share tool refused

  Scenario: list_shares lists the shares newest first, finds them by their words and refuses the old search filter
    Given the share "one.txt" of type "text/plain"
    And the share "notes.txt" of type "text/plain"
    When I call the MCP tool "list_shares"
    Then the MCP answer holds:
      """
      {"count": 2, "shares": [{"filename": "notes.txt"}, {"filename": "one.txt"}]}
      """
    When I call the MCP tool "list_shares" with:
      """
      {"query": "notes"}
      """
    Then the MCP answer holds:
      """
      {"shares": [{"filename": "notes.txt"}]}
      """
    When I call the MCP tool "list_shares" with:
      """
      {"search": "notes"}
      """
    Then the share tool refused

  Scenario: read_share reads one share and refuses an ID no share holds
    Given the share "notes.txt" of type "text/plain"
    When I call the MCP tool "read_share" with:
      """
      {"id": 1}
      """
    Then the MCP answer holds:
      """
      {"id": 1, "code": "1"}
      """
    When I call the MCP tool "read_share" with:
      """
      {"id": 0}
      """
    Then the share tool refused

  Scenario: list_share_groups and read_share_group read the groups with their files
    Given the share group of:
      | filename | type       |
      | a.txt    | text/plain |
      | b.png    | image/png  |
    When I call the MCP tool "list_share_groups"
    Then the MCP answer holds:
      """
      {"count": 1, "share_groups": [{"files": [{}, {}]}]}
      """
    When I call the MCP tool "read_share_group" with:
      """
      {"id": 1}
      """
    Then the MCP answer holds:
      """
      {"files": [{"filename": "a.txt"}, {"filename": "b.png"}]}
      """
    When I call the MCP tool "read_share_group" with:
      """
      {"id": 0}
      """
    Then the share tool refused

  Scenario: update_share renames a share and sets, trims and clears its alt text, keeping its code
    Given the share "notes.txt" of type "text/plain"
    When I call the MCP tool "update_share" with:
      """
      {"id": 1, "filename": "b.txt"}
      """
    Then the MCP answer holds:
      """
      {"filename": "b.txt"}
      """
    When I call the MCP tool "update_share" with:
      """
      {"id": 1, "alt_text": "  A red door "}
      """
    Then the MCP answer holds:
      """
      {"alt_text": "A red door", "code": "1"}
      """
    When I call the MCP tool "update_share" with:
      """
      {"id": 1, "alt_text": "A\u0000door"}
      """
    Then the share tool refused
    When I call the MCP tool "update_share" with:
      """
      {"id": 1, "alt_text": ""}
      """
    Then the MCP answer holds:
      """
      {"alt_text": null}
      """
    When I call the MCP tool "update_share" with:
      """
      {"id": 0, "alt_text": "A door"}
      """
    Then the share tool refused

  Scenario: update_share changes a share's code and moves its link
    Given the share "notes.txt" of type "text/plain"
    When I call the MCP tool "update_share" with:
      """
      {"id": 1, "code": " Resume-Me "}
      """
    Then the MCP answer holds:
      """
      {"code": "resume-me", "url": "http://shares.localhost/resume-me"}
      """
    And the short code "1" is free

  Scenario: update_share refuses a code another share holds or one that breaks the format
    Given the share "one.txt" of type "text/plain"
    And the share "two.txt" of type "text/plain"
    When I call the MCP tool "update_share" with:
      """
      {"id": 1, "code": "2"}
      """
    Then the share tool refuses with words "another share or short link already has this code"
    When I call the MCP tool "update_share" with:
      """
      {"id": 1, "code": "re--sume"}
      """
    Then the share tool refuses with words "code takes lowercase letters and digits"
    When I fetch "/1" from the share host
    Then the share host answers 200

  Scenario: update_share_group names a group, which read_share_group reads back
    Given the share group of:
      | filename | type       |
      | a.txt    | text/plain |
    When I call the MCP tool "update_share_group" with:
      """
      {"id": 1, "name": "Beach trip"}
      """
    And I call the MCP tool "read_share_group" with:
      """
      {"id": 1}
      """
    Then the MCP answer holds:
      """
      {"name": "Beach trip"}
      """

  Scenario: update_share_group_file renames a file in a group and refuses a blank name
    Given the share group of:
      | filename | type       |
      | a.txt    | text/plain |
    When I call the MCP tool "update_share_group_file" with:
      """
      {"id": 1, "file_id": 1, "filename": "b.txt"}
      """
    Then the MCP answer holds:
      """
      {"files": [{"id": 1, "filename": "b.txt"}]}
      """
    When I call the MCP tool "update_share_group_file" with:
      """
      {"id": 1, "file_id": 1, "filename": ""}
      """
    Then the share tool refused

  Scenario: delete_share deletes the share and its stored file, and refuses an ID no share holds
    Given the share "notes.txt" of type "text/plain"
    When I call the MCP tool "delete_share" with:
      """
      {"id": 1}
      """
    Then the MCP answer holds:
      """
      {"id": 1, "deleted": true}
      """
    And no shares or share groups are left
    And the share store holds 0 files
    When I call the MCP tool "delete_share" with:
      """
      {"id": 0}
      """
    Then the share tool refused

  Scenario: delete_share_group deletes the group and every stored file
    Given the share group of:
      | filename | type       |
      | a.txt    | text/plain |
      | b.txt    | text/plain |
    When I call the MCP tool "delete_share_group" with:
      """
      {"id": 1}
      """
    Then the MCP answer holds:
      """
      {"id": 1, "deleted": true}
      """
    And no shares or share groups are left
    And the share store holds 0 files
    When I call the MCP tool "delete_share_group" with:
      """
      {"id": 0}
      """
    Then the share tool refused

  Scenario: group_shares groups single shares under one new link and refuses one share
    Given the share "a.txt" of type "text/plain"
    And the share "b.txt" of type "text/plain"
    And the share "c.txt" of type "text/plain"
    When I call the MCP tool "group_shares" with:
      """
      {"ids": [1, 2]}
      """
    Then the MCP answer holds:
      """
      {"files": [{"id": 1}, {"id": 2}]}
      """
    When I call the MCP tool "group_shares" with:
      """
      {"ids": [3]}
      """
    Then the share tool refused

  Scenario: add_shares_to_group moves a share into a group and ungroup_share_file pulls one out under a new code
    Given the share group of:
      | filename | type       |
      | a.txt    | text/plain |
    And the share "b.txt" of type "text/plain"
    When I call the MCP tool "add_shares_to_group" with:
      """
      {"id": 1, "ids": [2]}
      """
    Then the MCP answer holds:
      """
      {"files": [{"id": 1}, {"id": 2}]}
      """
    When I call the MCP tool "ungroup_share_file" with:
      """
      {"id": 1, "file_id": 1}
      """
    Then the MCP answer holds:
      """
      {"id": 1, "url": "http://shares.localhost/3"}
      """

  Scenario: remove_share_group_file deletes one file and keeps the rest of the group
    Given the share group of:
      | filename | type       |
      | a.txt    | text/plain |
      | b.txt    | text/plain |
    When I call the MCP tool "remove_share_group_file" with:
      """
      {"id": 1, "file_id": 1}
      """
    Then the MCP answer holds:
      """
      {"id": 1, "file_id": 1, "deleted": true}
      """
    And the share store holds 1 file
    When I call the MCP tool "read_share_group" with:
      """
      {"id": 1}
      """
    Then the MCP answer holds:
      """
      {"files": [{"id": 2}]}
      """
    When I call the MCP tool "remove_share_group_file" with:
      """
      {"id": 1, "file_id": 0}
      """
    Then the share tool refused
    When I call the MCP tool "remove_share_group_file" with:
      """
      {"id": 0, "file_id": 1}
      """
    Then the share tool refused

  Scenario: remove_share_group_file deletes the group with its last file
    Given the share group of:
      | filename | type       |
      | a.txt    | text/plain |
    When I call the MCP tool "remove_share_group_file" with:
      """
      {"id": 1, "file_id": 1}
      """
    Then no shares or share groups are left

  Scenario: upload_share refuses when the store does not answer
    Given the share store fails every PUT
    When I call the MCP tool "upload_share" with:
      """
      {"data": "YQ==", "filename": "a.txt"}
      """
    Then the MCP tool refuses with "the share store is not set up or did not answer; try again later"
    And no shares or share groups are left

  Scenario: delete_share and remove_share_group_file keep the file when the store fails
    Given the share "notes.txt" of type "text/plain"
    And the share group of:
      | filename | type       |
      | a.txt    | text/plain |
      | b.txt    | text/plain |
    And the share store fails every DELETE
    When I call the MCP tool "delete_share" with:
      """
      {"id": 1}
      """
    Then the MCP tool refuses with "the share store is not set up or did not answer; try again later"
    And the shared file "notes.txt" stands alone
    When I call the MCP tool "remove_share_group_file" with:
      """
      {"id": 1, "file_id": 2}
      """
    Then the MCP tool refuses with "the share store is not set up or did not answer; try again later"
    And the share group holds 2 files
