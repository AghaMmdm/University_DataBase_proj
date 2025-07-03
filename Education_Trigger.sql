USE UniversityDB;
GO

IF OBJECT_ID('Education.TR_Education_Students_ValidateNationalCode', 'TR') IS NOT NULL
BEGIN
    DROP TRIGGER Education.TR_Education_Students_ValidateNationalCode; -- نام تریگر در اینجا اصلاح شد
    PRINT 'Dropped existing trigger: Education.TR_Education_Students_ValidateNationalCode.';
END
ELSE
BEGIN
    PRINT 'Trigger Education.TR_Education_Students_ValidateNationalCode does not exist.';
END;
GO
-- Simplified Trigger to validate the National Code (Melli Code)
CREATE TRIGGER TR_Education_Students_ValidateNationalCode
ON Education.Students
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON; -- اضافه شده: تضمین می‌کند که خطاها تراکنش را به طور کامل قطع کنند.

    DECLARE @NationalCode NVARCHAR(10);
    DECLARE @StudentID INT;
    DECLARE @ValidCode BIT = 1;

    DECLARE student_cursor CURSOR LOCAL FOR
    SELECT StudentID, NationalCode
    FROM INSERTED;

    OPEN student_cursor;
    FETCH NEXT FROM student_cursor INTO @StudentID, @NationalCode;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @NationalCode = REPLACE(REPLACE(@NationalCode, '-', ''), ' ', '');

        IF LEN(@NationalCode) <> 10 OR ISNUMERIC(@NationalCode) = 0
        BEGIN
            SET @ValidCode = 0;
            RAISERROR('The provided National Code (''%s'') for Student ID %d is invalid. It must be 10 numeric digits. Operation aborted.', 16, 1, @NationalCode, @StudentID);
            BREAK;
        END
        ELSE IF @NationalCode = REPLICATE(SUBSTRING(@NationalCode, 1, 1), 10)
        BEGIN
            SET @ValidCode = 0;
            RAISERROR('The provided National Code (''%s'') for Student ID %d is invalid. It cannot consist of all repeating digits. Operation aborted.', 16, 1, @NationalCode, @StudentID);
            BREAK;
        END

        FETCH NEXT FROM student_cursor INTO @StudentID, @NationalCode;
    END;

    CLOSE student_cursor;
    DEALLOCATE student_cursor;

    IF @ValidCode = 0
    BEGIN
        ROLLBACK TRANSACTION;
        RETURN;
    END

END;
GO

PRINT '--- TR_Education_Students_ValidateNationalCode created successfully. ---';
GO


-- Trigger to log changes to the Status column in the Students table
CREATE TRIGGER Education.trg_DeactivateLibraryMemberOnStudentStatusChange
ON Education.Students
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EventUser NVARCHAR(50) = SUSER_SNAME();
    DECLARE @LogDescription NVARCHAR(MAX);

    -- Check if the Status column was updated
    IF UPDATE(Status)
    BEGIN
        -- Handle students whose status changed to a deactivating status
        IF EXISTS (SELECT 1 FROM INSERTED i JOIN DELETED d ON i.StudentID = d.StudentID WHERE i.Status <> d.Status AND i.Status IN ('Graduated', 'Expelled', 'Withdrawn', 'Suspended'))
        BEGIN
            -- Deactivate corresponding Library Member
            UPDATE LM
            SET Status = 'Inactive'
            FROM Library.Members AS LM
            INNER JOIN INSERTED AS I ON LM.NationalCode = (SELECT NationalCode FROM Education.Students WHERE StudentID = I.StudentID) -- Assuming NationalCode is the link
            INNER JOIN DELETED AS D ON I.StudentID = D.StudentID
            WHERE I.Status <> D.Status -- Only process if status actually changed
              AND I.Status IN ('Graduated', 'Expelled', 'Withdrawn', 'Suspended'); -- Only for these specific statuses

            -- Log the status change and library deactivation
            INSERT INTO Education.LogEvents (EventType, EventDescription, UserID)
            SELECT
                'Student Status Change - Member Deactivated', -- Shortened string to fit NVARCHAR(50) (44 chars)
                'Student ID: ' + CAST(I.StudentID AS NVARCHAR(10)) +
                ', Status changed from: ' + ISNULL(D.Status, 'NULL') +
                ' to: ' + ISNULL(I.Status, 'NULL') +
                '. Corresponding Library member deactivated.',
                @EventUser
            FROM
                INSERTED AS I
            INNER JOIN
                DELETED AS D ON I.StudentID = D.StudentID
            WHERE
                I.Status <> D.Status -- Only log if status actually changed
                AND I.Status IN ('Graduated', 'Expelled', 'Withdrawn', 'Suspended'); -- Only log deactivation if new status implies it
        END

        -- Handle all other student status changes (if not already handled by deactivation logic)
        -- This ensures all status changes are logged, not just those leading to deactivation
        INSERT INTO Education.LogEvents (EventType, EventDescription, UserID)
        SELECT
            'Student Status Changed', -- Shortened string (22 chars)
            'Student ID: ' + CAST(I.StudentID AS NVARCHAR(10)) +
            ', Status changed from: ' + ISNULL(D.Status, 'NULL') +
            ' to: ' + ISNULL(I.Status, 'NULL'),
            @EventUser
        FROM
            INSERTED AS I
        INNER JOIN
            DELETED AS D ON I.StudentID = D.StudentID
        WHERE I.Status <> D.Status -- Only log if status actually changed
              AND I.Status NOT IN ('Graduated', 'Expelled', 'Withdrawn', 'Suspended'); -- Exclude statuses handled by deactivation logic (to avoid duplicate logs)
    END
END;
GO


-- Trigger to update Enrollment status based on the final grade
CREATE TRIGGER TR_Education_Grades_UpdateEnrollmentStatus
ON Education.Grades
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Update Enrollment status based on the inserted/updated grade
    UPDATE Education.Enrollments
    SET Status =
        CASE
            WHEN I.FinalGrade >= 10 THEN 'Completed' -- Assuming 10 is the passing grade
            ELSE 'Failed'
        END
    FROM
        Education.Enrollments AS E
    INNER JOIN
        INSERTED AS I ON E.EnrollmentID = I.EnrollmentID;

    -- Log the grade insertion/update and the resulting enrollment status
    INSERT INTO Education.LogEvents (EventType, EventDescription, UserID)
    SELECT
        'GradeInserted',
        'Enrollment ID: ' + CAST(I.EnrollmentID AS NVARCHAR(10)) +
        ', Grade: ' + CAST(I.FinalGrade AS NVARCHAR(10)) +
        ', Updated Enrollment Status to: ' +
        CASE
            WHEN I.FinalGrade >= 10 THEN 'Completed'
            ELSE 'Failed'
        END,
        SUSER_SNAME()
    FROM
        INSERTED AS I;
END;
GO

-- Trigger to log new enrollments
CREATE TRIGGER TR_Education_Enrollments_LogEnrollment
ON Education.Enrollments
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO Education.LogEvents (EventType, EventDescription, UserID)
    SELECT
        'NewEnrollment',
        'Student ID: ' + CAST(I.StudentID AS NVARCHAR(10)) +
        ', Enrolled in Offering ID: ' + CAST(I.OfferingID AS NVARCHAR(10)),
        SUSER_SNAME()
    FROM
        INSERTED AS I;
END;
GO


-- Prevents direct INSERT operations into Education.Enrollments table.
-- Forces users to use the sp_EnrollStudentInCourse stored procedure for enrollments.
CREATE TRIGGER Education.trg_PreventDirectEnrollmentOutsideSP
ON Education.Enrollments
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- Check if CONTEXT_INFO indicates an authorized call from Education.EnrollStudentInCourse
    IF CONTEXT_INFO() = 0x504F4351
    BEGIN
        -- If authorized, perform the actual insert into the base table
        INSERT INTO Education.Enrollments (StudentID, OfferingID, EnrollmentDate, Status)
        SELECT
            StudentID,
            OfferingID,
            EnrollmentDate,
            Status
        FROM INSERTED;
    END
    ELSE
    BEGIN
        DECLARE @LogDescription NVARCHAR(MAX);
        DECLARE @EventUser NVARCHAR(50) = SUSER_SNAME();
        DECLARE @StudentIDs NVARCHAR(MAX) = N'';
        DECLARE @OfferingIDs NVARCHAR(MAX) = N'';

        SELECT @StudentIDs = STRING_AGG(CAST(StudentID AS NVARCHAR(10)), ', ') FROM INSERTED;
        SELECT @OfferingIDs = STRING_AGG(CAST(OfferingID AS NVARCHAR(10)), ', ') FROM INSERTED;

        SET @LogDescription = N'Attempt to directly insert into Education.Enrollments detected. StudentID(s): [' + ISNULL(@StudentIDs, N'N/A') + N'], OfferingID(s): [' + ISNULL(@OfferingIDs, N'N/A') + N']. Direct inserts are not allowed. Please use the "Education.EnrollStudentInCourse" stored procedure.';
        INSERT INTO Education.LogEvents (EventType, EventDescription, UserID)
        VALUES (N'Direct Enrollment Blocked', @LogDescription, @EventUser);

        RAISERROR('Error: Direct enrollment into the Education.Enrollments table is not allowed. Please use the "Education.EnrollStudentInCourse" stored procedure.', 16, 1);
    END;
END;
GO

-- Description: This trigger automatically deactivates a corresponding library member's status
--				in the Library.Members table when a student's status in Education.Students
--				changes to 'Expelled' or 'Withdrawn'.
CREATE TRIGGER Education.trg_DeactivateLibraryMemberOnStudentStatusChange
ON Education.Students
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EventUser NVARCHAR(50) = SUSER_SNAME();

    -- Check if the Status column was actually changed in the update
    IF UPDATE(Status)
    BEGIN
        -- Log attempt for auditing (before actual update)
        INSERT INTO Education.LogEvents (EventType, EventDescription, UserID)
        SELECT
            N'Student Status Change - Library Deactivation Attempt',
            N'Attempting to deactivate library member for StudentID: ' + CAST(I.StudentID AS NVARCHAR(10)) +
            N' due to status change from "' + D.Status + N'" to "' + I.Status + N'".',
            @EventUser
        FROM INSERTED AS I
        INNER JOIN DELETED AS D ON I.StudentID = D.StudentID
        WHERE I.Status IN ('Expelled', 'Withdrawn')
          AND D.Status NOT IN ('Expelled', 'Withdrawn'); -- Ensure status was actually changed TO one of these statuses

        -- Update the status of the corresponding member in Library.Members
        UPDATE LM
        SET LM.Status = 'Deactivated' -- Setting status to 'Deactivated' as defined in your Library.Members table
            -- Uncomment the line below if you add a 'DeactivationDate' column to Library.Members
            -- , LM.DeactivationDate = GETDATE()
        FROM Library.Members AS LM
        INNER JOIN INSERTED AS I ON LM.Education_StudentID = I.StudentID -- *** Using Education_StudentID for direct link ***
        INNER JOIN DELETED AS D ON I.StudentID = D.StudentID
        WHERE I.Status IN ('Expelled', 'Withdrawn')
          AND D.Status NOT IN ('Expelled', 'Withdrawn')
          AND LM.MemberType = 'Student'; -- Only deactivate members who are of type 'Student'

        -- Log successful deactivations (after actual update)
        IF @@ROWCOUNT > 0
        BEGIN
            INSERT INTO Education.LogEvents (EventType, EventDescription, UserID)
            SELECT
                N'Library Member Deactivated',
                N'Library member for StudentID: ' + CAST(I.StudentID AS NVARCHAR(10)) +
                N' (NationalCode: ' + I.NationalCode + N') deactivated due to student status "' + I.Status + N'".',
                @EventUser
            FROM INSERTED AS I
            INNER JOIN DELETED AS D ON I.StudentID = D.StudentID
            WHERE I.Status IN ('Expelled', 'Withdrawn')
              AND D.Status NOT IN ('Expelled', 'Withdrawn');
        END
    END
END;
GO