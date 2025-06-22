USE UniversityDB;
GO

-- Drop the stored procedure if it already exists to allow for modifications
IF OBJECT_ID('Library.AddBook', 'P') IS NOT NULL
    DROP PROCEDURE Library.AddBook;
GO

-- Stored Procedure: Library.AddBook
-- Description: Adds a new book title to the Library.Books table and handles its authors.
-- Parameters:
--    @_Title: Title of the book (NVARCHAR(500))
--    @_ISBN: International Standard Book Number (NVARCHAR(13)) - Must be unique
--    @_PublicationYear: Year of publication (INT)
--    @_Edition: Edition of the book (NVARCHAR(50), optional)
--    @_PublisherName: Name of the publisher (NVARCHAR(200)) - If not exists, will be added
--    @_CategoryName: Name of the book category/genre (NVARCHAR(100)) - If not exists, will be added
--    @_TotalCopies: Total number of copies being added initially (INT, default 1)
--    @_Description: Optional description of the book (NVARCHAR(MAX))
--    @_AuthorNamesList: Comma-separated string of author full names (e.g., 'Author1 FirstName LastName, Author2 FirstName LastName')

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


-- Drop the stored procedure if it already exists to allow for modifications
IF OBJECT_ID('Library.RegisterMember', 'P') IS NOT NULL
    DROP PROCEDURE Library.RegisterMember;
GO

-- =========================================================
-- Stored Procedure: Library.RegisterMember
-- Description: Registers a new member in the Library.Members table.
--              It links to an existing student or professor from the Education schema
--              based on StudentID/ProfessorID and NationalCode (for students).
--              Assumes Education.Professors DOES NOT have a NationalCode column.
-- Parameters:
--    @NationalCode: Member's National Code (NVARCHAR(10)) - Primary key, must be unique.
--    @FirstName: Member's first name (NVARCHAR(100)).
--    @LastName: Member's last name (NVARCHAR(100)).
--    @MemberType: Type of member ('Student', 'Professor', 'Staff') (NVARCHAR(50)).
--    @ContactEmail: Member's contact email (NVARCHAR(100), optional).
--    @ContactPhone: Member's contact phone (NVARCHAR(20), optional).
--    @Education_StudentID: Optional. StudentID from Education.Students if MemberType is 'Student' (INT).
--    @Education_ProfessorID: Optional. ProfessorID from Education.Professors if MemberType is 'Professor' (INT).
-- =========================================================
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
    SET NOCOUNT ON; -- Suppress messages indicating the number of rows affected
    DECLARE @LogDescription NVARCHAR(MAX);
    DECLARE @NewMemberID INT; -- To store the newly generated MemberID
    DECLARE @EducationEntityExists BIT = 0; -- Flag to check if a linked Education entity was found
    DECLARE @EventUser NVARCHAR(50) = SUSER_SNAME(); -- Captures the user who executes the SP

    BEGIN TRY
        -- Start a transaction to ensure atomicity (all or nothing)
        BEGIN TRANSACTION;

        -- 1. Validate the @MemberType parameter against allowed values
        IF @MemberType NOT IN ('Student', 'Professor', 'Staff')
        BEGIN
            RAISERROR('Error: Invalid MemberType. Must be ''Student'', ''Professor'', or ''Staff''.', 16, 1);
            ROLLBACK TRANSACTION; -- Rollback the transaction on validation failure
            RETURN; -- Exit the procedure
        END

        -- 2. Validate @NationalCode for uniqueness in Library.Members table
        -- This checks against the UNIQUE CONSTRAINT UQ_Member_NationalCode in Library.Members
        IF EXISTS (SELECT 1 FROM Library.Members WHERE NationalCode = @NationalCode)
        BEGIN
            RAISERROR('Error: A member with this National Code (%s) already exists in Library.Members.', 16, 1, @NationalCode);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- 3. Handle linking with Education schema based on @MemberType
        IF @MemberType = 'Student'
        BEGIN
            -- If StudentID is provided, validate it against Education.Students
            IF @Education_StudentID IS NOT NULL
            BEGIN
                -- Check if provided StudentID and NationalCode match an existing student (Students table HAS NationalCode)
                IF NOT EXISTS (SELECT 1 FROM Education.Students WHERE StudentID = @Education_StudentID AND NationalCode = @NationalCode)
                BEGIN
                    RAISERROR('Error: Provided Education_StudentID %d does not exist or its National Code does not match in Education.Students.', 16, 1, @Education_StudentID);
                    ROLLBACK TRANSACTION;
                    RETURN;
                END
                SET @EducationEntityExists = 1; -- Mark that a linked entity was found
            END
            ELSE
            BEGIN
                -- If StudentID is NOT provided, try to find a matching student by NationalCode in Education.Students
                SELECT @Education_StudentID = StudentID FROM Education.Students WHERE NationalCode = @NationalCode;
                IF @Education_StudentID IS NOT NULL
                    SET @EducationEntityExists = 1; -- Mark that an auto-linked entity was found
            END
            -- Ensure ProfessorID is explicitly NULL for students
            SET @Education_ProfessorID = NULL;
        END
        ELSE IF @MemberType = 'Professor'
        BEGIN
            -- For professors, we assume Education.Professors DOES NOT have NationalCode.
            -- Linking must be via Education_ProfessorID if provided.
            IF @Education_ProfessorID IS NOT NULL
            BEGIN
                -- Validate if provided ProfessorID exists in Education.Professors
                IF NOT EXISTS (SELECT 1 FROM Education.Professors WHERE ProfessorID = @Education_ProfessorID)
                BEGIN
                    RAISERROR('Error: Provided Education_ProfessorID %d does not exist in Education.Professors.', 16, 1, @Education_ProfessorID);
                    ROLLBACK TRANSACTION;
                    RETURN;
                END
                SET @EducationEntityExists = 1; -- Mark that a linked entity was found
            END
            ELSE
            BEGIN
                -- If Education_ProfessorID is NOT provided, we cannot auto-link professors by NationalCode
                -- since Education.Professors supposedly lacks that column.
                -- The member will be registered without a direct link to Education.Professors,
                -- unless a specific ProfessorID is given.
                PRINT N'Warning: MemberType is ''Professor'' but no Education_ProfessorID was provided, and Education.Professors table does not contain NationalCode for auto-linking. Registering without direct link to Education.Professors.';
            END
            -- Ensure StudentID is explicitly NULL for professors
            SET @Education_StudentID = NULL;
        END
        ELSE IF @MemberType = 'Staff'
        BEGIN
            -- For Staff members, ensure no Education links are present
            SET @Education_StudentID = NULL;
            SET @Education_ProfessorID = NULL;
        END

        -- 4. Insert the new member record into Library.Members table
        INSERT INTO Library.Members (NationalCode, FirstName, LastName, MemberType, ContactEmail, ContactPhone, Education_StudentID, Education_ProfessorID, JoinDate, Status)
        VALUES (@NationalCode, @FirstName, @LastName, @MemberType, @ContactEmail, @ContactPhone, @Education_StudentID, @Education_ProfessorID, GETDATE(), 'Active'); -- 'Active' is default status, GETDATE() for JoinDate

        -- Get the MemberID generated for the newly inserted row
        SET @NewMemberID = SCOPE_IDENTITY();

        -- 5. Log the successful member registration event in Library.AuditLog
        SET @LogDescription = N'New library member registered. MemberID: ' + CAST(@NewMemberID AS NVARCHAR(10)) +
                              N', NationalCode: ' + @NationalCode +
                              N', Type: ' + @MemberType +
                              N', Linked to Education: ' + IIF(@EducationEntityExists = 1, 'Yes', 'No') + '.';
        INSERT INTO Library.AuditLog (EventType, EventDescription, UserID)
        VALUES (N'Member Registered', @LogDescription, @EventUser);

        COMMIT TRANSACTION; -- Commit the transaction if all operations were successful
        PRINT N'SUCCESS: Member ' + @FirstName + N' ' + @LastName + N' (' + @MemberType + N') registered successfully with MemberID: ' + CAST(@NewMemberID AS NVARCHAR(10));

    END TRY
    BEGIN CATCH
        -- If an error occurs, roll back the transaction
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        -- Get error details
        DECLARE @ErrorMessage NVARCHAR(MAX), @ErrorSeverity INT, @ErrorState INT;
        SELECT
            @ErrorMessage = ERROR_MESSAGE(),
            @ErrorSeverity = ERROR_SEVERITY(),
            @ErrorState = ERROR_STATE();

        -- Log the error event
        SET @LogDescription = N'Error registering new library member for NationalCode ' + @NationalCode + N': ' + @ErrorMessage;
        INSERT INTO Library.AuditLog (EventType, EventDescription, UserID)
        VALUES (N'Member Registration Failed', @LogDescription, @EventUser);

        -- Re-throw the error to the calling application/user
        THROW @ErrorSeverity, @ErrorMessage, @ErrorState;
    END CATCH;
END;
GO