USE UniversityDB;
GO

-- Description: enroll a student in a specific course offering
CREATE PROCEDURE Education.EnrollStudentInCourse
    @_StudentID INT,
    @_OfferingID INT,
    @NewEnrollmentID INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CourseID INT;
    DECLARE @CourseName NVARCHAR(100);
    DECLARE @StudentStatus NVARCHAR(20);
    DECLARE @MaxCapacity INT;
    DECLARE @CalculatedCurrentCapacity INT;
    DECLARE @StudentMajorID INT;
    DECLARE @CourseSchedule NVARCHAR(255);
    DECLARE @CourseOfferingAcademicYearID INT;
    DECLARE @CourseOfferingSemester NVARCHAR(20);

    SET @NewEnrollmentID = NULL; -- Initialize output parameter

    BEGIN TRY
        -- Set context to signal trigger that this is an authorized insert
        SET CONTEXT_INFO 0x504F4351;

        -- 1. Validate Student Existence and Status
        SELECT @StudentStatus = S.Status, @StudentMajorID = S.MajorID
        FROM Education.Students AS S
        WHERE S.StudentID = @_StudentID;

        IF @StudentStatus IS NULL
        BEGIN
            RAISERROR('Error: Student with ID %d does not exist.', 16, 1, @_StudentID);
            SET CONTEXT_INFO 0x; 
            RETURN;
        END

        IF @StudentStatus <> 'Active'
        BEGIN
            RAISERROR('Error: Student with ID %d is not active and cannot enroll in courses. Current status: %s', 16, 1, @_StudentID, @StudentStatus);
            SET CONTEXT_INFO 0x; 
            RETURN;
        END

        -- 2. Validate Course Offering Existence and Max Capacity
        SELECT
            @CourseID = CO.CourseID,
            @MaxCapacity = CO.Capacity,
            @CourseSchedule = CO.Schedule,
            @CourseOfferingAcademicYearID = CO.AcademicYear,
            @CourseOfferingSemester = CO.Semester,
            @CourseName = C.CourseName
        FROM Education.CourseOfferings AS CO
        INNER JOIN Education.Courses AS C ON CO.CourseID = C.CourseID
        WHERE CO.OfferingID = @_OfferingID;

        IF @CourseID IS NULL
        BEGIN
            RAISERROR('Error: Course Offering with ID %d does not exist.', 16, 1, @_OfferingID);
            SET CONTEXT_INFO 0x;
            RETURN;
        END

        -- Dynamically calculate CurrentCapacity by counting active enrollments for this offering
        SELECT @CalculatedCurrentCapacity = COUNT(*)
        FROM Education.Enrollments
        WHERE OfferingID = @_OfferingID
          AND Status IN ('Enrolled', 'InProgress');

        IF @CalculatedCurrentCapacity >= @MaxCapacity
        BEGIN
            RAISERROR('Error: Course Offering with ID %d is full. Current enrollments: %d, Max capacity: %d', 16, 1, @_OfferingID, @CalculatedCurrentCapacity, @MaxCapacity);
            SET CONTEXT_INFO 0x;
            RETURN;
        END

        -- 3. Check for Duplicate Enrollment in the same offering
        IF EXISTS (SELECT 1 FROM Education.Enrollments WHERE StudentID = @_StudentID AND OfferingID = @_OfferingID)
        BEGIN
            RAISERROR('Error: Student with ID %d is already enrolled in Course Offering with ID %d.', 16, 1, @_StudentID, @_OfferingID);
            SET CONTEXT_INFO 0x; 
            RETURN;
        END

        -- 4. Check for Time Conflicts for the student in the same semester and year
        IF EXISTS (
            SELECT 1
            FROM Education.Enrollments AS E
            INNER JOIN Education.CourseOfferings AS CO ON E.OfferingID = CO.OfferingID
            WHERE E.StudentID = @_StudentID
              AND CO.AcademicYear = @CourseOfferingAcademicYearID
              AND CO.Semester = @CourseOfferingSemester
              AND CO.Schedule = @CourseSchedule
              AND E.Status IN ('Enrolled', 'InProgress')
        )
        BEGIN
            RAISERROR('Error: Student with ID %d has a time conflict with another enrolled course for OfferingID %d.', 16, 1, @_StudentID, @_OfferingID);
            SET CONTEXT_INFO 0x;
            RETURN;
        END

        -- 5. Check for Prerequisites
        DECLARE @PrerequisitesMet BIT = 1;
        IF EXISTS (SELECT 1 FROM Education.Prerequisites WHERE CourseID = @CourseID)
        BEGIN
            IF NOT EXISTS (
                SELECT P.PrerequisiteCourseID
                FROM Education.Prerequisites AS P
                LEFT JOIN Education.Enrollments AS E ON E.StudentID = @_StudentID
                                                     AND E.Status = 'Completed'
                                                     AND E.OfferingID IN (SELECT OfferingID FROM Education.CourseOfferings WHERE CourseID = P.PrerequisiteCourseID)
                WHERE P.CourseID = @CourseID
                  AND E.EnrollmentID IS NULL
            )
            BEGIN
                SET @PrerequisitesMet = 1;
            END
            ELSE
            BEGIN
                DECLARE @MissingPrereqCourseName NVARCHAR(100);
                DECLARE @MissingPrereqCourseID INT;

                SELECT TOP 1 @MissingPrereqCourseID = P.PrerequisiteCourseID,
                             @MissingPrereqCourseName = PC.CourseName
                FROM Education.Prerequisites AS P
                INNER JOIN Education.Courses AS PC ON P.PrerequisiteCourseID = PC.CourseID
                LEFT JOIN Education.Enrollments AS E ON E.StudentID = @_StudentID
                                                     AND E.Status = 'Completed'
                                                     AND E.OfferingID IN (SELECT OfferingID FROM Education.CourseOfferings WHERE CourseID = P.PrerequisiteCourseID)
                WHERE P.CourseID = @CourseID
                  AND E.EnrollmentID IS NULL;

                RAISERROR('Error: Student with ID %d has not completed the prerequisite course "%s" (ID: %d).', 16, 1, @_StudentID, @MissingPrereqCourseName, @MissingPrereqCourseID);
                SET CONTEXT_INFO 0x;
                RETURN;
            END;
        END;

        -- 6. Check if student's major allows this course (Curriculum check)
        IF NOT EXISTS (
            SELECT 1 FROM Education.Curriculum
            WHERE MajorID = @StudentMajorID AND CourseID = @CourseID
        )
        BEGIN
            RAISERROR('Error: Course "%s" (ID: %d) is not part of the curriculum for student''s major (ID: %d).', 16, 1, @CourseName, @CourseID, @StudentMajorID);
            SET CONTEXT_INFO 0x; 
            RETURN;
        END

        -- 7. Insert the enrollment record (this will trigger INSTEAD OF INSERT trigger)
        INSERT INTO Education.Enrollments (StudentID, OfferingID, EnrollmentDate, Status)
        VALUES (@_StudentID, @_OfferingID, GETDATE(), 'Enrolled');

        -- Get the newly generated EnrollmentID and set the output parameter
        SET @NewEnrollmentID = SCOPE_IDENTITY();

        -- Log success
        DECLARE @LogDescription NVARCHAR(MAX);
        SET @LogDescription = N'Student ID ' + CAST(@_StudentID AS NVARCHAR(10)) + N' enrolled in Course Offering ID ' + CAST(@_OfferingID AS NVARCHAR(10)) + N'. EnrollmentID: ' + CAST(@NewEnrollmentID AS NVARCHAR(10));
        INSERT INTO Education.LogEvents (EventType, EventDescription)
        VALUES (N'Student Enrolled', @LogDescription);

        PRINT N'SUCCESS: Student ' + CAST(@_StudentID AS NVARCHAR(10)) + N' enrolled in Course Offering ' + CAST(@_OfferingID AS NVARCHAR(10)) + N'. EnrollmentID: ' + CAST(@NewEnrollmentID AS NVARCHAR(10));

    END TRY
    BEGIN CATCH
        SET CONTEXT_INFO 0x;

        DECLARE @ErrorMessage NVARCHAR(MAX), @ErrorSeverity INT, @ErrorState INT;
        SELECT
            @ErrorMessage = ERROR_MESSAGE(),
            @ErrorSeverity = ERROR_SEVERITY(),
            @ErrorState = ERROR_STATE();

        INSERT INTO Education.LogEvents (EventType, EventDescription)
        VALUES (N'Enrollment Failed', N'Error enrolling student ' + CAST(@_StudentID AS NVARCHAR(10)) + N' in offering ' + CAST(@_OfferingID AS NVARCHAR(10)) + N': ' + @ErrorMessage);

        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH

    SET CONTEXT_INFO 0x; 
END;
GO

-- Description: Adds a new student to the Education schema
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


-- Description: Records or updates the final grade for a student in a specific course offering.
-- Also updates the enrollment status based on the grade.
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



-- Description: Adds a new course offering for a specific academic year and semester.
-- Performs validations for Course and Professor existence.
CREATE PROCEDURE Education.sp_AddCourseOffering
    @CourseCode NVARCHAR(20),
    @ProfessorID INT,
    @AcademicYear INT,
    @Semester NVARCHAR(20),
    @Schedule NVARCHAR(255),
    @Capacity INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @CourseID INT;
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

-- Description : stored prosedure for suggesting course for student
CREATE PROCEDURE Education.SuggestCoursesForStudent
    @StudentID INT,
    @CurrentAcademicYear INT,
    @CurrentSemester NVARCHAR(20) -- e.g., 'Fall', 'Spring', 'Summer'
AS
BEGIN
    SET NOCOUNT ON;

    -- Log event for auditing
    INSERT INTO Education.LogEvents (EventType, EventDescription, UserID)
    VALUES ('Course Suggestion Request', 'Request for course suggestions for StudentID: ' + CAST(@StudentID AS NVARCHAR(10)), SUSER_SNAME());

    DECLARE @StudentMajorID INT;

    -- 1. Get Student's Major
    SELECT @StudentMajorID = S.MajorID
    FROM Education.Students AS S
    WHERE S.StudentID = @StudentID;

    IF @StudentMajorID IS NULL
    BEGIN
        RAISERROR('Error: Student not found or Major not assigned. Please ensure StudentID is correct and student has a MajorID.', 16, 1);
        RETURN;
    END;

    -- 2. Identify courses already completed by the student
    -- Assuming a passing grade is >= 10
    CREATE TABLE #CompletedCourses (CourseID INT PRIMARY KEY);
    INSERT INTO #CompletedCourses (CourseID)
    SELECT DISTINCT C.CourseID
    FROM Education.Grades AS G
    INNER JOIN Education.Enrollments AS E ON G.EnrollmentID = E.EnrollmentID
    INNER JOIN Education.CourseOfferings AS CO ON E.OfferingID = CO.OfferingID
    INNER JOIN Education.Courses AS C ON CO.CourseID = C.CourseID
    WHERE E.StudentID = @StudentID AND G.FinalGrade >= 10 -- Adjust passing grade threshold if different
      AND E.Status = 'Completed'; -- Only consider completed courses

    -- 3. Get currently offered courses for the specified academic year and semester
    CREATE TABLE #CurrentOfferings (
        OfferingID INT PRIMARY KEY,
        CourseID INT,
        ProfessorID INT,
        Schedule NVARCHAR(255),
        Capacity INT,
        EnrolledCount INT,
        AcademicYear INT,
        Semester NVARCHAR(20)
    );
    INSERT INTO #CurrentOfferings (OfferingID, CourseID, ProfessorID, Schedule, Capacity, EnrolledCount, AcademicYear, Semester)
    SELECT
        CO.OfferingID,
        CO.CourseID,
        CO.ProfessorID,
        CO.Schedule,
        CO.Capacity,
        (SELECT COUNT(*) FROM Education.Enrollments WHERE OfferingID = CO.OfferingID AND Status = 'Enrolled') AS Enrolled,
        CO.AcademicYear,
        CO.Semester
    FROM Education.CourseOfferings AS CO
    WHERE CO.AcademicYear = @CurrentAcademicYear
      AND CO.Semester = @CurrentSemester
      AND CO.Capacity > (SELECT COUNT(*) FROM Education.Enrollments WHERE OfferingID = CO.OfferingID AND Status = 'Enrolled'); -- Only available courses

    -- 4. Suggest courses based on:
    --    a. Part of student's major curriculum (from Education.Curriculum)
    --    b. Not already completed by the student
    --    c. Currently offered
    --    d. Prerequisite checks (if Education.Prerequisites table is populated)
    --    e. Order by RequiredSemester and then by whether it's mandatory
    SELECT
        C.CourseID,
        C.CourseName,
        C.CourseCode,
        C.Credits,
        COF.OfferingID,
        P.FirstName + ' ' + P.LastName AS ProfessorName,
        COF.Schedule,
        (COF.Capacity - COF.EnrolledCount) AS AvailableSlots,
        CUR.RequiredSemester,
        CASE WHEN CUR.IsMandatory = 1 THEN N'اجباری' ELSE N'اختیاری' END AS CourseType
    FROM Education.Curriculum AS CUR -- Using your Curriculum table
    INNER JOIN Education.Courses AS C ON CUR.CourseID = C.CourseID
    INNER JOIN #CurrentOfferings AS COF ON C.CourseID = COF.CourseID
    LEFT JOIN Education.Professors AS P ON COF.ProfessorID = P.ProfessorID
    WHERE
        CUR.MajorID = @StudentMajorID
        AND C.CourseID NOT IN (SELECT CourseID FROM #CompletedCourses)
        -- Check for prerequisites: Ensure all prerequisites for the suggested course are met
        AND NOT EXISTS (
            SELECT 1
            FROM Education.Prerequisites AS CP
            WHERE CP.CourseID = C.CourseID -- The course we are suggesting
              AND CP.PrerequisiteCourseID NOT IN (SELECT CourseID FROM #CompletedCourses) -- Prerequisite is NOT completed
        )
    ORDER BY
        CUR.RequiredSemester, -- Order by the suggested semester
        CUR.IsMandatory DESC, -- Mandatory courses first
        C.CourseName;

    -- Clean up temporary tables
    DROP TABLE #CompletedCourses;
    DROP TABLE #CurrentOfferings;

END;
GO

