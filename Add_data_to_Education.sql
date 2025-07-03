USE UniversityDB;
GO

PRINT '--- Starting full data insertion script ---';

-- 1. Insert data into Education.Departments
PRINT 'Inserting data into Education.Departments...';
INSERT INTO Education.Departments (DepartmentName, HeadOfDepartmentID) VALUES
('Computer Engineering', NULL),
('Electrical Engineering', NULL),
('Civil Engineering', NULL),
('Mechanical Engineering', NULL),
('Basic Sciences', NULL);
GO

-- 2. Insert data into Education.Majors
PRINT 'Inserting data into Education.Majors...';
INSERT INTO Education.Majors (MajorName, DepartmentID) VALUES
('Software Engineering', (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = 'Computer Engineering')),
('Hardware Engineering', (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = 'Computer Engineering')),
('Power Engineering', (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = 'Electrical Engineering')),
('Structural Engineering', (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = 'Civil Engineering'));
GO

-- 3. Insert data into Education.Addresses
PRINT 'Inserting data into Education.Addresses...';
INSERT INTO Education.Addresses (Street, City, StateProvince, ZipCode, Country) VALUES
('123 Main St', 'Tehran', 'Tehran', '12345', 'Iran'),
('456 Elm St', 'Isfahan', 'Isfahan', '67890', 'Iran'),
('789 Oak Ave', 'Shiraz', 'Fars', '11223', 'Iran'),
('101 Pine Rd', 'Mashhad', 'Razavi Khorasan', '44556', 'Iran'),
('202 Birch Ln', 'Tabriz', 'East Azerbaijan', '77889', 'Iran');
GO

-- 4. Insert data into Education.Professors
PRINT 'Inserting data into Education.Professors...';
-- Corrected: Removed NationalCode, DateOfBirth, PhoneNumber as they are not in your provided CREATE TABLE for Professors.
INSERT INTO Education.Professors (FirstName, LastName, Email, DepartmentID, AddressID, Rank, HireDate) VALUES
('Ali', 'Ahmadi', 'ali.ahmadi@uni.ac.ir', (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = 'Computer Engineering'), (SELECT AddressID FROM Education.Addresses WHERE Street = '123 Main St'), 'Full Professor', '1995-09-01'),
('Sara', 'Mohammadi', 'sara.m@uni.ac.ir', (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = 'Electrical Engineering'), (SELECT AddressID FROM Education.Addresses WHERE Street = '456 Elm St'), 'Associate Professor', '2000-02-10'),
('Reza', 'Karimi', 'reza.k@uni.ac.ir', (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = 'Basic Sciences'), (SELECT AddressID FROM Education.Addresses WHERE Street = '789 Oak Ave'), 'Assistant Professor', '2005-05-15');
GO

-- Update HeadOfDepartmentID for departments (linking to ProfessorID from newly inserted professors)
PRINT 'Updating HeadOfDepartmentID in Education.Departments...';
UPDATE D SET D.HeadOfDepartmentID = P.ProfessorID
FROM Education.Departments D
INNER JOIN Education.Professors P ON D.DepartmentName = 'Computer Engineering' AND P.LastName = 'Ahmadi'
WHERE D.DepartmentName = 'Computer Engineering';

UPDATE D SET D.HeadOfDepartmentID = P.ProfessorID
FROM Education.Departments D
INNER JOIN Education.Professors P ON D.DepartmentName = 'Electrical Engineering' AND P.LastName = 'Mohammadi'
WHERE D.DepartmentName = 'Electrical Engineering';
GO

-- 5. Insert data into Education.Students
PRINT 'Inserting data into Education.Students (Library.Members will be populated via trigger)...';
-- Using MajorID and AddressID columns as per your final table structure.
INSERT INTO Education.Students (NationalCode, FirstName, LastName, DateOfBirth, Email, PhoneNumber, EnrollmentDate, DepartmentID, MajorID, AddressID, Status) VALUES
('1234567890', 'Mohammad', 'Hosseini', '2000-05-10', 'm.hosseini@std.ac.ir', '09351112233', GETDATE(), (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = 'Computer Engineering'), (SELECT MajorID FROM Education.Majors WHERE MajorName = 'Software Engineering'), (SELECT AddressID FROM Education.Addresses WHERE Street = '101 Pine Rd'), 'Active'),
('0987654321', 'Fatemeh', 'Davoodi', '2001-08-22', 'f.davoodi@std.ac.ir', '09354445566', GETDATE(), (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = 'Electrical Engineering'), (SELECT MajorID FROM Education.Majors WHERE MajorName = 'Power Engineering'), (SELECT AddressID FROM Education.Addresses WHERE Street = '202 Birch Ln'), 'Active'),
('1122334455', 'Sina', 'Akbari', '1999-11-01', 's.akbari@std.ac.ir', '09357778899', GETDATE(), (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = 'Computer Engineering'), (SELECT MajorID FROM Education.Majors WHERE MajorName = 'Hardware Engineering'), (SELECT AddressID FROM Education.Addresses WHERE Street = '123 Main St'), 'Active'),
('5566778899', 'Narges', 'Abbasi', '2002-03-15', 'n.abbasi@std.ac.ir', '09350001122', GETDATE(), (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = 'Civil Engineering'), (SELECT MajorID FROM Education.Majors WHERE MajorName = 'Structural Engineering'), (SELECT AddressID FROM Education.Addresses WHERE Street = '456 Elm St'), 'Active'),
('9988776655', 'TestUser', 'Withdrawn', '1998-01-01', 'test.withdrawn@std.ac.ir', '09351234567', GETDATE(), (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = 'Computer Engineering'), (SELECT MajorID FROM Education.Majors WHERE MajorName = 'Software Engineering'), (SELECT AddressID FROM Education.Addresses WHERE Street = '789 Oak Ave'), 'Active'); -- This student's status will be updated later for trigger test
GO

-- 6. Insert data into Education.StudentContacts
PRINT 'Inserting data into Education.StudentContacts...';
INSERT INTO Education.StudentContacts (StudentID, FullName, Relationship, PhoneNumber, Email) VALUES
((SELECT StudentID FROM Education.Students WHERE NationalCode = '1234567890'), 'Reza Hosseini', 'Father', '09121231234', 'reza.h@example.com'),
((SELECT StudentID FROM Education.Students WHERE NationalCode = '0987654321'), 'Leila Davoodi', 'Mother', '09124564567', 'leila.d@example.com');
GO

-- 7. Insert data into Education.CourseCategories
PRINT 'Inserting data into Education.CourseCategories...';
INSERT INTO Education.CourseCategories (CategoryName, Description) VALUES
('Programming', 'Courses related to software development.'),
('Mathematics', 'Courses covering various mathematical concepts.'),
('Electronics', 'Courses in electrical and electronic circuits.'),
('General', 'General university courses.');
GO

-- 8. Insert data into Education.Courses
PRINT 'Inserting data into Education.Courses...';
-- Using CategoryID column as per your final table structure.
INSERT INTO Education.Courses (CourseCode, CourseName, Credits, DepartmentID, CategoryID, Description) VALUES
('CS101', 'Introduction to Programming', 3, (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = 'Computer Engineering'), (SELECT CategoryID FROM Education.CourseCategories WHERE CategoryName = 'Programming'), 'Basic programming concepts using Python.'),
('MA101', 'Calculus I', 3, (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = 'Basic Sciences'), (SELECT CategoryID FROM Education.CourseCategories WHERE CategoryName = 'Mathematics'), 'Fundamental concepts of calculus.'),
('EE201', 'Circuit Analysis I', 3, (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = 'Electrical Engineering'), (SELECT CategoryID FROM Education.CourseCategories WHERE CategoryName = 'Electronics'), 'Analysis of electrical circuits.'),
('CS201', 'Data Structures', 3, (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = 'Computer Engineering'), (SELECT CategoryID FROM Education.CourseCategories WHERE CategoryName = 'Programming'), 'Fundamental data structures and algorithms.'),
('MA201', 'Linear Algebra', 3, (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = 'Basic Sciences'), (SELECT CategoryID FROM Education.CourseCategories WHERE CategoryName = 'Mathematics'), 'Concepts of vectors, matrices, and linear transformations.');
GO

-- 9. Insert data into Education.Prerequisites
PRINT 'Inserting data into Education.Prerequisites...';
INSERT INTO Education.Prerequisites (CourseID, PrerequisiteCourseID) VALUES
((SELECT CourseID FROM Education.Courses WHERE CourseCode = 'CS201'), (SELECT CourseID FROM Education.Courses WHERE CourseCode = 'CS101')), -- Data Structures requires Intro to Programming
((SELECT CourseID FROM Education.Courses WHERE CourseCode = 'EE201'), (SELECT CourseID FROM Education.Courses WHERE CourseCode = 'MA101')); -- Circuit Analysis requires Calculus I
GO

-- 10. Insert data into Education.Curriculum
PRINT 'Inserting data into Education.Curriculum...';
INSERT INTO Education.Curriculum (MajorID, CourseID, RequiredSemester, IsMandatory) VALUES
-- Software Engineering Curriculum
((SELECT MajorID FROM Education.Majors WHERE MajorName = 'Software Engineering'), (SELECT CourseID FROM Education.Courses WHERE CourseCode = 'CS101'), 1, 1),
((SELECT MajorID FROM Education.Majors WHERE MajorName = 'Software Engineering'), (SELECT CourseID FROM Education.Courses WHERE CourseCode = 'MA101'), 1, 1),
((SELECT MajorID FROM Education.Majors WHERE MajorName = 'Software Engineering'), (SELECT CourseID FROM Education.Courses WHERE CourseCode = 'CS201'), 2, 1),
((SELECT MajorID FROM Education.Majors WHERE MajorName = 'Software Engineering'), (SELECT CourseID FROM Education.Courses WHERE CourseCode = 'MA201'), 2, 1),
((SELECT MajorID FROM Education.Majors WHERE MajorName = 'Software Engineering'), (SELECT CourseID FROM Education.Courses WHERE CourseCode = 'EE201'), 3, 0), -- نقطه ویرگول (;) را حذف و کاما (,) را جایگزین کنید
-- Power Engineering Curriculum
((SELECT MajorID FROM Education.Majors WHERE MajorName = 'Power Engineering'), (SELECT CourseID FROM Education.Courses WHERE CourseCode = 'MA101'), 1, 1),
((SELECT MajorID FROM Education.Majors WHERE MajorName = 'Power Engineering'), (SELECT CourseID FROM Education.Courses WHERE CourseCode = 'EE201'), 2, 1); -- نقطه ویرگول در اینجا صحیح است، چون پایان دستور INSERT است
GO

-- 11. Insert data into Education.CourseOfferings
PRINT 'Inserting data into Education.CourseOfferings...';
INSERT INTO Education.CourseOfferings (CourseID, ProfessorID, AcademicYear, Semester, Capacity, Location, Schedule) VALUES
-- Fall 1404 Offerings
((SELECT CourseID FROM Education.Courses WHERE CourseCode = 'CS101'), (SELECT ProfessorID FROM Education.Professors WHERE LastName = 'Ahmadi'), 1404, N'Fall', 30, 'Room 101', 'Mon/Wed 10:00-11:30'),
((SELECT CourseID FROM Education.Courses WHERE CourseCode = 'MA101'), (SELECT ProfessorID FROM Education.Professors WHERE LastName = 'Karimi'), 1404, N'Fall', 40, 'Room 205', 'Tue/Thu 08:30-10:00'),
((SELECT CourseID FROM Education.Courses WHERE CourseCode = 'EE201'), (SELECT ProfessorID FROM Education.Professors WHERE LastName = 'Mohammadi'), 1404, N'Fall', 25, 'Lab 302', 'Mon/Wed 13:00-14:30'),
((SELECT CourseID FROM Education.Courses WHERE CourseCode = 'CS201'), (SELECT ProfessorID FROM Education.Professors WHERE LastName = 'Ahmadi'), 1404, N'Fall', 20, 'Room 102', 'Tue/Thu 10:00-11:30'),
((SELECT CourseID FROM Education.Courses WHERE CourseCode = 'MA201'), (SELECT ProfessorID FROM Education.Professors WHERE LastName = 'Karimi'), 1404, N'Fall', 35, 'Room 206', 'Mon/Wed 08:30-10:00');
GO



PRINT '--- Populating Education.Enrollments using Education.EnrollStudentInCourse... ---';

-- Declare variables to hold Student IDs and Course Offering IDs
DECLARE @MohammadStudentID INT;
DECLARE @FatemehStudentID INT;
DECLARE @SinaStudentID INT;

DECLARE @CS101OfferingID INT;
DECLARE @MA101OfferingID INT;
DECLARE @CS201OfferingID INT;
DECLARE @EE201OfferingID INT;
DECLARE @MA201OfferingID INT;

-- Declare variables for Enrollment IDs (to capture OUTPUT from SP)
DECLARE @EnrollmentID_Mohammad_CS101 INT;
DECLARE @EnrollmentID_Mohammad_MA101 INT;
DECLARE @EnrollmentID_Fatemeh_MA101 INT;
DECLARE @EnrollmentID_Sina_CS101 INT;
DECLARE @EnrollmentID_Mohammad_CS201 INT;
DECLARE @EnrollmentID_Fatemeh_EE201 INT;


-- Get Student IDs
SELECT @MohammadStudentID = StudentID FROM Education.Students WHERE NationalCode = '1234567890'; -- Mohammad Hosseini
SELECT @FatemehStudentID = StudentID FROM Education.Students WHERE NationalCode = '0987654321'; -- Fatemeh Davoodi
SELECT @SinaStudentID = StudentID FROM Education.Students WHERE NationalCode = '1122334455';     -- Sina Akbari

-- Get Course Offering IDs for Fall 1404
SELECT @CS101OfferingID = OfferingID FROM Education.CourseOfferings CO
INNER JOIN Education.Courses C ON CO.CourseID = C.CourseID
WHERE C.CourseCode = 'CS101' AND CO.AcademicYear = 1404 AND CO.Semester = N'Fall';

SELECT @MA101OfferingID = OfferingID FROM Education.CourseOfferings CO
INNER JOIN Education.Courses C ON CO.CourseID = C.CourseID
WHERE C.CourseCode = 'MA101' AND CO.AcademicYear = 1404 AND CO.Semester = N'Fall';

SELECT @CS201OfferingID = OfferingID FROM Education.CourseOfferings CO
INNER JOIN Education.Courses C ON CO.CourseID = C.CourseID
WHERE C.CourseCode = 'CS201' AND CO.AcademicYear = 1404 AND CO.Semester = N'Fall';

SELECT @EE201OfferingID = OfferingID FROM Education.CourseOfferings CO
INNER JOIN Education.Courses C ON CO.CourseID = C.CourseID
WHERE C.CourseCode = 'EE201' AND CO.AcademicYear = 1404 AND CO.Semester = N'Fall';

SELECT @MA201OfferingID = OfferingID FROM Education.CourseOfferings CO
INNER JOIN Education.Courses C ON CO.CourseID = C.CourseID
WHERE C.CourseCode = 'MA201' AND CO.AcademicYear = 1404 AND CO.Semester = N'Fall';


-- Scenario 1: Successful Enrollments
PRINT 'Enrolling Mohammad in CS101...';
BEGIN TRY
    EXEC Education.EnrollStudentInCourse
        @_StudentID = @MohammadStudentID,
        @_OfferingID = @CS101OfferingID,
        @NewEnrollmentID = @EnrollmentID_Mohammad_CS101 OUTPUT;
END TRY
BEGIN CATCH
    PRINT N'Error enrolling Mohammad in CS101: ' + ERROR_MESSAGE();
    SET @EnrollmentID_Mohammad_CS101 = NULL; -- Ensure it's NULL on failure
END CATCH;


PRINT 'Enrolling Mohammad in MA101...';
BEGIN TRY
    EXEC Education.EnrollStudentInCourse
        @_StudentID = @MohammadStudentID,
        @_OfferingID = @MA101OfferingID,
        @NewEnrollmentID = @EnrollmentID_Mohammad_MA101 OUTPUT;
END TRY
BEGIN CATCH
    PRINT N'Error enrolling Mohammad in MA101: ' + ERROR_MESSAGE();
    SET @EnrollmentID_Mohammad_MA101 = NULL;
END CATCH;

PRINT 'Enrolling Fatemeh in MA101...';
BEGIN TRY
    EXEC Education.EnrollStudentInCourse
        @_StudentID = @FatemehStudentID,
        @_OfferingID = @MA101OfferingID,
        @NewEnrollmentID = @EnrollmentID_Fatemeh_MA101 OUTPUT;
END TRY
BEGIN CATCH
    PRINT N'Error enrolling Fatemeh in MA101: ' + ERROR_MESSAGE();
    SET @EnrollmentID_Fatemeh_MA101 = NULL;
END CATCH;

PRINT 'Enrolling Sina in CS101...';
BEGIN TRY
    EXEC Education.EnrollStudentInCourse
        @_StudentID = @SinaStudentID,
        @_OfferingID = @CS101OfferingID,
        @NewEnrollmentID = @EnrollmentID_Sina_CS101 OUTPUT;
END TRY
BEGIN CATCH
    PRINT N'Error enrolling Sina in CS101: ' + ERROR_MESSAGE();
    SET @EnrollmentID_Sina_CS101 = NULL;
END CATCH;

-- Scenario 2: Enrollments requiring prerequisites (CS201 requires CS101)
PRINT 'Enrolling Mohammad in CS201 (after presumed completion of CS101)...';
BEGIN TRY
    EXEC Education.EnrollStudentInCourse
        @_StudentID = @MohammadStudentID,
        @_OfferingID = @CS201OfferingID,
        @NewEnrollmentID = @EnrollmentID_Mohammad_CS201 OUTPUT;
END TRY
BEGIN CATCH
    PRINT N'Error enrolling Mohammad in CS201: ' + ERROR_MESSAGE();
    SET @EnrollmentID_Mohammad_CS201 = NULL;
END CATCH;


-- Scenario 3: Enroll Fatemeh in a course that has a prerequisite (EE201 requires MA101)
PRINT 'Enrolling Fatemeh in EE201 (after presumed completion of MA101)...';
BEGIN TRY
    EXEC Education.EnrollStudentInCourse
        @_StudentID = @FatemehStudentID,
        @_OfferingID = @EE201OfferingID,
        @NewEnrollmentID = @EnrollmentID_Fatemeh_EE201 OUTPUT;
END TRY
BEGIN CATCH
    PRINT N'Error enrolling Fatemeh in EE201: ' + ERROR_MESSAGE();
    SET @EnrollmentID_Fatemeh_EE201 = NULL;
END CATCH;

PRINT 'Enrollments populated.';

PRINT '--- Updating some enrollments to "Completed" and inserting grades... ---';

-- Mark some enrollments as 'Completed' and insert grades, only if enrollment was successful
-- Mohammad CS101
IF @EnrollmentID_Mohammad_CS101 IS NOT NULL
BEGIN
    UPDATE Education.Enrollments SET Status = 'Completed' WHERE EnrollmentID = @EnrollmentID_Mohammad_CS101;
    INSERT INTO Education.Grades (EnrollmentID, FinalGrade, GradeDate) VALUES (@EnrollmentID_Mohammad_CS101, 18.5, GETDATE());
    PRINT 'Inserted grade for Mohammad in CS101.';
END ELSE BEGIN
    PRINT 'Skipped grade insertion for Mohammad in CS101 (Enrollment failed).';
END;

-- Mohammad MA101
IF @EnrollmentID_Mohammad_MA101 IS NOT NULL
BEGIN
    UPDATE Education.Enrollments SET Status = 'Completed' WHERE EnrollmentID = @EnrollmentID_Mohammad_MA101;
    INSERT INTO Education.Grades (EnrollmentID, FinalGrade, GradeDate) VALUES (@EnrollmentID_Mohammad_MA101, 15.0, GETDATE());
    PRINT 'Inserted grade for Mohammad in MA101.';
END ELSE BEGIN
    PRINT 'Skipped grade insertion for Mohammad in MA101 (Enrollment failed).';
END;

-- Fatemeh MA101
IF @EnrollmentID_Fatemeh_MA101 IS NOT NULL
BEGIN
    UPDATE Education.Enrollments SET Status = 'Completed' WHERE EnrollmentID = @EnrollmentID_Fatemeh_MA101;
    INSERT INTO Education.Grades (EnrollmentID, FinalGrade, GradeDate) VALUES (@EnrollmentID_Fatemeh_MA101, 17.0, GETDATE());
    PRINT 'Inserted grade for Fatemeh in MA101.';
END ELSE BEGIN
    PRINT 'Skipped grade insertion for Fatemeh in MA101 (Enrollment failed).';
END;

-- Mohammad CS201 (For GPA testing, this enrollment is expected to fail due to prerequisite issues,
-- so the IF condition will prevent grade insertion if enrollment failed.)
IF @EnrollmentID_Mohammad_CS201 IS NOT NULL
BEGIN
    -- Only update to 'Completed' and insert grade if the enrollment actually happened.
    UPDATE Education.Enrollments SET Status = 'Completed' WHERE EnrollmentID = @EnrollmentID_Mohammad_CS201;
    INSERT INTO Education.Grades (EnrollmentID, FinalGrade, GradeDate) VALUES (@EnrollmentID_Mohammad_CS201, 19.0, GETDATE());
    PRINT 'Inserted grade for Mohammad in CS201 (if enrollment succeeded).';
END ELSE BEGIN
    PRINT 'Skipped grade insertion for Mohammad in CS201 (Enrollment failed or prerequisites not met).';
END;


PRINT '--- All Education schema data insertion completed successfully. ---';