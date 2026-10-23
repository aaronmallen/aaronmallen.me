Feature: Shares through the API
  An API token uploads, lists, reads, renames, groups and deletes shared files.

  Background:
    Given an API token

  Scenario: Uploading a share answers its link and stores the file byte for byte
    When I POST "/shares" through the API with:
      """
      {"data": "aGVsbG8=", "filename": "hello.txt", "content_type": "text/plain"}
      """
    Then the API answers 201
    And the API answer holds:
      """
      {"id": 1, "code": "1", "url": "http://shares.localhost/1", "filename": "hello.txt", "content_type": "text/plain",
        "byte_size": 5, "download_count": 0, "alt_text": null}
      """
    And the share store holds the file "hello.txt" as "hello"

  Scenario: An upload with no type is an octet stream, and a type in capitals is stored in lower case
    When I POST "/shares" through the API with:
      """
      {"data": "ZGF0YQ==", "filename": "blob"}
      """
    Then the API answer holds:
      """
      {"content_type": "application/octet-stream"}
      """
    When I POST "/shares" through the API with:
      """
      {"data": "ZGF0YQ==", "filename": "photo.png", "content_type": "Image/PNG"}
      """
    Then the API answer holds:
      """
      {"content_type": "image/png"}
      """

  Scenario: Base64 broken across lines is fine
    When I POST "/shares" through the API with:
      """
      {"data": "aGVs\nbG8=\n", "filename": "hello.txt"}
      """
    Then the API answers 201
    And the share store holds 1 file

  Scenario Outline: An upload with <what> is refused and nothing is stored
    When I POST "/shares" through the API with:
      """
      {"data": "<data>", "filename": "<filename>", "content_type": "<type>"}
      """
    Then the API answers 422
    And the API answer holds:
      """
      {"errors": {"<field>": ["<error>"]}}
      """
    And the share store holds 0 files
    And no shares or share groups are left

    Examples:
      | what                          | data        | filename      | type                  | field        | error                                        |
      | two content types             | PHA+aGk8L3A+ | photo.png     | image/png, text/html  | content_type | content_type is a media type, such as image/png|
      | a filename that climbs up     | ZGF0YQ==    | ../notes.txt  | text/plain            | filename     | filename is a bare name, with no slash, and not . or ..|
      | a filename with a folder      | ZGF0YQ==    | /etc/notes.txt | text/plain           | filename     | filename is a bare name, with no slash, and not . or ..|
      | the filename .                | ZGF0YQ==    | .             | text/plain            | filename     | filename is a bare name, with no slash, and not . or ..|
      | the filename ..               | ZGF0YQ==    | ..            | text/plain            | filename     | filename is a bare name, with no slash, and not . or ..|
      | data that is not base64       | not*base64! | a.txt         | text/plain            | data         | is not base64                                |

  Scenario: A blank file name is refused
    When I POST "/shares" through the API with:
      """
      {"data": "YQ==", "filename": " "}
      """
    Then the API answers 422
    And no shares or share groups are left

  Scenario: Uploading a group answers one link for the group and one for each file
    When I POST "/share_groups" through the API with:
      """
      {"files": [{"data": "YQ==", "filename": "a.txt", "content_type": "text/plain"}, {"data": "JVBERg==", "filename": "b.pdf"}]}
      """
    Then the API answers 201
    And the API answer holds:
      """
      {"id": 1, "code": "1", "url": "http://shares.localhost/1", "view_count": 0, "zip_download_count": 0,
        "files": [{"filename": "a.txt", "byte_size": 1, "url": "http://shares.localhost/1/1"},
                  {"filename": "b.pdf", "byte_size": 4, "url": "http://shares.localhost/1/2"}]}
      """
    And there is 1 share group
    And the share store holds the file "a.txt" as "a"
    When I GET "/shares" through the API
    Then the API answer holds:
      """
      {"count": 0}
      """

  Scenario: An empty group, a file that is not base64 and a blank name are refused
    When I POST "/share_groups" through the API with:
      """
      {"files": []}
      """
    Then the API answers 422
    When I POST "/share_groups" through the API with:
      """
      {"files": [{"data": "YQ==", "filename": "a.txt"}, {"data": "nope!", "filename": "b.txt"}]}
      """
    Then the API answers 422
    When I POST "/share_groups" through the API with:
      """
      {"files": [{"data": "YQ==", "filename": " "}]}
      """
    Then the API answers 422
    And the API answer holds:
      """
      {"errors": {"files": ["filename is empty"]}}
      """
    And the share store holds 0 files
    And no shares or share groups are left

  Scenario: The list holds shares newest first, filters images and finds them by their words
    Given the share "photo.png" of type "image/png"
    And the share "notes.txt" of type "text/plain"
    When I GET "/shares" through the API
    Then the API answer holds:
      """
      {"count": 2, "partial": false, "shares": [{"filename": "notes.txt"}, {"filename": "photo.png", "download_count": 0}]}
      """
    When I GET "/shares?filter=images" through the API
    Then the API answer holds:
      """
      {"shares": [{"filename": "photo.png"}]}
      """
    When I GET "/shares?query=notes" through the API
    Then the API answer holds:
      """
      {"shares": [{"filename": "notes.txt"}]}
      """
    When I GET "/shares?search=notes" through the API
    Then the API answer holds:
      """
      {"count": 2}
      """

  Scenario: The share list comes a page at a time
    Given 101 shares stored straight in the database
    When I GET "/shares" through the API
    Then the API answer holds:
      """
      {"count": 101, "partial": true, "next_page": 2}
      """

  Scenario: The share group list comes a page at a time
    Given 101 share groups stored straight in the database
    When I GET "/share_groups" through the API
    Then the API answer holds:
      """
      {"partial": true, "next_page": 2}
      """

  Scenario: A share reads by its ID and a missing one answers 404
    Given the share "notes.txt" of type "text/plain"
    When I GET "/shares/1" through the API
    Then the API answer holds:
      """
      {"id": 1, "code": "1"}
      """
    When I GET "/shares/999" through the API
    Then the API answers 404
    And the API answer holds:
      """
      {"message": "no share has the ID 999"}
      """

  Scenario: The group list holds groups newest first with their files, and a group reads by its ID
    Given the share group of:
      | filename | type       |
      | a.txt    | text/plain |
    And the share group of:
      | filename | type       |
      | b.txt    | text/plain |
      | c.txt    | text/plain |
    When I GET "/share_groups" through the API
    Then the API answer holds:
      """
      {"count": 2, "partial": false, "share_groups": [{"id": 2, "files": [{}, {}]}, {"id": 1, "files": [{}]}]}
      """
    When I GET "/share_groups/1" through the API
    Then the API answer holds:
      """
      {"id": 1, "code": "1", "files": [{"filename": "a.txt", "download_count": 0, "alt_text": null}]}
      """
    When I GET "/share_groups/999" through the API
    Then the API answers 404
    And the API answer holds:
      """
      {"message": "no share group has the ID 999"}
      """

  Scenario: Renaming a share keeps its code, and a blank name or a group file's ID is refused
    Given the share "notes.txt" of type "text/plain"
    And the share group of:
      | filename | type       |
      | a.txt    | text/plain |
    When I PATCH "/shares/1" through the API with:
      """
      {"filename": " todo.txt "}
      """
    Then the API answer holds:
      """
      {"filename": "todo.txt", "code": "1"}
      """
    When I PATCH "/shares/1" through the API with:
      """
      {"filename": " "}
      """
    Then the API answers 422
    And the API answer holds:
      """
      {"message": "filename: is empty"}
      """
    When I PATCH "/shares/2" through the API with:
      """
      {"filename": "b.txt"}
      """
    Then the API answers 404
    And the shared file "todo.txt" is named "todo.txt"
    And the shared file "a.txt" is named "a.txt"

  Scenario: Naming a group, clearing the name with null and reading it back
    Given the share group of:
      | filename | type       |
      | a.txt    | text/plain |
    When I PATCH "/share_groups/1" through the API with:
      """
      {"name": "Beach trip"}
      """
    Then the API answer holds:
      """
      {"name": "Beach trip", "code": "1"}
      """
    When I GET "/share_groups" through the API
    Then the API answer holds:
      """
      {"share_groups": [{"name": "Beach trip"}]}
      """
    When I PATCH "/share_groups/1" through the API with:
      """
      {"name": null}
      """
    Then the API answer holds:
      """
      {"name": null}
      """
    When I PATCH "/share_groups/999" through the API with:
      """
      {"name": "Beach trip"}
      """
    Then the API answers 404

  Scenario: Renaming a group file keeps its link, and a folder part or another group's file is refused
    Given the share group of:
      | filename | type       |
      | a.txt    | text/plain |
    And the share group of:
      | filename | type       |
      | c.txt    | text/plain |
    When I PATCH "/share_groups/1/files/1" through the API with:
      """
      {"filename": "b.txt"}
      """
    Then the API answer holds:
      """
      {"files": [{"filename": "b.txt", "url": "http://shares.localhost/1/1"}]}
      """
    When I PATCH "/share_groups/1/files/1" through the API with:
      """
      {"filename": "../../x.txt"}
      """
    Then the API answers 422
    When I PATCH "/share_groups/2/files/1" through the API with:
      """
      {"filename": "y.txt"}
      """
    Then the API answers 404
    And the shared file "b.txt" is named "b.txt"

  Scenario: Grouping shares answers a new group that keeps their IDs and frees their codes
    Given the share "a.txt" of type "text/plain"
    And the share "b.txt" of type "text/plain"
    When I POST "/shares/bulk/group" through the API with:
      """
      {"ids": [1, 2]}
      """
    Then the API answers 201
    And the API answer holds:
      """
      {"files": [{"id": 1}, {"id": 2}]}
      """
    And the short code "1" is free
    When I GET "/shares" through the API
    Then the API answer holds:
      """
      {"count": 0}
      """

  Scenario: Grouping one share counted twice, or a share already in a group, is refused
    Given the share "a.txt" of type "text/plain"
    And the share group of:
      | filename | type       |
      | c.txt    | text/plain |
    When I POST "/shares/bulk/group" through the API with:
      """
      {"ids": [1, 1]}
      """
    Then the API answers 422
    And the API answer holds:
      """
      {"message": "ids: needs two or more single shares"}
      """
    When I POST "/shares/bulk/group" through the API with:
      """
      {"ids": [1, 2]}
      """
    Then the API answers 422
    And the API answer holds:
      """
      {"message": "names a share that is not there or already sits in a group"}
      """
    When I GET "/shares" through the API
    Then the API answer holds:
      """
      {"count": 1}
      """

  Scenario: Adding a share to a group moves it under the group's link
    Given the share group of:
      | filename | type       |
      | a.txt    | text/plain |
    And the share "b.txt" of type "text/plain"
    When I POST "/share_groups/1/files" through the API with:
      """
      {"ids": [2]}
      """
    Then the API answer holds:
      """
      {"files": [{"id": 1}, {"id": 2, "url": "http://shares.localhost/1/2"}]}
      """

  Scenario: Adding to a missing group or adding a missing share is refused
    Given the share group of:
      | filename | type       |
      | a.txt    | text/plain |
    And the share "b.txt" of type "text/plain"
    When I POST "/share_groups/999/files" through the API with:
      """
      {"ids": [2]}
      """
    Then the API answers 404
    And the shared file "b.txt" stands alone
    When I POST "/share_groups/1/files" through the API with:
      """
      {"ids": [999]}
      """
    Then the API answers 422

  Scenario: Pulling a file out of a group answers it as a share under a new code and keeps the rest
    Given the share group of:
      | filename | type       |
      | a.txt    | text/plain |
      | b.txt    | text/plain |
    When I POST "/share_groups/1/files/1/ungroup" through the API
    Then the API answer holds:
      """
      {"id": 1, "filename": "a.txt", "url": "http://shares.localhost/2"}
      """
    When I GET "/share_groups/1" through the API
    Then the API answer holds:
      """
      {"files": [{"filename": "b.txt"}]}
      """

  Scenario: Pulling a file out of another group or a missing group answers 404
    Given the share group of:
      | filename | type       |
      | a.txt    | text/plain |
    And the share group of:
      | filename | type       |
      | c.txt    | text/plain |
    When I POST "/share_groups/2/files/1/ungroup" through the API
    Then the API answers 404
    And the API answer holds:
      """
      {"message": "share group 2 has no file with the ID 1"}
      """
    When I POST "/share_groups/999/files/1/ungroup" through the API
    Then the API answers 404

  Scenario Outline: A <type> upload is stored byte for byte under its short code number in base 36
    When I POST "/shares" through the API with:
      """
      {"data": "<data>", "filename": "<filename>", "content_type": "<type>"}
      """
    Then the API answer holds:
      """
      {"code": "1", "filename": "<filename>", "content_type": "<type>", "download_count": 0}
      """
    And the share store holds the file "<filename>" as the base64 "<data>"

    Examples:
      | filename  | type            | data                 |
      | deck.pdf  | application/pdf | JVBERi0xLjcKJeLjz9MK |
      | files.zip | application/zip | UEsDBBQAAAAAAA==     |
      | clip.mp4  | video/mp4       | AAAAGGZ0eXBtcDQy     |

  Scenario: A JPEG keeps its camera data and stays out of the photo store
    When I POST "/shares" through the API with:
      """
      {"data": "/9j/4QAQRXhpZgAAR1BTZGF0YQ==", "filename": "IMG_0001.JPG", "content_type": "image/jpeg"}
      """
    Then the API answers 201
    And the share store holds the file "IMG_0001.JPG" as the base64 "/9j/4QAQRXhpZgAAR1BTZGF0YQ=="
    And the share upload left the photo store and the photos table alone

  Scenario Outline: A new <what> skips to the next number when the code it would take is taken
    Given the short code "first" is taken
    And the short code "3" is taken
    When I POST "<path>" through the API with:
      """
      <body>
      """
    Then the API answers 201
    And the API answer holds:
      """
      {"code": "4"}
      """

    Examples:
      | what        | path          | body                                                   |
      | share       | /shares       | {"data": "YQ==", "filename": "a.txt"}                  |
      | share group | /share_groups | {"files": [{"data": "YQ==", "filename": "a.txt"}]}     |

  Scenario: A share's code changes as typed, and a missing share or short link answers 404
    Given the share "notes.txt" of type "text/plain"
    When I PATCH "/shares/1" through the API with:
      """
      {"code": "cv"}
      """
    Then the API answer holds:
      """
      {"code": "cv", "url": "http://shares.localhost/cv"}
      """
    When I PATCH "/shares/999" through the API with:
      """
      {"code": "resume"}
      """
    Then the API answers 404
    When I PATCH "/short_links/999" through the API with:
      """
      {"title": "x"}
      """
    Then the API answers 404

  Scenario Outline: A share's code <code> is refused and the old one stays
    Given the share "notes.txt" of type "text/plain"
    When I PATCH "/shares/1" through the API with:
      """
      {"code": "<code>"}
      """
    Then the API answers 422
    When I fetch "/1" from the share host
    Then the share host answers 200

    Examples:
      | code     |
      | -resume  |
      | resume-  |
      | re--sume |
      | re_sume  |
      | résumé   |
      |          |

  Scenario: Deleting a share takes its row, code and stored file, an image's preview too, and a missing one answers 404
    Given the share "dot.png" of type "image/png" holding "a 30 by 30 png"
    Then the share store holds 2 files
    When I DELETE "/shares/1" through the API
    Then the API answers 200
    And no shares or share groups are left
    And the share store holds 0 files
    When I DELETE "/shares/999" through the API
    Then the API answers 404

  Scenario Outline: A short link to <destination> is refused
    When I POST "/short_links" through the API with:
      """
      {"destination": "<destination>"}
      """
    Then the API answers 422

    Examples:
      | destination           |
      | ftp://example.com     |
      | javascript:alert(1)   |
      | example.com           |
      | mailto:me@example.com |
      |                       |

  Scenario: A short link takes the code and title I give, trimmed, and refuses codes others hold
    Given the short link "talk-old" to "http://203.0.113.5/talk"
    And the short link "other" to "http://203.0.113.5/other"
    And the share "notes.txt" of type "text/plain"
    When I PATCH "/short_links/1" through the API with:
      """
      {"code": " Talk ", "title": " My talk "}
      """
    Then the API answer holds:
      """
      {"code": "talk", "title": "My talk"}
      """
    When I PATCH "/short_links/1" through the API with:
      """
      {"code": "other"}
      """
    Then the API answers 422
    When I PATCH "/short_links/1" through the API with:
      """
      {"code": "3"}
      """
    Then the API answers 422
    When I PATCH "/short_links/1" through the API with:
      """
      {"code": "ta--lk"}
      """
    Then the API answers 422
    And the short link to "http://203.0.113.5/talk" has the code "talk"

  Scenario: A short link's title sets, refuses control characters and clears
    Given the short link "talk" to "http://203.0.113.5/talk"
    And the web answers GET "http://203.0.113.5/talk" with status 404
    When I PATCH "/short_links/1" through the API with:
      """
      {"title": "bad\u0007"}
      """
    Then the API answers 422
    And the short link to "http://203.0.113.5/talk" is titled "A short link"
    When I PATCH "/short_links/1" through the API with:
      """
      {"title": " "}
      """
    Then the API answer holds:
      """
      {"title": null}
      """
    And the short link to "http://203.0.113.5/talk" has no title once the fetch is done

  Scenario: An upload the share store refuses answers 503 and keeps no row
    Given the share store fails every PUT
    When I POST "/shares" through the API with:
      """
      {"data": "YQ==", "filename": "a.txt"}
      """
    Then the API answers 503
    And the API answer holds:
      """
      {"error": "unavailable"}
      """
    And no shares or share groups are left

  Scenario: A group upload whose second file the store refuses keeps no rows and no files
    Given the share store fails every PUT after the first
    When I POST "/share_groups" through the API with:
      """
      {"files": [{"data": "YQ==", "filename": "a.txt"}, {"data": "Yg==", "filename": "b.txt"}]}
      """
    Then the API answers 503
    And no shares or share groups are left
    And the share store holds 0 files

  Scenario: A group upload keeps an image whose preview the store refuses
    Given the share store fails every PUT after the first
    And the share group of:
      | filename | type      | body           |
      | dot.png  | image/png | a 30 by 30 png |
    Then the shared file "dot.png" has no preview stored
    And the share store holds 1 file

  Scenario: Deleting a share the store will not let go of keeps it
    Given the share "notes.txt" of type "text/plain"
    And the share store fails every DELETE
    When I DELETE "/shares/1" through the API
    Then the API answers 503
    And the shared file "notes.txt" stands alone
    And the share store holds 1 file
