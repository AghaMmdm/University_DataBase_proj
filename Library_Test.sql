USE UniversityDB;
GO

--======================================================================= Functions ========================================================================

SELECT * FROM Library.GetTopBorrowedBooks(5);




-- Declare variables for IDs (assuming these were populated from your previous comprehensive insert script)
DECLARE @MemberID_Ali INT, @MemberID_Sara INT, @MemberID_Reza INT;
DECLARE @BookID_1984 INT, @BookID_HP INT, @BookID_Foundation INT;

-- Retrieve MemberIDs by NationalCode to ensure correct IDs
SELECT @MemberID_Ali = MemberID FROM Library.Members WHERE NationalCode = N'1234567890';
SELECT @MemberID_Sara = MemberID FROM Library.Members WHERE NationalCode = N'9876543210';
SELECT @MemberID_Reza = MemberID FROM Library.Members WHERE NationalCode = N'1122334455';

-- Retrieve BookIDs by ISBN to ensure correct IDs
SELECT @BookID_1984 = BookID FROM Library.Books WHERE ISBN = N'9780451524935';
SELECT @BookID_HP = BookID FROM Library.Books WHERE ISBN = N'9780747532699';
SELECT @BookID_Foundation = BookID FROM Library.Books WHERE ISBN = N'9780553803714';


PRINT N'Ensuring overdue book records exist...';

-- Ensure Sara's 1984 borrow is overdue
IF @BookID_1984 IS NOT NULL AND @MemberID_Sara IS NOT NULL
AND NOT EXISTS (SELECT 1 FROM Library.Borrows WHERE BookID = @BookID_1984 AND MemberID = @MemberID_Sara AND BorrowDate = '2025-05-10' AND DueDate = '2025-05-20')
BEGIN
    INSERT INTO Library.Borrows (BookID, MemberID, BorrowDate, DueDate, Status, ActualReturnDate)
    VALUES (@BookID_1984, @MemberID_Sara, '2025-05-10', '2025-05-20', 'Borrowed', NULL);
    PRINT N'Added/Ensured Sara''s borrow of 1984 is set for overdue check.';
END;

-- Ensure Reza's Harry Potter borrow is overdue
IF @BookID_HP IS NOT NULL AND @MemberID_Reza IS NOT NULL
AND NOT EXISTS (SELECT 1 FROM Library.Borrows WHERE BookID = @BookID_HP AND MemberID = @MemberID_Reza AND BorrowDate = '2025-05-01' AND DueDate = '2025-05-15')
BEGIN
    INSERT INTO Library.Borrows (BookID, MemberID, BorrowDate, DueDate, Status, ActualReturnDate)
    VALUES (@BookID_HP, @MemberID_Reza, '2025-05-01', '2025-05-15', 'Borrowed', NULL);
    PRINT N'Added/Ensured Reza''s borrow of Harry Potter is set for overdue check.';
END;


-- Add a new overdue borrow record for Ali (if not already existing)
-- Use a DueDate well in the past to guarantee it shows as overdue
IF @BookID_Foundation IS NOT NULL AND @MemberID_Ali IS NOT NULL
AND NOT EXISTS (SELECT 1 FROM Library.Borrows WHERE BookID = @BookID_Foundation AND MemberID = @MemberID_Ali AND BorrowDate = '2024-12-01' AND DueDate = '2024-12-15')
BEGIN
    INSERT INTO Library.Borrows (BookID, MemberID, BorrowDate, DueDate, Status, ActualReturnDate)
    VALUES (@BookID_Foundation, @MemberID_Ali, '2024-12-01', '2024-12-15', 'Borrowed', NULL);
    PRINT N'Added/Ensured Ali''s borrow of Foundation is set for overdue check.';
END;


PRINT N'Attempting to retrieve overdue books for Sara Moradi:';
-- Call the function for Sara Moradi
IF @MemberID_Sara IS NOT NULL
    SELECT * FROM Library.GetMemberOverdueBooks(@MemberID_Sara);
ELSE
    PRINT N'MemberID for Sara Moradi not found. Please ensure previous data insertion scripts ran successfully.';

PRINT N'Attempting to retrieve overdue books for Reza Karimi:';
-- Call the function for Reza Karimi
IF @MemberID_Reza IS NOT NULL
    SELECT * FROM Library.GetMemberOverdueBooks(@MemberID_Reza);
ELSE
    PRINT N'MemberID for Reza Karimi not found. Please ensure previous data insertion scripts ran successfully.';

PRINT N'Attempting to retrieve overdue books for Ali Rezaei:';
-- Call the function for Ali Rezaei
IF @MemberID_Ali IS NOT NULL
    SELECT * FROM Library.GetMemberOverdueBooks(@MemberID_Ali);
ELSE
    PRINT N'MemberID for Ali Rezaei not found. Please ensure previous data insertion scripts ran successfully.';






--======================================================================= Procedures ========================================================================


DECLARE @_Title NVARCHAR(500) = N'The Hitchhiker''s Guide to the Galaxy';
DECLARE @_ISBN NVARCHAR(13) = N'9780345391803';
DECLARE @_PublicationYear INT = 1979;
DECLARE @_Edition NVARCHAR(50) = N'First Edition';
DECLARE @_PublisherName NVARCHAR(200) = N'Pan Books'; 
DECLARE @_CategoryName NVARCHAR(100) = N'Science Fiction';
DECLARE @_TotalCopies INT = 5;
DECLARE @_Description NVARCHAR(MAX) = N'A comedy science fiction series by Douglas Adams. First published in 1979.';
DECLARE @_AuthorNamesList NVARCHAR(MAX) = N'Douglas Adams';

EXEC Library.AddBook
    @_Title = @_Title,
    @_ISBN = @_ISBN,
    @_PublicationYear = @_PublicationYear,
    @_Edition = @_Edition,
    @_PublisherName = @_PublisherName,
    @_CategoryName = @_CategoryName,
    @_TotalCopies = @_TotalCopies,
    @_Description = @_Description,
    @_AuthorNamesList = @_AuthorNamesList;


SELECT
    B.BookID,
    B.Title,
    B.ISBN,
    B.PublicationYear,
    B.Edition,
    P.PublisherName,
    C.CategoryName,
    B.TotalCopies,
    B.AvailableCopies,
    B.Description
FROM Library.Books AS B
LEFT JOIN Library.Publishers AS P ON B.PublisherID = P.PublisherID
LEFT JOIN Library.BookCategories AS C ON B.CategoryID = C.CategoryID
WHERE B.ISBN = @_ISBN;









DECLARE @StaffNationalCode NVARCHAR(10) = N'1112223330'; 
DECLARE @StaffFirstName NVARCHAR(100) = N'Ali';
DECLARE @StaffLastName NVARCHAR(100) = N'Rostami';
DECLARE @StaffMemberType NVARCHAR(50) = N'Staff';
DECLARE @StaffContactEmail NVARCHAR(100) = N'ali.rostami@university.edu';
DECLARE @StaffContactPhone NVARCHAR(20) = N'09123456789';

EXEC Library.RegisterMember
    @NationalCode = @StaffNationalCode,
    @FirstName = @StaffFirstName,
    @LastName = @StaffLastName,
    @MemberType = @StaffMemberType,
    @ContactEmail = @StaffContactEmail,
    @ContactPhone = @StaffContactPhone;


SELECT * FROM Library.Members WHERE NationalCode = @StaffNationalCode;

SELECT TOP 1 EventDescription FROM Library.AuditLog WHERE EventType = N'Member Registered' ORDER BY LogID DESC;

GO







-- Declare variables for input parameters
DECLARE @TargetMemberID INT;
DECLARE @TargetBookID INT;
DECLARE @LoanPeriodDays INT = 21; -- You can change the loan period (e.g., 14 or 30 days)

-- 1. Find an active MemberID (example: the first active member)
SELECT TOP 1 @TargetMemberID = MemberID
FROM Library.Members
WHERE Status = 'Active'
ORDER BY MemberID; -- Order by MemberID to ensure consistent selection

IF @TargetMemberID IS NULL
BEGIN
    PRINT N'Error: No active members found in Library.Members table. Please register an active member first.';
    RETURN; -- Stop script execution
END

-- 2. Find a BookID with available copies (example: the first book with available copies)
SELECT TOP 1 @TargetBookID = BookID
FROM Library.Books
WHERE AvailableCopies > 0
ORDER BY BookID; -- Order by BookID to ensure consistent selection

IF @TargetBookID IS NULL
BEGIN
    PRINT N'Error: No available books found in Library.Books table. Please add books with available copies first.';
    RETURN; -- Stop script execution
END

PRINT N'Active MemberID selected: ' + CAST(@TargetMemberID AS NVARCHAR(10));
PRINT N'Available BookID selected: ' + CAST(@TargetBookID AS NVARCHAR(10));
PRINT N'Attempting to borrow BookID: ' + CAST(@TargetBookID AS NVARCHAR(10)) +
      N' by MemberID: ' + CAST(@TargetMemberID AS NVARCHAR(10)) +
      N' for ' + CAST(@LoanPeriodDays AS NVARCHAR(10)) + N' days.';

-- Execute the Library.BorrowBook stored procedure
EXEC Library.BorrowBook
    @MemberID = @TargetMemberID,
    @BookID = @TargetBookID,
    @DueDays = @LoanPeriodDays;

PRINT N'---------------------------------------------------';
PRINT N'Checking borrow details in Library.Borrows table:';
PRINT N'---------------------------------------------------';

-- Verify the borrow record in Library.Borrows table
SELECT
    BorrowID,
    MemberID,
    BookID,
    BorrowDate,
    DueDate,
    ActualReturnDate,
    Status
FROM Library.Borrows
WHERE MemberID = @TargetMemberID AND BookID = @TargetBookID
ORDER BY BorrowID DESC; -- Show the most recent borrow for this member and book

PRINT N'---------------------------------------------------';
PRINT N'Checking available copies in Library.Books table after borrowing:';
PRINT N'---------------------------------------------------';

-- Verify the number of available copies for the book after the borrow operation
SELECT
    BookID,
    Title,
    ISBN,
    TotalCopies,
    AvailableCopies
FROM Library.Books
WHERE BookID = @TargetBookID;

PRINT N'---------------------------------------------------';
PRINT N'Checking the latest entry in AuditLog related to this operation:';
PRINT N'---------------------------------------------------';

-- Check the audit logs for the borrow event (removed LogTimestamp from SELECT)
SELECT TOP 1
    LogID,
    EventType,
    EventDescription,
    UserID -- LogTimestamp column removed from SELECT
FROM Library.AuditLog
WHERE EventType IN (N'Book Borrowed', N'Book Borrow Failed') -- Include both success and failure events
ORDER BY LogID DESC;

GO











-- Add data for test of suggest book

-- Get BookIDs created by the test script (if they don't exist yet)
DECLARE @BookID_HarryPotter INT;
DECLARE @BookID_Dune INT;
SELECT @BookID_HarryPotter = BookID FROM Library.Books WHERE Title = 'Harry Potter and the Sorcerer''s Stone';
SELECT @BookID_Dune = BookID FROM Library.Books WHERE Title = 'Dune'; -- Assuming Dune is also used by Ali in your test script

-- Ensure test members exist (from Add_data_to_Library.sql)
DECLARE @MemberID_Reza INT = 1122334455;
-- Using a different NationalCode to avoid UNIQUE KEY constraint violation
DECLARE @NationalCode_Reza NVARCHAR(10) = N'1122334456'; -- Changed NationalCode

IF NOT EXISTS (SELECT 1 FROM Library.Members WHERE MemberID = @MemberID_Reza)
BEGIN
    PRINT N'Creating test member Reza (ID 1122334455)...';
    -- Set IDENTITY_INSERT ON to allow explicit insertion into identity column
    SET IDENTITY_INSERT Library.Members ON;

    -- Using 'ContactEmail' and 'ContactPhone' as per the Add_data_to_Library.sql provided by user
    INSERT INTO Library.Members (MemberID, FirstName, LastName, NationalCode, MemberType, ContactEmail, ContactPhone, JoinDate, Status)
    VALUES (@MemberID_Reza, N'Reza', N'Karimi', @NationalCode_Reza, N'Student', N'reza.karimi@example.com', N'09121112233', '2024-01-15', N'Active');

    -- Set IDENTITY_INSERT OFF after insertion
    SET IDENTITY_INSERT Library.Members OFF;
END;

-- Add a new book for suggestion, if it doesn't exist
DECLARE @BookID_Martian INT;
SELECT @BookID_Martian = BookID FROM Library.Books WHERE Title = 'The Martian';
IF @BookID_Martian IS NULL
BEGIN
    PRINT N'Creating new book: The Martian...';
    DECLARE @CategoryID_SciFi INT;
    SELECT @CategoryID_SciFi = CategoryID FROM Library.BookCategories WHERE CategoryName = 'Science Fiction';
    IF @CategoryID_SciFi IS NULL
    BEGIN
        INSERT INTO Library.BookCategories (CategoryName, Description) VALUES (N'Science Fiction', N'Fiction based on imagined future scientific or technological advances.');
        SET @CategoryID_SciFi = SCOPE_IDENTITY();
    END;

    -- Ensure Author and Publisher for The Martian exist (using dummy data if not found)
    DECLARE @AuthorID_AndyWeir INT;
    SELECT @AuthorID_AndyWeir = AuthorID FROM Library.Authors WHERE FirstName = N'Andy' AND LastName = N'Weir';
    IF @AuthorID_AndyWeir IS NULL
    BEGIN
        INSERT INTO Library.Authors (FirstName, LastName, Biography, DateOfBirth) VALUES (N'Andy', N'Weir', N'American', '1972-06-16');
        SET @AuthorID_AndyWeir = SCOPE_IDENTITY();
    END;

    DECLARE @PublisherID_Crown INT;
    SELECT @PublisherID_Crown = PublisherID FROM Library.Publishers WHERE PublisherName = N'Crown';
    IF @PublisherID_Crown IS NULL
    BEGIN
        -- Removed any contact-related column for Publishers based on repeated 'Invalid column name' errors
        INSERT INTO Library.Publishers (PublisherName, Address) VALUES (N'Crown', N'New York, NY');
        SET @PublisherID_Crown = SCOPE_IDENTITY();
    END;

    -- Corrected INSERT INTO Library.Books (removed AuthorID, added PublicationYear, Edition, Description as per user's schema)
    INSERT INTO Library.Books (Title, ISBN, PublicationYear, Edition, PublisherID, CategoryID, TotalCopies, AvailableCopies, Description)
    VALUES (N'The Martian', N'9780804139021', 2011, N'First Edition', @PublisherID_Crown, @CategoryID_SciFi, 2, 2, N'An astronaut tries to survive on Mars.');
    SET @BookID_Martian = SCOPE_IDENTITY();

    -- Add entry to Library.BookAuthors for The Martian
    IF @BookID_Martian IS NOT NULL AND @AuthorID_AndyWeir IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Library.BookAuthors WHERE BookID = @BookID_Martian AND AuthorID = @AuthorID_AndyWeir)
        INSERT INTO Library.BookAuthors (BookID, AuthorID) VALUES (@BookID_Martian, @AuthorID_AndyWeir);
END;

-- Clean up any existing borrows for Reza for these specific books (to ensure fresh test)
DELETE FROM Library.Borrows
WHERE MemberID = @MemberID_Reza AND BookID IN (SELECT BookID FROM Library.Books WHERE Title IN ('Harry Potter and the Sorcerer''s Stone', 'Dune', 'The Martian'));

-- Make Reza borrow books to create common history with Ali and a new suggestion
-- Make sure to use the BorrowBook procedure we created/updated
PRINT N'Simulating Reza (1122334455) borrowing books...';

-- Reza borrows Harry Potter (common with Ali)
IF @BookID_HarryPotter IS NOT NULL AND @MemberID_Reza IS NOT NULL
BEGIN
    EXEC Library.BorrowBook @MemberID = @MemberID_Reza, @BookID = @BookID_HarryPotter;
END;

-- Reza borrows The Martian (new suggestion for Ali)
IF @BookID_Martian IS NOT NULL AND @MemberID_Reza IS NOT NULL
BEGIN
    EXEC Library.BorrowBook @MemberID = @MemberID_Reza, @BookID = @BookID_Martian;
END;

PRINT N'Test data setup for collaborative filtering complete.';


PRINT N'-------------------------------------------------------------------------------------';
PRINT N'Enhanced Test Script for Library.SuggestBooksForMember Stored Procedure';
PRINT N'This script ensures diverse borrowing history for a test member and then calls the suggestion procedure.';
PRINT N'It first sets up necessary book categories and books if they do not exist.';
PRINT N'-------------------------------------------------------------------------------------';

-- Declare test variables
DECLARE @TestMemberID_Ali INT;
DECLARE @BookID_Fiction INT;
DECLARE @BookID_Fantasy INT;
DECLARE @BookID_SciFi INT;
DECLARE @BookID_Mystery INT;
DECLARE @BookID_History INT;

DECLARE @CategoryID_Fiction INT;
DECLARE @CategoryID_Fantasy INT;
DECLARE @CategoryID_SciFi INT;
DECLARE @CategoryID_Mystery INT;
DECLARE @CategoryID_History INT;

-- Retrieve Ali's MemberID (assuming NationalCode '1234567890' from Add_data_to_Library.sql)
SELECT @TestMemberID_Ali = MemberID FROM Library.Members WHERE NationalCode = N'1234567890';

IF @TestMemberID_Ali IS NULL
BEGIN
    PRINT N'Error: Test member (Ali, NationalCode 1234567890) not found.';
    PRINT N'Please ensure you have executed Add_data_to_Library.sql or added a member with NationalCode 1234567890.';
    RETURN;
END;
PRINT N'Using TestMemberID: ' + CAST(@TestMemberID_Ali AS NVARCHAR(10)) + N' (Ali) for demonstration.';

-- Ensure necessary categories exist and get their IDs
PRINT N'Ensuring test categories exist...';
IF NOT EXISTS (SELECT 1 FROM Library.BookCategories WHERE CategoryName = N'Fiction')
    INSERT INTO Library.BookCategories (CategoryName, Description) VALUES (N'Fiction', N'General fictional stories.');
IF NOT EXISTS (SELECT 1 FROM Library.BookCategories WHERE CategoryName = N'Fantasy')
    INSERT INTO Library.BookCategories (CategoryName, Description) VALUES (N'Fantasy', N'Stories with magic and mythical creatures.');
IF NOT EXISTS (SELECT 1 FROM Library.BookCategories WHERE CategoryName = N'Science Fiction')
    INSERT INTO Library.BookCategories (CategoryName, Description) VALUES (N'Science Fiction', N'Speculative fiction with advanced technology or space.');
IF NOT EXISTS (SELECT 1 FROM Library.BookCategories WHERE CategoryName = N'Mystery')
    INSERT INTO Library.BookCategories (CategoryName, Description) VALUES (N'Mystery', N'Stories involving a puzzling crime or situation.');
IF NOT EXISTS (SELECT 1 FROM Library.BookCategories WHERE CategoryName = N'History')
    INSERT INTO Library.BookCategories (CategoryName, Description) VALUES (N'History', N'Non-fiction books about historical events and figures.');

SELECT @CategoryID_Fiction = CategoryID FROM Library.BookCategories WHERE CategoryName = N'Fiction';
SELECT @CategoryID_Fantasy = CategoryID FROM Library.BookCategories WHERE CategoryName = N'Fantasy';
SELECT @CategoryID_SciFi = CategoryID FROM Library.BookCategories WHERE CategoryName = N'Science Fiction';
SELECT @CategoryID_Mystery = CategoryID FROM Library.BookCategories WHERE CategoryName = N'Mystery';
SELECT @CategoryID_History = CategoryID FROM Library.BookCategories WHERE CategoryName = N'History';

-- Ensure test books exist and have available copies
PRINT N'Ensuring test books exist and are available...';
-- Book 1: Fiction (e.g., The Kite Runner)
SELECT TOP 1 @BookID_Fiction = BookID FROM Library.Books WHERE Title = N'The Kite Runner' AND CategoryID = @CategoryID_Fiction;
IF @BookID_Fiction IS NULL
BEGIN
    INSERT INTO Library.Books (Title, ISBN, PublicationYear, TotalCopies, AvailableCopies, CategoryID)
    VALUES (N'The Kite Runner', '9780143034972', 2003, 5, 5, @CategoryID_Fiction);
    SELECT @BookID_Fiction = SCOPE_IDENTITY();
END;
UPDATE Library.Books SET AvailableCopies = TotalCopies WHERE BookID = @BookID_Fiction;

-- Book 2: Fantasy (e.g., Harry Potter and the Sorcerer''s Stone)
SELECT TOP 1 @BookID_Fantasy = BookID FROM Library.Books WHERE Title = N'Harry Potter and the Sorcerer''s Stone' AND CategoryID = @CategoryID_Fantasy;
IF @BookID_Fantasy IS NULL
BEGIN
    INSERT INTO Library.Books (Title, ISBN, PublicationYear, TotalCopies, AvailableCopies, CategoryID)
    VALUES (N'Harry Potter and the Sorcerer''s Stone', '9780590353403', 1997, 4, 4, @CategoryID_Fantasy);
    SELECT @BookID_Fantasy = SCOPE_IDENTITY();
END;
UPDATE Library.Books SET AvailableCopies = TotalCopies WHERE BookID = @BookID_Fantasy;

-- Book 3: Science Fiction (e.g., Dune)
SELECT TOP 1 @BookID_SciFi = BookID FROM Library.Books WHERE Title = N'Dune' AND CategoryID = @CategoryID_SciFi;
IF @BookID_SciFi IS NULL
BEGIN
    INSERT INTO Library.Books (Title, ISBN, PublicationYear, TotalCopies, AvailableCopies, CategoryID)
    VALUES (N'Dune', '9780441013593', 1965, 3, 3, @CategoryID_SciFi);
    SELECT @BookID_SciFi = SCOPE_IDENTITY();
END;
UPDATE Library.Books SET AvailableCopies = TotalCopies WHERE BookID = @BookID_SciFi;

-- Book 4: Another book in Fiction (for suggestion) (e.g., To Kill a Mockingbird)
DECLARE @BookID_Fiction_Suggest INT;
SELECT TOP 1 @BookID_Fiction_Suggest = BookID FROM Library.Books WHERE Title = N'To Kill a Mockingbird' AND CategoryID = @CategoryID_Fiction;
IF @BookID_Fiction_Suggest IS NULL
BEGIN
    INSERT INTO Library.Books (Title, ISBN, PublicationYear, TotalCopies, AvailableCopies, CategoryID)
    VALUES (N'To Kill a Mockingbird', '9780446310789', 1960, 3, 3, @CategoryID_Fiction);
    SELECT @BookID_Fiction_Suggest = SCOPE_IDENTITY();
END;
UPDATE Library.Books SET AvailableCopies = TotalCopies WHERE BookID = @BookID_Fiction_Suggest;

-- Book 5: Another book in Fantasy (for suggestion) (e.g., The Hobbit)
DECLARE @BookID_Fantasy_Suggest INT;
SELECT TOP 1 @BookID_Fantasy_Suggest = BookID FROM Library.Books WHERE Title = N'The Hobbit' AND CategoryID = @CategoryID_Fantasy;
IF @BookID_Fantasy_Suggest IS NULL
BEGIN
    INSERT INTO Library.Books (Title, ISBN, PublicationYear, TotalCopies, AvailableCopies, CategoryID)
    VALUES (N'The Hobbit', '9780345339683', 1937, 3, 3, @CategoryID_Fantasy);
    SELECT @BookID_Fantasy_Suggest = SCOPE_IDENTITY();
END;
UPDATE Library.Books SET AvailableCopies = TotalCopies WHERE BookID = @BookID_Fantasy_Suggest;

-- Clean up any existing borrows for Ali for a clean test run
PRINT N'Cleaning up existing borrows for TestMemberID ' + CAST(@TestMemberID_Ali AS NVARCHAR(10)) + N'...';
DELETE FROM Library.Borrows WHERE MemberID = @TestMemberID_Ali;
PRINT N'Existing borrows for Ali cleaned. (Rows affected: ' + CAST(@@ROWCOUNT AS NVARCHAR(10)) + N')';

-- Simulate diverse borrowing history for Ali
PRINT N'Simulating diverse borrowing history for Ali...';
BEGIN TRY
    PRINT N'Borrowing "The Kite Runner" (Fiction)...';
    EXEC Library.BorrowBook @MemberID = @TestMemberID_Ali, @BookID = @BookID_Fiction;

    PRINT N'Borrowing "Harry Potter and the Sorcerer''s Stone" (Fantasy)...';
    EXEC Library.BorrowBook @MemberID = @TestMemberID_Ali, @BookID = @BookID_Fantasy;

    PRINT N'Borrowing "Dune" (Science Fiction)...';
    EXEC Library.BorrowBook @MemberID = @TestMemberID_Ali, @BookID = @BookID_SciFi;

    -- Return one book to ensure suggestions also consider returned books' categories
    PRINT N'Returning "The Kite Runner"...';
    EXEC Library.ReturnBook @MemberID = @TestMemberID_Ali, @BookID = @BookID_Fiction;

END TRY
BEGIN CATCH
    PRINT N'Warning: Could not simulate borrowing history for demo. Error: ' + ERROR_MESSAGE();
    PRINT N'This might be due to issues with the BorrowBook/ReturnBook procedures or existing data. Proceeding with existing data.';
END CATCH;

-- Call the book suggestion procedure for Ali
PRINT N'---------------------------------------------------';
PRINT N'Calling Library.SuggestBooksForMember for Ali (TestMemberID: ' + CAST(@TestMemberID_Ali AS NVARCHAR(10)) + N'):';
PRINT N'---------------------------------------------------';

EXEC Library.SuggestBooksForMember @TestMemberID_Ali, 5; -- Request 5 suggestions

PRINT N'---------------------------------------------------';
PRINT N'End of Suggestion Procedure Test.';
PRINT N'---------------------------------------------------';

-- Optional Cleanup Section:
-- If you wish to revert the changes made by this test script, uncomment the section below.

PRINT N'Cleaning up test borrows for Ali...';
DELETE FROM Library.Borrows WHERE MemberID = @TestMemberID_Ali
    AND BookID IN (@BookID_Fiction, @BookID_Fantasy, @BookID_SciFi);

-- Revert AvailableCopies for the books used in this test
-- Note: This is a simplified cleanup. In a real scenario, you'd need to correctly
-- re-evaluate AvailableCopies based on remaining active borrows if any.
-- UPDATE Library.Books SET AvailableCopies = TotalCopies WHERE BookID IN (@BookID_Fiction, @BookID_Fantasy, @BookID_SciFi);
PRINT N'Test data cleanup for Ali completed.';


GO


--======================================================================= Triggers ========================================================================


-- Declare variables
DECLARE @MemberA_ID INT;
DECLARE @MemberB_ID INT;
DECLARE @Book_ID INT;
DECLARE @BorrowID_A INT; -- Borrow ID for Member A

-- Find two distinct active members
SELECT TOP 1 @MemberA_ID = MemberID
FROM Library.Members
WHERE Status = 'Active'
ORDER BY MemberID ASC;

SELECT TOP 1 @MemberB_ID = MemberID
FROM Library.Members
WHERE Status = 'Active' AND MemberID <> @MemberA_ID
ORDER BY MemberID DESC;

-- Find an available book
SELECT TOP 1 @Book_ID = BookID
FROM Library.Books
WHERE AvailableCopies > 0;

-- Pre-checks for necessary data
IF @MemberA_ID IS NULL OR @MemberB_ID IS NULL OR @MemberA_ID = @MemberB_ID
BEGIN
    PRINT N'Error: Could not find two distinct active members. Please ensure you have at least two active members registered (e.g., by running RegisterMember procedure).';
    RETURN;
END

IF @Book_ID IS NULL
BEGIN
    PRINT N'Error: No available books found. Please add books with available copies (e.g., by running AddBook procedure).';
    RETURN;
END

PRINT N'Found Member A (Borrower): MemberID = ' + CAST(@MemberA_ID AS NVARCHAR(10));
PRINT N'Found Member B (Reserver): MemberID = ' + CAST(@MemberB_ID AS NVARCHAR(10));
PRINT N'Found Book to use: BookID = ' + CAST(@Book_ID AS NVARCHAR(10));

-- Clean up any previous borrows/reservations for this specific scenario
-- This ensures a clean test if the script is run multiple times.
BEGIN TRY
    UPDATE Library.Borrows
    SET ActualReturnDate = GETDATE(), Status = 'Returned'
    WHERE MemberID IN (@MemberA_ID, @MemberB_ID) AND BookID = @Book_ID AND ActualReturnDate IS NULL;

    DELETE FROM Library.Reservations WHERE MemberID IN (@MemberA_ID, @MemberB_ID) AND BookID = @Book_ID;

    UPDATE B
    SET B.AvailableCopies = B.TotalCopies - ISNULL((SELECT COUNT(*) FROM Library.Borrows WHERE BookID = B.BookID AND ActualReturnDate IS NULL), 0)
    FROM Library.Books AS B
    WHERE B.BookID = @Book_ID;

    PRINT N'Cleaned up previous test data for MemberIDs ' + CAST(@MemberA_ID AS NVARCHAR(10)) + ' and ' + CAST(@MemberB_ID AS NVARCHAR(10)) + ' for BookID ' + CAST(@Book_ID AS NVARCHAR(10)) + '.';
END TRY
BEGIN CATCH
    PRINT N'Warning: An error occurred during cleanup. This might affect test consistency. Error: ' + ERROR_MESSAGE();
END CATCH;


-- Scenario Step 1: Member A borrows the book
PRINT N'---------------------------------------------------';
PRINT N'Step 1: Member A (' + CAST(@MemberA_ID AS NVARCHAR(10)) + ') borrows Book ' + CAST(@Book_ID AS NVARCHAR(10)) + '.';
PRINT N'---------------------------------------------------';
BEGIN TRY
    EXEC Library.BorrowBook
        @MemberID = @MemberA_ID,
        @BookID = @Book_ID;

    SELECT TOP 1 @BorrowID_A = BorrowID
    FROM Library.Borrows
    WHERE MemberID = @MemberA_ID AND BookID = @Book_ID AND ActualReturnDate IS NULL
    ORDER BY BorrowDate DESC;

    IF @BorrowID_A IS NULL
    BEGIN
        RAISERROR('Error: Failed to borrow book for Member A. Cannot proceed with trigger demo.', 16, 1);
        RETURN;
    END
    PRINT N'Book borrowed successfully by Member A. BorrowID: ' + CAST(@BorrowID_A AS NVARCHAR(10));
END TRY
BEGIN CATCH
    PRINT N'Error during Step 1 (Borrow Book). This step must succeed to proceed. Error: ' + ERROR_MESSAGE();
    RETURN;
END CATCH;

-- Scenario Step 2: Member B reserves the same book (with ExpirationDate)
PRINT N'---------------------------------------------------';
PRINT N'Step 2: Member B (' + CAST(@MemberB_ID AS NVARCHAR(10)) + ') reserves Book ' + CAST(@Book_ID AS NVARCHAR(10)) + '.';
PRINT N'Adding a default ExpirationDate (7 days from now) based on your table schema error.';
PRINT N'---------------------------------------------------';
BEGIN TRY
    INSERT INTO Library.Reservations (BookID, MemberID, ReservationDate, ExpirationDate, Status)
    VALUES (@Book_ID, @MemberB_ID, GETDATE(), DATEADD(DAY, 7, GETDATE()), 'Active'); -- Added ExpirationDate
    PRINT N'Book reserved successfully by Member B.';
END TRY
BEGIN CATCH
    PRINT N'Error during Step 2 (Reserve Book). This step must succeed to proceed. Error: ' + ERROR_MESSAGE();
    RETURN;
END CATCH;

-- Scenario Step 3: Attempt to renew the book for Member A
-- This update should now trigger trg_Library_PreventRenewalIfReserved
PRINT N'---------------------------------------------------';
PRINT N'Step 3: Attempting to renew BorrowID ' + CAST(@BorrowID_A AS NVARCHAR(10)) + ' for Member A.';
PRINT N'EXPECTING THE TRIGGER TO PREVENT THIS RENEWAL.';
PRINT N'---------------------------------------------------';

BEGIN TRY
    DECLARE @OriginalDueDate DATE;
    SELECT @OriginalDueDate = DueDate FROM Library.Borrows WHERE BorrowID = @BorrowID_A;
    PRINT N'Original DueDate for BorrowID ' + CAST(@BorrowID_A AS NVARCHAR(10)) + ': ' + CONVERT(NVARCHAR(10), @OriginalDueDate, 120);

    UPDATE Library.Borrows
    SET DueDate = DATEADD(DAY, 14, DueDate)
    WHERE BorrowID = @BorrowID_A;

    -- This line should NOT be reached if the trigger works
    PRINT N'WARNING: Renewal attempt unexpectedly succeeded. The trigger might not be working as expected or the conditions were not met.';
END TRY
BEGIN CATCH
    DECLARE @ErrorMessage NVARCHAR(MAX) = ERROR_MESSAGE();
    PRINT N'SUCCESS: Renewal attempt was prevented by the trigger!';
    PRINT N'Error Message from Trigger: ' + @ErrorMessage;
END CATCH;

-- Verification
PRINT N'---------------------------------------------------';
PRINT N'Verification Steps:';
PRINT N'---------------------------------------------------';

PRINT N'1. Check Member A''s borrow record (DueDate should NOT have changed if trigger worked):';
SELECT
    BorrowID,
    MemberID,
    BookID,
    BorrowDate,
    DueDate,
    ActualReturnDate,
    Status
FROM Library.Borrows
WHERE BorrowID = @BorrowID_A;

PRINT N'2. Check Member B''s reservation record (should still be Active):';
SELECT
    ReservationID,
    BookID,
    MemberID,
    ReservationDate,
    ExpirationDate,
    Status
FROM Library.Reservations
WHERE BookID = @Book_ID AND MemberID = @MemberB_ID;

PRINT N'3. Check Library.AuditLog for "Unauthorized Renewal Attempt" entry (look for Persian text in description):';
SELECT TOP 5
    LogID,
    EventType,
    EventDescription,
    UserID
FROM Library.AuditLog
WHERE EventType = N'Unauthorized Renewal Attempt'
ORDER BY LogID DESC;

PRINT N'---------------------------------------------------';
PRINT N'End of Trigger Demonstration.';
PRINT N'Please note that the AuditLog entry created by the trigger will contain Persian text';
PRINT N'as it is hardcoded within your trigger definition, which I cannot modify based on your request.';
PRINT N'---------------------------------------------------';

GO








PRINT N'-------------------------------------------------------------------------------------';
PRINT N'Demonstrating Library.trg_Library_PreventBorrowIfBookUnavailable Trigger (Corrected Script)';
PRINT N'This script will demonstrate two scenarios: attempting to borrow an unavailable book (should be prevented)';
PRINT N'and attempting to borrow an available book (should succeed).';
PRINT N'-------------------------------------------------------------------------------------';

-- Declare variables for the entire demonstration section
DECLARE @MemberID_Test INT;
DECLARE @BookID_Unavailable INT;
DECLARE @BookID_Available INT;
DECLARE @OriginalCopies_Unavailable INT;
DECLARE @BorrowID_Success INT;
DECLARE @ErrorMessage NVARCHAR(MAX); 
DECLARE @ErrorSeverity INT;          
DECLARE @ErrorState INT;             


-- Find an active member to use for tests
SELECT TOP 1 @MemberID_Test = MemberID FROM Library.Members WHERE Status = 'Active';

IF @MemberID_Test IS NULL
BEGIN
    PRINT N'Error: No active members found. Please ensure you have at least one active member in Library.Members table.';
    RETURN;
END;
PRINT N'Using MemberID for tests: ' + CAST(@MemberID_Test AS NVARCHAR(10));

-- Scenario 1: Attempt to borrow an UNAVAILABLE book
PRINT N'---------------------------------------------------';
PRINT N'Scenario 1: Attempting to borrow an UNAVAILABLE book.';
PRINT N'EXPECTING THE TRIGGER TO PREVENT THE BORROW.';
PRINT N'---------------------------------------------------';

-- Find a book to temporarily make unavailable
SELECT TOP 1 @BookID_Unavailable = BookID, @OriginalCopies_Unavailable = AvailableCopies
FROM Library.Books
WHERE TotalCopies > 0
ORDER BY BookID DESC;

IF @BookID_Unavailable IS NULL
BEGIN
    PRINT N'Error: No books found in Library.Books table. Please add some books to demonstrate the trigger.';
    RETURN;
END;

PRINT N'Book selected for unavailability test: BookID = ' + CAST(@BookID_Unavailable AS NVARCHAR(10)) + ', Original AvailableCopies = ' + CAST(@OriginalCopies_Unavailable AS NVARCHAR(10));

-- Clean up any existing active borrows for this book by the test member to ensure a clean test
UPDATE Library.Borrows
SET ActualReturnDate = GETDATE(), Status = 'Returned'
WHERE MemberID = @MemberID_Test AND BookID = @BookID_Unavailable AND ActualReturnDate IS NULL;

-- Temporarily set AvailableCopies to 0 for this book
UPDATE Library.Books
SET AvailableCopies = 0
WHERE BookID = @BookID_Unavailable;
PRINT N'Set AvailableCopies to 0 for BookID ' + CAST(@BookID_Unavailable AS NVARCHAR(10)) + ' for this test.';

-- Attempt to borrow the unavailable book using the stored procedure
BEGIN TRY
    EXEC Library.BorrowBook
        @MemberID = @MemberID_Test,
        @BookID = @BookID_Unavailable;

    PRINT N'WARNING: Borrow operation for unavailable book unexpectedly SUCCEEDED! The trigger might not be working as expected.';
END TRY
BEGIN CATCH
    SELECT
        @ErrorMessage = ERROR_MESSAGE(),
        @ErrorSeverity = ERROR_SEVERITY(),
        @ErrorState = ERROR_STATE();

    PRINT N'SUCCESS: Borrow operation for unavailable book was PREVENTED by the trigger!';
    PRINT N'Error Message from Trigger: ' + @ErrorMessage;
END CATCH;

-- Verification for Scenario 1
PRINT N'Verification for Scenario 1: Check if a borrow record for BookID ' + CAST(@BookID_Unavailable AS NVARCHAR(10)) + ' exists (expected: 0 rows):';
SELECT BorrowID, MemberID, BookID, BorrowDate, DueDate, ActualReturnDate, Status
FROM Library.Borrows
WHERE MemberID = @MemberID_Test AND BookID = @BookID_Unavailable AND ActualReturnDate IS NULL;


PRINT N'Check Library.AuditLog for "Borrow Failed (No Copies)" or "Borrow Failed (Book Not Found)" entry:';
SELECT TOP 5 LogID, EventType, EventDescription, UserID
FROM Library.AuditLog
WHERE EventType LIKE N'Borrow Failed%'
ORDER BY LogID DESC;
PRINT N'(Expected: 0 rows affected here if the trigger''s ROLLBACK TRANSACTION prevents the audit log entry, otherwise 1 row)';


-- Restore AvailableCopies for the book used in Scenario 1
UPDATE Library.Books
SET AvailableCopies = @OriginalCopies_Unavailable
WHERE BookID = @BookID_Unavailable;
PRINT N'Restored AvailableCopies to ' + CAST(@OriginalCopies_Unavailable AS NVARCHAR(10)) + ' for BookID ' + CAST(@BookID_Unavailable AS NVARCHAR(10)) + '.';


-- Scenario 2: Attempt to borrow an AVAILABLE book
PRINT N'---------------------------------------------------';
PRINT N'Scenario 2: Attempting to borrow an AVAILABLE book.';
PRINT N'EXPECTING THE BORROW TO SUCCEED.';
PRINT N'---------------------------------------------------';

-- Find a book that has available copies
SELECT TOP 1 @BookID_Available = BookID
FROM Library.Books
WHERE AvailableCopies > 0
ORDER BY BookID ASC;

IF @BookID_Available IS NULL
BEGIN
    PRINT N'Error: No available books found for success test. Please ensure some books have AvailableCopies > 0 in Library.Books table.';
    RETURN;
END;
PRINT N'Book selected for availability test: BookID = ' + CAST(@BookID_Available AS NVARCHAR(10)) + '.';

-- Clean up any existing active borrows for this book by the test member
UPDATE Library.Borrows
SET ActualReturnDate = GETDATE(), Status = 'Returned'
WHERE MemberID = @MemberID_Test AND BookID = @BookID_Available AND ActualReturnDate IS NULL;

-- Attempt to borrow the available book using the stored procedure
BEGIN TRY
    EXEC Library.BorrowBook
        @MemberID = @MemberID_Test,
        @BookID = @BookID_Available;

    SELECT TOP 1 @BorrowID_Success = BorrowID
    FROM Library.Borrows
    WHERE MemberID = @MemberID_Test AND BookID = @BookID_Available AND ActualReturnDate IS NULL
    ORDER BY BorrowDate DESC;

    IF @BorrowID_Success IS NOT NULL
    BEGIN
        PRINT N'SUCCESS: Borrow operation for available book SUCCEEDED. BorrowID: ' + CAST(@BorrowID_Success AS NVARCHAR(10));
    END
    ELSE
    BEGIN
        PRINT N'WARNING: Borrow operation for available book FAILED unexpectedly. No borrow record found.';
    END
END TRY
BEGIN CATCH
    -- No need to DECLARE here, variables are already declared at the top
    SELECT
        @ErrorMessage = ERROR_MESSAGE(),
        @ErrorSeverity = ERROR_SEVERITY(),
        @ErrorState = ERROR_STATE();

    PRINT N'ERROR: Borrow operation for available book FAILED unexpectedly. Error: ' + @ErrorMessage;
END CATCH;

-- Verification for Scenario 2
PRINT N'Verification for Scenario 2: Check if borrow record exists for BookID ' + CAST(@BookID_Available AS NVARCHAR(10)) + ' and AvailableCopies decreased:';
SELECT BorrowID, MemberID, BookID, BorrowDate, DueDate, ActualReturnDate, Status
FROM Library.Borrows
WHERE BorrowID = @BorrowID_Success;

PRINT N'Check updated AvailableCopies for BookID ' + CAST(@BookID_Available AS NVARCHAR(10)) + ':';
SELECT BookID, Title, TotalCopies, AvailableCopies FROM Library.Books WHERE BookID = @BookID_Available;
