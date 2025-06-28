USE UniversityDB;
GO

-- Table: Education.Departments
CREATE TABLE Education.Departments (
    DepartmentID INT PRIMARY KEY IDENTITY(1,1), -- IDENTITY for auto-incrementing primary key
    DepartmentName NVARCHAR(100) NOT NULL UNIQUE,
    HeadOfDepartmentID INT NULL -- link to profossor table
);
GO

-- Table: Education.Students
CREATE TABLE Education.Students (
    StudentID INT PRIMARY KEY IDENTITY(1000,1), -- Starting ID from 1000 for Students
    NationalCode NVARCHAR(10) NOT NULL UNIQUE,
    FirstName NVARCHAR(50) NOT NULL,
    LastName NVARCHAR(50) NOT NULL,
    DateOfBirth DATE,
    Email NVARCHAR(100) UNIQUE,
    PhoneNumber NVARCHAR(20),
    Address NVARCHAR(255),
    EnrollmentDate DATE NOT NULL DEFAULT GETDATE(), -- Default enrollment date is today
    DepartmentID INT NOT NULL,
    Major NVARCHAR(100),
    Status NVARCHAR(20) NOT NULL DEFAULT 'Active', -- ('Active', 'Graduated', 'Expelled', 'Withdrawn', 'Suspended')
    CONSTRAINT FK_Student_Department FOREIGN KEY (DepartmentID) REFERENCES Education.Departments(DepartmentID),
    CONSTRAINT CHK_StudentStatus CHECK (Status IN ('Active', 'Graduated', 'Expelled', 'Withdrawn', 'Suspended'))
);
GO

-- Table: Education.Professors
CREATE TABLE Education.Professors (
    ProfessorID INT PRIMARY KEY IDENTITY(1,1),
    FirstName NVARCHAR(50) NOT NULL,
    LastName NVARCHAR(50) NOT NULL,
    Email NVARCHAR(100) UNIQUE,
    DepartmentID INT NOT NULL,
    Rank NVARCHAR(50),
    HireDate DATE NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_Professor_Department FOREIGN KEY (DepartmentID) REFERENCES Education.Departments(DepartmentID)
);
GO

-- link the HeadOfDepartmentID column in the Departments table to ProfessorID in the Professors table
ALTER TABLE Education.Departments
ADD CONSTRAINT FK_Department_Head FOREIGN KEY (HeadOfDepartmentID) REFERENCES Education.Professors(ProfessorID);
GO

-- Table: Education.Courses
CREATE TABLE Education.Courses (
    CourseID INT PRIMARY KEY IDENTITY(1,1),
    CourseCode NVARCHAR(20) NOT NULL UNIQUE,
    CourseName NVARCHAR(100) NOT NULL,
    Credits DECIMAL(3,1) NOT NULL,
    DepartmentID INT NOT NULL,
    Description NVARCHAR(MAX),
    CONSTRAINT FK_Course_Department FOREIGN KEY (DepartmentID) REFERENCES Education.Departments(DepartmentID)
);
GO

-- Table: Education.CourseOfferings
CREATE TABLE Education.CourseOfferings (
    OfferingID INT PRIMARY KEY IDENTITY(1,1),
    CourseID INT NOT NULL,
    ProfessorID INT NOT NULL,
    AcademicYear INT NOT NULL,
    Semester NVARCHAR(20) NOT NULL,
    Capacity INT NOT NULL,
    Location NVARCHAR(100),
    Schedule NVARCHAR(255),
    CONSTRAINT FK_Offering_Course FOREIGN KEY (CourseID) REFERENCES Education.Courses(CourseID),
    CONSTRAINT FK_Offering_Professor FOREIGN KEY (ProfessorID) REFERENCES Education.Professors(ProfessorID),
    CONSTRAINT UQ_CourseOffering UNIQUE (CourseID, AcademicYear, Semester, ProfessorID) -- A course can be offered by one professor in a specific semester only once
);
GO

-- Table: Education.Enrollments
CREATE TABLE Education.Enrollments (
    EnrollmentID INT PRIMARY KEY IDENTITY(1,1),
    StudentID INT NOT NULL,
    OfferingID INT NOT NULL,
    EnrollmentDate DATETIME NOT NULL DEFAULT GETDATE(),
    Grade DECIMAL(4,2) NULL,
    Status NVARCHAR(20) NOT NULL DEFAULT 'Enrolled',
    CONSTRAINT FK_Enrollment_Student FOREIGN KEY (StudentID) REFERENCES Education.Students(StudentID),
    CONSTRAINT FK_Enrollment_Offering FOREIGN KEY (OfferingID) REFERENCES Education.CourseOfferings(OfferingID),
    CONSTRAINT UQ_Student_Offering UNIQUE (StudentID, OfferingID), -- A student can enroll in a specific course offering only once
    CONSTRAINT CHK_EnrollmentStatus CHECK (Status IN ('Enrolled', 'Completed', 'Dropped', 'Failed', 'Withdrawn'))
);
GO

-- Table: Education.Prerequisites
CREATE TABLE Education.Prerequisites (
    PrerequisiteID INT PRIMARY KEY IDENTITY(1,1),
    CourseID INT NOT NULL,
    PrerequisiteCourseID INT NOT NULL,
    CONSTRAINT FK_Prereq_Course FOREIGN KEY (CourseID) REFERENCES Education.Courses(CourseID),
    CONSTRAINT FK_Prereq_PrerequisiteCourse FOREIGN KEY (PrerequisiteCourseID) REFERENCES Education.Courses(CourseID),
    CONSTRAINT UQ_Course_Prereq UNIQUE (CourseID, PrerequisiteCourseID), -- Each course-prerequisite combination must be unique
    CONSTRAINT CHK_SelfPrerequisite CHECK (CourseID <> PrerequisiteCourseID) -- A course cannot be its own prerequisite
);
GO

-- Table: Education.Majors
CREATE TABLE Education.Majors (
    MajorID INT PRIMARY KEY IDENTITY(1,1),
    MajorName NVARCHAR(100) NOT NULL UNIQUE,
    DepartmentID INT NOT NULL,
    CONSTRAINT FK_Major_Department FOREIGN KEY (DepartmentID) REFERENCES Education.Departments(DepartmentID)
);
GO

-- link the Major column in the Students table to MajorID in the Majors table
ALTER TABLE Education.Students
DROP COLUMN Major; -- Drop the old Major column from Students
GO

ALTER TABLE Education.Students
ADD MajorID INT NULL; -- Add the new MajorID column

ALTER TABLE Education.Students
ADD CONSTRAINT FK_Student_Major FOREIGN KEY (MajorID) REFERENCES Education.Majors(MajorID);
GO

-- Table: Education.Curriculum
CREATE TABLE Education.Curriculum (
    CurriculumID INT PRIMARY KEY IDENTITY(1,1),
    MajorID INT NOT NULL,
    CourseID INT NOT NULL,
    RequiredSemester INT NOT NULL, -- Suggested semester for taking the course
    IsMandatory BIT NOT NULL DEFAULT 1, -- 1 for mandatory, 0 for elective
    CONSTRAINT FK_Curriculum_Major FOREIGN KEY (MajorID) REFERENCES Education.Majors(MajorID),
    CONSTRAINT FK_Curriculum_Course FOREIGN KEY (CourseID) REFERENCES Education.Courses(CourseID),
    CONSTRAINT UQ_Curriculum_Entry UNIQUE (MajorID, CourseID), -- Each course appears once in a major's curriculum
    CONSTRAINT CHK_RequiredSemester CHECK (RequiredSemester > 0)
);
GO

-- Table: Education.LogEvents
CREATE TABLE Education.LogEvents (
    LogID BIGINT PRIMARY KEY IDENTITY(1,1),
    EventType NVARCHAR(50) NOT NULL,
    EventDescription NVARCHAR(MAX),
    EventDate DATETIME NOT NULL DEFAULT GETDATE(),
    UserID NVARCHAR(50) NULL -- User ID who performed the operation
);
GO

-- Table: Education.AcademicYears
CREATE TABLE Education.AcademicYears (
    AcademicYearID INT PRIMARY KEY IDENTITY(1,1),
    YearStart INT NOT NULL UNIQUE,
    YearEnd INT NOT NULL UNIQUE,
    Description NVARCHAR(50),
    CONSTRAINT CHK_YearsOrder CHECK (YearEnd > YearStart)
);
GO

-- drop the Grade column from Enrollments to manage grades only in the Grades table
ALTER TABLE Education.Enrollments
DROP COLUMN Grade;
GO

-- Table: Education.Grades
CREATE TABLE Education.Grades (
    GradeID INT PRIMARY KEY IDENTITY(1,1),
    EnrollmentID INT NOT NULL UNIQUE, -- Each enrollment has only one final grade
    FinalGrade DECIMAL(4,2) NOT NULL,
    GradeDate DATE NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_Grade_Enrollment FOREIGN KEY (EnrollmentID) REFERENCES Education.Enrollments(EnrollmentID),
    CONSTRAINT CHK_FinalGradeRange CHECK (FinalGrade >= 0 AND FinalGrade <= 20)
);
GO

-- Table: Education.Addresses
CREATE TABLE Education.Addresses (
    AddressID INT PRIMARY KEY IDENTITY(1,1),
    Street NVARCHAR(100) NOT NULL,
    City NVARCHAR(50) NOT NULL,
    StateProvince NVARCHAR(50),
    ZipCode NVARCHAR(10),
    Country NVARCHAR(50) NOT NULL DEFAULT 'Iran'
);
GO

-- Now, remove the Address column from Students and add AddressID
ALTER TABLE Education.Students
DROP COLUMN Address;
GO

ALTER TABLE Education.Students
ADD AddressID INT NULL;

ALTER TABLE Education.Students
ADD CONSTRAINT FK_Student_Address FOREIGN KEY (AddressID) REFERENCES Education.Addresses(AddressID);
GO

-- we want to have addresses for Professors as well, we can do the same for the Professors table:
ALTER TABLE Education.Professors
ADD AddressID INT NULL;
ALTER TABLE Education.Professors
ADD CONSTRAINT FK_Professor_Address FOREIGN KEY (AddressID) REFERENCES Education.Addresses(AddressID);
GO

-- Table: Education.StudentContacts
CREATE TABLE Education.StudentContacts (
    ContactID INT PRIMARY KEY IDENTITY(1,1),
    StudentID INT NOT NULL,
    FullName NVARCHAR(100) NOT NULL,
    Relationship NVARCHAR(50),
    PhoneNumber NVARCHAR(20) NOT NULL,
    Email NVARCHAR(100),
    CONSTRAINT FK_StudentContact_Student FOREIGN KEY (StudentID) REFERENCES Education.Students(StudentID)
);
GO

-- Table: Education.CourseCategories
CREATE TABLE Education.CourseCategories (
    CategoryID INT PRIMARY KEY IDENTITY(1,1),
    CategoryName NVARCHAR(100) NOT NULL UNIQUE,
    Description NVARCHAR(MAX)
);
GO

-- Add CategoryID to the Courses table
ALTER TABLE Education.Courses
ADD CategoryID INT NULL; -- Can be NULL if not all courses have a category

ALTER TABLE Education.Courses
ADD CONSTRAINT FK_Course_Category FOREIGN KEY (CategoryID) REFERENCES Education.CourseCategories(CategoryID);
GO