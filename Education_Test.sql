-- SQL_Scripts/Education/06_Tests/Education_Tests.sql

USE UniversityDB;
GO

-- Prerequisite: Ensure Departments and Majors tables have at least one record for Foreign Key constraints
-- You would typically add these in SQL_Scripts/Education/05_Seed_Data/Education_Seed_Data.sql
-- For testing purposes, we might insert them here temporarily if not already present.
-- It's good practice to wrap seed data for tests in a transaction and rollback if not permanent.

BEGIN TRANSACTION; -- Start a transaction for temporary test data

-- Insert a sample Department if it doesn't exist
IF NOT EXISTS (SELECT 1 FROM Education.Departments WHERE DepartmentName = N'Computer Science')
BEGIN
    INSERT INTO Education.Departments (DepartmentName) VALUES (N'Computer Science');
END;

-- Insert a sample Major if it doesn't exist (assuming DepartmentID 1 exists from above)
IF NOT EXISTS (SELECT 1 FROM Education.Majors WHERE MajorName = N'Software Engineering')
BEGIN
    INSERT INTO Education.Majors (MajorName, DepartmentID)
    SELECT N'Software Engineering', DepartmentID FROM Education.Departments WHERE DepartmentName = N'Computer Science';
END;

DECLARE @DeptID INT, @MajorID INT;
SELECT @DeptID = DepartmentID FROM Education.Departments WHERE DepartmentName = N'Computer Science';
SELECT @MajorID = MajorID FROM Education.Majors WHERE MajorName = N'Software Engineering';

PRINT '--- TEST: Inserting a student with a VALID National Code ---';
BEGIN TRY
    INSERT INTO Education.Students (NationalCode, FirstName, LastName, DateOfBirth, Email, PhoneNumber, DepartmentID, MajorID, EnrollmentDate, Status)
    VALUES (N'0075535928', N'Ali', N'Mohammadi', '2000-01-15', 'ali.mohammadi@example.com', '09123456789', @DeptID, @MajorID, GETDATE(), 'Active');
    PRINT 'SUCCESS: Student with valid National Code inserted.';
END TRY
BEGIN CATCH
    PRINT 'FAILURE: Error inserting student with valid National Code: ' + ERROR_MESSAGE();
END CATCH
GO

PRINT '--- TEST: Inserting a student with an INVALID National Code (incorrect checksum) ---';
BEGIN TRY
    INSERT INTO Education.Students (NationalCode, FirstName, LastName, DateOfBirth, Email, PhoneNumber, DepartmentID, MajorID, EnrollmentDate, Status)
    VALUES (N'0075535920', N'Fatemeh', N'Ahmadi', '2001-03-20', 'fatemeh.ahmadi@example.com', '09129876543', @DeptID, @MajorID, GETDATE(), 'Active');
    PRINT 'FAILURE: Student with invalid National Code was inserted (expected an error)!';
END TRY
BEGIN CATCH
    PRINT 'SUCCESS: Expected error caught when inserting student with invalid National Code: ' + ERROR_MESSAGE();
END CATCH
GO

PRINT '--- TEST: Inserting a student with a National Code less than 10 digits ---';
BEGIN TRY
    INSERT INTO Education.Students (NationalCode, FirstName, LastName, DateOfBirth, Email, PhoneNumber, DepartmentID, MajorID, EnrollmentDate, Status)
    VALUES (N'123456789', N'Saeed', N'Rezaei', '1999-07-01', 'saeed.rezaei@example.com', '09121112233', @DeptID, @MajorID, GETDATE(), 'Active');
    PRINT 'FAILURE: Student with short National Code was inserted (expected an error)!';
END TRY
BEGIN CATCH
    PRINT 'SUCCESS: Expected error caught when inserting student with short National Code: ' + ERROR_MESSAGE();
END CATCH
GO

PRINT '--- TEST: Inserting a student with a non-numeric National Code ---';
BEGIN TRY
    INSERT INTO Education.Students (NationalCode, FirstName, LastName, DateOfBirth, Email, PhoneNumber, DepartmentID, MajorID, EnrollmentDate, Status)
    VALUES (N'ABCDEFGHIJ', N'Sara', N'Hasani', '1998-04-22', 'sara.hasani@example.com', '09124445566', @DeptID, @MajorID, GETDATE(), 'Active');
    PRINT 'FAILURE: Student with non-numeric National Code was inserted (expected an error)!';
END TRY
BEGIN CATCH
    PRINT 'SUCCESS: Expected error caught when inserting student with non-numeric National Code: ' + ERROR_MESSAGE();
END CATCH
GO

PRINT '--- TEST: Inserting a student with all repeating digits National Code (e.g., 1111111111) ---';
BEGIN TRY
    INSERT INTO Education.Students (NationalCode, FirstName, LastName, DateOfBirth, Email, PhoneNumber, DepartmentID, MajorID, EnrollmentDate, Status)
    VALUES (N'1111111111', N'Mona', N'Karimi', '2003-09-01', 'mona.karimi@example.com', '09127778899', @DeptID, @MajorID, GETDATE(), 'Active');
    PRINT 'FAILURE: Student with repeating digits National Code was inserted (expected an error)!';
END TRY
BEGIN CATCH
    PRINT 'SUCCESS: Expected error caught when inserting student with repeating digits National Code: ' + ERROR_MESSAGE();
END CATCH
GO

PRINT '--- TEST: Inserting a student with a DUPLICATE National Code (should be caught by UNIQUE constraint, not the trigger for format validation) ---';
-- This test assumes the previous valid insert went through.
BEGIN TRY
    INSERT INTO Education.Students (NationalCode, FirstName, LastName, DateOfBirth, Email, PhoneNumber, DepartmentID, MajorID, EnrollmentDate, Status)
    VALUES (N'0075535928', N'Noura', N'Karimi', '2002-05-10', 'nora.karimi@example.com', '09125554433', @DeptID, @MajorID, GETDATE(), 'Active');
    PRINT 'FAILURE: Student with duplicate National Code was inserted (expected an error)!';
END TRY
BEGIN CATCH
    PRINT 'SUCCESS: Expected error caught when inserting student with duplicate National Code: ' + ERROR_MESSAGE();
END CATCH
GO

-- Clean up test data and rollback the transaction if you don't want permanent changes.
-- If you want to keep the validly inserted data, change to COMMIT TRANSACTION.
ROLLBACK TRANSACTION;
PRINT '--- Test data rolled back. ---';
GO

-- Optional: Verify no test data remains (if rolled back successfully)
-- SELECT * FROM Education.Students WHERE Email IN ('ali.mohammadi@example.com', 'fatemeh.ahmadi@example.com', 'saeed.rezaei@example.com', 'sara.hasani@example.com', 'mona.karimi@example.com', 'nora.karimi@example.com');


-- ==================================================================================================================================================================================

-- SQL_Scripts/Education/05_Seed_Data/Education_Seed_Data.sql

USE UniversityDB;
GO

SET NOCOUNT ON; -- Suppress the message that indicates the number of rows affected

BEGIN TRANSACTION; -- Start a transaction for the seed data

-- region -- Departments

IF NOT EXISTS (SELECT 1 FROM Education.Departments WHERE DepartmentName = N'Computer Science')
    INSERT INTO Education.Departments (DepartmentName) VALUES (N'Computer Science');
IF NOT EXISTS (SELECT 1 FROM Education.Departments WHERE DepartmentName = N'Electrical Engineering')
    INSERT INTO Education.Departments (DepartmentName) VALUES (N'Electrical Engineering');
IF NOT EXISTS (SELECT 1 FROM Education.Departments WHERE DepartmentName = N'Civil Engineering')
    INSERT INTO Education.Departments (DepartmentName) VALUES (N'Civil Engineering');

-- endregion

-- region -- Majors

DECLARE @CompSciDeptID INT = (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = N'Computer Science');
DECLARE @EE_DeptID INT = (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = N'Electrical Engineering');

IF NOT EXISTS (SELECT 1 FROM Education.Majors WHERE MajorName = N'Software Engineering')
    INSERT INTO Education.Majors (MajorName, DepartmentID) VALUES (N'Software Engineering', @CompSciDeptID);
IF NOT EXISTS (SELECT 1 FROM Education.Majors WHERE MajorName = N'Artificial Intelligence')
    INSERT INTO Education.Majors (MajorName, DepartmentID) VALUES (N'Artificial Intelligence', @CompSciDeptID);
IF NOT EXISTS (SELECT 1 FROM Education.Majors WHERE MajorName = N'Electronics')
    INSERT INTO Education.Majors (MajorName, DepartmentID) VALUES (N'Electronics', @EE_DeptID);

-- endregion

-- region -- Professors

DECLARE @SoftwareEngMajorID INT = (SELECT MajorID FROM Education.Majors WHERE MajorName = N'Software Engineering');

IF NOT EXISTS (SELECT 1 FROM Education.Professors WHERE Email = N'dr.ahmadzadeh@example.com')
    INSERT INTO Education.Professors (FirstName, LastName, Email, DepartmentID, Rank, HireDate)
    VALUES (N'Reza', N'Ahmadzadeh', N'dr.ahmadzadeh@example.com', @CompSciDeptID, N'Associate Professor', '2010-09-01');
IF NOT EXISTS (SELECT 1 FROM Education.Professors WHERE Email = N'dr.karimi@example.com')
    INSERT INTO Education.Professors (FirstName, LastName, Email, DepartmentID, Rank, HireDate)
    VALUES (N'Sara', N'Karimi', N'dr.karimi@example.com', @CompSciDeptID, N'Assistant Professor', '2018-02-10');
IF NOT EXISTS (SELECT 1 FROM Education.Professors WHERE Email = N'dr.haddadi@example.com')
    INSERT INTO Education.Professors (FirstName, LastName, Email, DepartmentID, Rank, HireDate)
    VALUES (N'Mohammad', N'Haddadi', N'dr.haddadi@example.com', @EE_DeptID, N'Full Professor', '2005-05-15');

-- Update Department Heads (ensure professor IDs exist)
UPDATE D
SET HeadOfDepartmentID = P.ProfessorID
FROM Education.Departments AS D
JOIN Education.Professors AS P ON D.DepartmentName = N'Computer Science' AND P.Email = N'dr.ahmadzadeh@example.com'
WHERE D.HeadOfDepartmentID IS NULL OR D.HeadOfDepartmentID <> P.ProfessorID;

-- endregion

-- region -- AcademicYears

IF NOT EXISTS (SELECT 1 FROM Education.AcademicYears WHERE YearStart = 2023)
    INSERT INTO Education.AcademicYears (YearStart, YearEnd, Description) VALUES (2023, 2024, N'Fall 2023 - Summer 2024');
IF NOT EXISTS (SELECT 1 FROM Education.AcademicYears WHERE YearStart = 2024)
    INSERT INTO Education.AcademicYears (YearStart, YearEnd, Description) VALUES (2024, 2025, N'Fall 2024 - Summer 2025');

-- endregion

-- region -- Courses

IF NOT EXISTS (SELECT 1 FROM Education.Courses WHERE CourseCode = N'CS101')
    INSERT INTO Education.Courses (CourseCode, CourseName, Credits, DepartmentID, Description)
    VALUES (N'CS101', N'Introduction to Programming', 3.0, @CompSciDeptID, N'Basic concepts of programming using Python.');
IF NOT EXISTS (SELECT 1 FROM Education.Courses WHERE CourseCode = N'CS201')
    INSERT INTO Education.Courses (CourseCode, CourseName, Credits, DepartmentID, Description)
    VALUES (N'CS201', N'Data Structures', 3.0, @CompSciDeptID, N'Fundamental data structures and algorithms.');
IF NOT EXISTS (SELECT 1 FROM Education.Courses WHERE CourseCode = N'CS301')
    INSERT INTO Education.Courses (CourseCode, CourseName, Credits, DepartmentID, Description)
    VALUES (N'CS301', N'Database Systems', 3.0, @CompSciDeptID, N'Relational database design and SQL.');
IF NOT EXISTS (SELECT 1 FROM Education.Courses WHERE CourseCode = N'EE205')
    INSERT INTO Education.Courses (CourseCode, CourseName, Credits, DepartmentID, Description)
    VALUES (N'EE205', N'Circuit Theory I', 3.0, @EE_DeptID, N'Introduction to electrical circuits.');

-- endregion

-- region -- Prerequisites

DECLARE @CS101CourseID INT = (SELECT CourseID FROM Education.Courses WHERE CourseCode = N'CS101');
DECLARE @CS201CourseID INT = (SELECT CourseID FROM Education.Courses WHERE CourseCode = N'CS201');
DECLARE @CS301CourseID INT = (SELECT CourseID FROM Education.Courses WHERE CourseCode = N'CS301');

IF NOT EXISTS (SELECT 1 FROM Education.Prerequisites WHERE CourseID = @CS201CourseID AND PrerequisiteCourseID = @CS101CourseID)
    INSERT INTO Education.Prerequisites (CourseID, PrerequisiteCourseID) VALUES (@CS201CourseID, @CS101CourseID); -- CS201 requires CS101
IF NOT EXISTS (SELECT 1 FROM Education.Prerequisites WHERE CourseID = @CS301CourseID AND PrerequisiteCourseID = @CS201CourseID)
    INSERT INTO Education.Prerequisites (CourseID, PrerequisiteCourseID) VALUES (@CS301CourseID, @CS201CourseID); -- CS301 requires CS201

-- endregion

-- region -- Students

DECLARE @CompSciMajorID INT = (SELECT MajorID FROM Education.Majors WHERE MajorName = N'Software Engineering');
DECLARE @AI_MajorID INT = (SELECT MajorID FROM Education.Majors WHERE MajorName = N'Artificial Intelligence');

-- Valid student
IF NOT EXISTS (SELECT 1 FROM Education.Students WHERE NationalCode = N'0075535928')
    INSERT INTO Education.Students (NationalCode, FirstName, LastName, DateOfBirth, Email, PhoneNumber, DepartmentID, MajorID, EnrollmentDate, Status)
    VALUES (N'0075535928', N'Ali', N'Mohammadi', '2000-01-15', 'ali.mohammadi@example.com', '09123456789', @CompSciDeptID, @CompSciMajorID, '2023-09-01', 'Active');

-- Another valid student
IF NOT EXISTS (SELECT 1 FROM Education.Students WHERE NationalCode = N'0012345679') -- Example valid NC
    INSERT INTO Education.Students (NationalCode, FirstName, LastName, DateOfBirth, Email, PhoneNumber, DepartmentID, MajorID, EnrollmentDate, Status)
    VALUES (N'0012345679', N'Zahra', N'Hosseini', '2001-03-20', 'zahra.hosseini@example.com', '09129876543', @CompSciDeptID, @AI_MajorID, '2023-09-01', 'Active');

-- Inactive student (for testing enrollment failure)
IF NOT EXISTS (SELECT 1 FROM Education.Students WHERE NationalCode = N'0087654321') -- Example valid NC
    INSERT INTO Education.Students (NationalCode, FirstName, LastName, DateOfBirth, Email, PhoneNumber, DepartmentID, MajorID, EnrollmentDate, Status)
    VALUES (N'0087654321', N'Saeed', N'Rezaei', '1999-07-01', 'saeed.rezaei@example.com', '09121112233', @CompSciDeptID, @CompSciMajorID, '2022-09-01', 'Suspended');


-- endregion

-- region -- CourseOfferings

DECLARE @ProfAhmadzadehID INT = (SELECT ProfessorID FROM Education.Professors WHERE Email = N'dr.ahmadzadeh@example.com');
DECLARE @ProfKarimiID INT = (SELECT ProfessorID FROM Education.Professors WHERE Email = N'dr.karimi@example.com');
DECLARE @AY2023ID INT = (SELECT AcademicYearID FROM Education.AcademicYears WHERE YearStart = 2023);
DECLARE @AY2024ID INT = (SELECT AcademicYearID FROM Education.AcademicYears WHERE YearStart = 2024);

-- Offering CS101 in Fall 2023
IF NOT EXISTS (SELECT 1 FROM Education.CourseOfferings WHERE CourseID = @CS101CourseID AND AcademicYearID = @AY2023ID AND Semester = N'Fall' AND ProfessorID = @ProfAhmadzadehID)
    INSERT INTO Education.CourseOfferings (CourseID, ProfessorID, AcademicYearID, Semester, Capacity, Location, Schedule)
    VALUES (@CS101CourseID, @ProfAhmadzadehID, @AY2023ID, N'Fall', 30, N'Room 101', N'Mon/Wed 10:00-11:30');

-- Offering CS201 in Fall 2024
IF NOT EXISTS (SELECT 1 FROM Education.CourseOfferings WHERE CourseID = @CS201CourseID AND AcademicYearID = @AY2024ID AND Semester = N'Fall' AND ProfessorID = @ProfKarimiID)
    INSERT INTO Education.CourseOfferings (CourseID, ProfessorID, AcademicYearID, Semester, Capacity, Location, Schedule)
    VALUES (@CS201CourseID, @ProfKarimiID, @AY2024ID, N'Fall', 25, N'Room 203', N'Tue/Thu 14:00-15:30');

-- Offering CS301 in Fall 2024 (for prerequisite testing)
IF NOT EXISTS (SELECT 1 FROM Education.CourseOfferings WHERE CourseID = @CS301CourseID AND AcademicYearID = @AY2024ID AND Semester = N'Fall' AND ProfessorID = @ProfAhmadzadehID)
    INSERT INTO Education.CourseOfferings (CourseID, ProfessorID, AcademicYearID, Semester, Capacity, Location, Schedule)
    VALUES (@CS301CourseID, @ProfAhmadzadehID, @AY2024ID, N'Fall', 20, N'Room 201', N'Mon/Wed 14:00-15:30');

-- Offering CS201 in Spring 2024 (for testing time conflicts)
IF NOT EXISTS (SELECT 1 FROM Education.CourseOfferings WHERE CourseID = @CS201CourseID AND AcademicYearID = @AY2024ID AND Semester = N'Spring' AND ProfessorID = @ProfKarimiID)
    INSERT INTO Education.CourseOfferings (CourseID, ProfessorID, AcademicYearID, Semester, Capacity, Location, Schedule)
    VALUES (@CS201CourseID, @ProfKarimiID, @AY2024ID, N'Spring', 25, N'Room 203', N'Mon/Wed 10:00-11:30'); -- Same schedule as CS101 in Fall 2023

-- endregion

-- region -- Enrollments and Grades (for testing existing passed courses for prerequisites)

DECLARE @AliStudentID INT = (SELECT StudentID FROM Education.Students WHERE NationalCode = N'0075535928');
DECLARE @ZahraStudentID INT = (SELECT StudentID FROM Education.Students WHERE NationalCode = N'0012345679');
DECLARE @CS101OfferingFall23ID INT = (SELECT OfferingID FROM Education.CourseOfferings WHERE CourseID = @CS101CourseID AND AcademicYearID = @AY2023ID AND Semester = N'Fall');

-- Ali completes CS101 successfully
IF NOT EXISTS (SELECT 1 FROM Education.Enrollments WHERE StudentID = @AliStudentID AND OfferingID = @CS101OfferingFall23ID)
BEGIN
    INSERT INTO Education.Enrollments (StudentID, OfferingID, EnrollmentDate, Status)
    VALUES (@AliStudentID, @CS101OfferingFall23ID, '2023-09-05', 'Completed');

    DECLARE @EnrollmentIDForAliCS101 INT = (SELECT EnrollmentID FROM Education.Enrollments WHERE StudentID = @AliStudentID AND OfferingID = @CS101OfferingFall23ID);
    IF NOT EXISTS (SELECT 1 FROM Education.Grades WHERE EnrollmentID = @EnrollmentIDForAliCS101)
        INSERT INTO Education.Grades (EnrollmentID, FinalGrade, GradeDate)
        VALUES (@EnrollmentIDForAliCS101, 15.5, '2024-01-20');
END;

-- Zahra completes CS101 successfully
IF NOT EXISTS (SELECT 1 FROM Education.Enrollments WHERE StudentID = @ZahraStudentID AND OfferingID = @CS101OfferingFall23ID)
BEGIN
    INSERT INTO Education.Enrollments (StudentID, OfferingID, EnrollmentDate, Status)
    VALUES (@ZahraStudentID, @CS101OfferingFall23ID, '2023-09-05', 'Completed');

    DECLARE @EnrollmentIDForZahraCS101 INT = (SELECT EnrollmentID FROM Education.Enrollments WHERE StudentID = @ZahraStudentID AND OfferingID = @CS101OfferingFall23ID);
    IF NOT EXISTS (SELECT 1 FROM Education.Grades WHERE EnrollmentID = @EnrollmentIDForZahraCS101)
        INSERT INTO Education.Grades (EnrollmentID, FinalGrade, GradeDate)
        VALUES (@EnrollmentIDForZahraCS101, 14.0, '2024-01-20');
END;

-- Ali enrolls in CS201 (for conflict testing later if not enrolled via SP)
DECLARE @CS201OfferingFall24ID INT = (SELECT OfferingID FROM Education.CourseOfferings WHERE CourseID = @CS201CourseID AND AcademicYearID = @AY2024ID AND Semester = N'Fall');
IF NOT EXISTS (SELECT 1 FROM Education.Enrollments WHERE StudentID = @AliStudentID AND OfferingID = @CS201OfferingFall24ID)
BEGIN
    INSERT INTO Education.Enrollments (StudentID, OfferingID, EnrollmentDate, Status)
    VALUES (@AliStudentID, @CS201OfferingFall24ID, GETDATE(), 'Enrolled');
    -- Update capacity for this offering
    UPDATE Education.CourseOfferings SET Capacity = Capacity - 1 WHERE OfferingID = @CS201OfferingFall24ID;
END;


-- endregion

-- region -- Curriculum

-- Define curriculum for Software Engineering
IF NOT EXISTS (SELECT 1 FROM Education.Curriculum WHERE MajorID = @CompSciMajorID AND CourseID = @CS101CourseID)
    INSERT INTO Education.Curriculum (MajorID, CourseID, RequiredSemester, IsMandatory)
    VALUES (@CompSciMajorID, @CS101CourseID, 1, 1); -- CS101 in 1st semester
IF NOT EXISTS (SELECT 1 FROM Education.Curriculum WHERE MajorID = @CompSciMajorID AND CourseID = @CS201CourseID)
    INSERT INTO Education.Curriculum (MajorID, CourseID, RequiredSemester, IsMandatory)
    VALUES (@CompSciMajorID, @CS201CourseID, 2, 1); -- CS201 in 2nd semester
IF NOT EXISTS (SELECT 1 FROM Education.Curriculum WHERE MajorID = @CompSciMajorID AND CourseID = @CS301CourseID)
    INSERT INTO Education.Curriculum (MajorID, CourseID, RequiredSemester, IsMandatory)
    VALUES (@CompSciMajorID, @CS301CourseID, 3, 1); -- CS301 in 3rd semester

-- endregion


-- Consider committing the transaction if you want the data to persist,
-- or rolling it back if this is just for temporary testing.
-- To commit:
COMMIT TRANSACTION;
PRINT 'Seed data inserted successfully.';

-- To rollback:
-- ROLLBACK TRANSACTION;
-- PRINT 'Seed data rolled back (no changes persisted).';

GO