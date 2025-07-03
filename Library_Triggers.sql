USE UniversityDB;
GO
IF OBJECT_ID('Education.trg_Education_Students_CreateLibraryMember', 'TR') IS NOT NULL
BEGIN
    DROP TRIGGER Education.trg_Education_Students_CreateLibraryMember;
    PRINT 'Trigger Education.trg_Education_Students_CreateLibraryMember dropped successfully.';
END
ELSE
BEGIN
    PRINT 'Trigger Education.trg_Education_Students_CreateLibraryMember does not exist.';
END;
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


IF OBJECT_ID('Library.trg_Library_PreventDirectMemberInsert', 'TR') IS NOT NULL
BEGIN
    DROP TRIGGER Library.trg_Library_PreventDirectMemberInsert;
    PRINT 'Trigger trg_Library_PreventDirectMemberInsert dropped successfully.';
END
ELSE
BEGIN
    PRINT 'Trigger trg_Library_PreventDirectMemberInsert does not exist.';
END;
GO

PRINT '--- Creating new trigger trg_Library_PreventDirectMemberInsert with CONTEXT_INFO debug output ---';
GO


-- Description: Prevents direct INSERT operations into Library.Members table. Only allows inserts that originate from the Library.RegisterMember stored procedure.
CREATE TRIGGER trg_Library_PreventDirectMemberInsert
ON Library.Members
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON; -- Ensure transaction aborts on error

    -- DEBUGGING OUTPUT - THESE ARE THE LINES WE NEED TO SEE!
    DECLARE @currentContextInfo VARBINARY(128);
    SET @currentContextInfo = CONTEXT_INFO();
    PRINT N'DEBUG_TR_INFO: Inside trigger trg_Library_PreventDirectMemberInsert.';
    PRINT N'DEBUG_TR_INFO: CONTEXT_INFO() value: ' + ISNULL(CONVERT(NVARCHAR(MAX), @currentContextInfo, 1), 'NULL');
    PRINT N'DEBUG_TR_INFO: OBJECT_NAME(@@PROCID): ' + ISNULL(OBJECT_NAME(@@PROCID), 'NULL');
    PRINT N'DEBUG_TR_INFO: OBJECT_SCHEMA_NAME(@@PROCID): ' + ISNULL(OBJECT_SCHEMA_NAME(@@PROCID), 'NULL');

    -- Check if the current execution context has set the specific CONTEXT_INFO value
    IF @currentContextInfo = 0x01
    BEGIN
        PRINT N'DEBUG_TR_INFO: CONTEXT_INFO check PASSED. Attempting actual insert into Library.Members.';
        BEGIN TRY
            INSERT INTO Library.Members (
                NationalCode,
                FirstName,
                LastName,
                MemberType,
                ContactEmail,
                ContactPhone,
                Education_StudentID,
                Education_ProfessorID,
                JoinDate,
                Status
            )
            SELECT
                NationalCode,
                FirstName,
                LastName,
                MemberType,
                ContactEmail,
                ContactPhone,
                Education_StudentID,
                Education_ProfessorID,
                JoinDate,
                Status
            FROM INSERTED;
            PRINT N'DEBUG_TR_INFO: Insert into Library.Members completed successfully within trigger.';
        END TRY
        BEGIN CATCH
            DECLARE @ErrorMessage NVARCHAR(MAX), @ErrorSeverity INT, @ErrorState INT;
            SELECT
                @ErrorMessage = ERROR_MESSAGE(),
                @ErrorSeverity = ERROR_SEVERITY(),
                @ErrorState = ERROR_STATE();
            PRINT N'DEBUG_TR_ERROR: Error in INSTEAD OF INSERT. Original message: ' + @ErrorMessage;
            -- Re-raise the error so the calling procedure (RegisterMember) can catch it
            RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
            RETURN; -- Exit the trigger
        END CATCH;
    END
    ELSE
    BEGIN
        PRINT N'DEBUG_TR_INFO: CONTEXT_INFO check FAILED. Raising error for direct insertion.';
        RAISERROR('Direct insertion into Library.Members table is not allowed. Please use the Library.RegisterMember stored procedure to add new members.', 16, 1);
    END
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

    -- Find attempted renewals where the book is reserved by someone else
    IF EXISTS (
        SELECT 1
        FROM INSERTED I
        INNER JOIN DELETED D ON I.BorrowID = D.BorrowID
        INNER JOIN Library.Reservations R ON I.BookID = R.BookID
        WHERE
            ISNULL(I.ReturnDate, '') <> ISNULL(D.ReturnDate, '') -- Only care if ReturnDate changed
            AND R.Status = 'Active'
            AND R.MemberID <> I.MemberID
    )
    BEGIN
        -- Log the unauthorized renewal attempt
        INSERT INTO Library.AuditLog (EventType, EventDescription, UserID)
        SELECT
            N'Unauthorized Renewal Attempt',
            N'MemberID ' + CAST(I.MemberID AS NVARCHAR) +
            N' attempted to renew BookID ' + CAST(I.BookID AS NVARCHAR) +
            N' which is reserved by another member.',
            @EventUser
        FROM INSERTED I
        INNER JOIN DELETED D ON I.BorrowID = D.BorrowID
        INNER JOIN Library.Reservations R ON I.BookID = R.BookID
        WHERE
            ISNULL(I.ReturnDate, '') <> ISNULL(D.ReturnDate, '')
            AND R.Status = 'Active'
            AND R.MemberID <> I.MemberID;

        -- Prevent the update
        RAISERROR('This book is reserved by another member. Renewal is not allowed.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;
GO
