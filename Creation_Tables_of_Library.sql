USE UniversityDB;
GO

-- Table: Library.Authors
CREATE TABLE Library.Authors (
    AuthorID INT PRIMARY KEY IDENTITY(1,1),
    FirstName NVARCHAR(100) NOT NULL,
    LastName NVARCHAR(100) NOT NULL,
    Biography NVARCHAR(MAX),
    DateOfBirth DATE,
    DateOfDeath DATE,
    CONSTRAINT UQ_Author_FullName UNIQUE (FirstName, LastName)
);
GO

-- Table: Library.Publishers
CREATE TABLE Library.Publishers (
    PublisherID INT PRIMARY KEY IDENTITY(1,1),
    PublisherName NVARCHAR(200) NOT NULL UNIQUE,
    Address NVARCHAR(255),
    PhoneNumber NVARCHAR(20),
    Email NVARCHAR(100)
);
GO

-- Table: Library.BookCategories
CREATE TABLE Library.BookCategories (
    CategoryID INT PRIMARY KEY IDENTITY(1,1),
    CategoryName NVARCHAR(100) NOT NULL UNIQUE,
    Description NVARCHAR(MAX)
);
GO

-- Table: Library.Books
CREATE TABLE Library.Books (
    BookID INT PRIMARY KEY IDENTITY(1,1),
    Title NVARCHAR(500) NOT NULL,
    ISBN NVARCHAR(13) NOT NULL UNIQUE, -- International Standard Book Number
    PublicationYear INT,
    Edition NVARCHAR(50),
    PublisherID INT,
    CategoryID INT,
    TotalCopies INT NOT NULL DEFAULT 1, -- Total number of copies owned by the library
    AvailableCopies INT NOT NULL DEFAULT 1, -- Number of copies currently available for borrowing
    Description NVARCHAR(MAX),
    CONSTRAINT FK_Book_Publisher FOREIGN KEY (PublisherID) REFERENCES Library.Publishers(PublisherID),
    CONSTRAINT FK_Book_Category FOREIGN KEY (CategoryID) REFERENCES Library.BookCategories(CategoryID),
    CONSTRAINT CHK_AvailableCopies CHECK (AvailableCopies <= TotalCopies AND AvailableCopies >= 0)
);
GO

-- Table: Library.BookAuthors (Junction table for many-to-many relationship between Books and Authors)
CREATE TABLE Library.BookAuthors (
    BookID INT NOT NULL,
    AuthorID INT NOT NULL,
    PRIMARY KEY (BookID, AuthorID), -- Composite primary key
    CONSTRAINT FK_BookAuthor_Book FOREIGN KEY (BookID) REFERENCES Library.Books(BookID) ON DELETE CASCADE, -- If a book is deleted, remove its author associations
    CONSTRAINT FK_BookAuthor_Author FOREIGN KEY (AuthorID) REFERENCES Library.Authors(AuthorID) ON DELETE CASCADE -- If an author is deleted, remove their book associations
);
GO

-- Table: Library.Members
CREATE TABLE Library.Members (
    MemberID INT PRIMARY KEY IDENTITY(10000,1), -- Starting ID from 10000 for Library Members
    NationalCode NVARCHAR(10) UNIQUE, -- linked to student/professor NationalCode
    FirstName NVARCHAR(100) NOT NULL,
    LastName NVARCHAR(100) NOT NULL,
    MemberType NVARCHAR(50) NOT NULL, -- 'Student', 'Professor', 'Staff'
    ContactEmail NVARCHAR(100) UNIQUE,
    ContactPhone NVARCHAR(20),
    JoinDate DATE NOT NULL DEFAULT GETDATE(),
    Status NVARCHAR(20) NOT NULL DEFAULT 'Active' -- 'Active', 'Suspended', 'Deactivated'
    Education_StudentID INT NULL, -- Link to Education.Students.StudentID if MemberType is 'Student'
    Education_ProfessorID INT NULL, -- Link to Education.Professors.ProfessorID if MemberType is 'Professor'
    CONSTRAINT CHK_MemberType CHECK (MemberType IN ('Student', 'Professor', 'Staff')),
    CONSTRAINT UQ_Member_NationalCode UNIQUE (NationalCode), -- NationalCode should be unique for members too
    CONSTRAINT FK_Member_Student FOREIGN KEY (Education_StudentID) REFERENCES Education.Students(StudentID),
    CONSTRAINT FK_Member_Professor FOREIGN KEY (Education_ProfessorID) REFERENCES Education.Professors(ProfessorID)
);
GO

-- Table: Library.Borrows
CREATE TABLE Library.Borrows (
    BorrowID INT PRIMARY KEY IDENTITY(1,1),
    BookID INT NOT NULL,
    MemberID INT NOT NULL,
    BorrowDate DATE NOT NULL DEFAULT GETDATE(),
    ReturnDate DATE, -- Null if not yet returned
    DueDate DATE NOT NULL, -- Calculated based on BorrowDate and library policy
    ActualReturnDate DATE, 
    PenaltyAmount DECIMAL(10,2) DEFAULT 0.00, -- Any fine incurred
    Status NVARCHAR(20) NOT NULL DEFAULT 'Borrowed', -- 'Borrowed', 'Returned', 'Overdue', 'Lost'
    CONSTRAINT FK_Borrow_Book FOREIGN KEY (BookID) REFERENCES Library.Books(BookID),
    CONSTRAINT FK_Borrow_Member FOREIGN KEY (MemberID) REFERENCES Library.Members(MemberID),
    CONSTRAINT CHK_BorrowStatus CHECK (Status IN ('Borrowed', 'Returned', 'Overdue', 'Lost')),
    CONSTRAINT CHK_ReturnDates CHECK (ActualReturnDate IS NULL OR ActualReturnDate >= BorrowDate)
);
GO

-- Table: Library.Reservations
CREATE TABLE Library.Reservations (
    ReservationID INT PRIMARY KEY IDENTITY(1,1),
    BookID INT NOT NULL,
    MemberID INT NOT NULL,
    ReservationDate DATE NOT NULL DEFAULT GETDATE(),
    ExpirationDate DATE NOT NULL, 
    Status NVARCHAR(20) NOT NULL DEFAULT 'Active', -- 'Active', 'Fulfilled', 'Cancelled', 'Expired'
    CONSTRAINT FK_Reservation_Book FOREIGN KEY (BookID) REFERENCES Library.Books(BookID),
    CONSTRAINT FK_Reservation_Member FOREIGN KEY (MemberID) REFERENCES Library.Members(MemberID),
    CONSTRAINT UQ_Reservation_BookMember UNIQUE (BookID, MemberID), -- A member can only reserve a specific book once at a time
    CONSTRAINT CHK_ReservationStatus CHECK (Status IN ('Active', 'Fulfilled', 'Cancelled', 'Expired'))
);
GO

-- Table: Library.Fines
-- Records details of fines incurred by members.
CREATE TABLE Library.Fines (
    FineID INT PRIMARY KEY IDENTITY(1,1),
    MemberID INT NOT NULL,
    BorrowID INT NULL, -- Link to the specific borrow transaction if applicable
    FineDate DATE NOT NULL DEFAULT GETDATE(),
    Amount DECIMAL(10,2) NOT NULL,
    Reason NVARCHAR(255), -- e.g., 'Overdue', 'Damaged Book', 'Lost Book'
    PaidDate DATE, -- Null if not yet paid
    Status NVARCHAR(20) NOT NULL DEFAULT 'Outstanding', -- 'Outstanding', 'Paid', 'Waived'
    CONSTRAINT FK_Fine_Member FOREIGN KEY (MemberID) REFERENCES Library.Members(MemberID),
    CONSTRAINT FK_Fine_Borrow FOREIGN KEY (BorrowID) REFERENCES Library.Borrows(BorrowID),
    CONSTRAINT CHK_FineStatus CHECK (Status IN ('Outstanding', 'Paid', 'Waived'))
);
GO

-- Table: Library.AuditLog (Separate log table for Library Schema)
-- To log important events specific to the library system.
CREATE TABLE Library.AuditLog (
    LogID INT PRIMARY KEY IDENTITY(1,1),
    EventType NVARCHAR(50) NOT NULL, -- e.g., 'BookAdded', 'BookBorrowed', 'MemberRegistered', 'Error'
    EventDescription NVARCHAR(MAX) NOT NULL,
    EventDate DATETIME NOT NULL DEFAULT GETDATE(),
    UserID NVARCHAR(50) DEFAULT SUSER_SNAME() -- User who performed the action
);
GO