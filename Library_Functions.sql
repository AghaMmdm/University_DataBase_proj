USE UniversityDB;
GO

--Some of the most borrowed books
CREATE OR ALTER FUNCTION Library.GetTopBorrowedBooks (
    @TopN INT
)
RETURNS TABLE
AS
RETURN
(
    SELECT TOP (@TopN)
        B.BookID,
        B.Title,
        B.ISBN,
        COUNT(*) AS BorrowCount
    FROM Library.Borrows BR
    INNER JOIN Library.Books B ON BR.BookID = B.BookID
    GROUP BY B.BookID, B.Title, B.ISBN
    ORDER BY BorrowCount DESC
);

--Receiving overdue books
CREATE FUNCTION Library.GetMemberOverdueBooks
(
    @MemberID INT
)
RETURNS @OverdueBooks TABLE
(
    BookID INT,
    Title NVARCHAR(500),
    BorrowDate DATE,
    DueDate DATE,
    DaysOverdue INT,
    EstimatedPenalty DECIMAL(10,2)
)
AS
BEGIN
    INSERT INTO @OverdueBooks
    SELECT 
        B.BookID,
        B.Title,
        BR.BorrowDate,
        BR.DueDate,
        DATEDIFF(DAY, BR.DueDate, GETDATE()) AS DaysOverdue,
        DATEDIFF(DAY, BR.DueDate, GETDATE()) * 1000 AS EstimatedPenalty -- Assumption: Daily fine of 1000 Tomans
    FROM Library.Borrows BR
    INNER JOIN Library.Books B ON BR.BookID = B.BookID
    WHERE 
        BR.MemberID = @MemberID
        AND BR.ActualReturnDate IS NULL
        AND BR.DueDate < GETDATE()
    
    RETURN;
END
GO

--Advanced book search
CREATE FUNCTION Library.SearchBooks
(
    @Keyword NVARCHAR(200) = NULL,
    @ISBN NVARCHAR(13) = NULL,
    @AuthorName NVARCHAR(200) = NULL,
    @PublisherName NVARCHAR(200) = NULL,
    @CategoryName NVARCHAR(100) = NULL,
    @PublicationYear INT = NULL
)
RETURNS TABLE
AS
RETURN
(
    SELECT DISTINCT
        B.BookID,
        B.Title,
        B.ISBN,
        B.PublicationYear,
        B.Edition,
        P.PublisherName,
        C.CategoryName,
        B.TotalCopies,
        B.AvailableCopies
    FROM Library.Books B
    LEFT JOIN Library.Publishers P ON B.PublisherID = P.PublisherID
    LEFT JOIN Library.BookCategories C ON B.CategoryID = C.CategoryID
    LEFT JOIN Library.BookAuthors BA ON B.BookID = BA.BookID
    LEFT JOIN Library.Authors A ON BA.AuthorID = A.AuthorID
    WHERE 
        (@Keyword IS NULL OR B.Title LIKE '%' + @Keyword + '%')
        AND (@ISBN IS NULL OR B.ISBN = @ISBN)
        AND (@AuthorName IS NULL OR (A.FirstName + ' ' + A.LastName LIKE '%' + @AuthorName + '%'))
        AND (@PublisherName IS NULL OR P.PublisherName LIKE '%' + @PublisherName + '%')
        AND (@CategoryName IS NULL OR C.CategoryName LIKE '%' + @CategoryName + '%')
        AND (@PublicationYear IS NULL OR B.PublicationYear = @PublicationYear)
);
GO