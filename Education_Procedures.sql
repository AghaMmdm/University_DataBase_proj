-- SQL_Scripts/Education/03_Stored_Procedures/Education_StoredProcedures.sql

USE UniversityDB;
GO

-- Stored Procedure to enroll a student in a specific course offering
CREATE PROCEDURE Education.EnrollStudentInCourse
    @_StudentID INT,
    @_OfferingID INT
AS
BEGIN
    SET NOCOUNT ON; -- Suppress the message that indicates the number of rows affected

    DECLARE @CourseID INT;
    DECLARE @CourseName NVARCHAR(100);
    DECLARE @StudentStatus NVARCHAR(20);
    DECLARE @CurrentCapacity INT;
    DECLARE @MaxCapacity INT;
    DECLARE @StudentMajorID INT;
    DECLARE @CourseSchedule NVARCHAR(255);
    DECLARE @CourseOfferingAcademicYearID INT;
    DECLARE @CourseOfferingSemester NVARCHAR(20);

    BEGIN TRY
        -- 1. Validate Student Existence and Status
        SELECT @StudentStatus = S.Status, @StudentMajorID = S.MajorID
        FROM Education.Students AS S
        WHERE S.StudentID = @_StudentID;

        IF @StudentStatus IS NULL
        BEGIN
            RAISERROR('Error: Student with ID %d does not exist.', 16, 1, @_StudentID);
            RETURN;
        END

        IF @StudentStatus <> 'Active'
        BEGIN
            RAISERROR('Error: Student with ID %d is not active and cannot enroll in courses. Current status: %s', 16, 1, @_StudentID, @StudentStatus);
            RETURN;
        END

        -- 2. Validate Course Offering Existence and Capacity
        SELECT
            @CourseID = CO.CourseID,
            @CourseName = C.CourseName,
            @CurrentCapacity = CO.Capacity,
            @CourseSchedule = CO.Schedule,
            @CourseOfferingAcademicYearID = CO.AcademicYearID,
            @CourseOfferingSemester = CO.Semester,
            @MaxCapacity = (SELECT Capacity FROM Education.CourseOfferings WHERE OfferingID = @_OfferingID) -- Get original capacity if needed
        FROM
            Education.CourseOfferings AS CO
        INNER JOIN
            Education.Courses AS C ON CO.CourseID = C.CourseID
        WHERE
            CO.OfferingID = @_OfferingID;

        IF @CourseID IS NULL
        BEGIN
            RAISERROR('Error: Course Offering with ID %d does not exist.', 16, 1, @_OfferingID);
            RETURN;
        END

        IF @CurrentCapacity <= 0
        BEGIN
            RAISERROR('Error: Course "%s" (Offering ID: %d) has no available capacity.', 16, 1, @CourseName, @_OfferingID);
            RETURN;
        END

        -- 3. Check for Duplicate Enrollment (Student already enrolled in this exact offering)
        IF EXISTS (SELECT 1 FROM Education.Enrollments WHERE StudentID = @_StudentID AND OfferingID = @_OfferingID)
        BEGIN
            RAISERROR('Error: Student with ID %d is already enrolled in this course offering (ID: %d).', 16, 1, @_StudentID, @_OfferingID);
            RETURN;
        END

        -- 4. Check Prerequisites (More robust check)
        -- Get a list of prerequisites for the course being enrolled in
        DECLARE @RequiredPrerequisites TABLE (PrerequisiteCourseID INT);
        INSERT INTO @RequiredPrerequisites (PrerequisiteCourseID)
        SELECT PrerequisiteCourseID
        FROM Education.Prerequisites
        WHERE CourseID = @CourseID;

        -- For each required prerequisite, check if the student has passed it
        IF EXISTS (SELECT 1 FROM @RequiredPrerequisites)
        BEGIN
            DECLARE @MissingPrereqCourseID INT;
            DECLARE @MissingPrereqCourseName NVARCHAR(100);

            -- Find if any required prerequisite is NOT completed by the student with a passing grade
            SELECT TOP 1 @MissingPrereqCourseID = RP.PrerequisiteCourseID
            FROM @RequiredPrerequisites AS RP
            LEFT JOIN Education.CourseOfferings AS CO_Passed
                ON CO_Passed.CourseID = RP.PrerequisiteCourseID
            LEFT JOIN Education.Enrollments AS E_Passed
                ON E_Passed.OfferingID = CO_Passed.OfferingID
                AND E_Passed.StudentID = @_StudentID
                AND E_Passed.Status = 'Completed'
            LEFT JOIN Education.Grades AS G_Passed
                ON G_Passed.EnrollmentID = E_Passed.EnrollmentID
                AND G_Passed.FinalGrade >= 10 -- Assuming 10 is the passing grade
            WHERE G_Passed.GradeID IS NULL; -- If GradeID is NULL, it means the prerequisite was not found as completed

            IF @MissingPrereqCourseID IS NOT NULL
            BEGIN
                SELECT @MissingPrereqCourseName = CourseName FROM Education.Courses WHERE CourseID = @MissingPrereqCourseID;
                RAISERROR('Error: Student with ID %d has not completed the prerequisite course "%s" (ID: %d).', 16, 1, @_StudentID, @MissingPrereqCourseName, @MissingPrereqCourseID);
                RETURN;
            END
        END

        -- 5. Check Scheduling Conflicts
        IF EXISTS (
            SELECT 1
            FROM Education.Enrollments AS E
            INNER JOIN Education.CourseOfferings AS ExistingCO
                ON E.OfferingID = ExistingCO.OfferingID
            WHERE E.StudentID = @_StudentID
              AND E.Status = 'Enrolled' -- Check only actively enrolled courses
              AND ExistingCO.AcademicYearID = @CourseOfferingAcademicYearID
              AND ExistingCO.Semester = @CourseOfferingSemester
              AND ExistingCO.Schedule = @CourseSchedule -- Assuming identical schedules conflict
        )
        BEGIN
            RAISERROR('Error: Student with ID %d has a scheduling conflict with another course in the same semester and time.', 16, 1, @_StudentID);
            RETURN;
        END

        -- Start Transaction for atomicity
        BEGIN TRANSACTION;

        -- Insert the new enrollment record
        INSERT INTO Education.Enrollments (StudentID, OfferingID, EnrollmentDate, Status)
        VALUES (@_StudentID, @_OfferingID, GETDATE(), 'Enrolled');

        -- Decrease the capacity of the course offering
        UPDATE Education.CourseOfferings
        SET Capacity = Capacity - 1
        WHERE OfferingID = @_OfferingID;

        -- Log the successful enrollment event
        INSERT INTO Education.LogEvents (EventType, EventDescription, UserID)
        VALUES (
            'StudentEnrolled',
            'Student with ID ' + CAST(@_StudentID AS NVARCHAR(10)) + ' enrolled in Course Offering ID ' + CAST(@_OfferingID AS NVARCHAR(10)) + ' (' + @CourseName + ').',
            SUSER_SNAME() -- Log the user who executed the procedure (usually dbo or a specific user)
        );

        COMMIT TRANSACTION;
        PRINT 'SUCCESS: Student with ID ' + CAST(@_StudentID AS NVARCHAR(10)) + ' successfully enrolled in course "' + @CourseName + '" (Offering ID: ' + CAST(@_OfferingID AS NVARCHAR(10)) + ').';

    END TRY
    BEGIN CATCH
        -- If any error occurs, rollback the transaction
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        -- Re-raise the error for the calling application
        DECLARE @ErrorMessage NVARCHAR(MAX) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();

        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END;
GO