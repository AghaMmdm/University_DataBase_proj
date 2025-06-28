USE UniversityDB;
GO


-- Simplified Trigger to validate the National Code (Melli Code)
CREATE TRIGGER TR_Education_Students_ValidateNationalCode
ON Education.Students
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON; -- Prevents "X rows affected" messages

    DECLARE @NationalCode NVARCHAR(10);
    DECLARE @StudentID INT;
    DECLARE @ValidCode BIT = 1; -- Initial assumption that the code is valid

    -- Iterate through all rows affected by the INSERT/UPDATE operation
    DECLARE student_cursor CURSOR FOR
    SELECT StudentID, NationalCode
    FROM INSERTED;

    OPEN student_cursor;
    FETCH NEXT FROM student_cursor INTO @StudentID, @NationalCode;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Remove any hyphens or spaces from the National Code for consistent checks
        SET @NationalCode = REPLACE(REPLACE(@NationalCode, '-', ''), ' ', '');

        -- 1. Validate length (must be 10 digits) and character type (numeric only)
        IF LEN(@NationalCode) <> 10 OR ISNUMERIC(@NationalCode) = 0
        BEGIN
            SET @ValidCode = 0;
            RAISERROR('The provided National Code (''%s'') for Student ID %d is invalid. It must be 10 numeric digits. Operation aborted.', 16, 1, @NationalCode, @StudentID);
            BREAK; -- Exit the loop as we already found an invalid code
        END
        -- 2. Check for repeating digits (e.g., 1111111111 or 0000000000 are usually invalid)
        ELSE IF @NationalCode = REPLICATE(SUBSTRING(@NationalCode, 1, 1), 10)
        BEGIN
            SET @ValidCode = 0;
            RAISERROR('The provided National Code (''%s'') for Student ID %d is invalid. It cannot consist of all repeating digits. Operation aborted.', 16, 1, @NationalCode, @StudentID);
            BREAK; -- Exit the loop as we already found an invalid code
        END
        
        -- Fetch the next row from the cursor
        FETCH NEXT FROM student_cursor INTO @StudentID, @NationalCode;
    END;

    CLOSE student_cursor;
    DEALLOCATE student_cursor;

    -- If any invalid code was found, rollback the entire transaction
    IF @ValidCode = 0
    BEGIN
        ROLLBACK TRANSACTION; -- Reverts the entire DML statement that fired the trigger
        RETURN; -- Exits the trigger
    END

END;
GO


-- Trigger to log changes to the Status column in the Students table
CREATE TRIGGER TR_Education_Students_LogStatusChange
ON Education.Students
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Check if the Status column was updated
    IF UPDATE(Status)
    BEGIN
        INSERT INTO Education.LogEvents (EventType, EventDescription, UserID)
        SELECT
            'StudentStatusChanged',
            'Student ID: ' + CAST(I.StudentID AS NVARCHAR(10)) +
            ', Status changed from: ' + ISNULL(D.Status, 'NULL') +
            ' to: ' + ISNULL(I.Status, 'NULL'),
            SUSER_SNAME() -- Log the user who performed the update
        FROM
            INSERTED AS I
        INNER JOIN
            DELETED AS D ON I.StudentID = D.StudentID;
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


-- Updates the Capacity of a CourseOffering
CREATE TRIGGER Education.trg_UpdateCourseCapacityOnEnrollmentChange
ON Education.Enrollments
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @OfferingID INT;
    DECLARE @CourseName NVARCHAR(100);
    DECLARE @LogDescription NVARCHAR(MAX);
    DECLARE @CapacityChange INT;
    DECLARE @EventUser NVARCHAR(50) = SUSER_SNAME(); -- Capture the user who initiated the action

    -- Handle INSERT operations
    IF EXISTS (SELECT * FROM INSERTED) AND NOT EXISTS (SELECT * FROM DELETED)
    BEGIN
        -- A new enrollment has been inserted (Capacity decreases)
        SELECT @OfferingID = OfferingID FROM INSERTED;

        UPDATE CO
        SET Capacity = CO.Capacity - 1
        FROM Education.CourseOfferings AS CO
        INNER JOIN INSERTED AS I ON CO.OfferingID = I.OfferingID;

        SELECT @CourseName = C.CourseName
        FROM Education.CourseOfferings AS CO
        INNER JOIN Education.Courses AS C ON CO.CourseID = C.CourseID
        WHERE CO.OfferingID = @OfferingID;

        SET @LogDescription = N'Course capacity decreased for "' + @CourseName + N'" (OfferingID: ' + CAST(@OfferingID AS NVARCHAR(10)) + N') due to new enrollment. New capacity: ' + CAST((SELECT Capacity FROM Education.CourseOfferings WHERE OfferingID = @OfferingID) AS NVARCHAR(10));
        INSERT INTO Education.LogEvents (EventType, EventDescription, UserID) VALUES (N'Capacity Update', @LogDescription, @EventUser);
    END
    -- Handle DELETE operations (Enrollment removed)
    ELSE IF EXISTS (SELECT * FROM DELETED) AND NOT EXISTS (SELECT * FROM INSERTED)
    BEGIN
        -- An enrollment has been deleted (Capacity increases)
        SELECT @OfferingID = OfferingID FROM DELETED;

        UPDATE CO
        SET Capacity = CO.Capacity + 1
        FROM Education.CourseOfferings AS CO
        INNER JOIN DELETED AS D ON CO.OfferingID = D.OfferingID;

        SELECT @CourseName = C.CourseName
        FROM Education.CourseOfferings AS CO
        INNER JOIN Education.Courses AS C ON CO.CourseID = C.CourseID
        WHERE CO.OfferingID = @OfferingID;

        SET @LogDescription = N'Course capacity increased for "' + @CourseName + N'" (OfferingID: ' + CAST(@OfferingID AS NVARCHAR(10)) + N') due to enrollment deletion. New capacity: ' + CAST((SELECT Capacity FROM Education.CourseOfferings WHERE OfferingID = @OfferingID) AS NVARCHAR(10));
        INSERT INTO Education.LogEvents (EventType, EventDescription, UserID) VALUES (N'Capacity Update', @LogDescription, @EventUser);
    END
    -- Handle UPDATE operations (Enrollment status changed)
    ELSE IF EXISTS (SELECT * FROM INSERTED) AND EXISTS (SELECT * FROM DELETED)
    BEGIN
        -- Check if status changed from 'Enrolled' to 'Dropped', 'Failed', or 'Withdrawn'
        -- Or if status changed from 'Dropped'/'Failed'/'Withdrawn' back to 'Enrolled' (less common but possible)
        SELECT
            @OfferingID = I.OfferingID,
            @CapacityChange =
                CASE
                    -- If old status was 'Enrolled' but new status is 'Dropped', 'Failed', 'Withdrawn' -> Capacity increases by 1
                    WHEN D.Status = 'Enrolled' AND I.Status IN ('Dropped', 'Failed', 'Withdrawn') THEN 1
                    -- If old status was 'Dropped', 'Failed', 'Withdrawn' but new status is 'Enrolled' -> Capacity decreases by 1
                    WHEN D.Status IN ('Dropped', 'Failed', 'Withdrawn') AND I.Status = 'Enrolled' THEN -1
                    ELSE 0 -- No change relevant to capacity, or status is already Completed
                END
        FROM INSERTED AS I
        INNER JOIN DELETED AS D ON I.EnrollmentID = D.EnrollmentID
        WHERE I.Status <> D.Status; -- Only interested if status actually changed

        IF @CapacityChange <> 0
        BEGIN
            UPDATE CO
            SET Capacity = CO.Capacity + @CapacityChange
            FROM Education.CourseOfferings AS CO
            INNER JOIN INSERTED AS I ON CO.OfferingID = I.OfferingID;

            SELECT @CourseName = C.CourseName
            FROM Education.CourseOfferings AS CO
            INNER JOIN Education.Courses AS C ON CO.CourseID = C.CourseID
            WHERE CO.OfferingID = @OfferingID;

            SET @LogDescription = N'Course capacity adjusted for "' + @CourseName + N'" (OfferingID: ' + CAST(@OfferingID AS NVARCHAR(10)) + N') due to enrollment status change. Change: ' + CAST(@CapacityChange AS NVARCHAR(10)) + N'. New capacity: ' + CAST((SELECT Capacity FROM Education.CourseOfferings WHERE OfferingID = @OfferingID) AS NVARCHAR(10));
            INSERT INTO Education.LogEvents (EventType, EventDescription, UserID) VALUES (N'Capacity Update', @LogDescription, @EventUser);
        END
    END
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

    DECLARE @LogDescription NVARCHAR(MAX);
    DECLARE @EventUser NVARCHAR(50) = SUSER_SNAME();
    DECLARE @StudentIDs NVARCHAR(MAX) = N'';
    DECLARE @OfferingIDs NVARCHAR(MAX) = N'';

    -- Build a string of affected StudentIDs and OfferingIDs for logging
    SELECT @StudentIDs = @StudentIDs + CAST(StudentID AS NVARCHAR(10)) + N', '
    FROM INSERTED;
    SELECT @OfferingIDs = @OfferingIDs + CAST(OfferingID AS NVARCHAR(10)) + N', '
    FROM INSERTED;

    -- Remove trailing comma and space
    SET @StudentIDs = IIF(LEN(@StudentIDs) > 0, LEFT(@StudentIDs, LEN(@StudentIDs) - 1), @StudentIDs);
    SET @OfferingIDs = IIF(LEN(@OfferingIDs) > 0, LEFT(@OfferingIDs, LEN(@OfferingIDs) - 1), @OfferingIDs);

    -- Log the attempt
    SET @LogDescription = N'Attempt to directly insert into Education.Enrollments detected. StudentID(s): [' + @StudentIDs + N'], OfferingID(s): [' + @OfferingIDs + N']. Direct inserts are not allowed. Please use sp_EnrollStudentInCourse.';
    INSERT INTO Education.LogEvents (EventType, EventDescription, UserID)
    VALUES (N'Direct Enrollment Blocked', @LogDescription, @EventUser);

    -- Raise an error to prevent the direct insert
    THROW 50001, N'Error: Direct enrollment into the Education.Enrollments table is not allowed. Please use the "Education.EnrollStudentInCourse" stored procedure.', 1;

END;
GO

