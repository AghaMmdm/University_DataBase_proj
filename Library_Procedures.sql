USE UniversityDB;
GO


-- Description: Adds a new book title to the Library.Books table and handles its authors.
CREATE PROCEDURE Library.AddBook
    @_Title NVARCHAR(500),
    @_ISBN NVARCHAR(13),
    @_PublicationYear INT,
    @_Edition NVARCHAR(50) = NULL,
    @_PublisherName NVARCHAR(200),
    @_CategoryName NVARCHAR(100),
    @_TotalCopies INT = 1,
    @_Description NVARCHAR(MAX) = NULL,
    @_AuthorNamesList NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LogDescription NVARCHAR(MAX);
    DECLARE @NewBookID INT;
    DECLARE @PublisherID INT;
    DECLARE @CategoryID INT;
    DECLARE @EventUser NVARCHAR(50) = SUSER_SNAME();

    BEGIN TRY
        -- Start Transaction
        BEGIN TRANSACTION;

        -- 1. Validate Input
        IF @_TotalCopies < 1
        BEGIN
            RAISERROR('Error: TotalCopies must be at least 1.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- 2. Handle Publisher: Get existing PublisherID or insert new
        SELECT @PublisherID = PublisherID FROM Library.Publishers WHERE PublisherName = @_PublisherName;
        IF @PublisherID IS NULL
        BEGIN
            INSERT INTO Library.Publishers (PublisherName) VALUES (@_PublisherName);
            SET @PublisherID = SCOPE_IDENTITY();
            SET @LogDescription = N'New Publisher Added: ' + @_PublisherName + N' (ID: ' + CAST(@PublisherID AS NVARCHAR(10)) + N').';
            INSERT INTO Library.AuditLog (EventType, EventDescription, UserID) VALUES (N'Publisher Added', @LogDescription, @EventUser);
        END

        -- 3. Handle Category: Get existing CategoryID or insert new
        SELECT @CategoryID = CategoryID FROM Library.BookCategories WHERE CategoryName = @_CategoryName;
        IF @CategoryID IS NULL
        BEGIN
            INSERT INTO Library.BookCategories (CategoryName) VALUES (@_CategoryName);
            SET @CategoryID = SCOPE_IDENTITY();
            SET @LogDescription = N'New Category Added: ' + @_CategoryName + N' (ID: ' + CAST(@CategoryID AS NVARCHAR(10)) + N').';
            INSERT INTO Library.AuditLog (EventType, EventDescription, UserID) VALUES (N'Category Added', @LogDescription, @EventUser);
        END

        -- 4. Check for existing ISBN
        IF EXISTS (SELECT 1 FROM Library.Books WHERE ISBN = @_ISBN)
        BEGIN
            RAISERROR('Error: A book with this ISBN (%s) already exists.', 16, 1, @_ISBN);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- 5. Insert the new book
        INSERT INTO Library.Books (Title, ISBN, PublicationYear, Edition, PublisherID, CategoryID, TotalCopies, AvailableCopies, Description)
        VALUES (@_Title, @_ISBN, @_PublicationYear, @_Edition, @PublisherID, @CategoryID, @_TotalCopies, @_TotalCopies, @_Description);

        SET @NewBookID = SCOPE_IDENTITY();

        -- 6. Handle Authors: Parse @_AuthorNamesList and link authors to the book
        IF @_AuthorNamesList IS NOT NULL AND LTRIM(RTRIM(@_AuthorNamesList)) <> ''
        BEGIN
            DECLARE @AuthorName NVARCHAR(200);
            DECLARE @AuthorFirstName NVARCHAR(100);
            DECLARE @AuthorLastName NVARCHAR(100);
            DECLARE @AuthorID INT;

            -- Using a temporary table to parse the comma-separated list
            CREATE TABLE #TempAuthors (AuthorFullName NVARCHAR(200));

            INSERT INTO #TempAuthors (AuthorFullName)
            SELECT LTRIM(RTRIM(value))
            FROM STRING_SPLIT(@_AuthorNamesList, ',');

            DECLARE author_cursor CURSOR FOR
            SELECT AuthorFullName FROM #TempAuthors;

            OPEN author_cursor;
            FETCH NEXT FROM author_cursor INTO @AuthorName;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                -- Split full name into first and last name (simple approach, assumes space separated)
                SET @AuthorFirstName = LEFT(@AuthorName, CHARINDEX(' ', @AuthorName + ' ') - 1);
                SET @AuthorLastName = SUBSTRING(@AuthorName, CHARINDEX(' ', @AuthorName + ' ') + 1, LEN(@AuthorName));

                -- Get existing AuthorID or insert new
                SELECT @AuthorID = AuthorID FROM Library.Authors WHERE FirstName = @AuthorFirstName AND LastName = @AuthorLastName;

                IF @AuthorID IS NULL
                BEGIN
                    INSERT INTO Library.Authors (FirstName, LastName) VALUES (@AuthorFirstName, @AuthorLastName);
                    SET @AuthorID = SCOPE_IDENTITY();
                    SET @LogDescription = N'New Author Added: ' + @AuthorFirstName + N' ' + @AuthorLastName + N' (ID: ' + CAST(@AuthorID AS NVARCHAR(10)) + N').';
                    INSERT INTO Library.AuditLog (EventType, EventDescription, UserID) VALUES (N'Author Added', @LogDescription, @EventUser);
                END

                -- Link book to author in BookAuthors (check for duplicates first, though primary key should prevent)
                IF NOT EXISTS (SELECT 1 FROM Library.BookAuthors WHERE BookID = @NewBookID AND AuthorID = @AuthorID)
                BEGIN
                    INSERT INTO Library.BookAuthors (BookID, AuthorID) VALUES (@NewBookID, @AuthorID);
                END

                FETCH NEXT FROM author_cursor INTO @AuthorName;
            END;

            CLOSE author_cursor;
            DEALLOCATE author_cursor;
            DROP TABLE #TempAuthors;
        END

        -- Log the successful book addition
        SET @LogDescription = N'New book added: "' + @_Title + N'" (ISBN: ' + @_ISBN + N'). BookID: ' + CAST(@NewBookID AS NVARCHAR(10));
        INSERT INTO Library.AuditLog (EventType, EventDescription, UserID) VALUES (N'Book Added', @LogDescription, @EventUser);

        COMMIT TRANSACTION;
        PRINT N'SUCCESS: Book "' + @_Title + N'" (ISBN: ' + @_ISBN + N') added successfully with BookID: ' + CAST(@NewBookID AS NVARCHAR(10));

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrorMessage NVARCHAR(MAX), @ErrorSeverity INT, @ErrorState INT;
        SELECT
            @ErrorMessage = ERROR_MESSAGE(),
            @ErrorSeverity = ERROR_SEVERITY(),
            @ErrorState = ERROR_STATE();

        SET @LogDescription = N'Error adding book "' + @_Title + N'" (ISBN: ' + @_ISBN + N'): ' + @ErrorMessage;
        INSERT INTO Library.AuditLog (EventType, EventDescription, UserID) VALUES (N'Book Addition Failed', @LogDescription, @EventUser);

        -- Re-throw the error
        THROW @ErrorSeverity, @ErrorMessage, @ErrorState;
    END CATCH;
END;
GO


-- Description: Registers a new member in the Library.Members table.
--              It links to an existing student or professor from the Education schema
--              based on StudentID/ProfessorID and NationalCode (for students).
--              Assumes Education.Professors DOES NOT have a NationalCode column.
CREATE PROCEDURE Library.RegisterMember
    @NationalCode NVARCHAR(10),
    @FirstName NVARCHAR(100),
    @LastName NVARCHAR(100),
    @MemberType NVARCHAR(50),
    @ContactEmail NVARCHAR(100) = NULL,
    @ContactPhone NVARCHAR(20) = NULL,
    @Education_StudentID INT = NULL,
    @Education_ProfessorID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @LogDescription NVARCHAR(MAX);
    DECLARE @NewMemberID INT;
    DECLARE @EducationEntityExists BIT = 0;
    DECLARE @EventUser NVARCHAR(50) = SUSER_SNAME();
    
    DECLARE @ContextTag VARBINARY(128) = CONVERT(VARBINARY(128), 'RegisterMember');

    SET CONTEXT_INFO @ContextTag;
    PRINT N'DEBUG_RM: CONTEXT_INFO set.';

    BEGIN TRY
        IF @MemberType NOT IN ('Student', 'Professor', 'Staff')
        BEGIN
            RAISERROR('Error: Invalid MemberType. Must be ''Student'', ''Professor'', or ''Staff''.', 16, 1);
            RETURN;
        END

        IF EXISTS (SELECT 1 FROM Library.Members WHERE NationalCode = @NationalCode)
        BEGIN
            RAISERROR('Error: A member with this National Code (%s) already exists.', 16, 1, @NationalCode);
            RETURN;
        END

        IF @MemberType = 'Student'
        BEGIN
            IF @Education_StudentID IS NULL
                SELECT @Education_StudentID = StudentID FROM Education.Students WHERE NationalCode = @NationalCode;

            IF @Education_StudentID IS NOT NULL
                SET @EducationEntityExists = 1;

            SET @Education_ProfessorID = NULL;
        END
        ELSE IF @MemberType = 'Professor'
        BEGIN
            IF @Education_ProfessorID IS NOT NULL
            BEGIN
                IF NOT EXISTS (SELECT 1 FROM Education.Professors WHERE ProfessorID = @Education_ProfessorID)
                BEGIN
                    RAISERROR('Error: ProfessorID %d does not exist.', 16, 1, @Education_ProfessorID);
                    RETURN;
                END
                SET @EducationEntityExists = 1;
            END
            SET @Education_StudentID = NULL;
        END
        ELSE
        BEGIN
            SET @Education_StudentID = NULL;
            SET @Education_ProfessorID = NULL;
        END

        -- درج عضو جدید
        INSERT INTO Library.Members (
            NationalCode, FirstName, LastName, MemberType, ContactEmail, ContactPhone,
            Education_StudentID, Education_ProfessorID, JoinDate, Status
        )
        VALUES (
            @NationalCode, @FirstName, @LastName, @MemberType, @ContactEmail, @ContactPhone,
            @Education_StudentID, @Education_ProfessorID, GETDATE(), 'Active'
        );

        SET @NewMemberID = SCOPE_IDENTITY();

        SET @LogDescription = N'New library member registered. MemberID: ' + CAST(@NewMemberID AS NVARCHAR) +
                              N', NationalCode: ' + @NationalCode +
                              N', Type: ' + @MemberType +
                              N', Linked to Education: ' + IIF(@EducationEntityExists = 1, 'Yes', 'No') + '.';

        INSERT INTO Library.AuditLog (EventType, EventDescription, UserID)
        VALUES (N'Member Registered', @LogDescription, @EventUser);
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(MAX) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();

        SET @LogDescription = N'Error registering member with NationalCode ' + ISNULL(@NationalCode, 'UNKNOWN') + N': ' + @ErrorMessage;

        BEGIN TRY
            INSERT INTO Library.AuditLog (EventType, EventDescription, UserID)
            VALUES (N'Member Registration Failed', @LogDescription, @EventUser);
        END TRY
        BEGIN CATCH
        END CATCH;

        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH

    SET CONTEXT_INFO 0x0;
    PRINT N'DEBUG_RM: CONTEXT_INFO cleared.';
END;
GO



-- Description: Registers a book borrow event for a library member.
--              Validates availability, updates inventory, and logs the borrow.
CREATE PROCEDURE Library.BorrowBook
    @MemberID INT,
    @BookID INT,
    @DueDays INT = 14 -- Default loan period is 14 days
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LogDescription NVARCHAR(MAX);
    DECLARE @EventUser NVARCHAR(50) = SUSER_SNAME();
    DECLARE @AvailableCopies INT;
    DECLARE @BorrowDate DATE = GETDATE();
    DECLARE @DueDate DATE = DATEADD(DAY, @DueDays, @BorrowDate);
    DECLARE @BorrowID INT; -- Declared, but will be NULL if INSERT fails

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Validate Member existence and status
        IF NOT EXISTS (SELECT 1 FROM Library.Members WHERE MemberID = @MemberID AND Status = 'Active')
        BEGIN
            RAISERROR('Error: Invalid or inactive member (MemberID: %d).', 16, 1, @MemberID);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- 2. Validate Book existence
        IF NOT EXISTS (SELECT 1 FROM Library.Books WHERE BookID = @BookID)
        BEGIN
            RAISERROR('Error: Book with ID %d does not exist.', 16, 1, @BookID);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- 3. Check book availability
        SELECT @AvailableCopies = AvailableCopies FROM Library.Books WHERE BookID = @BookID;
        IF @AvailableCopies < 1
        BEGIN
            RAISERROR('Error: No available copies for BookID: %d.', 16, 1, @BookID);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- 4. Insert borrow record
        INSERT INTO Library.Borrows (MemberID, BookID, BorrowDate, DueDate, Status)
        VALUES (@MemberID, @BookID, @BorrowDate, @DueDate, 'Borrowed');

        -- Set @BorrowID *after* successful insert
        SET @BorrowID = SCOPE_IDENTITY();

        -- 5. Update book availability
        UPDATE Library.Books
        SET AvailableCopies = AvailableCopies - 1
        WHERE BookID = @BookID;

        -- 6. Log audit event
        -- Use ISNULL for @BorrowID to prevent NULL concatenation issues
        SET @LogDescription = N'MemberID ' + CAST(@MemberID AS NVARCHAR(10)) +
                              N' borrowed BookID ' + CAST(@BookID AS NVARCHAR(10)) +
                              N' on ' + CONVERT(NVARCHAR(10), @BorrowDate, 120) +
                              N'. Due on ' + CONVERT(NVARCHAR(10), @DueDate, 120) +
                              N'. BorrowID: ' + ISNULL(CAST(@BorrowID AS NVARCHAR(10)), N'N/A');
        INSERT INTO Library.AuditLog (EventType, EventDescription, UserID)
        VALUES (N'Book Borrowed', @LogDescription, @EventUser);

        COMMIT TRANSACTION;
        PRINT N'SUCCESS: Book borrowed successfully. BorrowID: ' + ISNULL(CAST(@BorrowID AS NVARCHAR(10)), N'N/A'); -- Also here for PRINT

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrorMessage NVARCHAR(MAX), @ErrorSeverity INT, @ErrorState INT;
        SELECT
            @ErrorMessage = ERROR_MESSAGE(),
            @ErrorSeverity = ERROR_SEVERITY(),
            @ErrorState = ERROR_STATE();

        -- Log audit event for failed borrow
        -- Make sure this log also doesn't fail due to NULLs
        DECLARE @ErrorLogDescription NVARCHAR(MAX);
        SET @ErrorLogDescription = N'Error borrowing book (BookID: ' + ISNULL(CAST(@BookID AS NVARCHAR(10)), 'N/A') +
                                  N', MemberID: ' + ISNULL(CAST(@MemberID AS NVARCHAR(10)), 'N/A') + N'): ' + ISNULL(@ErrorMessage, 'Unknown Error');
        INSERT INTO Library.AuditLog (EventType, EventDescription, UserID)
        VALUES (N'Book Borrow Failed', @ErrorLogDescription, @EventUser);

        -- Calculate the user-defined error number into a variable first
        DECLARE @UserDefinedErrorNumber INT = 50000 + @ErrorState;
        IF @UserDefinedErrorNumber < 50000
            SET @UserDefinedErrorNumber = 50000;

        THROW @UserDefinedErrorNumber, @ErrorMessage, @ErrorState;
    END CATCH;
END;
GO




-- Create the ReturnBook procedure
CREATE PROCEDURE Library.ReturnBook
    @MemberID INT,
    @BookID INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LogDescription NVARCHAR(MAX);
    DECLARE @EventUser NVARCHAR(50) = SUSER_SNAME();
    DECLARE @ReturnDate DATE = GETDATE();
    DECLARE @BorrowID_ToReturn INT;
    DECLARE @CurrentStatus NVARCHAR(50);

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Find the active borrow record for the given MemberID and BookID
        SELECT TOP 1 @BorrowID_ToReturn = BorrowID, @CurrentStatus = Status
        FROM Library.Borrows
        WHERE MemberID = @MemberID
          AND BookID = @BookID
          AND Status = 'Borrowed' -- Ensure we are returning an active borrow
        ORDER BY BorrowDate DESC; -- Return the most recent borrow if multiple exist

        IF @BorrowID_ToReturn IS NULL
        BEGIN
            RAISERROR('Error: No active borrow record found for MemberID %d and BookID %d.', 16, 1, @MemberID, @BookID);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- If found but already returned (should be caught by WHERE Status = 'Borrowed'), defensive check
        IF @CurrentStatus = 'Returned'
        BEGIN
            RAISERROR('Error: Book with BorrowID %d has already been returned by MemberID %d.', 16, 1, @BorrowID_ToReturn, @MemberID);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Update borrow record status and actual return date
        UPDATE Library.Borrows
        SET Status = 'Returned', ActualReturnDate = @ReturnDate
        WHERE BorrowID = @BorrowID_ToReturn;

        -- Increase book availability
        UPDATE Library.Books
        SET AvailableCopies = AvailableCopies + 1
        WHERE BookID = @BookID;

        -- Log audit event
        SET @LogDescription = N'BookID ' + CAST(@BookID AS NVARCHAR(10)) +
                              N' (BorrowID: ' + CAST(@BorrowID_ToReturn AS NVARCHAR(10)) +
                              N') returned by MemberID ' + CAST(@MemberID AS NVARCHAR(10)) +
                              N' on ' + CONVERT(NVARCHAR(10), @ReturnDate, 120);
        INSERT INTO Library.AuditLog (EventType, EventDescription, UserID)
        VALUES (N'Book Returned', @LogDescription, @EventUser);

        COMMIT TRANSACTION;
        PRINT N'SUCCESS: Book returned successfully. BorrowID: ' + CAST(@BorrowID_ToReturn AS NVARCHAR(10));

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrorMessage NVARCHAR(MAX), @ErrorSeverity INT, @ErrorState INT;
        SELECT
            @ErrorMessage = ERROR_MESSAGE(),
            @ErrorSeverity = ERROR_SEVERITY(),
            @ErrorState = ERROR_STATE();

        -- Log audit event for failed return
        DECLARE @ErrorLogDescription NVARCHAR(MAX);
        SET @ErrorLogDescription = N'Error returning book for MemberID ' + ISNULL(CAST(@MemberID AS NVARCHAR(10)), 'N/A') +
                                  N', BookID ' + ISNULL(CAST(@BookID AS NVARCHAR(10)), 'N/A') +
                                  N': ' + ISNULL(@ErrorMessage, 'Unknown Error');
        INSERT INTO Library.AuditLog (EventType, EventDescription, UserID)
        VALUES (N'Book Return Failed', @ErrorLogDescription, @EventUser);

        -- Calculate the user-defined error number into a variable first
        DECLARE @UserDefinedErrorNumber INT = 50000 + @ErrorState;
        IF @UserDefinedErrorNumber < 50000
            SET @UserDefinedErrorNumber = 50000;

        THROW @UserDefinedErrorNumber, @ErrorMessage, @ErrorState;
    END CATCH;
END;
GO


-- Stored Procedure: Library.SuggestBooksForMember
-- Description: Suggests books to a member based on a collaborative filtering algorithm.
--              (Finds similar users and suggests books they have borrowed that the current user has not)
CREATE PROCEDURE Library.SuggestBooksForMember
    @_MemberID INT,
    @_TopN INT = 3 -- Maximum number of suggestions to return (Default: 3)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON; -- Ensures that errors cause the transaction to roll back completely

    DECLARE @LogDescription NVARCHAR(MAX);
    DECLARE @EventUser NVARCHAR(50) = SUSER_SNAME();

    BEGIN TRY
        -- Validate MemberID
        IF NOT EXISTS (SELECT 1 FROM Library.Members WHERE MemberID = @_MemberID)
        BEGIN
            RAISERROR('Error: Member with ID %d does not exist.', 16, 1, @_MemberID);
            RETURN;
        END;

        -- Log the attempt to suggest books in AuditLog
        SET @LogDescription = N'Attempting to suggest books (Collaborative Filtering) for MemberID: ' + CAST(@_MemberID AS NVARCHAR(10)) + N'.';
        INSERT INTO Library.AuditLog (EventType, EventDescription, UserID)
        VALUES (N'Book Suggestion Attempt (Collaborative)', @LogDescription, @EventUser);

        -- Step 1: Get the list of books currently borrowed by the current member
        SELECT BookID
        INTO #CurrentMemberBorrows
        FROM Library.Borrows
        WHERE MemberID = @_MemberID;

        -- If the current member has not borrowed any books, we cannot provide collaborative suggestions.
        IF NOT EXISTS (SELECT 1 FROM #CurrentMemberBorrows)
        BEGIN
            PRINT N'No books borrowed by MemberID ' + CAST(@_MemberID AS NVARCHAR(10)) + '. Cannot provide collaborative suggestions.';
            -- In this implementation, if no history exists, no suggestions are returned.
            DROP TABLE #CurrentMemberBorrows;
            RETURN;
        END;

        -- Step 2: Find similar members (at least one common book)
        SELECT B.MemberID AS SimilarMemberID, COUNT(DISTINCT B.BookID) AS CommonBooksCount
        INTO #SimilarMembers
        FROM Library.Borrows B
        INNER JOIN #CurrentMemberBorrows CMB ON B.BookID = CMB.BookID
        WHERE B.MemberID <> @_MemberID -- Must not be the current member
        GROUP BY B.MemberID
        HAVING COUNT(DISTINCT B.BookID) >= 1; -- Changed from >= 2 to >= 1

        -- If no similar members are found
        IF NOT EXISTS (SELECT 1 FROM #SimilarMembers)
        BEGIN
            PRINT N'No similar members found for MemberID ' + CAST(@_MemberID AS NVARCHAR(10)) + '. Cannot provide collaborative suggestions.';
            DROP TABLE #CurrentMemberBorrows;
            RETURN;
        END;

        -- Step 3 & 4: Extract suggested books from similar members (that the current member hasn't borrowed)
        -- and order by borrowing frequency among similar users
        SELECT TOP (@_TopN)
            BK.BookID,
            BK.Title,
            BK.ISBN,
            C.CategoryName,
            BK.AvailableCopies,
            COUNT(DISTINCT SB.SimilarMemberID) AS BorrowCountBySimilarUsers -- Number of times borrowed by similar users
        FROM Library.Borrows B_Sim
        INNER JOIN #SimilarMembers SB ON B_Sim.MemberID = SB.SimilarMemberID
        INNER JOIN Library.Books BK ON B_Sim.BookID = BK.BookID
        LEFT JOIN Library.BookCategories C ON BK.CategoryID = C.CategoryID
        WHERE B_Sim.BookID NOT IN (SELECT BookID FROM #CurrentMemberBorrows) -- Books the current member has not yet borrowed
          AND BK.AvailableCopies > 0 -- Must have available copies
        GROUP BY
            BK.BookID, BK.Title, BK.ISBN, C.CategoryName, BK.AvailableCopies
        ORDER BY
            BorrowCountBySimilarUsers DESC, BK.Title; -- Order by borrowing frequency among similar users

        -- Clean up temporary tables
        DROP TABLE #CurrentMemberBorrows;
        DROP TABLE #SimilarMembers;

    END TRY
    BEGIN CATCH
        -- Log any errors in AuditLog
        DECLARE @ErrorMessage NVARCHAR(MAX), @ErrorSeverity INT, @ErrorState INT;
        SELECT
            @ErrorMessage = ERROR_MESSAGE(),
            @ErrorSeverity = ERROR_SEVERITY(),
            @ErrorState = ERROR_STATE();

        SET @LogDescription = N'Error suggesting books (Collaborative Filtering) for MemberID: ' + CAST(@_MemberID AS NVARCHAR(10)) + N'. Error: ' + @ErrorMessage;
        INSERT INTO Library.AuditLog (EventType, EventDescription, UserID)
        VALUES (N'Book Suggestion Error (Collaborative)', @LogDescription, @EventUser);

        -- Re-throw the original error
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);

        -- Clean up temporary tables in case of error
        IF OBJECT_ID('tempdb..#CurrentMemberBorrows') IS NOT NULL
            DROP TABLE #CurrentMemberBorrows;
        IF OBJECT_ID('tempdb..#SimilarMembers') IS NOT NULL
            DROP TABLE #SimilarMembers;
    END CATCH;
END;
GO
