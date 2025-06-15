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
USE UniversityDB;
GO

-- Drop the existing procedure if it exists to replace it with the new version
IF OBJECT_ID('Education.sp_AddStudent', 'P') IS NOT NULL
    DROP PROCEDURE Education.sp_AddStudent;
GO

-- Stored Procedure 1: sp_AddStudent
-- Description: Adds a new student to the Education schema,
-- handling address, department, and major lookup/creation.
-- Requirements: Addresses, Departments, Majors tables must exist.
-- LogEvents table must have at least EventType, EventDescription.
CREATE PROCEDURE Education.sp_AddStudent
    @NationalCode NVARCHAR(10),
    @FirstName NVARCHAR(50),
    @LastName NVARCHAR(50),
    @DateOfBirth DATE,
    @Email NVARCHAR(100),
    @PhoneNumber NVARCHAR(20),
    @Street NVARCHAR(255),
    @City NVARCHAR(100),
    @StateProvince NVARCHAR(100),
    @ZipCode NVARCHAR(20),
    @Country NVARCHAR(100),
    @DepartmentName NVARCHAR(100),
    @MajorName NVARCHAR(100),
    @Status NVARCHAR(20) = 'Active' -- Default status to 'Active'
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @AddressID INT;
        DECLARE @DepartmentID INT;
        DECLARE @MajorID INT;
        DECLARE @NewStudentID INT;
        DECLARE @LogDescription NVARCHAR(MAX);

        -- 1. Check if NationalCode or Email already exists for a student
        IF EXISTS (SELECT 1 FROM Education.Students WHERE NationalCode = @NationalCode)
        BEGIN
            SET @LogDescription = N'Attempt to add student with existing National Code: ' + @NationalCode;
            INSERT INTO Education.LogEvents (EventType, EventDescription) -- Use only existing columns
            VALUES (N'Student Add Failed', @LogDescription);
            THROW 50000, N'Error: A student with this National Code already exists.', 1;
        END

        IF EXISTS (SELECT 1 FROM Education.Students WHERE Email = @Email AND @Email IS NOT NULL)
        BEGIN
            SET @LogDescription = N'Attempt to add student with existing Email: ' + @Email;
            INSERT INTO Education.LogEvents (EventType, EventDescription) -- Use only existing columns
            VALUES (N'Student Add Failed', @LogDescription);
            THROW 50000, N'Error: A student with this Email address already exists.', 1;
        END

        -- 2. Get or Insert Address
        SELECT @AddressID = AddressID
        FROM Education.Addresses
        WHERE Street = @Street AND City = @City AND StateProvince = @StateProvince AND ZipCode = @ZipCode AND Country = @Country;

        IF @AddressID IS NULL
        BEGIN
            INSERT INTO Education.Addresses (Street, City, StateProvince, ZipCode, Country)
            VALUES (@Street, @City, @StateProvince, @ZipCode, @Country);
            SET @AddressID = SCOPE_IDENTITY(); -- Get the ID of the newly inserted address
            PRINT N'Address inserted for new student.';
        END

        -- 3. Get DepartmentID
        SELECT @DepartmentID = DepartmentID
        FROM Education.Departments
        WHERE DepartmentName = @DepartmentName;

        IF @DepartmentID IS NULL
        BEGIN
            SET @LogDescription = N'Attempt to add student with non-existent Department: ' + @DepartmentName;
            INSERT INTO Education.LogEvents (EventType, EventDescription) -- Use only existing columns
            VALUES (N'Student Add Failed', @LogDescription);
            THROW 50000, N'Error: Department not found. Please provide a valid Department Name.', 1;
        END

        -- 4. Get MajorID
        SELECT @MajorID = MajorID
        FROM Education.Majors
        WHERE MajorName = @MajorName AND DepartmentID = @DepartmentID;

        IF @MajorID IS NULL
        BEGIN
            SET @LogDescription = N'Attempt to add student with non-existent Major: ' + @MajorName + N' in Department: ' + @DepartmentName;
            INSERT INTO Education.LogEvents (EventType, EventDescription) -- Use only existing columns
            VALUES (N'Student Add Failed', @LogDescription);
            THROW 50000, N'Error: Major not found within the specified Department. Please provide a valid Major Name.', 1;
        END

        -- 5. Insert new Student
        INSERT INTO Education.Students (NationalCode, FirstName, LastName, DateOfBirth, Email, PhoneNumber, AddressID, EnrollmentDate, DepartmentID, MajorID, Status)
        VALUES (@NationalCode, @FirstName, @LastName, @DateOfBirth, @Email, @PhoneNumber, @AddressID, GETDATE(), @DepartmentID, @MajorID, @Status);

        SET @NewStudentID = SCOPE_IDENTITY();
        PRINT N'Student ' + @FirstName + N' ' + @LastName + N' added successfully with StudentID: ' + CAST(@NewStudentID AS NVARCHAR(10));

        -- 6. Log the event using only the columns available in your LogEvents table
        SET @LogDescription = N'New student ' + @FirstName + N' ' + @LastName + N' added. StudentID: ' + CAST(@NewStudentID AS NVARCHAR(10));
        INSERT INTO Education.LogEvents (EventType, EventDescription)
        VALUES (N'Student Added', @LogDescription);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        -- Re-throw the error to the caller
        DECLARE @ErrorMessage NVARCHAR(MAX), @ErrorSeverity INT, @ErrorState INT;
        SELECT
            @ErrorMessage = ERROR_MESSAGE(),
            @ErrorSeverity = ERROR_SEVERITY(),
            @ErrorState = ERROR_STATE();

        -- Log the error (using only existing columns)
        SET @LogDescription = N'Error adding student: ' + @ErrorMessage;
        INSERT INTO Education.LogEvents (EventType, EventDescription)
        VALUES (N'Student Add Failed', @LogDescription);

        THROW @ErrorMessage, @ErrorSeverity, @ErrorState;
    END CATCH
END;
GO

USE UniversityDB;
GO

-- Drop the existing procedure if it exists to replace it with the new version
IF OBJECT_ID('Education.sp_UpdateStudentGrade', 'P') IS NOT NULL
    DROP PROCEDURE Education.sp_UpdateStudentGrade;
GO

-- Stored Procedure 3: sp_UpdateStudentGrade
-- Description: Records or updates the final grade for a student in a specific course offering.
-- Also updates the enrollment status based on the grade.
-- Requirements: Enrollments, Grades, CourseOfferings, Students tables must exist.
-- LogEvents table must have at least EventType, EventDescription.
CREATE PROCEDURE Education.sp_UpdateStudentGrade
    @StudentID INT,
    @CourseCode NVARCHAR(20),
    @AcademicYear INT,
    @Semester NVARCHAR(20),
    @FinalGrade DECIMAL(5, 2) -- Using DECIMAL for grades to allow for decimal points
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @OfferingID INT;
        DECLARE @EnrollmentID INT;
        DECLARE @CurrentEnrollmentStatus NVARCHAR(20);
        DECLARE @NewEnrollmentStatus NVARCHAR(20);
        DECLARE @LogDescription NVARCHAR(MAX);
        DECLARE @CourseName NVARCHAR(100);
        DECLARE @StudentNationalCode NVARCHAR(10);
        
        -- Define passing grade threshold
        DECLARE @PassingGradeThreshold DECIMAL(5, 2) = 10.00;

        -- 1. Validate Student existence
        SELECT @StudentNationalCode = NationalCode FROM Education.Students WHERE StudentID = @StudentID;
        IF @StudentNationalCode IS NULL
        BEGIN
            SET @LogDescription = N'Grade update failed for StudentID: ' + CAST(@StudentID AS NVARCHAR(10)) + N'. Student not found.';
            INSERT INTO Education.LogEvents (EventType, EventDescription) VALUES (N'Grade Update Failed', @LogDescription);
            THROW 50000, N'Error: Student with the provided StudentID does not exist.', 1;
        END

        -- 2. Get OfferingID based on CourseCode, AcademicYear, Semester
        SELECT
            @OfferingID = co.OfferingID,
            @CourseName = c.CourseName
        FROM Education.CourseOfferings co
        INNER JOIN Education.Courses c ON co.CourseID = c.CourseID
        WHERE c.CourseCode = @CourseCode
          AND co.AcademicYear = @AcademicYear
          AND co.Semester = @Semester;

        IF @OfferingID IS NULL
        BEGIN
            SET @LogDescription = N'Grade update failed for StudentID: ' + CAST(@StudentID AS NVARCHAR(10)) + N'. Course Offering ' + @CourseCode + N' for ' + CAST(@AcademicYear AS NVARCHAR(4)) + N' ' + @Semester + N' not found.';
            INSERT INTO Education.LogEvents (EventType, EventDescription) VALUES (N'Grade Update Failed', @LogDescription);
            THROW 50000, N'Error: The specified Course Offering does not exist.', 1;
        END

        -- 3. Get EnrollmentID and current status
        SELECT @EnrollmentID = EnrollmentID, @CurrentEnrollmentStatus = Status
        FROM Education.Enrollments
        WHERE StudentID = @StudentID AND OfferingID = @OfferingID;

        IF @EnrollmentID IS NULL
        BEGIN
            SET @LogDescription = N'Grade update failed for StudentID: ' + CAST(@StudentID AS NVARCHAR(10)) + N' in ' + @CourseCode + N'. Student not enrolled in this course offering.';
            INSERT INTO Education.LogEvents (EventType, EventDescription) VALUES (N'Grade Update Failed', @LogDescription);
            THROW 50000, N'Error: Student is not enrolled in the specified course offering.', 1;
        END

        -- Optional: Prevent updating grades for already "Completed" or "Failed" courses
        -- IF @CurrentEnrollmentStatus IN ('Completed', 'Failed')
        -- BEGIN
        --     SET @LogDescription = N'Grade update attempted for already ' + @CurrentEnrollmentStatus + N' course. StudentID: ' + CAST(@StudentID AS NVARCHAR(10)) + N', Course: ' + @CourseCode;
        --     INSERT INTO Education.LogEvents (EventType, EventDescription) VALUES (N'Grade Update Failed', @LogDescription);
        --     THROW 50000, N'Error: Grade for this course has already been finalized (' + @CurrentEnrollmentStatus + ').', 1;
        -- END

        -- 4. Determine new enrollment status based on the grade
        IF @FinalGrade >= @PassingGradeThreshold
        BEGIN
            SET @NewEnrollmentStatus = N'Completed';
        END
        ELSE
        BEGIN
            SET @NewEnrollmentStatus = N'Failed';
        END

        -- 5. Insert or Update Grade in Grades table
        IF EXISTS (SELECT 1 FROM Education.Grades WHERE EnrollmentID = @EnrollmentID)
        BEGIN
            -- Update existing grade
            UPDATE Education.Grades
            SET FinalGrade = @FinalGrade,
                GradeDate = GETDATE()
            WHERE EnrollmentID = @EnrollmentID;
            SET @LogDescription = N'Updated grade for StudentID: ' + CAST(@StudentID AS NVARCHAR(10)) + N' in ' + @CourseCode + N' to ' + CAST(@FinalGrade AS NVARCHAR(10)) + N'.';
        END
        ELSE
        BEGIN
            -- Insert new grade
            INSERT INTO Education.Grades (EnrollmentID, FinalGrade, GradeDate)
            VALUES (@EnrollmentID, @FinalGrade, GETDATE());
            SET @LogDescription = N'Inserted grade for StudentID: ' + CAST(@StudentID AS NVARCHAR(10)) + N' in ' + @CourseCode + N' as ' + CAST(@FinalGrade AS NVARCHAR(10)) + N'.';
        END

        -- 6. Update Enrollment Status
        IF @CurrentEnrollmentStatus <> @NewEnrollmentStatus -- Only update if status needs to change
        BEGIN
            UPDATE Education.Enrollments
            SET Status = @NewEnrollmentStatus
            WHERE EnrollmentID = @EnrollmentID;
            SET @LogDescription = @LogDescription + N' Enrollment status changed from ' + @CurrentEnrollmentStatus + N' to ' + @NewEnrollmentStatus + N'.';
        END

        -- 7. Log the successful event (using EventType, EventDescription only as per your LogEvents table)
        INSERT INTO Education.LogEvents (EventType, EventDescription)
        VALUES (N'Grade Updated', @LogDescription);

        COMMIT TRANSACTION;
        PRINT N'SUCCESS: Grade for StudentID ' + CAST(@StudentID AS NVARCHAR(10)) + N' in ' + @CourseCode + N' updated to ' + CAST(@FinalGrade AS NVARCHAR(10)) + N'. Enrollment status is now: ' + @NewEnrollmentStatus + N'.';

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrorMessage NVARCHAR(MAX), @ErrorSeverity INT, @ErrorState INT;
        SELECT
            @ErrorMessage = ERROR_MESSAGE(),
            @ErrorSeverity = ERROR_SEVERITY(),
            @ErrorState = ERROR_STATE();

        -- Log the error (using only existing columns)
        SET @LogDescription = N'Error updating grade for StudentID ' + CAST(@StudentID AS NVARCHAR(10)) + N' in ' + @CourseCode + N': ' + @ErrorMessage;
        INSERT INTO Education.LogEvents (EventType, EventDescription) VALUES (N'Grade Update Failed', @LogDescription);

        THROW @ErrorMessage, @ErrorSeverity, @ErrorState;
    END CATCH
END;
GO

USE UniversityDB;
GO

USE UniversityDB;
GO

-- Drop the existing procedure if it exists to replace it with the new version
IF OBJECT_ID('Education.sp_AddCourseOffering', 'P') IS NOT NULL
    DROP PROCEDURE Education.sp_AddCourseOffering;
GO

-- Stored Procedure 4: sp_AddCourseOffering
-- Description: Adds a new course offering for a specific academic year and semester.
-- Performs validations for Course and Professor existence.
-- *** Adheres strictly to your provided Creation_Tables_of_Education.sql structure ***
-- Requirements: Courses, Professors, CourseOfferings tables must exist.
-- LogEvents table must have at least EventType, EventDescription.
CREATE PROCEDURE Education.sp_AddCourseOffering
    @CourseCode NVARCHAR(20),
    @ProfessorID INT,              -- Changed from ProfessorNationalCode to ProfessorID
    @AcademicYear INT,             -- Year as INT, e.g., 2024
    @Semester NVARCHAR(20),        -- e.g., 'Fall', 'Spring', 'Summer'
    @Schedule NVARCHAR(255),
    -- @Classroom NVARCHAR(50),     -- Removed as per your error (Invalid column name 'Classroom')
    @Capacity INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @CourseID INT;
        -- DECLARE @ProfessorID INT; -- Already a parameter
        DECLARE @LogDescription NVARCHAR(MAX);
        DECLARE @NewOfferingID INT;
        DECLARE @CourseName NVARCHAR(100);
        DECLARE @ProfessorFullName NVARCHAR(100);

        -- 1. Validate Course
        SELECT @CourseID = CourseID, @CourseName = CourseName
        FROM Education.Courses
        WHERE CourseCode = @CourseCode;

        IF @CourseID IS NULL
        BEGIN
            SET @LogDescription = N'Failed to add course offering. Course Code "' + @CourseCode + N'" not found.';
            INSERT INTO Education.LogEvents (EventType, EventDescription) VALUES (N'Course Offering Failed', @LogDescription);
            THROW 50000, N'Error: Course with provided Course Code does not exist.', 1;
        END

        -- 2. Validate Professor by ProfessorID
        SELECT @ProfessorFullName = FirstName + N' ' + LastName
        FROM Education.Professors
        WHERE ProfessorID = @ProfessorID;

        IF @ProfessorFullName IS NULL -- If ProfessorID not found
        BEGIN
            SET @LogDescription = N'Failed to add course offering. Professor with ID ' + CAST(@ProfessorID AS NVARCHAR(10)) + N' not found.';
            INSERT INTO Education.LogEvents (EventType, EventDescription) VALUES (N'Course Offering Failed', @LogDescription);
            THROW 50000, N'Error: Professor with provided ID does not exist.', 1;
        END

        -- 3. Check for Duplicate Course Offering (same course, same professor, same year, same semester)
        IF EXISTS (
            SELECT 1
            FROM Education.CourseOfferings
            WHERE CourseID = @CourseID
              AND ProfessorID = @ProfessorID
              AND AcademicYear = @AcademicYear
              AND Semester = @Semester
        )
        BEGIN
            SET @LogDescription = N'Failed to add course offering. Duplicate offering for ' + @CourseCode + N' by ' + @ProfessorFullName + N' in ' + @Semester + N' ' + CAST(@AcademicYear AS NVARCHAR(4)) + N' already exists.';
            INSERT INTO Education.LogEvents (EventType, EventDescription) VALUES (N'Course Offering Failed', @LogDescription);
            THROW 50000, N'Error: This exact course offering (Course, Professor, Academic Year, Semester) already exists.', 1;
        END

        -- 4. Insert new Course Offering
        INSERT INTO Education.CourseOfferings (CourseID, ProfessorID, AcademicYear, Semester, Schedule, Capacity)
        -- Removed 'Classroom' from the column list, and from VALUES
        VALUES (@CourseID, @ProfessorID, @AcademicYear, @Semester, @Schedule, @Capacity);

        SET @NewOfferingID = SCOPE_IDENTITY();
        SET @LogDescription = N'New Course Offering "' + @CourseName + N'" (' + @CourseCode + N') for ' + @ProfessorFullName + N' in ' + @Semester + N' ' + CAST(@AcademicYear AS NVARCHAR(4)) + N' added successfully. OfferingID: ' + CAST(@NewOfferingID AS NVARCHAR(10));
        INSERT INTO Education.LogEvents (EventType, EventDescription) VALUES (N'Course Offering Added', @LogDescription);

        COMMIT TRANSACTION;
        PRINT N'SUCCESS: Course Offering "' + @CourseName + N'" (' + @CourseCode + N') added successfully with OfferingID: ' + CAST(@NewOfferingID AS NVARCHAR(10));

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrorMessage NVARCHAR(MAX), @ErrorSeverity INT, @ErrorState INT;
        SELECT
            @ErrorMessage = ERROR_MESSAGE(),
            @ErrorSeverity = ERROR_SEVERITY(),
            @ErrorState = ERROR_STATE();

        SET @LogDescription = N'Error adding course offering for ' + @CourseCode + N' (' + @Semester + N' ' + CAST(@AcademicYear AS NVARCHAR(4)) + N'): ' + @ErrorMessage;
        INSERT INTO Education.LogEvents (EventType, EventDescription) VALUES (N'Course Offering Failed', @LogDescription);

        THROW @ErrorMessage, @ErrorSeverity, @ErrorState;
    END CATCH
END;
GO

