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
    @_AuthorNamesList NVARCHAR(MAX) -- Comma-separated full names
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


IF OBJECT_ID('Library.RegisterMember', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE Library.RegisterMember;
    PRINT 'Procedure Library.RegisterMember dropped successfully.';
END
ELSE
BEGIN
    PRINT 'Procedure Library.RegisterMember does not exist.';
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
    SET XACT_ABORT ON; -- Ensures transaction aborts on runtime error

    DECLARE @LogDescription NVARCHAR(MAX);
    DECLARE @NewMemberID INT;
    DECLARE @EducationEntityExists BIT = 0;
    DECLARE @EventUser NVARCHAR(50) = SUSER_SNAME();

    PRINT N'DEBUG_RM: Starting Library.RegisterMember for NationalCode: ' + @NationalCode + N', MemberType: ' + @MemberType;

    -- Set CONTEXT_INFO to signal that this operation originates from RegisterMember
    SET CONTEXT_INFO 0x01;
    PRINT N'DEBUG_RM: CONTEXT_INFO set to 0x01.';

    BEGIN TRY
        -- 1. Validate the @MemberType parameter against allowed values
        IF @MemberType NOT IN ('Student', 'Professor', 'Staff')
        BEGIN
            RAISERROR('Error: Invalid MemberType. Must be ''Student'', ''Professor'', or ''Staff''.', 16, 1);
            RETURN;
        END
        PRINT N'DEBUG_RM: MemberType validation passed.';

        -- 2. Validate @NationalCode for uniqueness in Library.Members table
        IF EXISTS (SELECT 1 FROM Library.Members WHERE NationalCode = @NationalCode)
        BEGIN
            RAISERROR('Error: A member with this National Code (%s) already exists in Library.Members.', 16, 1, @NationalCode);
            RETURN;
        END
        PRINT N'DEBUG_RM: NationalCode uniqueness check passed.';

        -- 3. Handle linking with Education schema based on @MemberType
        IF @MemberType = 'Student'
        BEGIN
            PRINT N'DEBUG_RM: MemberType is Student. Checking Education_StudentID: ' + ISNULL(CAST(@Education_StudentID AS NVARCHAR(10)), 'NULL');
            IF @Education_StudentID IS NOT NULL
            BEGIN
                SET @EducationEntityExists = 1;
                PRINT N'DEBUG_RM: StudentID assumed valid for Education.Students (validation commented).';
            END
            ELSE
            BEGIN
                SELECT @Education_StudentID = StudentID FROM Education.Students WHERE NationalCode = @NationalCode;
                IF @Education_StudentID IS NOT NULL
                    SET @EducationEntityExists = 1;
                PRINT N'DEBUG_RM: Auto-linked StudentID: ' + ISNULL(CAST(@Education_StudentID AS NVARCHAR(10)), 'NULL');
            END
            SET @Education_ProfessorID = NULL;
        END
        ELSE IF @MemberType = 'Professor'
        BEGIN
            PRINT N'DEBUG_RM: MemberType is Professor. Checking Education_ProfessorID: ' + ISNULL(CAST(@Education_ProfessorID AS NVARCHAR(10)), 'NULL');
            IF @Education_ProfessorID IS NOT NULL
            BEGIN
                IF NOT EXISTS (SELECT 1 FROM Education.Professors WHERE ProfessorID = @Education_ProfessorID)
                BEGIN
                    RAISERROR('Error: Provided Education_ProfessorID %d does not exist in Education.Professors.', 16, 1, @Education_ProfessorID);
                    RETURN;
                END
                SET @EducationEntityExists = 1;
                PRINT N'DEBUG_RM: ProfessorID matched in Education.Professors.';
            END
            ELSE
            BEGIN
                PRINT N'Warning: MemberType is ''Professor'' but no Education_ProfessorID was provided, and Education.Professors table does not contain NationalCode for auto-linking. Registering without direct link to Education.Professors.';
            END
            SET @Education_StudentID = NULL;
        END
        ELSE IF @MemberType = 'Staff'
        BEGIN
            SET @Education_StudentID = NULL;
            SET @Education_ProfessorID = NULL;
            PRINT N'DEBUG_RM: MemberType is Staff. No Education link.';
        END

        PRINT N'DEBUG_RM: Attempting INSERT into Library.Members. NationalCode: ' + @NationalCode + N', FirstName: ' + @FirstName + N', LastName: ' + @LastName + N', Email: ' + ISNULL(@ContactEmail, 'NULL') + N', Phone: ' + ISNULL(@ContactPhone, 'NULL') + N', StudentID: ' + ISNULL(CAST(@Education_StudentID AS NVARCHAR(10)), 'NULL') + N', ProfessorID: ' + ISNULL(CAST(@Education_ProfessorID AS NVARCHAR(10)), 'NULL');

        -- Perform the actual insert. This will be intercepted by the INSTEAD OF INSERT trigger.
        INSERT INTO Library.Members (NationalCode, FirstName, LastName, MemberType, ContactEmail, ContactPhone, Education_StudentID, Education_ProfessorID, JoinDate, Status)
        VALUES (@NationalCode, @FirstName, @LastName, @MemberType, @ContactEmail, @ContactPhone, @Education_StudentID, @Education_ProfessorID, GETDATE(), 'Active');

        SET @NewMemberID = SCOPE_IDENTITY();
        PRINT N'DEBUG_RM: Member inserted (via INSTEAD OF trigger). New MemberID: ' + ISNULL(CAST(@NewMemberID AS NVARCHAR(10)), 'NULL (SCOPE_IDENTITY() was NULL)');

        -- 5. Log the successful member registration event in Library.AuditLog
        SET @LogDescription = N'New library member registered. MemberID: ' + ISNULL(CAST(@NewMemberID AS NVARCHAR(10)), 'N/A (Failed Insert)') +
                              N', NationalCode: ' + @NationalCode +
                              N', Type: ' + @MemberType +
                              N', Linked to Education: ' + IIF(@EducationEntityExists = 1, 'Yes', 'No') + '.';
        INSERT INTO Library.AuditLog (EventType, EventDescription, UserID)
        VALUES (N'Member Registered', @LogDescription, @EventUser);
        PRINT N'DEBUG_RM: AuditLog for success inserted.';

        PRINT N'SUCCESS_RM: Member ' + @FirstName + N' ' + @LastName + N' (' + @MemberType + N') registered successfully with MemberID: ' + ISNULL(CAST(@NewMemberID AS NVARCHAR(10)), 'N/A');

    END TRY
    BEGIN CATCH
        -- DO NOT ROLLBACK TRANSACTION HERE. Let the calling transaction handle it.
        DECLARE @ErrorMessage NVARCHAR(MAX), @ErrorSeverity INT, @ErrorState INT;
        SELECT
            @ErrorMessage = ERROR_MESSAGE(),
            @ErrorSeverity = ERROR_SEVERITY(),
            @ErrorState = ERROR_STATE();

        PRINT N'DEBUG_RM: Entering CATCH block. Error: ' + @ErrorMessage;
        SET @LogDescription = N'Error registering new library member for NationalCode ' + ISNULL(@NationalCode, 'UNKNOWN') + N': ' + @ErrorMessage;

        -- Attempt to log failure, but don't re-raise error if AuditLog insert itself fails
        BEGIN TRY
            INSERT INTO Library.AuditLog (EventType, EventDescription, UserID)
            VALUES (N'Member Registration Failed', @LogDescription, @EventUser);
        END TRY
        BEGIN CATCH
            PRINT N'DEBUG_RM: Failed to log error to AuditLog for NationalCode: ' + ISNULL(@NationalCode, 'UNKNOWN') + N'. Secondary error: ' + ERROR_MESSAGE();
        END CATCH;

        -- Re-raise the original error to the calling batch
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH;

    -- Always clear CONTEXT_INFO after the procedure execution, regardless of success or error that might have propagated.
    SET CONTEXT_INFO NULL;
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
    DECLARE @BorrowID INT;

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

        SET @BorrowID = SCOPE_IDENTITY();

        -- 5. Update book availability
        UPDATE Library.Books
        SET AvailableCopies = AvailableCopies - 1
        WHERE BookID = @BookID;

        -- 6. Log audit event
        SET @LogDescription = N'MemberID ' + CAST(@MemberID AS NVARCHAR(10)) +
                              N' borrowed BookID ' + CAST(@BookID AS NVARCHAR(10)) +
                              N' on ' + CONVERT(NVARCHAR(10), @BorrowDate, 120) +
                              N'. Due on ' + CONVERT(NVARCHAR(10), @DueDate, 120) +
                              N'. BorrowID: ' + CAST(@BorrowID AS NVARCHAR(10));
        INSERT INTO Library.AuditLog (EventType, EventDescription, UserID)
        VALUES (N'Book Borrowed', @LogDescription, @EventUser);

        COMMIT TRANSACTION;
        PRINT N'SUCCESS: Book borrowed successfully. BorrowID: ' + CAST(@BorrowID AS NVARCHAR(10));

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrorMessage NVARCHAR(MAX), @ErrorSeverity INT, @ErrorState INT;
        SELECT
            @ErrorMessage = ERROR_MESSAGE(),
            @ErrorSeverity = ERROR_SEVERITY(),
            @ErrorState = ERROR_STATE();

        SET @LogDescription = N'Error borrowing book (BookID: ' + CAST(@BookID AS NVARCHAR(10)) +
                              N', MemberID: ' + CAST(@MemberID AS NVARCHAR(10)) + N'): ' + @ErrorMessage;
        INSERT INTO Library.AuditLog (EventType, EventDescription, UserID)
        VALUES (N'Book Borrow Failed', @LogDescription, @EventUser);

        THROW @ErrorSeverity, @ErrorMessage, @ErrorState;
    END CATCH;
END;
GO
