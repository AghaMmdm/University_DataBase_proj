USE UniversityDB;
GO

PRINT '--- Starting full data deletion across Education and relevant Library schema tables... ---';

-- 1. Education Schema Tables (from child to parent)
PRINT 'Deleting from Education.Grades...';
DELETE FROM Education.Grades;
GO

PRINT 'Deleting from Education.Enrollments...';
DELETE FROM Education.Enrollments;
GO

PRINT 'Deleting from Education.StudentContacts...';
DELETE FROM Education.StudentContacts;
GO

PRINT 'Deleting from Education.Curriculum...';
DELETE FROM Education.Curriculum;
GO

PRINT 'Deleting from Education.Prerequisites...';
DELETE FROM Education.Prerequisites;
GO

PRINT 'Deleting from Education.CourseOfferings...';
DELETE FROM Education.CourseOfferings;
GO

-- If HeadOfDepartmentID in Departments references ProfessorID, set it to NULL first to break dependency
PRINT 'Setting HeadOfDepartmentID in Education.Departments to NULL...';
UPDATE Education.Departments SET HeadOfDepartmentID = NULL;
GO

-- 2. Library Schema Tables (from child to parent where dependencies might exist, or for general cleanup)
-- Ensure Library.Fines, Library.Reservations, Library.Borrows are cleared before Library.Members
PRINT 'Deleting from Library.Fines...';
DELETE FROM Library.Fines;
GO

PRINT 'Deleting from Library.Fines...';
DELETE FROM Library.Books;
GO

PRINT 'Deleting from Library.Reservations...';
DELETE FROM Library.Reservations;
GO

PRINT 'Deleting from Library.Borrows...';
DELETE FROM Library.Borrows;
GO

PRINT 'Deleting from Library.Members (Crucial for Unique Constraint issues)...';
DELETE FROM Library.Members; -- This is very important for your current error!
GO

-- 3. Remaining Education Schema Tables
PRINT 'Deleting from Education.Students...';
DELETE FROM Education.Students;
GO

PRINT 'Deleting from Education.Professors...';
DELETE FROM Education.Professors;
GO

PRINT 'Deleting from Education.Courses...';
DELETE FROM Education.Courses;
GO

PRINT 'Deleting from Education.Majors...';
DELETE FROM Education.Majors;
GO

PRINT 'Deleting from Education.Departments...';
DELETE FROM Education.Departments;
GO

PRINT 'Deleting from Education.Addresses...';
DELETE FROM Education.Addresses;
GO

PRINT 'Deleting from Education.CourseCategories...';
DELETE FROM Education.CourseCategories;
GO

-- 4. Audit/Log Tables (for a completely fresh start)
PRINT 'Deleting from Education.LogEvents...';
DELETE FROM Education.LogEvents;
GO

PRINT 'Deleting from Library.AuditLog...';
DELETE FROM Library.AuditLog; -- Also very important for a clean log

-- Optional: If you inserted data into AcademicYears, uncomment this
-- PRINT 'Deleting from Education.AcademicYears...';
-- DELETE FROM Education.AcademicYears;
-- GO

PRINT '--- All data from Education and relevant Library schema tables deleted. ---';