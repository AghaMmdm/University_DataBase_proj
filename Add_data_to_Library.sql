USE UniversityDB;
GO

INSERT INTO Library.Authors (FirstName, LastName, Biography, DateOfBirth)
VALUES 
(N'Khaled', N'Hosseini', N'Afghan-American novelist', '1965-03-04'),
(N'J.K.', N'Rowling', N'British author', '1965-07-31'),
(N'George', N'Orwell', N'British novelist', '1903-06-25');

INSERT INTO Library.Publishers (PublisherName, Address, PhoneNumber, Email)
VALUES 
(N'Penguin Books', N'London, UK', N'1234567890', N'info@penguin.com'),
(N'Bloomsbury Publishing', N'Oxford St, London', N'2345678901', N'contact@bloomsbury.com');

INSERT INTO Library.BookCategories (CategoryName, Description)
VALUES 
(N'Fiction', N'Fictional books and novels'),
(N'Science', N'Scientific and educational books'),
(N'Dystopian', N'Dystopian and political literature');

INSERT INTO Library.Books (Title, ISBN, PublicationYear, Edition, PublisherID, CategoryID, TotalCopies, AvailableCopies, Description)
VALUES 
(N'The Kite Runner', N'9781594480003', 2003, N'1st', 1, 1, 5, 3, N'Novel about friendship and redemption.'),
(N'Harry Potter and the Philosopher''s Stone', N'9780747532699', 1997, N'1st', 2, 1, 7, 4, N'Magic and wizardry school.'),
(N'1984', N'9780451524935', 1949, N'1st', 1, 3, 4, 1, N'Dystopian future with Big Brother.');

-- The Kite Runner - Khaled Hosseini
INSERT INTO Library.BookAuthors (BookID, AuthorID) VALUES (1, 1);

-- Harry Potter - J.K. Rowling
INSERT INTO Library.BookAuthors (BookID, AuthorID) VALUES (2, 2);

-- 1984 - George Orwell
INSERT INTO Library.BookAuthors (BookID, AuthorID) VALUES (3, 3);

INSERT INTO Library.Members (NationalCode, FirstName, LastName, MemberType, ContactEmail, ContactPhone, Status)
VALUES 
(N'1234567890', N'Ali', N'Rezaei', N'Student', N'ali.rezaei@example.com', N'09121234567', N'Active'),
(N'9876543210', N'Sara', N'Moradi', N'Professor', N'sara.moradi@example.com', N'09129876543', N'Active');

-- Sara borrowed 1984 and it’s overdue
INSERT INTO Library.Borrows (BookID, MemberID, BorrowDate, DueDate, Status)
VALUES (3, 10001, '2025-05-10', '2025-05-20', 'Borrowed');

-- Ali borrowed Kite Runner, still within due date
INSERT INTO Library.Borrows (BookID, MemberID, BorrowDate, DueDate, Status)
VALUES (1, 10000, '2025-06-15', '2025-07-01', 'Borrowed');

INSERT INTO Library.Reservations (BookID, MemberID, ReservationDate, ExpirationDate, Status)
VALUES (2, 10000, '2025-06-20', '2025-06-25', 'Active');

INSERT INTO Library.Fines (MemberID, BorrowID, Amount, Reason, Status)
VALUES (10001, 1, 5000.00, N'Overdue', 'Outstanding');

