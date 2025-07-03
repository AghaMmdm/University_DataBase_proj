USE UniversityDB;
GO


-- ===================================================================== functions =============================================================================
PRINT '--- Starting Test Script for Education Functions ---';
GO

-- 1. Test Education.CalculateStudentGPA
PRINT '--- Testing Education.CalculateStudentGPA ---';
DECLARE @StudentIDForGPA INT;
DECLARE @CalculatedGPA DECIMAL(4,2);

-- Fetch a StudentID that has enrollments and grades (e.g., Mohammad Hosseini from Add_data_to_Education.sql)
SELECT TOP 1 @StudentIDForGPA = StudentID
FROM Education.Students
WHERE NationalCode = '1234567890'; -- Using NationalCode of Mohammad Hosseini

IF @StudentIDForGPA IS NOT NULL
BEGIN
    SET @CalculatedGPA = Education.CalculateStudentGPA(@StudentIDForGPA);
    PRINT N'GPA for StudentID ' + CAST(@StudentIDForGPA AS NVARCHAR(10)) + N' (Mohammad Hosseini): ' + ISNULL(CAST(@CalculatedGPA AS NVARCHAR(10)), 'N/A');

    -- You can add more specific assertions here, e.g., IF @CalculatedGPA > 0.00 THEN PRINT 'GPA is positive.';
END
ELSE
BEGIN
    PRINT 'Student with NationalCode 1234567890 not found. Cannot test CalculateStudentGPA.';
END
GO

-- 2. Test Education.GetRemainingCredits
PRINT '--- Testing Education.GetRemainingCredits ---';
DECLARE @StudentIDForRemainingCredits INT;
DECLARE @RemainingCredits DECIMAL(10,2);

-- Fetch the same StudentID (Mohammad Hosseini)
SELECT TOP 1 @StudentIDForRemainingCredits = StudentID
FROM Education.Students
WHERE NationalCode = '1234567890';

IF @StudentIDForRemainingCredits IS NOT NULL
BEGIN
    SET @RemainingCredits = Education.GetRemainingCredits(@StudentIDForRemainingCredits);
    PRINT N'Remaining Credits for StudentID ' + CAST(@StudentIDForRemainingCredits AS NVARCHAR(10)) + N' (Mohammad Hosseini): ' + ISNULL(CAST(@RemainingCredits AS NVARCHAR(10)), 'N/A');

    -- Note: This result depends heavily on your Curriculum data and what courses are completed.
END
ELSE
BEGIN
    PRINT 'Student with NationalCode 1234567890 not found. Cannot test GetRemainingCredits.';
END
GO

-- 3. Test Education.fn_GetStudentSemesterStatus
PRINT '--- Testing Education.fn_GetStudentSemesterStatus ---';
DECLARE @StudentIDForSemesterStatus INT;
DECLARE @AcademicYear INT = 2024; -- Example Academic Year
DECLARE @Semester NVARCHAR(20) = 'Fall'; -- Example Semester
DECLARE @SemesterStatus NVARCHAR(50);

-- Fetch the same StudentID (Mohammad Hosseini)
SELECT TOP 1 @StudentIDForSemesterStatus = StudentID
FROM Education.Students
WHERE NationalCode = '1234567890';

IF @StudentIDForSemesterStatus IS NOT NULL
BEGIN
    SET @SemesterStatus = Education.fn_GetStudentSemesterStatus(@StudentIDForSemesterStatus, @AcademicYear, @Semester);
    PRINT N'Semester Status for StudentID ' + CAST(@StudentIDForSemesterStatus AS NVARCHAR(10)) +
          N' in ' + CAST(@AcademicYear AS NVARCHAR(4)) + N' ' + @Semester + N' (Mohammad Hosseini): ' + ISNULL(@SemesterStatus, 'N/A');

    -- Test for a student with 0 enrolled credits but 'Active' status (expected 'On Leave')
    -- To properly test 'On Leave', ensure the selected student (or a dummy one) has no enrollments for 2024 Fall
    -- Or, use an AcademicYear/Semester where your student has no enrollments.
    DECLARE @StudentIDForOnLeaveTest INT;
    SELECT TOP 1 @StudentIDForOnLeaveTest = StudentID FROM Education.Students ORDER BY StudentID DESC; -- Pick last inserted student if exists
    -- Assuming no enrollments for this student in 2025 Spring
    SET @AcademicYear = 2025;
    SET @Semester = 'Spring';
    SET @SemesterStatus = Education.fn_GetStudentSemesterStatus(@StudentIDForOnLeaveTest, @AcademicYear, @Semester);
    PRINT N'Semester Status for StudentID ' + ISNULL(CAST(@StudentIDForOnLeaveTest AS NVARCHAR(10)), 'N/A') +
          N' in ' + CAST(@AcademicYear AS NVARCHAR(4)) + N' ' + @Semester + N' (expecting "On Leave" if active and no enrollments): ' + ISNULL(@SemesterStatus, 'N/A');

END
ELSE
BEGIN
    PRINT 'Student with NationalCode 1234567890 not found. Cannot test fn_GetStudentSemesterStatus.';
END
GO

PRINT '--- Test Script for Education Functions Completed ---';
GO


-- ===================================================================== Procedures =============================================================================

USE UniversityDB;
GO

PRINT '--- Starting Test for Education.EnrollStudentInCourse ---' + CHAR(13) + CHAR(10);

-- ---------------------------------------------------------------------
-- Test Education.EnrollStudentInCourse
-- ---------------------------------------------------------------------
PRINT '--- Testing Education.EnrollStudentInCourse ---';

DECLARE @EnrollmentID_Test INT;

-- Select an existing StudentID and OfferingID.
-- You might need to adjust these SELECTs based on your actual data.
-- For example, use a specific NationalCode to get StudentID if you know one.
DECLARE @TestStudentID INT = (SELECT TOP 1 StudentID FROM Education.Students ORDER BY StudentID DESC);
DECLARE @TestOfferingID INT = (SELECT TOP 1 OfferingID FROM Education.CourseOfferings ORDER BY OfferingID DESC);

-- Example: If you want to use a specific student and course offering:
-- DECLARE @TestStudentID INT = (SELECT StudentID FROM Education.Students WHERE NationalCode = N'1234567890');
-- DECLARE @TestOfferingID INT = (SELECT OfferingID FROM Education.CourseOfferings WHERE CourseID = (SELECT CourseID FROM Education.Courses WHERE CourseCode = N'DAT201') AND AcademicYear = 2025 AND Semester = N'Fall');


IF @TestStudentID IS NULL
BEGIN
    PRINT 'Skipping EnrollStudentInCourse tests: Test StudentID could not be determined. Please ensure there is at least one student in Education.Students table.';
END
ELSE IF @TestOfferingID IS NULL
BEGIN
    PRINT 'Skipping EnrollStudentInCourse tests: Test OfferingID could not be determined. Please ensure there is at least one course offering in Education.CourseOfferings table.';
END
ELSE
BEGIN
    PRINT 'Using StudentID: ' + CAST(@TestStudentID AS NVARCHAR(10)) + ' and OfferingID: ' + CAST(@TestOfferingID AS NVARCHAR(10));

    -- Scenario 1: Attempt successful enrollment
    -- This might fail if the student is already enrolled in this offering or the course is at full capacity.
    PRINT 'Attempting successful enrollment (will fail if student already enrolled or capacity full)...';
    BEGIN TRY
        EXEC Education.EnrollStudentInCourse
            @_StudentID = @TestStudentID,
            @_OfferingID = @TestOfferingID,
            @NewEnrollmentID = @EnrollmentID_Test OUTPUT;
        PRINT 'Successfully enrolled student. New EnrollmentID: ' + ISNULL(CAST(@EnrollmentID_Test AS NVARCHAR(10)), 'NULL');
    END TRY
    BEGIN CATCH
        PRINT 'Error enrolling student (Expected for duplicate enrollment, time conflict, capacity full, or missing prerequisites): ' + ERROR_MESSAGE();
    END CATCH;

    -- Scenario 2: Attempt to enroll an already enrolled student (should fail with specific error)
    PRINT 'Attempting to enroll an already enrolled student (should fail with specific error)...';
    BEGIN TRY
        EXEC Education.EnrollStudentInCourse
            @_StudentID = @TestStudentID,
            @_OfferingID = @TestOfferingID,
            @NewEnrollmentID = @EnrollmentID_Test OUTPUT;
    END TRY
    BEGIN CATCH
        PRINT 'Caught expected error for duplicate enrollment: ' + ERROR_MESSAGE();
    END CATCH;

    -- Scenario 3: Attempt to enroll a non-existent student (should fail with specific error)
    PRINT 'Attempting to enroll a non-existent student (should fail with specific error)...';
    BEGIN TRY
        EXEC Education.EnrollStudentInCourse
            @_StudentID = 99999, -- A non-existent StudentID
            @_OfferingID = @TestOfferingID,
            @NewEnrollmentID = @EnrollmentID_Test OUTPUT;
    END TRY
    BEGIN CATCH
        PRINT 'Caught expected error for non-existent student: ' + ERROR_MESSAGE();
    END CATCH;

    -- Scenario 4: Attempt to enroll in a non-existent course offering (should fail with specific error)
    PRINT 'Attempting to enroll in a non-existent course offering (should fail with specific error)...';
    BEGIN TRY
        EXEC Education.EnrollStudentInCourse
            @_StudentID = @TestStudentID,
            @_OfferingID = 99999, -- A non-existent OfferingID
            @NewEnrollmentID = @EnrollmentID_Test OUTPUT;
    END TRY
    BEGIN CATCH
        PRINT 'Caught expected error for non-existent course offering: ' + ERROR_MESSAGE();
    END CATCH;

    -- Scenario 5: Attempt to enroll an inactive student (should fail with specific error)
    -- This requires you to have an inactive student in your database or temporarily update one.
    -- Example (do NOT run this if you don't want to change your data):
    -- UPDATE Education.Students SET Status = 'Withdrawn' WHERE StudentID = @TestStudentID;
    -- Consider testing this manually or with temporary data if modifying existing data is an issue.
    DECLARE @InactiveStudentID INT = (SELECT TOP 1 StudentID FROM Education.Students WHERE Status <> 'Active');
    IF @InactiveStudentID IS NOT NULL
    BEGIN
        PRINT 'Attempting to enroll an inactive student (should fail)... StudentID: ' + CAST(@InactiveStudentID AS NVARCHAR(10));
        BEGIN TRY
            EXEC Education.EnrollStudentInCourse
                @_StudentID = @InactiveStudentID,
                @_OfferingID = @TestOfferingID,
                @NewEnrollmentID = @EnrollmentID_Test OUTPUT;
        END TRY
        BEGIN CATCH
            PRINT 'Caught expected error for inactive student: ' + ERROR_MESSAGE();
        END CATCH;
    END
    ELSE
    BEGIN
        PRINT 'Skipping test for inactive student: No inactive student found in the database. ';
    END;

END;
PRINT CHAR(13) + CHAR(10);
PRINT '--- Test for Education.EnrollStudentInCourse Completed ---';


USE UniversityDB;
GO

PRINT '--- Starting Test for Education.sp_AddStudent ---' + CHAR(13) + CHAR(10);

USE UniversityDB;
GO

PRINT '--- Starting Test for Education.sp_AddStudent ---' + CHAR(13) + CHAR(10);

-- ---------------------------------------------------------------------
-- Test Education.sp_AddStudent
-- ---------------------------------------------------------------------

USE UniversityDB;
GO

PRINT '--- Attempting to execute Education.sp_AddStudent once ---' + CHAR(13) + CHAR(10);

-- IMPORTANT: This script will INSERT a new student into your database.
-- Please ensure the NationalCode and Email are UNIQUE in your Education.Students table
-- before running, otherwise it will fail with an "already exists" error.
-- Also, ensure 'Computer Engineering' and 'Software Engineering' exist in your
-- Education.Departments and Education.Majors tables, respectively.

DECLARE @TestNationalCode NVARCHAR(10) = N'1000000000'; -- Change this to a NationalCode that DOES NOT exist in your DB
DECLARE @TestEmail NVARCHAR(100) = N'test.single.run@example.com'; -- Change this to an Email that DOES NOT exist in your DB

PRINT 'Attempting to add student with NationalCode: ' + @TestNationalCode + ' and Email: ' + @TestEmail;

BEGIN TRY
    EXEC Education.sp_AddStudent
        @NationalCode = @TestNationalCode,
        @FirstName = N'Sahar',
        @LastName = N'Rad',
        @DateOfBirth = '1998-07-20',
        @Email = @TestEmail,
        @PhoneNumber = N'09121234567',
        @Street = N'Elm Street 10',
        @City = N'Tehran',
        @StateProvince = N'Tehran',
        @ZipCode = N'98765',
        @Country = N'Iran',
        @DepartmentName = N'Computer Engineering', -- Ensure this department exists
        @MajorName = N'Software Engineering',    -- Ensure this major exists under the specified department
        @Status = N'Active'; -- Optional, defaults to 'Active'

    PRINT CHAR(13) + CHAR(10) + 'SUCCESS: sp_AddStudent executed successfully. Please check your Education.Students table for the new record.';
END TRY
BEGIN CATCH
    PRINT CHAR(13) + CHAR(10) + 'FAILED: Error executing sp_AddStudent: ' + ERROR_MESSAGE();
    PRINT 'Please check the error message. It might be due to duplicate NationalCode/Email or missing Department/Major.';
END CATCH;

PRINT CHAR(13) + CHAR(10) + '--- Single execution of Education.sp_AddStudent completed ---';






PRINT '--- Attempting to execute Education.sp_UpdateStudentGrade once ---' + CHAR(13) + CHAR(10);

-- IMPORTANT: This script will UPDATE an existing student's grade and enrollment status.
-- Please ensure you provide valid and existing data for the parameters below.

-- Declare variables for the test parameters
DECLARE @TestStudentID INT;
DECLARE @TestCourseCode NVARCHAR(20);
DECLARE @TestAcademicYear INT;
DECLARE @TestSemester NVARCHAR(20);
DECLARE @TestFinalGrade DECIMAL(5, 2);

-- ************************************************************************************
-- ** STEP 1: Replace these placeholder values with actual existing data from your DB **
-- ** You MUST find an existing StudentID, a CourseCode, AcademicYear, and Semester **
-- ** for which an enrollment already exists.                                      **
-- ************************************************************************************

-- Example: Find an existing enrollment to use for testing
-- (You might want to pick specific values you know exist, rather than TOP 1)
SELECT TOP 1
    @TestStudentID = E.StudentID,
    @TestCourseCode = C.CourseCode,
    @TestAcademicYear = CO.AcademicYear,
    @TestSemester = CO.Semester
FROM Education.Enrollments AS E
INNER JOIN Education.CourseOfferings AS CO ON E.OfferingID = CO.OfferingID
INNER JOIN Education.Courses AS C ON CO.CourseID = C.CourseID
-- WHERE E.Status = 'Enrolled' -- Optional: only pick 'Enrolled' students to see status change
ORDER BY E.EnrollmentID DESC; -- Get the most recent enrollment for example

-- Set the grade you want to update/insert
SET @TestFinalGrade = 15.50; -- Example grade: change this as needed (e.g., 8.00 for a fail scenario)

PRINT 'Attempting to update grade for StudentID: ' + ISNULL(CAST(@TestStudentID AS NVARCHAR(10)), 'NULL') +
      ', CourseCode: ' + ISNULL(@TestCourseCode, 'NULL') +
      ', AcademicYear: ' + ISNULL(CAST(@TestAcademicYear AS NVARCHAR(4)), 'NULL') +
      ', Semester: ' + ISNULL(@TestSemester, 'NULL') +
      ' with FinalGrade: ' + ISNULL(CAST(@TestFinalGrade AS NVARCHAR(10)), 'NULL');

-- ************************************************************************************
-- ** STEP 2: Execute the stored procedure with the selected/defined parameters    **
-- ************************************************************************************
IF @TestStudentID IS NOT NULL AND @TestCourseCode IS NOT NULL AND @TestAcademicYear IS NOT NULL AND @TestSemester IS NOT NULL
BEGIN
    BEGIN TRY
        EXEC Education.sp_UpdateStudentGrade
            @StudentID = @TestStudentID,
            @CourseCode = @TestCourseCode,
            @AcademicYear = @TestAcademicYear,
            @Semester = @TestSemester,
            @FinalGrade = @TestFinalGrade;

        PRINT CHAR(13) + CHAR(10) + 'SUCCESS: sp_UpdateStudentGrade executed successfully.';
        PRINT 'Please check the Education.Grades and Education.Enrollments tables for updates related to StudentID ' + CAST(@TestStudentID AS NVARCHAR(10)) + ' and CourseCode ' + @TestCourseCode + '.';
    END TRY
    BEGIN CATCH
        PRINT CHAR(13) + CHAR(10) + 'FAILED: Error executing sp_UpdateStudentGrade: ' + ERROR_MESSAGE();
        PRINT 'Possible reasons: Student/Course Offering/Enrollment not found, or other database errors.';
    END CATCH;
END
ELSE
BEGIN
    PRINT CHAR(13) + CHAR(10) + 'WARNING: Could not find suitable existing data to run the procedure.';
    PRINT 'Please manually set the @TestStudentID, @TestCourseCode, @TestAcademicYear, and @TestSemester variables.';
END;

PRINT CHAR(13) + CHAR(10) + '--- Single execution of Education.sp_UpdateStudentGrade completed ---';



USE UniversityDB;
GO

PRINT '--- Attempting to execute Education.sp_AddCourseOffering once ---' + CHAR(13) + CHAR(10);

-- IMPORTANT: This script will INSERT a new course offering into your database.
-- Please ensure you provide valid and existing data for ProfessorID and CourseCode.
-- Also, the combination of CourseCode, ProfessorID, AcademicYear, and Semester
-- MUST be UNIQUE to avoid a "duplicate offering" error.

-- Declare variables for the test parameters
DECLARE @TestCourseCode NVARCHAR(20);
DECLARE @TestProfessorID INT;
DECLARE @TestAcademicYear INT = 2026; -- Set a future academic year to reduce chance of duplicates
DECLARE @TestSemester NVARCHAR(20) = N'Fall'; -- Set a semester

-- ************************************************************************************
-- ** STEP 1: Replace these placeholder values with actual existing data from your DB **
-- ** You MUST find an existing CourseCode and ProfessorID.                         **
-- ************************************************************************************

-- Example: Find an existing CourseCode
SELECT TOP 1 @TestCourseCode = CourseCode FROM Education.Courses ORDER BY CourseID;
-- Example: Find an existing ProfessorID
SELECT TOP 1 @TestProfessorID = ProfessorID FROM Education.Professors ORDER BY ProfessorID;

-- Add a unique identifier to the semester for repeated runs if @TestAcademicYear is not always future
-- For example, use a dynamic part or a distinct year/semester combo.
-- For a single test run, just incrementing the year can work.
SET @TestAcademicYear = (SELECT ISNULL(MAX(AcademicYear), 2025) + 1 FROM Education.CourseOfferings);
-- You might want to make the semester unique if running multiple times within the same year
-- SET @TestSemester = N'Fall_' + CAST(DATEPART(hh, GETDATE()) AS NVARCHAR) + CAST(DATEPART(mi, GETDATE()) AS NVARCHAR);


PRINT 'Attempting to add Course Offering for CourseCode: ' + ISNULL(@TestCourseCode, 'NULL') +
      ', ProfessorID: ' + ISNULL(CAST(@TestProfessorID AS NVARCHAR(10)), 'NULL') +
      ', AcademicYear: ' + ISNULL(CAST(@TestAcademicYear AS NVARCHAR(4)), 'NULL') +
      ', Semester: ' + ISNULL(@TestSemester, 'NULL');

-- ************************************************************************************
-- ** STEP 2: Execute the stored procedure with the selected/defined parameters    **
-- ************************************************************************************
IF @TestCourseCode IS NOT NULL AND @TestProfessorID IS NOT NULL
BEGIN
    BEGIN TRY
        EXEC Education.sp_AddCourseOffering
            @CourseCode = @TestCourseCode,
            @ProfessorID = @TestProfessorID,
            @AcademicYear = @TestAcademicYear,
            @Semester = @TestSemester,
            @Schedule = N'Sun, Tue 10:00-11:30 (Room A101)',
            @Capacity = 50;

        PRINT CHAR(13) + CHAR(10) + 'SUCCESS: sp_AddCourseOffering executed successfully.';
        PRINT 'Please check your Education.CourseOfferings table for the new record.';
    END TRY
    BEGIN CATCH
        PRINT CHAR(13) + CHAR(10) + 'FAILED: Error executing sp_AddCourseOffering: ' + ERROR_MESSAGE();
        PRINT 'Possible reasons: Course/Professor not found, duplicate offering, or other database errors.';
    END CATCH;
END
ELSE
BEGIN
    PRINT CHAR(13) + CHAR(10) + 'WARNING: Could not find suitable existing data (Course or Professor) to run the procedure.';
    PRINT 'Please manually set the @TestCourseCode and @TestProfessorID variables with valid IDs from your database.';
END;

PRINT CHAR(13) + CHAR(10) + '--- Single execution of Education.sp_AddCourseOffering completed ---';

select *
from Education.CourseOfferings;




-- ===================================================================== Triggers =============================================================================

