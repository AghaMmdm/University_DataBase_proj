USE UniversityDB;
GO

-- Description: Automatically registers a new student from Education.Students as a member in Library.Members after successful student insertion.
CREATE TRIGGER Education.trg_Education_Students_CreateLibraryMember
ON Education.Students
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @LogDescription NVARCHAR(MAX);
    DECLARE @EventUser NVARCHAR(50) = SUSER_SNAME();

    -- (Initial AuditLog insert commented out for now, as per previous debugging steps)

    DECLARE @StudentID INT, @NationalCode NVARCHAR(10), @FirstName NVARCHAR(50), @LastName NVARCHAR(50), @Email NVARCHAR(100), @PhoneNumber NVARCHAR(20);

    DECLARE student_cursor CURSOR LOCAL FOR
    SELECT StudentID, NationalCode, FirstName, LastName, Email, PhoneNumber
    FROM INSERTED;

    OPEN student_cursor;
    FETCH NEXT FROM student_cursor INTO @StudentID, @NationalCode, @FirstName, @LastName, @Email, @PhoneNumber;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            PRINT N'DEBUG_TR: Calling RegisterMember for StudentID: ' + CAST(@StudentID AS NVARCHAR(10));
            -- *** CORRECTED PARAMETER NAMES HERE (removed leading underscore) ***
            EXEC Library.RegisterMember
                @NationalCode = @NationalCode, -- Changed from @_NationalCode
                @FirstName = @FirstName,       -- Changed from @_FirstName
                @LastName = @LastName,         -- Changed from @_LastName
                @MemberType = N'Student',
                @ContactEmail = @Email,        -- Changed from @_ContactEmail
                @ContactPhone = @PhoneNumber,  -- Changed from @_ContactPhone
                @Education_StudentID = @StudentID, -- Changed from @_Education_StudentID
                @Education_ProfessorID = NULL;

            SET @LogDescription = N'Successfully registered new student as library member. StudentID: ' + CAST(@StudentID AS NVARCHAR(10));
            INSERT INTO Library.AuditLog (EventType, EventDescription, UserID)
            VALUES (N'Auto Library Registration Success', @LogDescription, @EventUser);
            PRINT N'DEBUG_TR: AuditLog success for StudentID: ' + CAST(@StudentID AS NVARCHAR(10));

        END TRY
        BEGIN CATCH
            DECLARE @ErrorMessage NVARCHAR(MAX), @ErrorSeverity INT, @ErrorState INT;
            SELECT
                @ErrorMessage = ERROR_MESSAGE(),
                @ErrorSeverity = ERROR_SEVERITY(),
                @ErrorState = ERROR_STATE();

            PRINT N'DEBUG_TR: Entering CATCH block in trigger. Error: ' + @ErrorMessage + N' For StudentID: ' + CAST(@StudentID AS NVARCHAR(10));
            SET @LogDescription = N'Error in trg_Education_Students_CreateLibraryMember for StudentID ' + CAST(@StudentID AS NVARCHAR(10)) + N': ' + @ErrorMessage;
            INSERT INTO Library.AuditLog (EventType, EventDescription, UserID)
            VALUES (N'Auto Library Registration Failed', @LogDescription, @EventUser);
            PRINT N'DEBUG_TR: AuditLog failed for StudentID: ' + CAST(@StudentID AS NVARCHAR(10));

            RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
        END CATCH;

        FETCH NEXT FROM student_cursor INTO @StudentID, @NationalCode, @FirstName, @LastName, @Email, @PhoneNumber;
    END;

    CLOSE student_cursor;
    DEALLOCATE student_cursor;

END;
GO


-- Description: Prevents borrow renewal if the book is currently reserved by another member.
CREATE TRIGGER trg_Library_PreventRenewalIfReserved
ON Library.Borrows
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EventUser NVARCHAR(50) = SUSER_SNAME();

    -- Check for renewal attempts where DueDate has been extended
    -- AND the book is reserved by someone else
    IF EXISTS (
        SELECT 1
        FROM INSERTED I
        INNER JOIN DELETED D ON I.BorrowID = D.BorrowID
        INNER JOIN Library.Reservations R ON I.BookID = R.BookID
        WHERE
            I.DueDate > D.DueDate -- Check if DueDate has been extended
            AND I.ActualReturnDate IS NULL -- Ensure it's not a return operation
            AND D.ActualReturnDate IS NULL -- And was not returned previously either
            AND R.Status = 'Active'
            AND R.MemberID <> I.MemberID -- Book is reserved by a *different* member
    )
    BEGIN
        -- Log the unauthorized renewal attempt
        INSERT INTO Library.AuditLog (EventType, EventDescription, UserID)
        SELECT
            N'Unauthorized Renewal Attempt', -- This text is hardcoded in your trigger definition (Persian)
            N'MemberID ' + CAST(I.MemberID AS NVARCHAR) +
            N' attempted to renew BookID ' + CAST(I.BookID AS NVARCHAR) +
            N' which is reserved by another member.', -- This text is hardcoded in your trigger definition (Persian)
            @EventUser
        FROM INSERTED I
        INNER JOIN DELETED D ON I.BorrowID = D.BorrowID
        INNER JOIN Library.Reservations R ON I.BookID = R.BookID
        WHERE
            I.DueDate > D.DueDate
            AND I.ActualReturnDate IS NULL
            AND D.ActualReturnDate IS NULL
            AND R.Status = 'Active'
            AND R.MemberID <> I.MemberID;

        -- Prevent the update
        RAISERROR('This book is reserved by another member. Renewal is not allowed.', 16, 1); -- This message is hardcoded in your trigger definition (Persian)
        ROLLBACK TRANSACTION;
    END
END;
GO


CREATE TRIGGER Library.trg_Library_PreventBorrowIfBookUnavailable
ON Library.Borrows
INSTEAD OF INSERT -- <<< This trigger executes instead of the INSERT operation >>>
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON; -- Ensures transaction aborts on runtime error

    DECLARE @LogDescription NVARCHAR(MAX);
    DECLARE @EventUser NVARCHAR(50) = SUSER_SNAME();
    DECLARE @BookID INT;
    DECLARE @AvailableCopies INT;
    DECLARE @MemberID INT;

    -- Use a CURSOR to process multiple inserted rows (if multiple records are inserted simultaneously)
    DECLARE borrow_cursor CURSOR LOCAL FOR
    SELECT BookID, MemberID
    FROM INSERTED;

    OPEN borrow_cursor;
    FETCH NEXT FROM borrow_cursor INTO @BookID, @MemberID;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Get the number of available copies for the book
        SELECT @AvailableCopies = AvailableCopies
        FROM Library.Books
        WHERE BookID = @BookID;

        -- Check if any copies are available for borrowing
        IF @AvailableCopies IS NULL -- The book with this BookID does not exist
        BEGIN
            RAISERROR('Error: Book with BookID %d does not exist. Borrow operation aborted for this book.', 16, 1, @BookID);
            -- Log this attempt
            SET @LogDescription = N'Failed borrow attempt: BookID ' + CAST(@BookID AS NVARCHAR(10)) + N' does not exist. MemberID: ' + CAST(@MemberID AS NVARCHAR(10));
            INSERT INTO Library.AuditLog (EventType, EventDescription, UserID)
            VALUES (N'Borrow Failed (Book Not Found)', @LogDescription, @EventUser);
            ROLLBACK TRANSACTION; -- Rollback the entire transaction if even one book is unavailable/non-existent
            RETURN;
        END
        ELSE IF @AvailableCopies <= 0
        BEGIN
            -- If no copies are available, raise an error and cancel the insert operation
            RAISERROR('Error: No available copies for BookID %d. Borrow operation aborted.', 16, 1, @BookID);
            -- Log this attempt
            SET @LogDescription = N'Failed borrow attempt: No available copies for BookID ' + CAST(@BookID AS NVARCHAR(10)) + N'. MemberID: ' + CAST(@MemberID AS NVARCHAR(10));
            INSERT INTO Library.AuditLog (EventType, EventDescription, UserID)
            VALUES (N'Borrow Failed (No Copies)', @LogDescription, @EventUser);
            ROLLBACK TRANSACTION; -- Rollback the entire transaction
            RETURN;
        END

        FETCH NEXT FROM borrow_cursor INTO @BookID, @MemberID;
    END;

    CLOSE borrow_cursor;
    DEALLOCATE borrow_cursor;

    -- If all checks were successful, perform the original INSERT operation
    INSERT INTO Library.Borrows (BorrowDate, DueDate, MemberID, BookID, ActualReturnDate)
    SELECT BorrowDate, DueDate, MemberID, BookID, ActualReturnDate
    FROM INSERTED;

    -- You can add a successful log here, but the BorrowBook procedure itself logs
    -- SET @LogDescription = N'Borrow operation successful for BookID(s): ' + STUFF((SELECT N', ' + CAST(BookID AS NVARCHAR(10)) FROM INSERTED FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, N'');
    -- INSERT INTO Library.AuditLog (EventType, EventDescription, UserID)
    -- VALUES (N'Book Borrowed (Trigger Approved)', @LogDescription, @EventUser);
    PRINT N'DEBUG_TR_PreventBorrow: Borrow operation passed trigger validation and proceeded.';

END;
GO