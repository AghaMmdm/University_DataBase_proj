-- SQL_Scripts/Education/04_Triggers/Education_Triggers.sql

USE UniversityDB; -- Ensure you are working on the correct database
GO

IF EXISTS (SELECT * FROM sys.triggers WHERE name = 'TR_Education_Students_ValidateNationalCode')
BEGIN
    DROP TRIGGER Education.TR_Education_Students_ValidateNationalCode;
    PRINT 'Trigger TR_Education_Students_ValidateNationalCode dropped successfully.';
END
GO

---- Trigger to validate the Iranian National Code (Melli Code) during INSERT or UPDATE operations on student data
--CREATE TRIGGER TR_Education_Students_ValidateNationalCode
--ON Education.Students
--AFTER INSERT, UPDATE -- This trigger fires after an INSERT or UPDATE statement
--AS
--BEGIN
--    SET NOCOUNT ON; -- Prevents "X rows affected" messages from being returned to the client

--    DECLARE @NationalCode NVARCHAR(10);
--    DECLARE @StudentID INT;
--    DECLARE @CalculatedCheckDigit INT;
--    DECLARE @Sum INT;
--    DECLARE @Remainder INT;
--    DECLARE @ValidCode BIT = 1; -- Initial assumption that the code is valid

--    -- Iterate through all rows affected by the INSERT/UPDATE operation
--    -- (This is important when a single DML statement affects multiple rows)
--    DECLARE student_cursor CURSOR FOR
--    SELECT StudentID, NationalCode
--    FROM INSERTED; -- 'INSERTED' pseudo-table contains the new or updated rows

--    OPEN student_cursor;
--    FETCH NEXT FROM student_cursor INTO @StudentID, @NationalCode;

--    WHILE @@FETCH_STATUS = 0 -- Loop while there are more rows in the cursor
--    BEGIN
--        -- Remove any hyphens or spaces from the National Code
--        SET @NationalCode = REPLACE(REPLACE(@NationalCode, '-', ''), ' ', '');

--        -- 1. Validate length and character type (must be 10 digits and numeric only)
--        IF LEN(@NationalCode) <> 10 OR ISNUMERIC(@NationalCode) = 0
--        BEGIN
--            SET @ValidCode = 0;
--        END
--        -- 2. Check for repeating digits (e.g., 1111111111 or 0000000000 are usually invalid)
--        -- This is an additional and commonly useful check for Iranian National Codes
--        ELSE IF @NationalCode = REPLICATE(SUBSTRING(@NationalCode, 1, 1), 10)
--        BEGIN
--            SET @ValidCode = 0;
--        END
--        ELSE
--        BEGIN
--            -- 3. Implement the National Code validation algorithm (checksum calculation)
--            SET @Sum = 0;
--            -- Calculate the weighted sum of the first 9 digits
--            SET @Sum = (CAST(SUBSTRING(@NationalCode, 1, 1) AS INT) * 10) +
--                       (CAST(SUBSTRING(@NationalCode, 2, 1) AS INT) * 9) +
--                       (CAST(SUBSTRING(@NationalCode, 3, 1) AS INT) * 8) +
--                       (CAST(SUBSTRING(@NationalCode, 4, 1) AS INT) * 7) +
--                       (CAST(SUBSTRING(@NationalCode, 5, 1) AS INT) * 6) +
--                       (CAST(SUBSTRING(@NationalCode, 6, 1) AS INT) * 5) +
--                       (CAST(SUBSTRING(@NationalCode, 7, 1) AS INT) * 4) +
--                       (CAST(SUBSTRING(@NationalCode, 8, 1) AS INT) * 3) +
--                       (CAST(SUBSTRING(@NationalCode, 9, 1) AS INT) * 2);

--            SET @Remainder = @Sum % 11;

--            -- Calculate the expected check digit (10th digit)
--            IF @Remainder < 2
--                SET @CalculatedCheckDigit = @Remainder;
--            ELSE
--                SET @CalculatedCheckDigit = 11 - @Remainder;

--            -- Compare the calculated check digit with the actual 10th digit of the National Code
--            IF @CalculatedCheckDigit <> CAST(SUBSTRING(@NationalCode, 10, 1) AS INT)
--            BEGIN
--                SET @ValidCode = 0;
--            END
--        END

--        -- If the National Code is determined to be invalid, rollback the transaction and raise an error
--        IF @ValidCode = 0
--        BEGIN
--            RAISERROR('The provided National Code (''%s'') for Student ID %d is invalid. Operation aborted.', 16, 1, @NationalCode, @StudentID);
--            ROLLBACK TRANSACTION; -- Reverts the entire DML statement
--            RETURN; -- Exits the trigger
--        END

--        -- Fetch the next row from the cursor
--        FETCH NEXT FROM student_cursor INTO @StudentID, @NationalCode;
--    END;

--    CLOSE student_cursor;      -- Close the cursor
--    DEALLOCATE student_cursor; -- Deallocate the cursor to release resources

--END;
--GO





-- Simplified Trigger to validate the Iranian National Code (Melli Code)
-- Checks for length, numeric type, and repeating digits only.
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

