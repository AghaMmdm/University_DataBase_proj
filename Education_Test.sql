USE UniversityDB;
GO


-- ===================================================================== functions =============================================================================


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
DECLARE @AcademicYear INT = 2025; -- Example Academic Year
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

PRINT '--- Starting Test for Education.EnrollStudentInCourse ---';


PRINT '--- Testing Education.EnrollStudentInCourse ---';

DECLARE @EnrollmentID_Test INT;

-- Select an existing StudentID and OfferingID.
DECLARE @TestStudentID INT = (SELECT TOP 1 StudentID FROM Education.Students ORDER BY StudentID DESC);
DECLARE @TestOfferingID INT = (SELECT TOP 1 OfferingID FROM Education.CourseOfferings ORDER BY OfferingID DESC);


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
        PRINT 'Successfully enrolled student';
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

--========================================================================================================================================--

PRINT '--- Attempting to execute Education.sp_AddStudent once ---';

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

--========================================================================================================================================--

PRINT '--- Attempting to execute Education.sp_UpdateStudentGrade once ---';

-- Declare variables for the test parameters
DECLARE @TestStudentID INT;
DECLARE @TestCourseCode NVARCHAR(20);
DECLARE @TestAcademicYear INT;
DECLARE @TestSemester NVARCHAR(20);
DECLARE @TestFinalGrade DECIMAL(5, 2);

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
ORDER BY E.EnrollmentID DESC; -- Get the most recent enrollment for example

-- Set the grade you want to update/insert
SET @TestFinalGrade = 13.20; -- Example grade: change this as needed (e.g., 8.00 for a fail scenario)

PRINT 'Attempting to update grade for StudentID: ' + ISNULL(CAST(@TestStudentID AS NVARCHAR(10)), 'NULL') +
      ', CourseCode: ' + ISNULL(@TestCourseCode, 'NULL') +
      ', AcademicYear: ' + ISNULL(CAST(@TestAcademicYear AS NVARCHAR(4)), 'NULL') +
      ', Semester: ' + ISNULL(@TestSemester, 'NULL');


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

select *
from Education.grades

PRINT CHAR(13) + CHAR(10) + '--- Single execution of Education.sp_UpdateStudentGrade completed ---';

--========================================================================================================================================--

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
select *
from Education.courses


--========================================================================================================================================--


PRINT N'--- Testing Education.SuggestCoursesForStudent ---';

-- Declare a variable to hold Mohammad Hosseini's StudentID
DECLARE @MohammadStudentID INT;
select *
from Education.students
-- Get Mohammad Hosseini's StudentID using his NationalCode (as per Add_data_to_Education.sql)
SELECT @MohammadStudentID = StudentID FROM Education.Students WHERE NationalCode = '1234567890';

IF @MohammadStudentID IS NOT NULL
BEGIN
    PRINT N'Calling Education.SuggestCoursesForStudent for Mohammad Hosseini (StudentID: ' + CAST(@MohammadStudentID AS NVARCHAR(10)) + N')...';
    EXEC Education.SuggestCoursesForStudent
        @StudentID = @MohammadStudentID,
        @CurrentAcademicYear = 2025,
        @CurrentSemester = N'Fall';

    PRINT N'Testing with a StudentID that does not exist...';
    EXEC Education.SuggestCoursesForStudent
        @StudentID = 99999, -- A non-existent StudentID
        @CurrentAcademicYear = 2025,
        @CurrentSemester = N'Fall';
END
ELSE
BEGIN
    PRINT N'Mohammad Hosseini''s StudentID not found. Please ensure the data insertion script was executed successfully.';
END;

PRINT N'--- Test Execution Complete ---';


-- ===================================================================== Triggers =============================================================================

USE UniversityDB;
GO

PRINT '--- Testing TR_Education_Students_ValidateNationalCode Trigger ---' + CHAR(13) + CHAR(10);

-- Test Case 1: Successful INSERT with a VALID National Code
PRINT 'Test Case 1: Inserting a student with a VALID National Code (Expected: SUCCESS)';
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO Education.Students (NationalCode, FirstName, LastName, DateOfBirth, Email, PhoneNumber, EnrollmentDate, DepartmentID, MajorID, Status, AddressID)
    VALUES ('2345678999', 'Valid', 'Student1', '2000-01-01', 'valid.student1@example.com', '09123456789', GETDATE(),
            (SELECT TOP 1 DepartmentID FROM Education.Departments),
            (SELECT TOP 1 MajorID FROM Education.Majors),
            'Active', NULL);
    COMMIT TRANSACTION;
    PRINT 'SUCCESS: Student with valid National Code inserted.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'FAILED: Unexpected error for valid National Code: ' + ERROR_MESSAGE();
END CATCH;
PRINT CHAR(13) + CHAR(10);

-- Test Case 2: INSERT with an INVALID National Code (Less than 10 digits)
PRINT 'Test Case 2: Inserting a student with an INVALID National Code (less than 10 digits) (Expected: FAILURE)';
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO Education.Students (NationalCode, FirstName, LastName, DateOfBirth, Email, PhoneNumber, EnrollmentDate, DepartmentID, MajorID, Status, AddressID)
    VALUES ('123', 'Invalid', 'Student2', '2000-01-02', 'invalid.student2@example.com', '09123456789', GETDATE(),
            (SELECT TOP 1 DepartmentID FROM Education.Departments),
            (SELECT TOP 1 MajorID FROM Education.Majors),
            'Active', NULL);
    COMMIT TRANSACTION;
    PRINT 'FAILED: Unexpected success for invalid National Code (less than 10 digits).';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'SUCCESS: Insertion blocked as expected for invalid National Code (less than 10 digits): ' + ERROR_MESSAGE();
END CATCH;
PRINT CHAR(13) + CHAR(10);

-- Test Case 3: INSERT with an INVALID National Code (Non-numeric characters)
PRINT 'Test Case 3: Inserting a student with an INVALID National Code (non-numeric) (Expected: FAILURE)';
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO Education.Students (NationalCode, FirstName, LastName, DateOfBirth, Email, PhoneNumber, EnrollmentDate, DepartmentID, MajorID, Status, AddressID)
    VALUES ('ABCDEFGHIJ', 'Invalid', 'Student3', '2000-01-03', 'invalid.student3@example.com', '09123456789', GETDATE(),
            (SELECT TOP 1 DepartmentID FROM Education.Departments),
            (SELECT TOP 1 MajorID FROM Education.Majors),
            'Active', NULL);
    COMMIT TRANSACTION;
    PRINT 'FAILED: Unexpected success for invalid National Code (non-numeric).';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'SUCCESS: Insertion blocked as expected for invalid National Code (non-numeric): ' + ERROR_MESSAGE();
END CATCH;
PRINT CHAR(13) + CHAR(10);

-- Test Case 4: INSERT with an INVALID National Code (All repeating digits)
PRINT 'Test Case 4: Inserting a student with an INVALID National Code (all repeating digits) (Expected: FAILURE)';
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO Education.Students (NationalCode, FirstName, LastName, DateOfBirth, Email, PhoneNumber, EnrollmentDate, DepartmentID, MajorID, Status, AddressID)
    VALUES ('1111111111', 'Invalid', 'Student4', '2000-01-04', 'invalid.student4@example.com', '09123456789', GETDATE(),
            (SELECT TOP 1 DepartmentID FROM Education.Departments),
            (SELECT TOP 1 MajorID FROM Education.Majors),
            'Active', NULL);
    COMMIT TRANSACTION;
    PRINT 'FAILED: Unexpected success for invalid National Code (repeating digits).';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'SUCCESS: Insertion blocked as expected for invalid National Code (repeating digits): ' + ERROR_MESSAGE();
END CATCH;
PRINT CHAR(13) + CHAR(10);

select *
from Education.Students

--========================================================================================================================================--

-- TR_Education_Grades_UpdateEnrollmentStatus test
-- 1. Update a student's status to activate the trigger.
-- Ensure that StudentID 1000 (or any other valid StudentID) exists in your database.
-- Also, the new status must be different from the student's current status for the change to be detected.
UPDATE Education.Students
SET Status = 'Suspended' -- Change status to 'Suspended' or any other valid status
WHERE StudentID = 1000; -- Enter the desired StudentID here
GO

select *
from Education.students

-- 2. Check the contents of the Education.LogEvents table to verify if the trigger logged the event.
SELECT *
FROM Education.LogEvents
ORDER BY LogID DESC; -- Order by LogID to see the latest events first
GO

--========================================================================================================================================--


-- 1. Test trigger to update Enrollment status based on the final grade
INSERT INTO Education.Grades (EnrollmentID, FinalGrade)
VALUES (2, 7.05); -- Example: A passing grade (FinalGrade >= 10 leads to 'Completed' in EnrollmentStatus)
GO


-- 2. Check the updated status in Education.Enrollments table.
-- Include the EnrollmentID(s) you just modified.
SELECT EnrollmentID, Status
FROM Education.Enrollments
WHERE EnrollmentID IN (1, 2); -- Adjust based on the EnrollmentIDs you used

-- 3. Check the logged event in Education.LogEvents table.
SELECT *
FROM Education.LogEvents
ORDER BY LogID DESC; -- Order by LogID to see the latest events first
GO


--========================================================================================================================================--


-- test TR_Education_Enrollments_LogEnrollment

select *
from Education.LogEvents;



--========================================================================================================================================--

-- trg_PreventDirectEnrollmentOutsideSP test
-- 1. Attempt a direct INSERT into Education.Enrollments.
-- This operation is expected to be blocked by the trg_PreventDirectEnrollmentOutsideSP trigger.
-- You can use any plausible (even non-existent) StudentID and OfferingID here,
-- as the trigger will fire and prevent the insert BEFORE foreign key checks occur.
PRINT '--- Attempting Direct Enrollment (Expected to Fail) ---';
INSERT INTO Education.Enrollments (StudentID, OfferingID, EnrollmentDate, Status)
VALUES (9999, 8888, GETDATE(), 'Enrolled'); -- Using dummy IDs for a direct insert attempt
GO

-- 2. Check the Education.Enrollments table to confirm no new record was inserted directly.
-- You should NOT see any record with StudentID 9999 or OfferingID 8888 here.
PRINT '--- Checking Enrollments Table (No Direct Insert Expected) ---';
SELECT EnrollmentID, StudentID, OfferingID, EnrollmentDate, Status
FROM Education.Enrollments
WHERE StudentID = 9999 OR OfferingID = 8888;
GO

-- 3. Check the Education.LogEvents table for the 'Direct Enrollment Blocked' entry.
-- This confirms the trigger successfully intercepted and logged the unauthorized attempt.
PRINT '--- Checking LogEvents for Blocked Attempt ---';
SELECT EventType, EventDescription, UserID, EventDate
FROM Education.LogEvents
WHERE EventType = 'Direct Enrollment Blocked'
ORDER BY LogID DESC;
GO

--========================================================================================================================================--

-- trg_DeactivateLibraryMemberOnStudentStatusChange test
select *
from Education.Students;

-- Declare variables for the test
DECLARE @TestStudentID INT = 1001; 
DECLARE @OldStatus NVARCHAR(20);
DECLARE @NewStatus NVARCHAR(20) = 'Expelled'; -- Or 'Withdrawn' to test that scenario

-- 1. Check the student's initial status and the corresponding library member's status.
PRINT '--- Before Student Status Update ---';
SELECT StudentID, NationalCode, Status AS StudentStatus
FROM Education.Students
WHERE StudentID = @TestStudentID;

SELECT MemberID, Education_StudentID, Status AS MemberStatus
FROM Library.Members
WHERE Education_StudentID = @TestStudentID;

-- Get the current status for comparison (optional, but good for understanding)
SELECT @OldStatus = Status FROM Education.Students WHERE StudentID = @TestStudentID;
PRINT 'Student ' + CAST(@TestStudentID AS NVARCHAR(10)) + ' current status: ' + @OldStatus;

-- 2. Update the student's status to activate the trigger.
-- The trigger Education.trg_DeactivateLibraryMemberOnStudentStatusChange (AFTER UPDATE) will fire.
PRINT '--- Updating Student Status to ' + @NewStatus + ' ---';
UPDATE Education.Students
SET Status = @NewStatus -- Change to 'Expelled' or 'Withdrawn'
WHERE StudentID = @TestStudentID;

-- 3. Check the student's new status and the library member's updated status.
PRINT '--- After Student Status Update ---';
SELECT StudentID, NationalCode, Status AS StudentStatus
FROM Education.Students
WHERE StudentID = @TestStudentID;

SELECT MemberID, Education_StudentID, Status AS MemberStatus
FROM Library.Members
WHERE Education_StudentID = @TestStudentID;

-- 4. Check the Education.LogEvents table for entries related to this action.
-- You should see two entries: 'Student Status Change - Library Deactivation Attempt' and 'Library Member Deactivated'.
SELECT EventType, EventDescription, UserID, EventDate
FROM Education.LogEvents
ORDER BY LogID DESC;