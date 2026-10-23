Feature: Files in the admin
  The owner uploads files to the share host, finds them, edits their names, codes and alt text, and deletes them.

  Background:
    Given I am signed in to the admin

  Scenario: The files tab sits under Publish beside Links and says when nothing is shared
    When I open the files
    Then the files page tabs link "/admin/posts, /admin/social, /admin/files, /admin/links"
    And I see "Nothing shared yet. Drop a file above."
    And the files box "Share as one link" is unticked
    And the page has no axe breaches in light or dark

  Scenario: A card shows the file's name, link, size and downloads, and its link opens signed out
    Given the share "deck.pdf" of type "application/pdf" holding "2048 bytes"
    When I open the files
    Then the file cards read "deck.pdf"
    And the file card "deck.pdf" reads "shares.localhost/[code of deck.pdf]"
    And the file card "deck.pdf" reads "2 KB"
    And the file card "deck.pdf" reads "0 downloads"
    And the file card "deck.pdf" opens "[link of deck.pdf]" in a new tab
    And the open icon of the file card "deck.pdf" turns the accent color when I hover it
    And I see "1 file shared on shares.localhost, 2 KB in all. Anyone with the link can open it."
    And the page has no axe breaches in light or dark
    When I fetch "/[code of deck.pdf]" from the share host
    Then the share host answers 200

  Scenario: The lede sums several files
    Given the share "deck.pdf" of type "application/pdf" holding "2048 bytes"
    And the share "notes.txt" of type "text/plain" holding "2048 bytes"
    When I open the files
    Then I see "2 files shared on shares.localhost, 4 KB in all. Anyone with a file's link can open it."

  Scenario: An image shows as a thumbnail with its alt text, asked for as a preview
    Given the share "shot.png" of type "image/png"
    And the shared file "shot.png" has the alt text "A cat"
    When I open the files
    Then the file card thumbnail of "shot.png" shows "http://shares.localhost/[code of shot.png]?preview"
    And the file card thumbnail of "shot.png" reads the alt text "A cat"

  Scenario: The search narrows by name, type and code, and says when nothing matches
    Given the share "notes.txt" of type "text/plain"
    And the share "photo.png" of type "image/png"
    And the share "clip.mp4" of type "video/mp4"
    And the shared file "notes.txt" has the code "zzqzzqzz"
    When I open the files at "?search=NOTES"
    Then the file cards read "notes.txt"
    And the file filter keeps the search "NOTES"
    When I open the files at "?search=video"
    Then the file cards read "clip.mp4"
    And I see "1 match"
    When I open the files at "?search=zzqzzqzz"
    Then the file cards read "notes.txt"
    When I open the files at "?search=nothing"
    Then I see "No files match."

  Scenario: The filter keeps images, or everything but images
    Given the share "notes.txt" of type "text/plain"
    And the share "photo.png" of type "image/png"
    And the share "clip.mp4" of type "video/mp4"
    When I open the files at "?kind=images"
    Then the file cards read "photo.png"
    When I open the files at "?kind=other"
    Then the file cards read "clip.mp4, notes.txt"

  Scenario: The list shows the newest twelve and pages back to older files
    Given 13 shares stored straight in the database
    When I open the files at "?kind=other"
    Then the file cards read "s12.txt, s11.txt, s10.txt, s9.txt, s8.txt, s7.txt, s6.txt, s5.txt, s4.txt, s3.txt, s2.txt, s1.txt"
    When I click "Older"
    Then I am on "/admin/files?kind=other&page=2"
    And the file cards read "s0.txt"
    When I click "Newer"
    Then I am on "/admin/files?kind=other"
    When I visit "/admin/files?page=3"
    Then the server answers 404

  Scenario: Dropping one file uploads it, says so and copies its link
    When I open the files
    And I watch the clipboard
    And I drop the files on the file drop:
      | filename | type            | body     |
      | deck.pdf | application/pdf | %PDF-1.7 |
    Then the toast says "Uploaded · link copied"
    And the file cards read "deck.pdf"
    And the clipboard got "[link of deck.pdf]"
    And the share store holds the file "deck.pdf" as "%PDF-1.7"

  Scenario: Dropping several files uploads each one without copying
    When I open the files
    And I watch the clipboard
    And I drop the files on the file drop:
      | filename | type            | body |
      | a.txt    | text/plain      | a    |
      | b.zip    | application/zip | PK   |
    Then the toast says "2 files uploaded"
    And I see "a.txt"
    And I see "b.zip"
    And the clipboard got ""

  Scenario: A file chosen in the picker uploads
    When I open the files
    And I watch the clipboard
    And I choose the file "small.png" in the file picker
    Then the toast says "Uploaded · link copied"

  Scenario: Files over the form and photo limits upload
    When I open the files
    And I watch the clipboard
    And I drop the files on the file drop:
      | filename | type            | body           |
      | big.zip  | application/zip | 2097152 bytes  |
    Then the toast says "Uploaded · link copied"
    And the shared file "big.zip" is 2097152 bytes
    When I drop the files on the file drop:
      | filename  | type            | body           |
      | huge.zip  | application/zip | 34952534 bytes |
    Then the toast says "Uploaded · link copied"
    And the shared file "huge.zip" is 34952534 bytes

  Scenario: A body past 100 MB is refused before it is read
    When I open the files
    And I send the files page an upload that claims 104857601 bytes
    Then the files page answers 413
    And no shares or share groups are left

  Scenario: An upload with no file is refused
    When I open the files
    And I upload no file to the files page
    Then the files page answers 422
    And the files page says "Nothing uploaded · pick a file first"

  Scenario: Files dropped as one link make one group
    When I open the files
    And I tick the files box "Share as one link"
    And I drop the files on the file drop:
      | filename | type            | body |
      | a.txt    | text/plain      | a    |
      | b.pdf    | application/pdf | %PDF |
    Then the toast says "2 files uploaded as one link"
    And there is 1 share group
    And the shared file "a.txt" sits in the share group
    And the shared file "b.pdf" sits in the share group
    And the share store holds the file "b.pdf" as "%PDF"
    When I visit "/admin/files"
    Then the file cards read "2 files"

  Scenario: A card's link copies, and its drawer opens from the card
    Given the share "deck.pdf" of type "application/pdf" holding "2048 bytes"
    When I open the files
    And I watch the clipboard
    And I click "Copy link"
    Then the toast says "Link copied"
    And the clipboard got "[link of deck.pdf]"
    When I open the file card "deck.pdf"
    Then the file drawer reads "deck.pdf"
    And the file drawer reads "2 KB"
    And the file drawer reads "application/pdf"
    And the file drawer reads "uploaded "
    And the file drawer reads "0 downloads"
    And the file drawer reads "[link of deck.pdf]"
    And the file drawer field "File name" holds "deck.pdf"
    And the file drawer field "Short code" holds "[code of deck.pdf]"
    And the file drawer has no field "Alt text"
    And the page has no axe breaches in light or dark
    When I click "Copy as markdown" in the file drawer
    Then the clipboard got "[link of deck.pdf] then [deck.pdf]([link of deck.pdf])"

  Scenario: An image's drawer edits the alt text, and its markdown uses it with brackets escaped
    Given the share "shot.png" of type "image/png"
    When I open the files
    And I open the file card "shot.png"
    And I set the file drawer field "Alt text" to "A [cat] \ dog"
    And I click "Save" in the file drawer
    Then the toast says "File saved"
    And the shared file "shot.png" has the alt text "A [cat] \ dog" stored
    When I open the file card "shot.png"
    Then the file drawer field "Alt text" holds "A [cat] \ dog"
    And the file drawer reads "The markdown you copy uses it."
    When I watch the clipboard
    And I click "Copy as markdown" in the file drawer
    Then the toast says "Markdown copied"
    And the clipboard got "![A \[cat\] \\ dog]([link of shot.png])"

  Scenario: The drawer keeps text I closed it on across another upload
    Given the share "shot.png" of type "image/png"
    When I open the files
    And I open the file card "shot.png"
    And I set the file drawer field "Alt text" to "A cat"
    And I close the file drawer
    And I drop the files on the file drop:
      | filename | type            | body     |
      | deck.pdf | application/pdf | %PDF-1.7 |
    And I see "deck.pdf"
    And I open the file card "shot.png"
    Then the file drawer field "Alt text" holds "A cat"

  Scenario: The edit page works without scripts and answers 404 for a missing file
    Given the share "deck.pdf" of type "application/pdf"
    And the admin scripts do not load
    When I open the edit page of the shared file "deck.pdf"
    And I fill in "Short code" with "resume-cv"
    And I click "Save"
    And I fetch "/resume-cv" from the share host
    Then the share host answers 200
    When I fetch "/1" from the share host
    Then the share host answers 404
    When I open the edit page of the shared file "deck.pdf"
    Then I see "The part after shares.localhost/. Save a new one and the old link stops working at once."
    When I visit "/admin/files/0/edit"
    Then the server answers 404

  Scenario: Renaming a file downloads it under its new name at the same link
    Given the share "shot.png" of type "image/png"
    When I open the files
    And I open the file card "shot.png"
    And I set the file drawer field "File name" to " cat.png "
    And I click "Save" in the file drawer
    Then the toast says "File saved"
    When I fetch "/[code of cat.png]" from the share host
    Then the share host answers 200
    And the share host header "Content-Disposition" holds 'filename="cat.png"'

  Scenario Outline: The drawer refuses <what> and keeps what was there
    Given the share "shot.png" of type "image/png"
    And the share "deck.pdf" of type "application/pdf"
    And the short code "resume-pdf" is taken
    When I open the edit page of the shared file "shot.png"
    And I fill in "<field>" with "<value>"
    And I click "Save"
    Then I see "<error>"
    And the file field "<field>" is marked wrong
    And the shared file "shot.png" is named "shot.png"
    And the shared file "shot.png" has the code "1" still

    Examples:
      | what                       | field      | value      | error                                                 |
      | a blank name               | File name  |            | Give it a name.                                       |
      | a bad code                 | Short code | Re Sume    | Use lowercase letters, numbers and single hyphens.    |
      | a blank code               | Short code |            | Give it a code.                                       |
      | a code another share holds | Short code | 2          | Another file or short link already uses that code.    |
      | a code a short link holds  | Short code | resume-pdf | Another file or short link already uses that code.    |

  Scenario: The drawer refuses a control character and changes nothing
    Given the share "shot.png" of type "image/png"
    When I open the files
    And I post to "/admin/files/[id of shot.png]" from the files page with:
      | share[filename] | a\u0007.png |
      | share[code]     | 1           |
    Then the files page answers 422
    And the files page says "Take out the control characters."
    When I post to "/admin/files/[id of shot.png]" from the files page with:
      | share[code]     | resume      |
      | share[alt_text] | A\u0000cat  |
    Then the files page answers 422
    And the shared file "shot.png" is named "shot.png"
    And the shared file "shot.png" has the code "1" still
    And the shared file "shot.png" has the alt text "" stored

  Scenario: Deleting a file asks first, then removes it, its code and its stored file
    Given the share "deck.pdf" of type "application/pdf"
    When I open the files
    And I open the file card "deck.pdf"
    And I click "Delete file" in the file drawer
    Then the file drawer asks "Delete deck.pdf? Its link stops working at once."
    When I click "Delete file" in the file drawer
    Then the toast says "File deleted"
    And the file cards read ""
    And no shares or share groups are left
    And the share store holds 0 files

  Scenario: Deleting a missing file answers 404
    When I open the files
    And I post to "/admin/files/0/delete" from the files page
    Then the files page answers 404

  Scenario: Deleting a file the store will not let go of keeps it and says so
    Given the share "deck.pdf" of type "application/pdf"
    And the share store fails every DELETE
    When I open the files
    And I open the file card "deck.pdf"
    And I click "Delete file" in the file drawer
    And I click "Delete file" in the file drawer
    Then the toast says "Nothing deleted · the share store isn't answering"
    And the file cards read "deck.pdf"
    And the shared file "deck.pdf" stands alone
