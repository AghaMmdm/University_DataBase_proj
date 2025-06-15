-- SQL_Scripts/Education/05_Seed_Data/Education_Seed_Data.sql

USE UniversityDB;
GO

SET NOCOUNT ON; -- Suppress the message that indicates the number of rows affected

PRINT '--- Starting Seeding Data for Education Schema (English) ---';

-- Wrap all inserts in a transaction for atomicity and easy rollback during development
BEGIN TRANSACTION;

BEGIN TRY

    -- Delete existing data to ensure a clean slate for seeding (optional, but good for re-running)
    -- Order matters due to foreign key constraints.
    DELETE FROM Education.Grades;
    DELETE FROM Education.Enrollments;
    DELETE FROM Education.StudentContacts;
    DELETE FROM Education.Curriculum;
    DELETE FROM Education.Prerequisites;
    DELETE FROM Education.CourseOfferings;
    DELETE FROM Education.Courses;

    -- CRITICAL STEP: Reset HeadOfDepartmentID in Departments BEFORE deleting Professors
    -- This breaks the foreign key dependency from Departments to Professors.
    UPDATE Education.Departments SET HeadOfDepartmentID = NULL;

    DELETE FROM Education.Professors; -- Now safe to delete professors

    DELETE FROM Education.Students;
    DELETE FROM Education.Majors;
    DELETE FROM Education.Departments;

    DELETE FROM Education.AcademicYears;
    DELETE FROM Education.CourseCategories;
    DELETE FROM Education.Addresses;
    DELETE FROM Education.LogEvents; -- Clear log events from previous runs

    PRINT 'Existing Education data cleared (if any).';

    -- Insert data into AcademicYears
    INSERT INTO Education.AcademicYears (YearStart, YearEnd, Description) VALUES
    (2023, 2024, N'Academic Year 2023-2024'),
    (2024, 2025, N'Current Academic Year 2024-2025'),
    (2025, 2026, N'Next Academic Year 2025-2026');
    PRINT 'AcademicYears seeded.';

    -- Insert data into Departments
    INSERT INTO Education.Departments (DepartmentName) VALUES
    (N'Computer Science'),
    (N'Electrical Engineering'),
    (N'Civil Engineering'),
    (N'Mechanical Engineering'),
    (N'Chemistry');
    PRINT 'Departments seeded.';

    -- Insert data into Majors
    INSERT INTO Education.Majors (MajorName, DepartmentID) VALUES
    (N'Software Engineering', (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = N'Computer Science')),
    (N'Artificial Intelligence', (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = N'Computer Science')),
    (N'Power Engineering', (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = N'Electrical Engineering')),
    (N'Electronics', (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = N'Electrical Engineering')),
    (N'Structural Engineering', (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = N'Civil Engineering')),
    (N'Fluid Mechanics', (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = N'Mechanical Engineering')),
    (N'Organic Chemistry', (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = N'Chemistry'));
    PRINT 'Majors seeded.';

    -- Insert data into Addresses
    INSERT INTO Education.Addresses (Street, City, StateProvince, ZipCode, Country) VALUES
    (N'123 Main St', N'Tehran', N'Tehran', N'12345', N'Iran'),
    (N'456 Elm St', N'Isfahan', N'Isfahan', N'67890', N'Iran'),
    (N'789 Oak Ave', N'Shiraz', N'Fars', N'11223', N'Iran'),
    (N'101 Maple Rd', N'Mashhad', N'Razavi Khorasan', N'98765', N'Iran'),
    (N'202 Pine Ln', N'Tabriz', N'East Azerbaijan', N'54321', N'Iran'),
    (N'303 Cedar Blvd', N'Ahvaz', N'Khuzestan', N'10010', N'Iran'),
    (N'404 Birch Ct', N'Kermanshah', N'Kermanshah', N'20020', N'Iran'),
    (N'505 Willow Way', N'Rasht', N'Gilan', N'30030', N'Iran'),
    (N'606 Fir Dr', N'Qom', N'Qom', N'40040', N'Iran'),
    (N'707 Spruce Grv', N'Karaj', N'Alborz', N'50050', N'Iran');
    PRINT 'Addresses seeded.';

    -- Insert data into Students
    -- Using the simplified National Code validation rules
    INSERT INTO Education.Students (NationalCode, FirstName, LastName, DateOfBirth, Email, PhoneNumber, AddressID, EnrollmentDate, DepartmentID, MajorID, Status) VALUES
    (N'0075535920', N'Ali', N'Ahmadi', '2001-05-15', N'ali.ahmadi@example.com', N'09123456789',
     (SELECT AddressID FROM Education.Addresses WHERE Street = N'123 Main St'), GETDATE(),
     (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = N'Computer Science'),
     (SELECT MajorID FROM Education.Majors WHERE MajorName = N'Software Engineering'), N'Active'),
    (N'0012345670', N'Zahra', N'Hosseini', '2002-01-20', N'zahra.hosseini@example.com', N'09129876543',
     (SELECT AddressID FROM Education.Addresses WHERE Street = N'456 Elm St'), GETDATE(),
     (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = N'Computer Science'),
     (SELECT MajorID FROM Education.Majors WHERE MajorName = N'Artificial Intelligence'), N'Active'),
    (N'0087654326', N'Saeed', N'Moradi', '2000-11-01', N'saeed.moradi@example.com', N'09121112233',
     (SELECT AddressID FROM Education.Addresses WHERE Street = N'789 Oak Ave'), GETDATE(),
     (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = N'Electrical Engineering'),
     (SELECT MajorID FROM Education.Majors WHERE MajorName = N'Power Engineering'), N'Suspended'),
    (N'1234567890', N'Nazanin', N'Rahimi', '2003-03-10', N'nazanin.rahimi@example.com', N'09122223344',
     (SELECT AddressID FROM Education.Addresses WHERE Street = N'101 Maple Rd'), GETDATE(),
     (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = N'Civil Engineering'),
     (SELECT MajorID FROM Education.Majors WHERE MajorName = N'Structural Engineering'), N'Active'),
    (N'9876543210', N'Mohammad', N'Karimi', '2001-07-25', N'mohammad.karimi@example.com', N'09123334455',
     (SELECT AddressID FROM Education.Addresses WHERE Street = N'202 Pine Ln'), GETDATE(),
     (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = N'Electrical Engineering'),
     (SELECT MajorID FROM Education.Majors WHERE MajorName = N'Electronics'), N'Active'),
    (N'5501122334', N'Sara', N'Akbari', '2002-09-05', N'sara.akbari@example.com', N'09124445566',
     (SELECT AddressID FROM Education.Addresses WHERE Street = N'303 Cedar Blvd'), GETDATE(),
     (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = N'Computer Science'),
     (SELECT MajorID FROM Education.Majors WHERE MajorName = N'Software Engineering'), N'Active'),
    (N'3322110045', N'Reza', N'Ghasemi', '2000-02-18', N'reza.ghasemi@example.com', N'09125556677',
     (SELECT AddressID FROM Education.Addresses WHERE Street = N'404 Birch Ct'), GETDATE(),
     (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = N'Mechanical Engineering'),
     (SELECT MajorID FROM Education.Majors WHERE MajorName = N'Fluid Mechanics'), N'Active'),
    (N'7766554433', N'Leila', N'Abbasi', '2003-12-01', N'leila.abbasi@example.com', N'09126667788',
     (SELECT AddressID FROM Education.Addresses WHERE Street = N'505 Willow Way'), GETDATE(),
     (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = N'Chemistry'),
     (SELECT MajorID FROM Education.Majors WHERE MajorName = N'Organic Chemistry'), N'Active'),
    (N'0102030405', N'Omid', N'Norouzi', '2004-06-30', N'omid.norouzi@example.com', N'09127778899',
     (SELECT AddressID FROM Education.Addresses WHERE Street = N'606 Fir Dr'), GETDATE(),
     (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = N'Computer Science'),
     (SELECT MajorID FROM Education.Majors WHERE MajorName = N'Artificial Intelligence'), N'Active'),
    (N'0504030201', N'Maryam', N'Sadeghi', '2002-04-12', N'maryam.sadeghi@example.com', N'09128889900',
     (SELECT AddressID FROM Education.Addresses WHERE Street = N'707 Spruce Grv'), GETDATE(),
     (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = N'Electrical Engineering'),
     (SELECT MajorID FROM Education.Majors WHERE MajorName = N'Power Engineering'), N'Active');
    PRINT 'Students seeded.';

    -- Insert data into Professors
    INSERT INTO Education.Professors (FirstName, LastName, Email, DepartmentID, Rank, HireDate, AddressID) VALUES
    (N'Mohammad', N'Ahmadzadeh', N'dr.ahmadzadeh@example.com', (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = N'Computer Science'), N'Assistant Professor', '2018-09-01', (SELECT AddressID FROM Education.Addresses WHERE Street = N'123 Main St')),
    (N'Fatemeh', N'Karimi', N'dr.karimi@example.com', (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = N'Computer Science'), N'Associate Professor', '2015-09-01', (SELECT AddressID FROM Education.Addresses WHERE Street = N'456 Elm St')),
    (N'Reza', N'Sadeghi', N'dr.sadeghi@example.com', (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = N'Electrical Engineering'), N'Professor', '2010-09-01', (SELECT AddressID FROM Education.Addresses WHERE Street = N'789 Oak Ave')),
    (N'Mina', N'Hassani', N'dr.hassani@example.com', (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = N'Civil Engineering'), N'Assistant Professor', '2019-09-01', (SELECT AddressID FROM Education.Addresses WHERE Street = N'101 Maple Rd')),
    (N'Ali', N'Nazari', N'dr.nazari@example.com', (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = N'Mechanical Engineering'), N'Associate Professor', '2016-09-01', (SELECT AddressID FROM Education.Addresses WHERE Street = N'202 Pine Ln')),
    (N'Zahra', N'Alavi', N'dr.alavi@example.com', (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = N'Chemistry'), N'Professor', '2012-09-01', (SELECT AddressID FROM Education.Addresses WHERE Street = N'303 Cedar Blvd'));
    PRINT 'Professors seeded.';

    -- Update HeadOfDepartmentID in Departments
    UPDATE Education.Departments SET HeadOfDepartmentID = (SELECT ProfessorID FROM Education.Professors WHERE Email = N'dr.ahmadzadeh@example.com') WHERE DepartmentName = N'Computer Science';
    UPDATE Education.Departments SET HeadOfDepartmentID = (SELECT ProfessorID FROM Education.Professors WHERE Email = N'dr.sadeghi@example.com') WHERE DepartmentName = N'Electrical Engineering';
    UPDATE Education.Departments SET HeadOfDepartmentID = (SELECT ProfessorID FROM Education.Professors WHERE Email = N'dr.hassani@example.com') WHERE DepartmentName = N'Civil Engineering';
    PRINT 'HeadOfDepartmentID updated in Departments.';

    -- Insert data into CourseCategories
    INSERT INTO Education.CourseCategories (CategoryName, Description) VALUES
    (N'Core Computer Science', N'Mandatory courses for CS majors'),
    (N'Elective Computer Science', N'Optional courses for CS majors'),
    (N'General Education', N'Non-major specific courses'),
    (N'Electrical Engineering Core', N'Mandatory courses for EE majors'),
    (N'Civil Engineering Core', N'Mandatory courses for Civil majors'),
    (N'Chemistry Core', N'Mandatory courses for Chemistry majors');
    PRINT 'CourseCategories seeded.';

    -- Insert data into Courses
    INSERT INTO Education.Courses (CourseCode, CourseName, Credits, DepartmentID, Description, CategoryID) VALUES
    (N'CS101', N'Introduction to Programming', 3.0, (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = N'Computer Science'), N'Fundamental programming concepts.', (SELECT CategoryID FROM Education.CourseCategories WHERE CategoryName = N'Core Computer Science')),
    (N'CS201', N'Data Structures and Algorithms', 3.0, (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = N'Computer Science'), N'Advanced data structures and algorithm design.', (SELECT CategoryID FROM Education.CourseCategories WHERE CategoryName = N'Core Computer Science')),
    (N'CS301', N'Operating Systems', 3.0, (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = N'Computer Science'), N'Principles and design of operating systems.', (SELECT CategoryID FROM Education.CourseCategories WHERE CategoryName = N'Core Computer Science')),
    (N'AI401', N'Machine Learning', 3.0, (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = N'Computer Science'), N'Introduction to machine learning algorithms and applications.', (SELECT CategoryID FROM Education.CourseCategories WHERE CategoryName = N'Elective Computer Science')),
    (N'EE101', N'Basic Electrical Circuits', 3.0, (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = N'Electrical Engineering'), N'Introduction to electrical circuit analysis.', (SELECT CategoryID FROM Education.CourseCategories WHERE CategoryName = N'Electrical Engineering Core')),
    (N'EE201', N'Digital Electronics', 3.0, (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = N'Electrical Engineering'), N'Fundamentals of digital logic and circuit design.', (SELECT CategoryID FROM Education.CourseCategories WHERE CategoryName = N'Electrical Engineering Core')),
    (N'CE101', N'Statics', 3.0, (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = N'Civil Engineering'), N'Introduction to forces and equilibrium.', (SELECT CategoryID FROM Education.CourseCategories WHERE CategoryName = N'Civil Engineering Core')),
    (N'ME201', N'Thermodynamics', 3.0, (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = N'Mechanical Engineering'), N'Principles of energy conversion and heat.', NULL), -- No specific category for Mechanical for now
    (N'CH101', N'General Chemistry I', 3.0, (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = N'Chemistry'), N'Fundamental concepts of chemistry.', (SELECT CategoryID FROM Education.CourseCategories WHERE CategoryName = N'Chemistry Core')),
    (N'MATH101', N'General Mathematics I', 3.0, (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = N'Computer Science'), N'Basic mathematical concepts.', (SELECT CategoryID FROM Education.CourseCategories WHERE CategoryName = N'General Education')),
    (N'PHY101', N'General Physics I', 3.0, (SELECT DepartmentID FROM Education.Departments WHERE DepartmentName = N'Electrical Engineering'), N'Fundamental principles of mechanics and heat.', (SELECT CategoryID FROM Education.CourseCategories WHERE CategoryName = N'General Education'));
    PRINT 'Courses seeded.';

    -- Insert data into Prerequisites
    INSERT INTO Education.Prerequisites (CourseID, PrerequisiteCourseID) VALUES
    ((SELECT CourseID FROM Education.Courses WHERE CourseCode = N'CS201'), (SELECT CourseID FROM Education.Courses WHERE CourseCode = N'CS101')),
    ((SELECT CourseID FROM Education.Courses WHERE CourseCode = N'CS301'), (SELECT CourseID FROM Education.Courses WHERE CourseCode = N'CS201')),
    ((SELECT CourseID FROM Education.Courses WHERE CourseCode = N'AI401'), (SELECT CourseID FROM Education.Courses WHERE CourseCode = N'CS201')),
    ((SELECT CourseID FROM Education.Courses WHERE CourseCode = N'EE201'), (SELECT CourseID FROM Education.Courses WHERE CourseCode = N'EE101'));
    PRINT 'Prerequisites seeded.';

    -- Insert data into CourseOfferings
    -- Using 'AcademicYear' column directly with the year number (e.g., 2023)
    INSERT INTO Education.CourseOfferings (CourseID, ProfessorID, AcademicYear, Semester, Capacity, Location, Schedule) VALUES
    -- 2023-2024 Academic Year Offerings
    ((SELECT CourseID FROM Education.Courses WHERE CourseCode = N'CS101'), (SELECT ProfessorID FROM Education.Professors WHERE Email = N'dr.ahmadzadeh@example.com'), 2023, N'Fall', 50, N'Room 101', N'Sun/Tue 09:00-10:30'),
    ((SELECT CourseID FROM Education.Courses WHERE CourseCode = N'MATH101'), (SELECT ProfessorID FROM Education.Professors WHERE Email = N'dr.sadeghi@example.com'), 2023, N'Fall', 60, N'Auditorium A', N'Mon/Wed 10:00-11:30'),
    ((SELECT CourseID FROM Education.Courses WHERE CourseCode = N'EE101'), (SELECT ProfessorID FROM Education.Professors WHERE Email = N'dr.sadeghi@example.com'), 2023, N'Fall', 45, N'Lab 15', N'Tue/Thu 13:00-14:30'),
    ((SELECT CourseID FROM Education.Courses WHERE CourseCode = N'CH101'), (SELECT ProfessorID FROM Education.Professors WHERE Email = N'dr.alavi@example.com'), 2023, N'Fall', 40, N'Lab 5', N'Sun/Tue 14:00-15:30'),
    ((SELECT CourseID FROM Education.Courses WHERE CourseCode = N'CS201'), (SELECT ProfessorID FROM Education.Professors WHERE Email = N'dr.karimi@example.com'), 2023, N'Spring', 40, N'Room 201', N'Mon/Wed 09:00-10:30'),
    ((SELECT CourseID FROM Education.Courses WHERE CourseCode = N'PHY101'), (SELECT ProfessorID FROM Education.Professors WHERE Email = N'dr.sadeghi@example.com'), 2023, N'Spring', 55, N'Auditorium B', N'Tue/Thu 11:00-12:30'),

    -- 2024-2025 Academic Year Offerings (Current)
    ((SELECT CourseID FROM Education.Courses WHERE CourseCode = N'CS101'), (SELECT ProfessorID FROM Education.Professors WHERE Email = N'dr.ahmadzadeh@example.com'), 2024, N'Fall', 55, N'Room 102', N'Sun/Tue 09:00-10:30'),
    ((SELECT CourseID FROM Education.Courses WHERE CourseCode = N'CS201'), (SELECT ProfessorID FROM Education.Professors WHERE Email = N'dr.karimi@example.com'), 2024, N'Fall', 45, N'Room 202', N'Tue/Thu 14:00-15:30'),
    ((SELECT CourseID FROM Education.Courses WHERE CourseCode = N'CS301'), (SELECT ProfessorID FROM Education.Professors WHERE Email = N'dr.ahmadzadeh@example.com'), 2024, N'Fall', 35, N'Room 301', N'Sun/Tue 11:00-12:30'),
    ((SELECT CourseID FROM Education.Courses WHERE CourseCode = N'AI401'), (SELECT ProfessorID FROM Education.Professors WHERE Email = N'dr.karimi@example.com'), 2024, N'Fall', 30, N'Room 401', N'Mon/Wed 16:00-17:30'),
    ((SELECT CourseID FROM Education.Courses WHERE CourseCode = N'EE201'), (SELECT ProfessorID FROM Education.Professors WHERE Email = N'dr.sadeghi@example.com'), 2024, N'Fall', 38, N'Lab 16', N'Mon/Wed 13:00-14:30'),
    ((SELECT CourseID FROM Education.Courses WHERE CourseCode = N'CE101'), (SELECT ProfessorID FROM Education.Professors WHERE Email = N'dr.hassani@example.com'), 2024, N'Fall', 50, N'Room 501', N'Sun/Tue 10:00-11:30'),
    ((SELECT CourseID FROM Education.Courses WHERE CourseCode = N'ME201'), (SELECT ProfessorID FROM Education.Professors WHERE Email = N'dr.nazari@example.com'), 2024, N'Fall', 42, N'Lab 10', N'Tue/Thu 09:00-10:30'),
    ((SELECT CourseID FROM Education.Courses WHERE CourseCode = N'MATH101'), (SELECT ProfessorID FROM Education.Professors WHERE Email = N'dr.ahmadzadeh@example.com'), 2024, N'Fall', 50, N'Auditorium A', N'Mon/Wed 10:00-11:30'), -- **NEWLY ADDED OFFERING**

    -- 2025-2026 Academic Year Offerings (Next)
    ((SELECT CourseID FROM Education.Courses WHERE CourseCode = N'CS201'), (SELECT ProfessorID FROM Education.Professors WHERE Email = N'dr.karimi@example.com'), 2025, N'Spring', 40, N'Room 203', N'Mon/Wed 10:00-11:30'),
    ((SELECT CourseID FROM Education.Courses WHERE CourseCode = N'AI401'), (SELECT ProfessorID FROM Education.Professors WHERE Email = N'dr.karimi@example.com'), 2025, N'Spring', 35, N'Room 402', N'Tue/Thu 11:00-12:30');
    PRINT 'CourseOfferings seeded.';

    -- Insert data into Enrollments (initial enrollments for testing)
    INSERT INTO Education.Enrollments (StudentID, OfferingID, EnrollmentDate, Status) VALUES
    -- Ali Ahmadi (0075535920)
    ((SELECT StudentID FROM Education.Students WHERE NationalCode = N'0075535920'), (SELECT OfferingID FROM Education.CourseOfferings WHERE CourseID = (SELECT CourseID FROM Education.Courses WHERE CourseCode = N'CS101') AND AcademicYear = 2023 AND Semester = N'Fall'), DATEADD(year, -1, GETDATE()), N'Completed'), -- Ali in CS101 2023 Fall
    ((SELECT StudentID FROM Education.Students WHERE NationalCode = N'0075535920'), (SELECT OfferingID FROM Education.CourseOfferings WHERE CourseID = (SELECT CourseID FROM Education.Courses WHERE CourseCode = N'MATH101') AND AcademicYear = 2023 AND Semester = N'Fall'), DATEADD(year, -1, GETDATE()), N'Completed'), -- Ali in MATH101 2023 Fall
    ((SELECT StudentID FROM Education.Students WHERE NationalCode = N'0075535920'), (SELECT OfferingID FROM Education.CourseOfferings WHERE CourseID = (SELECT CourseID FROM Education.Courses WHERE CourseCode = N'CS201') AND AcademicYear = 2024 AND Semester = N'Fall'), GETDATE(), N'Enrolled'), -- Ali in CS201 2024 Fall

    -- Zahra Hosseini (0012345670)
    ((SELECT StudentID FROM Education.Students WHERE NationalCode = N'0012345670'), (SELECT OfferingID FROM Education.CourseOfferings WHERE CourseID = (SELECT CourseID FROM Education.Courses WHERE CourseCode = N'CS101') AND AcademicYear = 2023 AND Semester = N'Fall'), DATEADD(year, -1, GETDATE()), N'Completed'), -- Zahra in CS101 2023 Fall
    ((SELECT StudentID FROM Education.Students WHERE NationalCode = N'0012345670'), (SELECT OfferingID FROM Education.CourseOfferings WHERE CourseID = (SELECT CourseID FROM Education.Courses WHERE CourseCode = N'CS201') AND AcademicYear = 2023 AND Semester = N'Spring'), DATEADD(year, -1, GETDATE()), N'Completed'), -- Zahra in CS201 2023 Spring
    ((SELECT StudentID FROM Education.Students WHERE NationalCode = N'0012345670'), (SELECT OfferingID FROM Education.CourseOfferings WHERE CourseID = (SELECT CourseID FROM Education.Courses WHERE CourseCode = N'AI401') AND AcademicYear = 2024 AND Semester = N'Fall'), GETDATE(), N'Enrolled'), -- Zahra in AI401 2024 Fall

    -- Saeed Moradi (0087654326)
    ((SELECT StudentID FROM Education.Students WHERE NationalCode = N'0087654326'), (SELECT OfferingID FROM Education.CourseOfferings WHERE CourseID = (SELECT CourseID FROM Education.Courses WHERE CourseCode = N'EE101') AND AcademicYear = 2023 AND Semester = N'Fall'), DATEADD(year, -1, GETDATE()), N'Completed'),
    ((SELECT StudentID FROM Education.Students WHERE NationalCode = N'0087654326'), (SELECT OfferingID FROM Education.CourseOfferings WHERE CourseID = (SELECT CourseID FROM Education.Courses WHERE CourseCode = N'EE201') AND AcademicYear = 2024 AND Semester = N'Fall'), GETDATE(), N'Enrolled'),

    -- Nazanin Rahimi (1234567890)
    ((SELECT StudentID FROM Education.Students WHERE NationalCode = N'1234567890'), (SELECT OfferingID FROM Education.CourseOfferings WHERE CourseID = (SELECT CourseID FROM Education.Courses WHERE CourseCode = N'CE101') AND AcademicYear = 2024 AND Semester = N'Fall'), GETDATE(), N'Enrolled'),
    ((SELECT StudentID FROM Education.Students WHERE NationalCode = N'1234567890'), (SELECT OfferingID FROM Education.CourseOfferings WHERE CourseID = (SELECT CourseID FROM Education.Courses WHERE CourseCode = N'PHY101') AND AcademicYear = 2023 AND Semester = N'Spring'), DATEADD(year, -1, GETDATE()), N'Completed'),

    -- Mohammad Karimi (9876543210)
    ((SELECT StudentID FROM Education.Students WHERE NationalCode = N'9876543210'), (SELECT OfferingID FROM Education.CourseOfferings WHERE CourseID = (SELECT CourseID FROM Education.Courses WHERE CourseCode = N'EE101') AND AcademicYear = 2023 AND Semester = N'Fall'), DATEADD(year, -1, GETDATE()), N'Completed'),
    ((SELECT StudentID FROM Education.Students WHERE NationalCode = N'9876543210'), (SELECT OfferingID FROM Education.CourseOfferings WHERE CourseID = (SELECT CourseID FROM Education.Courses WHERE CourseCode = N'EE201') AND AcademicYear = 2024 AND Semester = N'Fall'), GETDATE(), N'Enrolled'),

    -- Sara Akbari (5501122334)
    ((SELECT StudentID FROM Education.Students WHERE NationalCode = N'5501122334'), (SELECT OfferingID FROM Education.CourseOfferings WHERE CourseID = (SELECT CourseID FROM Education.Courses WHERE CourseCode = N'CS101') AND AcademicYear = 2024 AND Semester = N'Fall'), GETDATE(), N'Enrolled'),
    ((SELECT StudentID FROM Education.Students WHERE NationalCode = N'5501122334'), (SELECT OfferingID FROM Education.CourseOfferings WHERE CourseID = (SELECT CourseID FROM Education.Courses WHERE CourseCode = N'MATH101') AND AcademicYear = 2024 AND Semester = N'Fall'), GETDATE(), N'Enrolled'), -- **THIS ENROLLMENT NOW HAS A MATCHING OFFERING**

    -- Reza Ghasemi (3322110045)
    ((SELECT StudentID FROM Education.Students WHERE NationalCode = N'3322110045'), (SELECT OfferingID FROM Education.CourseOfferings WHERE CourseID = (SELECT CourseID FROM Education.Courses WHERE CourseCode = N'ME201') AND AcademicYear = 2024 AND Semester = N'Fall'), GETDATE(), N'Enrolled'),

    -- Leila Abbasi (7766554433)
    ((SELECT StudentID FROM Education.Students WHERE NationalCode = N'7766554433'), (SELECT OfferingID FROM Education.CourseOfferings WHERE CourseID = (SELECT CourseID FROM Education.Courses WHERE CourseCode = N'CH101') AND AcademicYear = 2023 AND Semester = N'Fall'), DATEADD(year, -1, GETDATE()), N'Completed'),
    ((SELECT StudentID FROM Education.Students WHERE NationalCode = N'7766554433'), (SELECT OfferingID FROM Education.CourseOfferings WHERE CourseID = (SELECT CourseID FROM Education.Courses WHERE CourseCode = N'MATH101') AND AcademicYear = 2023 AND Semester = N'Fall'), DATEADD(year, -1, GETDATE()), N'Completed');
    PRINT 'Initial Enrollments seeded.';

    -- Insert data into Grades for completed enrollments
    INSERT INTO Education.Grades (EnrollmentID, FinalGrade, GradeDate) VALUES
    ((SELECT EnrollmentID FROM Education.Enrollments WHERE StudentID = (SELECT StudentID FROM Education.Students WHERE NationalCode = N'0075535920') AND OfferingID = (SELECT OfferingID FROM Education.CourseOfferings WHERE CourseID = (SELECT CourseID FROM Education.Courses WHERE CourseCode = N'CS101') AND AcademicYear = 2023 AND Semester = N'Fall')), 18.0, DATEADD(month, -6, GETDATE())),
    ((SELECT EnrollmentID FROM Education.Enrollments WHERE StudentID = (SELECT StudentID FROM Education.Students WHERE NationalCode = N'0075535920') AND OfferingID = (SELECT OfferingID FROM Education.CourseOfferings WHERE CourseID = (SELECT CourseID FROM Education.Courses WHERE CourseCode = N'MATH101') AND AcademicYear = 2023 AND Semester = N'Fall')), 15.5, DATEADD(month, -6, GETDATE())),
    ((SELECT EnrollmentID FROM Education.Enrollments WHERE StudentID = (SELECT StudentID FROM Education.Students WHERE NationalCode = N'0012345670') AND OfferingID = (SELECT OfferingID FROM Education.CourseOfferings WHERE CourseID = (SELECT CourseID FROM Education.Courses WHERE CourseCode = N'CS101') AND AcademicYear = 2023 AND Semester = N'Fall')), 17.0, DATEADD(month, -6, GETDATE())),
    ((SELECT EnrollmentID FROM Education.Enrollments WHERE StudentID = (SELECT StudentID FROM Education.Students WHERE NationalCode = N'0012345670') AND OfferingID = (SELECT OfferingID FROM Education.CourseOfferings WHERE CourseID = (SELECT CourseID FROM Education.Courses WHERE CourseCode = N'CS201') AND AcademicYear = 2023 AND Semester = N'Spring')), 16.5, DATEADD(month, -6, GETDATE())),
    ((SELECT EnrollmentID FROM Education.Enrollments WHERE StudentID = (SELECT StudentID FROM Education.Students WHERE NationalCode = N'0087654326') AND OfferingID = (SELECT OfferingID FROM Education.CourseOfferings WHERE CourseID = (SELECT CourseID FROM Education.Courses WHERE CourseCode = N'EE101') AND AcademicYear = 2023 AND Semester = N'Fall')), 14.0, DATEADD(month, -6, GETDATE())),
    ((SELECT EnrollmentID FROM Education.Enrollments WHERE StudentID = (SELECT StudentID FROM Education.Students WHERE NationalCode = N'1234567890') AND OfferingID = (SELECT OfferingID FROM Education.CourseOfferings WHERE CourseID = (SELECT CourseID FROM Education.Courses WHERE CourseCode = N'PHY101') AND AcademicYear = 2023 AND Semester = N'Spring')), 12.0, DATEADD(month, -6, GETDATE())),
    ((SELECT EnrollmentID FROM Education.Enrollments WHERE StudentID = (SELECT StudentID FROM Education.Students WHERE NationalCode = N'9876543210') AND OfferingID = (SELECT OfferingID FROM Education.CourseOfferings WHERE CourseID = (SELECT CourseID FROM Education.Courses WHERE CourseCode = N'EE101') AND AcademicYear = 2023 AND Semester = N'Fall')), 16.0, DATEADD(month, -6, GETDATE())),
    ((SELECT EnrollmentID FROM Education.Enrollments WHERE StudentID = (SELECT StudentID FROM Education.Students WHERE NationalCode = N'7766554433') AND OfferingID = (SELECT OfferingID FROM Education.CourseOfferings WHERE CourseID = (SELECT CourseID FROM Education.Courses WHERE CourseCode = N'CH101') AND AcademicYear = 2023 AND Semester = N'Fall')), 19.0, DATEADD(month, -6, GETDATE())),
    ((SELECT EnrollmentID FROM Education.Enrollments WHERE StudentID = (SELECT StudentID FROM Education.Students WHERE NationalCode = N'7766554433') AND OfferingID = (SELECT OfferingID FROM Education.CourseOfferings WHERE CourseID = (SELECT CourseID FROM Education.Courses WHERE CourseCode = N'MATH101') AND AcademicYear = 2023 AND Semester = N'Fall')), 14.5, DATEADD(month, -6, GETDATE()));
    PRINT 'Grades for initial enrollments seeded and enrollment statuses updated.';

    -- Insert data into Curriculum
    INSERT INTO Education.Curriculum (MajorID, CourseID, RequiredSemester, IsMandatory) VALUES
    ((SELECT MajorID FROM Education.Majors WHERE MajorName = N'Software Engineering'), (SELECT CourseID FROM Education.Courses WHERE CourseCode = N'CS101'), 1, 1),
    ((SELECT MajorID FROM Education.Majors WHERE MajorName = N'Software Engineering'), (SELECT CourseID FROM Education.Courses WHERE CourseCode = N'CS201'), 2, 1),
    ((SELECT MajorID FROM Education.Majors WHERE MajorName = N'Software Engineering'), (SELECT CourseID FROM Education.Courses WHERE CourseCode = N'CS301'), 3, 1),
    ((SELECT MajorID FROM Education.Majors WHERE MajorName = N'Artificial Intelligence'), (SELECT CourseID FROM Education.Courses WHERE CourseCode = N'CS101'), 1, 1),
    ((SELECT MajorID FROM Education.Majors WHERE MajorName = N'Artificial Intelligence'), (SELECT CourseID FROM Education.Courses WHERE CourseCode = N'AI401'), 3, 1),
    ((SELECT MajorID FROM Education.Majors WHERE MajorName = N'Power Engineering'), (SELECT CourseID FROM Education.Courses WHERE CourseCode = N'EE101'), 1, 1),
    ((SELECT MajorID FROM Education.Majors WHERE MajorName = N'Power Engineering'), (SELECT CourseID FROM Education.Courses WHERE CourseCode = N'EE201'), 2, 1),
    ((SELECT MajorID FROM Education.Majors WHERE MajorName = N'Structural Engineering'), (SELECT CourseID FROM Education.Courses WHERE CourseCode = N'CE101'), 1, 1),
    ((SELECT MajorID FROM Education.Majors WHERE MajorName = N'Organic Chemistry'), (SELECT CourseID FROM Education.Courses WHERE CourseCode = N'CH101'), 1, 1),
    ((SELECT MajorID FROM Education.Majors WHERE MajorName = N'Software Engineering'), (SELECT CourseID FROM Education.Courses WHERE CourseCode = N'MATH101'), 1, 1),
    ((SELECT MajorID FROM Education.Majors WHERE MajorName = N'Electronics'), (SELECT CourseID FROM Education.Courses WHERE CourseCode = N'EE101'), 1, 1),
    ((SELECT MajorID FROM Education.Majors WHERE MajorName = N'Electronics'), (SELECT CourseID FROM Education.Courses WHERE CourseCode = N'EE201'), 2, 1);
    PRINT 'Curriculum seeded.';

    -- Insert data into StudentContacts
    INSERT INTO Education.StudentContacts (StudentID, FullName, Relationship, PhoneNumber, Email) VALUES
    ((SELECT StudentID FROM Education.Students WHERE NationalCode = N'0075535920'), N'Reza Ahmadi', N'Father', N'09121234567', N'reza.ahmadi.contact@example.com'),
    ((SELECT StudentID FROM Education.Students WHERE NationalCode = N'0012345670'), N'Maryam Hosseini', N'Mother', N'09127654321', N'maryam.hosseini.contact@example.com'),
    ((SELECT StudentID FROM Education.Students WHERE NationalCode = N'1234567890'), N'Hassan Rahimi', N'Father', N'09121110022', N'h.rahimi.contact@example.com'),
    ((SELECT StudentID FROM Education.Students WHERE NationalCode = N'9876543210'), N'Parvin Karimi', N'Mother', N'09123330044', N'p.karimi.contact@example.com'),
    ((SELECT StudentID FROM Education.Students WHERE NationalCode = N'5501122334'), N'Vahid Akbari', N'Father', N'09125550066', N'v.akbari.contact@example.example.com'),
    ((SELECT StudentID FROM Education.Students WHERE NationalCode = N'3322110045'), N'Narges Ghasemi', N'Mother', N'09127770088', N'n.ghasemi.contact@example.com');
    PRINT 'StudentContacts seeded.';

    -- Commit the transaction if all inserts were successful
    COMMIT TRANSACTION;
    PRINT '--- Education Schema Data Seeding Completed Successfully ---';

END TRY
BEGIN CATCH
    -- Rollback the transaction if any error occurs
    ROLLBACK TRANSACTION;
    PRINT '--- ERROR: Education Schema Data Seeding FAILED! ---';
    PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS NVARCHAR(10));
    PRINT 'Error Severity: ' + CAST(ERROR_SEVERITY() AS NVARCHAR(10));
    PRINT 'Error State: ' + CAST(ERROR_STATE() AS NVARCHAR(10));
    PRINT 'Error Procedure: ' + ISNULL(ERROR_PROCEDURE(), 'N/A');
    PRINT 'Error Line: ' + CAST(ERROR_LINE() AS NVARCHAR(10));
    PRINT 'Error Message: ' + ERROR_MESSAGE();
END CATCH
GO