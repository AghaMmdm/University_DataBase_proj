USE UniversityDB;
GO


-- Description: Automatically registers a new student from Education.Students as a member in Library.Members after successful student insertion.
CREATE TRIGGER Education.trg_Education_Students_CreateLibraryMember
ON Education.Students
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @LogDescription NVARCHAR(MAX);
    DECLARE @EventUser NVARCHAR(50) = SUSER_SNAME();

    -- Loop through all inserted students (in case of multi-row inserts)
    INSERT INTO Library.AuditLog (EventType, EventDescription, UserID)
    SELECT
        N'Library Member Registration Attempt',
        N'Attempting to register new student as library member. StudentID: ' + CAST(I.StudentID AS NVARCHAR(10)) + N', NationalCode: ' + I.NationalCode,
        @EventUser
    FROM INSERTED AS I;

    BEGIN TRY
        -- Call the Library.RegisterMember Stored Procedure for each new student
        -- Using a cursor to process each row individually ensures each call to the SP is distinct.
        -- For performance on large inserts, a MERGE statement might be considered if RegisterMember was not a SP.
        -- But for calling an SP with specific logic per row, a cursor is appropriate here.
        DECLARE @StudentID INT, @NationalCode NVARCHAR(10), @FirstName NVARCHAR(50), @LastName NVARCHAR(50), @Email NVARCHAR(100), @PhoneNumber NVARCHAR(20);

        DECLARE student_cursor CURSOR FOR
        SELECT StudentID, NationalCode, FirstName, LastName, Email, PhoneNumber
        FROM INSERTED;

        OPEN student_cursor;
        FETCH NEXT FROM student_cursor INTO @StudentID, @NationalCode, @FirstName, @LastName, @Email, @PhoneNumber;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC Library.RegisterMember
                @_NationalCode = @NationalCode,
                @_FirstName = @FirstName,
                @_LastName = @LastName,
                @_MemberType = N'Student', -- Hardcode as 'Student' for this trigger
                @_ContactEmail = @Email,
                @_ContactPhone = @PhoneNumber,
                @_Education_StudentID = @StudentID,
                @_Education_ProfessorID = NULL; -- Ensure this is NULL for students

            FETCH NEXT FROM student_cursor INTO @StudentID, @NationalCode, @FirstName, @LastName, @Email, @PhoneNumber;
        END;

        CLOSE student_cursor;
        DEALLOCATE student_cursor;

    END TRY
    BEGIN CATCH
        -- Log any error during the library member registration process
        DECLARE @ErrorMessage NVARCHAR(MAX), @ErrorSeverity INT, @ErrorState INT;
        SELECT
            @ErrorMessage = ERROR_MESSAGE(),
            @ErrorSeverity = ERROR_SEVERITY(),
            @ErrorState = ERROR_STATE();

        SET @LogDescription = N'Error in trg_Education_Students_CreateLibraryMember for StudentID ' + CAST(@StudentID AS NVARCHAR(10)) + N': ' + @ErrorMessage;
        INSERT INTO Library.AuditLog (EventType, EventDescription, UserID)
        VALUES (N'Auto Library Registration Failed', @LogDescription, @EventUser);

        -- Note: We are not re-throwing the error here to avoid blocking the initial student registration.
        -- The primary student registration should succeed even if library registration fails for some reason.
        -- However, this means the library member registration might fail silently from the perspective of the original SP,
        -- so proper logging is crucial.
    END CATCH;
END;
GO



-- Description: Prevents direct INSERT operations into Library.Members table. Only allows inserts that originate from the Library.RegisterMember stored procedure.
CREATE TRIGGER trg_Library_PreventDirectMemberInsert
ON Library.Members
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON; -- Prevents the message showing the number of rows affected by the trigger.

    -- Check if the current execution context is within the 'RegisterMember' stored procedure.
    -- OBJECT_NAME(@@PROCID) returns the name of the stored procedure that is currently executing.
    -- If a direct INSERT is attempted, @@PROCID will typically be NULL or refer to a different context.
    IF OBJECT_NAME(@@PROCID) = 'RegisterMember'
    BEGIN
        -- If the insert is coming from Library.RegisterMember SP, allow the actual insert to proceed.
        -- We must explicitly perform the insert here because INSTEAD OF triggers replace the original operation.
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
        FROM INSERTED; -- INSERTED is a pseudo-table containing the rows that were attempted to be inserted.
    END
    ELSE
    BEGIN
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
