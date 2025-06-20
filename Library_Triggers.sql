USE UniversityDB;
GO

-- Drop the trigger if it already exists to allow for modifications
IF OBJECT_ID('Education.trg_Education_Students_CreateLibraryMember', 'TR') IS NOT NULL
    DROP TRIGGER Education.trg_Education_Students_CreateLibraryMember;
GO

-- Trigger: trg_Education_Students_CreateLibraryMember
-- Description: Automatically registers a new student from Education.Students
-- as a member in Library.Members after successful student insertion.
-- Type: AFTER INSERT
-- Table: Education.Students
-- Requirements: Library.RegisterMember Stored Procedure and Library.AuditLog table must exist.
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