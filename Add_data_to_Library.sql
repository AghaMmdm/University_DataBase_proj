USE UniversityDB;
GO

-- Declare variables for IDs
DECLARE @AuthorID_Khaled INT, @AuthorID_JK INT, @AuthorID_George INT, @AuthorID_Stephen INT, @AuthorID_Isaac INT, @AuthorID_Agatha INT, @AuthorID_Gabriel INT, @AuthorID_Jane INT;
DECLARE @PublisherID_Penguin INT, @PublisherID_Bloomsbury INT, @PublisherID_Doubleday INT, @PublisherID_HarperCollins INT, @PublisherID_Vintage INT, @PublisherID_Wordsworth INT;
DECLARE @CategoryID_Fiction INT, @CategoryID_Science INT, @CategoryID_Dystopian INT, @CategoryID_Horror INT, @CategoryID_SciFi INT, @CategoryID_Mystery INT, @CategoryID_MagicalRealism INT, @CategoryID_Romance INT;
DECLARE @BookID_KiteRunner INT, @BookID_HP INT, @BookID_1984 INT, @BookID_Shining INT, @BookID_Foundation INT, @BookID_AndThenThereWereNone INT, @BookID_OneHundredYears INT, @BookID_PrideAndPrejudice INT;
DECLARE @MemberID_Ali INT, @MemberID_Sara INT, @MemberID_Reza INT, @MemberID_Narges INT, @MemberID_Majid INT;
DECLARE @BorrowID_Sara_1984 INT, @BorrowID_Ali_KiteRunner INT, @BorrowID_Narges_Shining INT, @BorrowID_Majid_Foundation INT, @BorrowID_Reza_HP INT, @BorrowID_Ali_OneHundredYears INT;


-- Insert into Library.Authors
PRINT N'Inserting into Library.Authors...';
IF NOT EXISTS (SELECT 1 FROM Library.Authors WHERE FirstName = N'Khaled' AND LastName = N'Hosseini')
    INSERT INTO Library.Authors (FirstName, LastName, Biography, DateOfBirth) VALUES (N'Khaled', N'Hosseini', N'Afghan-American novelist', '1965-03-04');
IF NOT EXISTS (SELECT 1 FROM Library.Authors WHERE FirstName = N'J.K.' AND LastName = N'Rowling')
    INSERT INTO Library.Authors (FirstName, LastName, Biography, DateOfBirth) VALUES (N'J.K.', N'Rowling', N'British author, creator of Harry Potter series.', '1965-07-31');
IF NOT EXISTS (SELECT 1 FROM Library.Authors WHERE FirstName = N'George' AND LastName = N'Orwell')
    INSERT INTO Library.Authors (FirstName, LastName, Biography, DateOfBirth) VALUES (N'George', N'Orwell', N'British novelist, essayist, journalist, and critic.', '1903-06-25');
IF NOT EXISTS (SELECT 1 FROM Library.Authors WHERE FirstName = N'Stephen' AND LastName = N'King')
    INSERT INTO Library.Authors (FirstName, LastName, Biography, DateOfBirth) VALUES (N'Stephen', N'King', N'American author of horror, supernatural fiction, suspense, crime, and fantasy novels.', '1947-09-21');
IF NOT EXISTS (SELECT 1 FROM Library.Authors WHERE FirstName = N'Isaac' AND LastName = N'Asimov')
    INSERT INTO Library.Authors (FirstName, LastName, Biography, DateOfBirth) VALUES (N'Isaac', N'Asimov', N'American science fiction writer and professor of biochemistry.', '1920-01-02');
IF NOT EXISTS (SELECT 1 FROM Library.Authors WHERE FirstName = N'Agatha' AND LastName = N'Christie')
    INSERT INTO Library.Authors (FirstName, LastName, Biography, DateOfBirth) VALUES (N'Agatha', N'Christie', N'English crime novelist, short story writer, and playwright.', '1890-09-15');
IF NOT EXISTS (SELECT 1 FROM Library.Authors WHERE FirstName = N'Gabriel Garcia' AND LastName = N'Marquez')
    INSERT INTO Library.Authors (FirstName, LastName, Biography, DateOfBirth) VALUES (N'Gabriel Garcia', N'Marquez', N'Colombian novelist, short-story writer, screenwriter, and journalist.', '1927-03-06');
IF NOT EXISTS (SELECT 1 FROM Library.Authors WHERE FirstName = N'Jane' AND LastName = N'Austen')
    INSERT INTO Library.Authors (FirstName, LastName, Biography, DateOfBirth) VALUES (N'Jane', N'Austen', N'English novelist known primarily for her six major novels.', '1775-12-16');

-- Get Author IDs
SELECT @AuthorID_Khaled = AuthorID FROM Library.Authors WHERE FirstName = N'Khaled' AND LastName = N'Hosseini';
SELECT @AuthorID_JK = AuthorID FROM Library.Authors WHERE FirstName = N'J.K.' AND LastName = N'Rowling';
SELECT @AuthorID_George = AuthorID FROM Library.Authors WHERE FirstName = N'George' AND LastName = N'Orwell';
SELECT @AuthorID_Stephen = AuthorID FROM Library.Authors WHERE FirstName = N'Stephen' AND LastName = N'King';
SELECT @AuthorID_Isaac = AuthorID FROM Library.Authors WHERE FirstName = N'Isaac' AND LastName = N'Asimov';
SELECT @AuthorID_Agatha = AuthorID FROM Library.Authors WHERE FirstName = N'Agatha' AND LastName = N'Christie';
SELECT @AuthorID_Gabriel = AuthorID FROM Library.Authors WHERE FirstName = N'Gabriel Garcia' AND LastName = N'Marquez';
SELECT @AuthorID_Jane = AuthorID FROM Library.Authors WHERE FirstName = N'Jane' AND LastName = N'Austen';


-- Insert into Library.Publishers
PRINT N'Inserting into Library.Publishers...';
IF NOT EXISTS (SELECT 1 FROM Library.Publishers WHERE PublisherName = N'Penguin Books')
    INSERT INTO Library.Publishers (PublisherName, Address, PhoneNumber, Email) VALUES (N'Penguin Books', N'London, UK', N'1234567890', N'info@penguin.com');
IF NOT EXISTS (SELECT 1 FROM Library.Publishers WHERE PublisherName = N'Bloomsbury Publishing')
    INSERT INTO Library.Publishers (PublisherName, Address, PhoneNumber, Email) VALUES (N'Bloomsbury Publishing', N'Oxford St, London', N'2345678901', N'contact@bloomsbury.com');
IF NOT EXISTS (SELECT 1 FROM Library.Publishers WHERE PublisherName = N'Doubleday')
    INSERT INTO Library.Publishers (PublisherName, Address, PhoneNumber, Email) VALUES (N'Doubleday', N'New York, USA', N'3456789012', N'info@doubleday.com');
IF NOT EXISTS (SELECT 1 FROM Library.Publishers WHERE PublisherName = N'HarperCollins')
    INSERT INTO Library.Publishers (PublisherName, Address, PhoneNumber, Email) VALUES (N'HarperCollins', N'New York, USA', N'4567890123', N'contact@harpercollins.com');
IF NOT EXISTS (SELECT 1 FROM Library.Publishers WHERE PublisherName = N'Vintage Books')
    INSERT INTO Library.Publishers (PublisherName, Address, PhoneNumber, Email) VALUES (N'Vintage Books', N'New York, USA', N'5678901234', N'sales@vintagebooks.com');
IF NOT EXISTS (SELECT 1 FROM Library.Publishers WHERE PublisherName = N'Wordsworth Editions')
    INSERT INTO Library.Publishers (PublisherName, Address, PhoneNumber, Email) VALUES (N'Wordsworth Editions', N'Herts, UK', N'6789012345', N'info@wordsworth-editions.com');

-- Get Publisher IDs
SELECT @PublisherID_Penguin = PublisherID FROM Library.Publishers WHERE PublisherName = N'Penguin Books';
SELECT @PublisherID_Bloomsbury = PublisherID FROM Library.Publishers WHERE PublisherName = N'Bloomsbury Publishing';
SELECT @PublisherID_Doubleday = PublisherID FROM Library.Publishers WHERE PublisherName = N'Doubleday';
SELECT @PublisherID_HarperCollins = PublisherID FROM Library.Publishers WHERE PublisherName = N'HarperCollins';
SELECT @PublisherID_Vintage = PublisherID FROM Library.Publishers WHERE PublisherName = N'Vintage Books';
SELECT @PublisherID_Wordsworth = PublisherID FROM Library.Publishers WHERE PublisherName = N'Wordsworth Editions';


-- Insert into Library.BookCategories
PRINT N'Inserting into Library.BookCategories...';
IF NOT EXISTS (SELECT 1 FROM Library.BookCategories WHERE CategoryName = N'Fiction')
    INSERT INTO Library.BookCategories (CategoryName, Description) VALUES (N'Fiction', N'Fictional books and novels');
IF NOT EXISTS (SELECT 1 FROM Library.BookCategories WHERE CategoryName = N'Science')
    INSERT INTO Library.BookCategories (CategoryName, Description) VALUES (N'Science', N'Scientific and educational books');
IF NOT EXISTS (SELECT 1 FROM Library.BookCategories WHERE CategoryName = N'Dystopian')
    INSERT INTO Library.BookCategories (CategoryName, Description) VALUES (N'Dystopian', N'Dystopian and political literature');
IF NOT EXISTS (SELECT 1 FROM Library.BookCategories WHERE CategoryName = N'Horror')
    INSERT INTO Library.BookCategories (CategoryName, Description) VALUES (N'Horror', N'Fiction intended to frighten or disgust.');
IF NOT EXISTS (SELECT 1 FROM Library.BookCategories WHERE CategoryName = N'Science Fiction')
    INSERT INTO Library.BookCategories (CategoryName, Description) VALUES (N'Science Fiction', N'Fiction based on imagined future scientific or technological advances.');
IF NOT EXISTS (SELECT 1 FROM Library.BookCategories WHERE CategoryName = N'Mystery')
    INSERT INTO Library.BookCategories (CategoryName, Description) VALUES (N'Mystery', N'Stories centered on unraveling a crime or puzzle.');
IF NOT EXISTS (SELECT 1 FROM Library.BookCategories WHERE CategoryName = N'Magical Realism')
    INSERT INTO Library.BookCategories (CategoryName, Description) VALUES (N'Magical Realism', N'A literary genre in which magical elements are blended with reality.');
IF NOT EXISTS (SELECT 1 FROM Library.BookCategories WHERE CategoryName = N'Romance')
    INSERT INTO Library.BookCategories (CategoryName, Description) VALUES (N'Romance', N'Stories focused on love relationships.');

-- Get Category IDs
SELECT @CategoryID_Fiction = CategoryID FROM Library.BookCategories WHERE CategoryName = N'Fiction';
SELECT @CategoryID_Science = CategoryID FROM Library.BookCategories WHERE CategoryName = N'Science';
SELECT @CategoryID_Dystopian = CategoryID FROM Library.BookCategories WHERE CategoryName = N'Dystopian';
SELECT @CategoryID_Horror = CategoryID FROM Library.BookCategories WHERE CategoryName = N'Horror';
SELECT @CategoryID_SciFi = CategoryID FROM Library.BookCategories WHERE CategoryName = N'Science Fiction';
SELECT @CategoryID_Mystery = CategoryID FROM Library.BookCategories WHERE CategoryName = N'Mystery';
SELECT @CategoryID_MagicalRealism = CategoryID FROM Library.BookCategories WHERE CategoryName = N'Magical Realism';
SELECT @CategoryID_Romance = CategoryID FROM Library.BookCategories WHERE CategoryName = N'Romance';


-- Insert into Library.Books
PRINT N'Inserting into Library.Books...';
IF NOT EXISTS (SELECT 1 FROM Library.Books WHERE ISBN = N'9781594480003')
BEGIN
    INSERT INTO Library.Books (Title, ISBN, PublicationYear, Edition, PublisherID, CategoryID, TotalCopies, AvailableCopies, Description)
    VALUES (N'The Kite Runner', N'9781594480003', 2003, N'1st', @PublisherID_Penguin, @CategoryID_Fiction, 5, 3, N'Novel about friendship and redemption.');
    SET @BookID_KiteRunner = SCOPE_IDENTITY();
END ELSE SELECT @BookID_KiteRunner = BookID FROM Library.Books WHERE ISBN = N'9781594480003';

IF NOT EXISTS (SELECT 1 FROM Library.Books WHERE ISBN = N'9780747532699')
BEGIN
    INSERT INTO Library.Books (Title, ISBN, PublicationYear, Edition, PublisherID, CategoryID, TotalCopies, AvailableCopies, Description)
    VALUES (N'Harry Potter and the Philosopher''s Stone', N'9780747532699', 1997, N'1st', @PublisherID_Bloomsbury, @CategoryID_Fiction, 7, 4, N'Magic and wizardry school.');
    SET @BookID_HP = SCOPE_IDENTITY();
END ELSE SELECT @BookID_HP = BookID FROM Library.Books WHERE ISBN = N'9780747532699';

IF NOT EXISTS (SELECT 1 FROM Library.Books WHERE ISBN = N'9780451524935')
BEGIN
    INSERT INTO Library.Books (Title, ISBN, PublicationYear, Edition, PublisherID, CategoryID, TotalCopies, AvailableCopies, Description)
    VALUES (N'1984', N'9780451524935', 1949, N'1st', @PublisherID_Penguin, @CategoryID_Dystopian, 4, 1, N'Dystopian future with Big Brother.');
    SET @BookID_1984 = SCOPE_IDENTITY();
END ELSE SELECT @BookID_1984 = BookID FROM Library.Books WHERE ISBN = N'9780451524935';

IF NOT EXISTS (SELECT 1 FROM Library.Books WHERE ISBN = N'9780385121675')
BEGIN
    INSERT INTO Library.Books (Title, ISBN, PublicationYear, Edition, PublisherID, CategoryID, TotalCopies, AvailableCopies, Description)
    VALUES (N'The Shining', N'9780385121675', 1977, N'First Edition', @PublisherID_Doubleday, @CategoryID_Horror, 3, 2, N'Horror novel about a family isolated in a haunted hotel.');
    SET @BookID_Shining = SCOPE_IDENTITY();
END ELSE SELECT @BookID_Shining = BookID FROM Library.Books WHERE ISBN = N'9780385121675';

IF NOT EXISTS (SELECT 1 FROM Library.Books WHERE ISBN = N'9780553803714')
BEGIN
    INSERT INTO Library.Books (Title, ISBN, PublicationYear, Edition, PublisherID, CategoryID, TotalCopies, AvailableCopies, Description)
    VALUES (N'Foundation', N'9780553803714', 1951, N'Bantam Spectra', @PublisherID_Doubleday, @CategoryID_SciFi, 2, 2, N'The first novel in the Foundation series by Isaac Asimov.');
    SET @BookID_Foundation = SCOPE_IDENTITY();
END ELSE SELECT @BookID_Foundation = BookID FROM Library.Books WHERE ISBN = N'9780553803714';

IF NOT EXISTS (SELECT 1 FROM Library.Books WHERE ISBN = N'9780062073488')
BEGIN
    INSERT INTO Library.Books (Title, ISBN, PublicationYear, Edition, PublisherID, CategoryID, TotalCopies, AvailableCopies, Description)
    VALUES (N'And Then There Were None', N'9780062073488', 1939, N'Reprint', @PublisherID_HarperCollins, @CategoryID_Mystery, 3, 3, N'Classic mystery novel by Agatha Christie.');
    SET @BookID_AndThenThereWereNone = SCOPE_IDENTITY();
END ELSE SELECT @BookID_AndThenThereWereNone = BookID FROM Library.Books WHERE ISBN = N'9780062073488';

IF NOT EXISTS (SELECT 1 FROM Library.Books WHERE ISBN = N'9780060883287')
BEGIN
    INSERT INTO Library.Books (Title, ISBN, PublicationYear, Edition, PublisherID, CategoryID, TotalCopies, AvailableCopies, Description)
    VALUES (N'One Hundred Years of Solitude', N'9780060883287', 1967, N'Paperback', @PublisherID_Vintage, @CategoryID_MagicalRealism, 4, 4, N'A multi-generational novel by Gabriel Garcia Marquez.');
    SET @BookID_OneHundredYears = SCOPE_IDENTITY();
END ELSE SELECT @BookID_OneHundredYears = BookID FROM Library.Books WHERE ISBN = N'9780060883287';

IF NOT EXISTS (SELECT 1 FROM Library.Books WHERE ISBN = N'9780141439518')
BEGIN
    INSERT INTO Library.Books (Title, ISBN, PublicationYear, Edition, PublisherID, CategoryID, TotalCopies, AvailableCopies, Description)
    VALUES (N'Pride and Prejudice', N'9780141439518', 1813, N'Wordsworth Classics', @PublisherID_Wordsworth, @CategoryID_Romance, 6, 5, N'A classic romance novel by Jane Austen.');
    SET @BookID_PrideAndPrejudice = SCOPE_IDENTITY();
END ELSE SELECT @BookID_PrideAndPrejudice = BookID FROM Library.Books WHERE ISBN = N'9780141439518';


-- Insert into Library.BookAuthors
PRINT N'Inserting into Library.BookAuthors...';
IF @BookID_KiteRunner IS NOT NULL AND @AuthorID_Khaled IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Library.BookAuthors WHERE BookID = @BookID_KiteRunner AND AuthorID = @AuthorID_Khaled)
    INSERT INTO Library.BookAuthors (BookID, AuthorID) VALUES (@BookID_KiteRunner, @AuthorID_Khaled);
IF @BookID_HP IS NOT NULL AND @AuthorID_JK IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Library.BookAuthors WHERE BookID = @BookID_HP AND AuthorID = @AuthorID_JK)
    INSERT INTO Library.BookAuthors (BookID, AuthorID) VALUES (@BookID_HP, @AuthorID_JK);
IF @BookID_1984 IS NOT NULL AND @AuthorID_George IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Library.BookAuthors WHERE BookID = @BookID_1984 AND AuthorID = @AuthorID_George)
    INSERT INTO Library.BookAuthors (BookID, AuthorID) VALUES (@BookID_1984, @AuthorID_George);
IF @BookID_Shining IS NOT NULL AND @AuthorID_Stephen IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Library.BookAuthors WHERE BookID = @BookID_Shining AND AuthorID = @AuthorID_Stephen)
    INSERT INTO Library.BookAuthors (BookID, AuthorID) VALUES (@BookID_Shining, @AuthorID_Stephen);
IF @BookID_Foundation IS NOT NULL AND @AuthorID_Isaac IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Library.BookAuthors WHERE BookID = @BookID_Foundation AND AuthorID = @AuthorID_Isaac)
    INSERT INTO Library.BookAuthors (BookID, AuthorID) VALUES (@BookID_Foundation, @AuthorID_Isaac);
IF @BookID_AndThenThereWereNone IS NOT NULL AND @AuthorID_Agatha IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Library.BookAuthors WHERE BookID = @BookID_AndThenThereWereNone AND AuthorID = @AuthorID_Agatha)
    INSERT INTO Library.BookAuthors (BookID, AuthorID) VALUES (@BookID_AndThenThereWereNone, @AuthorID_Agatha);
IF @BookID_OneHundredYears IS NOT NULL AND @AuthorID_Gabriel IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Library.BookAuthors WHERE BookID = @BookID_OneHundredYears AND AuthorID = @AuthorID_Gabriel)
    INSERT INTO Library.BookAuthors (BookID, AuthorID) VALUES (@BookID_OneHundredYears, @AuthorID_Gabriel);
IF @BookID_PrideAndPrejudice IS NOT NULL AND @AuthorID_Jane IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Library.BookAuthors WHERE BookID = @BookID_PrideAndPrejudice AND AuthorID = @AuthorID_Jane)
    INSERT INTO Library.BookAuthors (BookID, AuthorID) VALUES (@BookID_PrideAndPrejudice, @AuthorID_Jane);


-- Insert into Library.Members
PRINT N'Inserting into Library.Members...';
IF NOT EXISTS (SELECT 1 FROM Library.Members WHERE NationalCode = N'1234567890')
BEGIN
    INSERT INTO Library.Members (NationalCode, FirstName, LastName, MemberType, ContactEmail, ContactPhone, Status)
    VALUES (N'1234567890', N'Ali', N'Rezaei', N'Student', N'ali.rezaei@example.com', N'09121234567', N'Active');
    SET @MemberID_Ali = SCOPE_IDENTITY();
END ELSE SELECT @MemberID_Ali = MemberID FROM Library.Members WHERE NationalCode = N'1234567890';

IF NOT EXISTS (SELECT 1 FROM Library.Members WHERE NationalCode = N'9876543210')
BEGIN
    INSERT INTO Library.Members (NationalCode, FirstName, LastName, MemberType, ContactEmail, ContactPhone, Status)
    VALUES (N'9876543210', N'Sara', N'Moradi', N'Professor', N'sara.moradi@example.com', N'09129876543', N'Active');
    SET @MemberID_Sara = SCOPE_IDENTITY();
END ELSE SELECT @MemberID_Sara = MemberID FROM Library.Members WHERE NationalCode = N'9876543210';

IF NOT EXISTS (SELECT 1 FROM Library.Members WHERE NationalCode = N'1122334455')
BEGIN
    INSERT INTO Library.Members (NationalCode, FirstName, LastName, MemberType, ContactEmail, ContactPhone, Status)
    VALUES (N'1122334455', N'Reza', N'Karimi', N'Student', N'reza.karimi@example.com', N'09125554433', N'Active');
    SET @MemberID_Reza = SCOPE_IDENTITY();
END ELSE SELECT @MemberID_Reza = MemberID FROM Library.Members WHERE NationalCode = N'1122334455';

IF NOT EXISTS (SELECT 1 FROM Library.Members WHERE NationalCode = N'2233445566')
BEGIN
    INSERT INTO Library.Members (NationalCode, FirstName, LastName, MemberType, ContactEmail, ContactPhone, Status)
    VALUES (N'2233445566', N'Narges', N'Hashemi', N'Staff', N'n.hashemi@example.com', N'09301239876', N'Active');
    SET @MemberID_Narges = SCOPE_IDENTITY();
END ELSE SELECT @MemberID_Narges = MemberID FROM Library.Members WHERE NationalCode = N'2233445566';

IF NOT EXISTS (SELECT 1 FROM Library.Members WHERE NationalCode = N'3344556677')
BEGIN
    INSERT INTO Library.Members (NationalCode, FirstName, LastName, MemberType, ContactEmail, ContactPhone, Status)
    VALUES (N'3344556677', N'Majid', N'Davari', N'Professor', N'm.davari@example.com', N'09127776655', N'Active');
    SET @MemberID_Majid = SCOPE_IDENTITY();
END ELSE SELECT @MemberID_Majid = MemberID FROM Library.Members WHERE NationalCode = N'3344556677';


-- Insert into Library.Borrows
PRINT N'Inserting into Library.Borrows...';
IF @BookID_1984 IS NOT NULL AND @MemberID_Sara IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Library.Borrows WHERE BookID = @BookID_1984 AND MemberID = @MemberID_Sara AND BorrowDate = '2025-05-10')
BEGIN
    INSERT INTO Library.Borrows (BookID, MemberID, BorrowDate, DueDate, Status, ActualReturnDate)
    VALUES (@BookID_1984, @MemberID_Sara, '2025-05-10', '2025-05-20', 'Borrowed', NULL);
    SET @BorrowID_Sara_1984 = SCOPE_IDENTITY();
END ELSE SELECT @BorrowID_Sara_1984 = BorrowID FROM Library.Borrows WHERE BookID = @BookID_1984 AND MemberID = @MemberID_Sara AND BorrowDate = '2025-05-10';

IF @BookID_KiteRunner IS NOT NULL AND @MemberID_Ali IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Library.Borrows WHERE BookID = @BookID_KiteRunner AND MemberID = @MemberID_Ali AND BorrowDate = '2025-06-15')
BEGIN
    INSERT INTO Library.Borrows (BookID, MemberID, BorrowDate, DueDate, Status, ActualReturnDate)
    VALUES (@BookID_KiteRunner, @MemberID_Ali, '2025-06-15', '2025-07-01', 'Borrowed', NULL);
    SET @BorrowID_Ali_KiteRunner = SCOPE_IDENTITY();
END ELSE SELECT @BorrowID_Ali_KiteRunner = BorrowID FROM Library.Borrows WHERE BookID = @BookID_KiteRunner AND MemberID = @MemberID_Ali AND BorrowDate = '2025-06-15';

IF @BookID_Shining IS NOT NULL AND @MemberID_Narges IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Library.Borrows WHERE BookID = @BookID_Shining AND MemberID = @MemberID_Narges AND BorrowDate = '2025-04-01')
BEGIN
    INSERT INTO Library.Borrows (BookID, MemberID, BorrowDate, DueDate, Status, ActualReturnDate)
    VALUES (@BookID_Shining, @MemberID_Narges, '2025-04-01', '2025-04-15', 'Returned', '2025-04-10');
    SET @BorrowID_Narges_Shining = SCOPE_IDENTITY();
END ELSE SELECT @BorrowID_Narges_Shining = BorrowID FROM Library.Borrows WHERE BookID = @BookID_Shining AND MemberID = @MemberID_Narges AND BorrowDate = '2025-04-01';

IF @BookID_Foundation IS NOT NULL AND @MemberID_Majid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Library.Borrows WHERE BookID = @BookID_Foundation AND MemberID = @MemberID_Majid AND BorrowDate = '2025-06-20')
BEGIN
    INSERT INTO Library.Borrows (BookID, MemberID, BorrowDate, DueDate, Status, ActualReturnDate)
    VALUES (@BookID_Foundation, @MemberID_Majid, '2025-06-20', '2025-07-04', 'Borrowed', NULL);
    SET @BorrowID_Majid_Foundation = SCOPE_IDENTITY();
END ELSE SELECT @BorrowID_Majid_Foundation = BorrowID FROM Library.Borrows WHERE BookID = @BookID_Foundation AND MemberID = @MemberID_Majid AND BorrowDate = '2025-06-20';

IF @BookID_HP IS NOT NULL AND @MemberID_Reza IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Library.Borrows WHERE BookID = @BookID_HP AND MemberID = @MemberID_Reza AND BorrowDate = '2025-05-01')
BEGIN
    INSERT INTO Library.Borrows (BookID, MemberID, BorrowDate, DueDate, Status, ActualReturnDate)
    VALUES (@BookID_HP, @MemberID_Reza, '2025-05-01', '2025-05-15', 'Borrowed', NULL);
    SET @BorrowID_Reza_HP = SCOPE_IDENTITY();
END ELSE SELECT @BorrowID_Reza_HP = BorrowID FROM Library.Borrows WHERE BookID = @BookID_HP AND MemberID = @MemberID_Reza AND BorrowDate = '2025-05-01';

IF @BookID_OneHundredYears IS NOT NULL AND @MemberID_Ali IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Library.Borrows WHERE BookID = @BookID_OneHundredYears AND MemberID = @MemberID_Ali AND BorrowDate = '2025-06-25')
BEGIN
    INSERT INTO Library.Borrows (BookID, MemberID, BorrowDate, DueDate, Status, ActualReturnDate)
    VALUES (@BookID_OneHundredYears, @MemberID_Ali, '2025-06-25', '2025-07-09', 'Borrowed', NULL);
    SET @BorrowID_Ali_OneHundredYears = SCOPE_IDENTITY();
END ELSE SELECT @BorrowID_Ali_OneHundredYears = BorrowID FROM Library.Borrows WHERE BookID = @BookID_OneHundredYears AND MemberID = @MemberID_Ali AND BorrowDate = '2025-06-25';


-- Insert into Library.Reservations
PRINT N'Inserting into Library.Reservations...';
IF @BookID_HP IS NOT NULL AND @MemberID_Ali IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Library.Reservations WHERE BookID = @BookID_HP AND MemberID = @MemberID_Ali AND ReservationDate = '2025-06-20')
    INSERT INTO Library.Reservations (BookID, MemberID, ReservationDate, ExpirationDate, Status)
    VALUES (@BookID_HP, @MemberID_Ali, '2025-06-20', '2025-06-25', 'Active');

IF @BookID_AndThenThereWereNone IS NOT NULL AND @MemberID_Reza IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Library.Reservations WHERE BookID = @BookID_AndThenThereWereNone AND MemberID = @MemberID_Reza AND ReservationDate = '2025-06-22')
    INSERT INTO Library.Reservations (BookID, MemberID, ReservationDate, ExpirationDate, Status)
    VALUES (@BookID_AndThenThereWereNone, @MemberID_Reza, '2025-06-22', '2025-06-27', 'Active');

IF @BookID_PrideAndPrejudice IS NOT NULL AND @MemberID_Sara IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Library.Reservations WHERE BookID = @BookID_PrideAndPrejudice AND MemberID = @MemberID_Sara AND ReservationDate = '2025-06-28')
    INSERT INTO Library.Reservations (BookID, MemberID, ReservationDate, ExpirationDate, Status)
    VALUES (@BookID_PrideAndPrejudice, @MemberID_Sara, '2025-06-28', '2025-07-03', 'Active');


-- Insert into Library.Fines
PRINT N'Inserting into Library.Fines...';
IF @MemberID_Sara IS NOT NULL AND @BorrowID_Sara_1984 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Library.Fines WHERE MemberID = @MemberID_Sara AND BorrowID = @BorrowID_Sara_1984 AND Reason = N'Overdue on 1984')
    INSERT INTO Library.Fines (MemberID, BorrowID, Amount, Reason, Status)
    VALUES (@MemberID_Sara, @BorrowID_Sara_1984, 5000.00, N'Overdue on 1984', 'Outstanding');

IF @MemberID_Reza IS NOT NULL AND @BorrowID_Reza_HP IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Library.Fines WHERE MemberID = @MemberID_Reza AND BorrowID = @BorrowID_Reza_HP AND Reason = N'Overdue on Harry Potter')
    INSERT INTO Library.Fines (MemberID, BorrowID, Amount, Reason, Status)
    VALUES (@MemberID_Reza, @BorrowID_Reza_HP, 7500.00, N'Overdue on Harry Potter', 'Outstanding');

IF @MemberID_Narges IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Library.Fines WHERE MemberID = @MemberID_Narges AND Reason = N'Lost book (The Shining)')
    INSERT INTO Library.Fines (MemberID, BorrowID, Amount, Reason, Status)
    VALUES (@MemberID_Narges, NULL, 150000.00, N'Lost book (The Shining)', 'Outstanding');
