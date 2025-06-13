USE UniversityDB;
GO

-- Education schema creation

CREATE TABLE Education.Departments (
    DepartmentID INT PRIMARY KEY IDENTITY(1,1), -- IDENTITY برای افزایش خودکار
    DepartmentName NVARCHAR(100) NOT NULL UNIQUE,
    HeadOfDepartmentID INT NULL -- این ستون بعداً به جدول Professors لینک می‌شود
);
GO

CREATE TABLE Education.Students (
    StudentID INT PRIMARY KEY IDENTITY(1000,1), -- شروع از 1000 برای Students
    NationalCode NVARCHAR(10) NOT NULL UNIQUE,
    FirstName NVARCHAR(50) NOT NULL,
    LastName NVARCHAR(50) NOT NULL,
    DateOfBirth DATE,
    Email NVARCHAR(100) UNIQUE,
    PhoneNumber NVARCHAR(20),
    Address NVARCHAR(255),
    EnrollmentDate DATE NOT NULL DEFAULT GETDATE(), -- تاریخ ثبت نام پیش فرض امروز
    DepartmentID INT NOT NULL,
    Major NVARCHAR(100),
    Status NVARCHAR(20) NOT NULL DEFAULT 'Active', -- Active, Graduated, Expelled, Withdrawn
    CONSTRAINT FK_Student_Department FOREIGN KEY (DepartmentID) REFERENCES Education.Departments(DepartmentID),
    CONSTRAINT CHK_StudentStatus CHECK (Status IN ('Active', 'Graduated', 'Expelled', 'Withdrawn', 'Suspended')) -- اضافه کردن وضعیت Suspended
);
GO

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

-- حالا می‌توانیم ستون HeadOfDepartmentID در جدول Departments را به ProfessorID در جدول Professors لینک کنیم
ALTER TABLE Education.Departments
ADD CONSTRAINT FK_Department_Head FOREIGN KEY (HeadOfDepartmentID) REFERENCES Education.Professors(ProfessorID);
GO

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
    CONSTRAINT UQ_CourseOffering UNIQUE (CourseID, AcademicYear, Semester, ProfessorID) -- یک درس توسط یک استاد در یک ترم یک بار ارائه شود
);
GO

CREATE TABLE Education.Enrollments (
    EnrollmentID INT PRIMARY KEY IDENTITY(1,1),
    StudentID INT NOT NULL,
    OfferingID INT NOT NULL,
    EnrollmentDate DATETIME NOT NULL DEFAULT GETDATE(),
    Grade DECIMAL(4,2) NULL, -- نمره می‌تواند تا دو رقم اعشار باشد
    Status NVARCHAR(20) NOT NULL DEFAULT 'Enrolled',
    CONSTRAINT FK_Enrollment_Student FOREIGN KEY (StudentID) REFERENCES Education.Students(StudentID),
    CONSTRAINT FK_Enrollment_Offering FOREIGN KEY (OfferingID) REFERENCES Education.CourseOfferings(OfferingID),
    CONSTRAINT UQ_Student_Offering UNIQUE (StudentID, OfferingID), -- یک دانشجو فقط یک بار در یک ارائه درس ثبت نام کند
    CONSTRAINT CHK_EnrollmentStatus CHECK (Status IN ('Enrolled', 'Completed', 'Dropped', 'Failed', 'Withdrawn')) -- اضافه کردن وضعیت Withdrawn
);
GO


CREATE TABLE Education.Prerequisites (
    PrerequisiteID INT PRIMARY KEY IDENTITY(1,1),
    CourseID INT NOT NULL,
    PrerequisiteCourseID INT NOT NULL,
    CONSTRAINT FK_Prereq_Course FOREIGN KEY (CourseID) REFERENCES Education.Courses(CourseID),
    CONSTRAINT FK_Prereq_PrerequisiteCourse FOREIGN KEY (PrerequisiteCourseID) REFERENCES Education.Courses(CourseID),
    CONSTRAINT UQ_Course_Prereq UNIQUE (CourseID, PrerequisiteCourseID), -- هر ترکیب پیش نیاز و درس یکتا باشد
    CONSTRAINT CHK_SelfPrerequisite CHECK (CourseID <> PrerequisiteCourseID) -- درس نمی تواند پیش نیاز خودش باشد
);
GO

CREATE TABLE Education.Majors (
    MajorID INT PRIMARY KEY IDENTITY(1,1),
    MajorName NVARCHAR(100) NOT NULL UNIQUE,
    DepartmentID INT NOT NULL,
    CONSTRAINT FK_Major_Department FOREIGN KEY (DepartmentID) REFERENCES Education.Departments(DepartmentID)
);
GO

-- حالا می توانیم ستون Major در جدول Students را به MajorID در جدول Majors لینک کنیم
ALTER TABLE Education.Students
DROP COLUMN Major; -- حذف ستون Major از Students
GO

ALTER TABLE Education.Students
ADD MajorID INT NULL; -- اضافه کردن MajorID جدید

ALTER TABLE Education.Students
ADD CONSTRAINT FK_Student_Major FOREIGN KEY (MajorID) REFERENCES Education.Majors(MajorID);
GO

CREATE TABLE Education.Curriculum (
    CurriculumID INT PRIMARY KEY IDENTITY(1,1),
    MajorID INT NOT NULL,
    CourseID INT NOT NULL,
    RequiredSemester INT NOT NULL, -- ترم پیشنهادی برای اخذ درس
    IsMandatory BIT NOT NULL DEFAULT 1, -- 1 برای اجباری، 0 برای اختیاری
    CONSTRAINT FK_Curriculum_Major FOREIGN KEY (MajorID) REFERENCES Education.Majors(MajorID),
    CONSTRAINT FK_Curriculum_Course FOREIGN KEY (CourseID) REFERENCES Education.Courses(CourseID),
    CONSTRAINT UQ_Curriculum_Entry UNIQUE (MajorID, CourseID), -- هر درس یک بار در چارت یک رشته
    CONSTRAINT CHK_RequiredSemester CHECK (RequiredSemester > 0)
);
GO


CREATE TABLE Education.LogEvents (
    LogID BIGINT PRIMARY KEY IDENTITY(1,1),
    EventType NVARCHAR(50) NOT NULL,
    EventDescription NVARCHAR(MAX),
    EventDate DATETIME NOT NULL DEFAULT GETDATE(),
    UserID NVARCHAR(50) NULL -- شناسه کاربری که عملیات را انجام داده است
);
GO


CREATE TABLE Education.AcademicYears (
    AcademicYearID INT PRIMARY KEY IDENTITY(1,1),
    YearStart INT NOT NULL UNIQUE,
    YearEnd INT NOT NULL UNIQUE,
    Description NVARCHAR(50),
    CONSTRAINT CHK_YearsOrder CHECK (YearEnd > YearStart)
);
GO

-- تغییر جدول CourseOfferings برای استفاده از AcademicYearID
ALTER TABLE Education.CourseOfferings
ADD AcademicYearID INT NULL;

UPDATE Education.CourseOfferings
SET AcademicYearID = (SELECT AcademicYearID FROM Education.AcademicYears WHERE YearStart = Education.CourseOfferings.AcademicYear);

ALTER TABLE Education.CourseOfferings
DROP COLUMN AcademicYear; -- حذف ستون قدیمی

ALTER TABLE Education.CourseOfferings
ALTER COLUMN AcademicYearID INT NOT NULL; -- تبدیل به NOT NULL بعد از پر کردن اطلاعات

ALTER TABLE Education.CourseOfferings
ADD CONSTRAINT FK_Offering_AcademicYear FOREIGN KEY (AcademicYearID) REFERENCES Education.AcademicYears(AcademicYearID);
GO


-- ابتدا ستون Grade را از Enrollments حذف می‌کنیم تا نمرات فقط در جدول Grades مدیریت شوند
ALTER TABLE Education.Enrollments
DROP COLUMN Grade;
GO

CREATE TABLE Education.Grades (
    GradeID INT PRIMARY KEY IDENTITY(1,1),
    EnrollmentID INT NOT NULL UNIQUE, -- هر ثبت نام فقط یک نمره نهایی دارد
    FinalGrade DECIMAL(4,2) NOT NULL,
    GradeDate DATE NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_Grade_Enrollment FOREIGN KEY (EnrollmentID) REFERENCES Education.Enrollments(EnrollmentID),
    CONSTRAINT CHK_FinalGradeRange CHECK (FinalGrade >= 0 AND FinalGrade <= 20) -- فرض بر نمره از 0 تا 20
);
GO


CREATE TABLE Education.Addresses (
    AddressID INT PRIMARY KEY IDENTITY(1,1),
    Street NVARCHAR(100) NOT NULL,
    City NVARCHAR(50) NOT NULL,
    StateProvince NVARCHAR(50),
    ZipCode NVARCHAR(10),
    Country NVARCHAR(50) NOT NULL DEFAULT 'Iran'
);
GO

-- حالا ستون Address را از Students حذف می‌کنیم و AddressID را اضافه می‌کنیم
ALTER TABLE Education.Students
DROP COLUMN Address;
GO

ALTER TABLE Education.Students
ADD AddressID INT NULL; -- می تواند NULL باشد اگر آدرس اجباری نباشد

ALTER TABLE Education.Students
ADD CONSTRAINT FK_Student_Address FOREIGN KEY (AddressID) REFERENCES Education.Addresses(AddressID);
GO

-- اگر بخواهیم برای اساتید هم آدرس داشته باشیم، می‌توانیم همین کار را برای جدول Professors هم انجام دهیم:
ALTER TABLE Education.Professors
ADD AddressID INT NULL;
ALTER TABLE Education.Professors
ADD CONSTRAINT FK_Professor_Address FOREIGN KEY (AddressID) REFERENCES Education.Addresses(AddressID);
GO


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


CREATE TABLE Education.CourseCategories (
    CategoryID INT PRIMARY KEY IDENTITY(1,1),
    CategoryName NVARCHAR(100) NOT NULL UNIQUE,
    Description NVARCHAR(MAX)
);
GO

-- اضافه کردن CategoryID به جدول Courses
ALTER TABLE Education.Courses
ADD CategoryID INT NULL; -- می تواند NULL باشد اگر همه دروس دسته بندی نداشته باشند

ALTER TABLE Education.Courses
ADD CONSTRAINT FK_Course_Category FOREIGN KEY (CategoryID) REFERENCES Education.CourseCategories(CategoryID);
GO
