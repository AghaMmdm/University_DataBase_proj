--USE UniversityDB;
--GO

---- بررسی وجود پروسیجر و حذف آن در صورت وجود
--IF OBJECT_ID('Library.SuggestBooksForMember', 'P') IS NOT NULL
--DROP PROCEDURE Library.SuggestBooksForMember;
--GO

---- پروسیجر ذخیره شده: Library.SuggestBooksForMember
---- توضیحات: به یک عضو بر اساس دسته‌بندی کتاب‌هایی که قبلاً امانت گرفته است، کتاب پیشنهاد می‌دهد.
----          کتاب‌هایی که قبلاً امانت گرفته یا در حال حاضر دارد، از پیشنهادات حذف می‌شوند.
--CREATE PROCEDURE Library.SuggestBooksForMember
--    @_MemberID INT,
--    @_TopN INT = 5 -- تعداد حداکثر پیشنهاداتی که باید برگردانده شود
--AS
--BEGIN
--    SET NOCOUNT ON;
--    SET XACT_ABORT ON; -- اطمینان از Rollback شدن تراکنش در صورت بروز خطا

--    DECLARE @LogDescription NVARCHAR(MAX);
--    DECLARE @EventUser NVARCHAR(50) = SUSER_SNAME();

--    BEGIN TRY
--        -- اعتبار سنجی MemberID
--        IF NOT EXISTS (SELECT 1 FROM Library.Members WHERE MemberID = @_MemberID)
--        BEGIN
--            RAISERROR('Error: Member with ID %d does not exist.', 16, 1, @_MemberID);
--            RETURN;
--        END;

--        -- ثبت تلاش برای پیشنهاد کتاب در AuditLog
--        SET @LogDescription = N'تلاش برای پیشنهاد کتاب برای MemberID: ' + CAST(@_MemberID AS NVARCHAR(10)) + N'.';
--        INSERT INTO Library.AuditLog (EventType, EventDescription, UserID)
--        VALUES (N'Book Suggestion Attempt', @LogDescription, @EventUser);

--        -- یافتن دسته‌بندی‌های کتاب‌هایی که عضو قبلاً امانت گرفته است
--        SELECT DISTINCT BC.CategoryID
--        INTO #MemberBorrowedCategories -- جدول موقت برای نگهداری دسته‌بندی‌ها
--        FROM Library.Borrows B
--        INNER JOIN Library.Books BK ON B.BookID = BK.BookID
--        INNER JOIN Library.BookCategories BC ON BK.CategoryID = BC.CategoryID
--        WHERE B.MemberID = @_MemberID;

--        -- یافتن کتاب‌هایی برای پیشنهاد از این دسته‌بندی‌ها،
--        -- به استثنای کتاب‌هایی که عضو قبلاً امانت گرفته است و کتاب‌هایی که موجود نیستند.
--        SELECT TOP (@_TopN)
--            BK.BookID,
--            BK.Title,
--            BK.ISBN,
--            BC.CategoryName,
--            BK.AvailableCopies
--        FROM Library.Books BK
--        INNER JOIN Library.BookCategories BC ON BK.CategoryID = BC.CategoryID
--        WHERE BK.CategoryID IN (SELECT CategoryID FROM #MemberBorrowedCategories) -- از دسته‌بندی‌هایی که عضو دوست دارد
--          AND BK.BookID NOT IN (SELECT BookID FROM Library.Borrows WHERE MemberID = @_MemberID) -- قبلاً امانت گرفته نشده باشد
--          AND BK.AvailableCopies > 0 -- باید نسخه‌های موجود داشته باشد
--        ORDER BY BK.Title; -- ترتیب ساده بر اساس عنوان (می‌تواند به محبوبیت تغییر کند)

--        -- پاک کردن جدول موقت
--        DROP TABLE #MemberBorrowedCategories;

--    END TRY
--    BEGIN CATCH
--        -- ثبت هرگونه خطا در AuditLog
--        DECLARE @ErrorMessage NVARCHAR(MAX), @ErrorSeverity INT, @ErrorState INT;
--        SELECT
--            @ErrorMessage = ERROR_MESSAGE(),
--            @ErrorSeverity = ERROR_SEVERITY(),
--            @ErrorState = ERROR_STATE();

--        SET @LogDescription = N'خطا در پیشنهاد کتاب برای MemberID: ' + CAST(@_MemberID AS NVARCHAR(10)) + N'. خطا: ' + @ErrorMessage;
--        INSERT INTO Library.AuditLog (EventType, EventDescription, UserID)
--        VALUES (N'Book Suggestion Error', @LogDescription, @EventUser);

--        -- دوباره ارور را نمایش می‌دهد (Raise)
--        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
--    END CATCH;
--END;
--GO



--USE UniversityDB;
--GO

--PRINT N'-------------------------------------------------------------------------------------';
--PRINT N'Demonstrating Library.SuggestBooksForMember Stored Procedure';
--PRINT N'This script will set up test data and then call the suggestion procedure.';
--PRINT N'-------------------------------------------------------------------------------------';

---- Declare test variables
--DECLARE @TestMemberID INT;
--DECLARE @BookID_Borrowed1 INT;
--DECLARE @BookID_Borrowed2 INT;
--DECLARE @BookID_Suggested1 INT;
--DECLARE @BookID_Suggested2 INT;
--DECLARE @CategoryID_1 INT;
--DECLARE @CategoryID_2 INT;

---- از یک MemberID موجود برای دمو استفاده کنید.
--SELECT TOP 1 @TestMemberID = MemberID FROM Library.Members ORDER BY MemberID ASC;
--IF @TestMemberID IS NULL
--BEGIN
--    PRINT N'Error: No members found. Please ensure you have members in Library.Members table to run this demo.';
--    RETURN;
--END;
--PRINT N'Using MemberID ' + CAST(@TestMemberID AS NVARCHAR(10)) + ' for demonstration.';

---- پاکسازی هرگونه امانت موجود برای این عضو در دیتابیس
--DELETE FROM Library.Borrows WHERE MemberID = @TestMemberID;
--PRINT N'Cleaned up existing borrows for MemberID ' + CAST(@TestMemberID AS NVARCHAR(10)) + '.';

---- اطمینان از وجود برخی دسته‌بندی‌های تستی
--IF NOT EXISTS (SELECT 1 FROM Library.BookCategories WHERE CategoryName = N'Science Fiction')
--    INSERT INTO Library.BookCategories (CategoryName, Description) VALUES (N'Science Fiction', N'Books about future technology and space.');
--IF NOT EXISTS (SELECT 1 FROM Library.BookCategories WHERE CategoryName = N'Fantasy')
--    INSERT INTO Library.BookCategories (CategoryName, Description) VALUES (N'Fantasy', N'Books about magic and mythical creatures.');
--IF NOT EXISTS (SELECT 1 FROM Library.BookCategories WHERE CategoryName = N'History')
--    INSERT INTO Library.BookCategories (CategoryName, Description) VALUES (N'History', N'Books about historical events.');

--SELECT @CategoryID_1 = CategoryID FROM Library.BookCategories WHERE CategoryName = N'Science Fiction';
--SELECT @CategoryID_2 = CategoryID FROM Library.BookCategories WHERE CategoryName = N'Fantasy';

---- اطمینان از وجود کتاب‌های تستی و داشتن نسخه‌های موجود
---- کتاب ۱ (امانت گرفته شده): علمی تخیلی
--SELECT TOP 1 @BookID_Borrowed1 = BookID FROM Library.Books WHERE Title = N'Dune' AND CategoryID = @CategoryID_1;
--IF @BookID_Borrowed1 IS NULL
--BEGIN
--    INSERT INTO Library.Books (Title, ISBN, PublicationYear, TotalCopies, AvailableCopies, CategoryID)
--    VALUES (N'Dune', '9780441172719', 1965, 5, 5, @CategoryID_1);
--    SELECT @BookID_Borrowed1 = SCOPE_IDENTITY();
--END;
--UPDATE Library.Books SET AvailableCopies = TotalCopies WHERE BookID = @BookID_Borrowed1; -- اطمینان از در دسترس بودن

---- کتاب ۲ (پیشنهادی، هم‌دسته‌بندی با کتاب ۱): علمی تخیلی
--SELECT TOP 1 @BookID_Suggested1 = BookID FROM Library.Books WHERE Title = N'Neuromancer' AND CategoryID = @CategoryID_1;
--IF @BookID_Suggested1 IS NULL
--BEGIN
--    INSERT INTO Library.Books (Title, ISBN, PublicationYear, TotalCopies, AvailableCopies, CategoryID)
--    VALUES (N'Neuromancer', '9780441569595', 1984, 3, 3, @CategoryID_1);
--    SELECT @BookID_Suggested1 = SCOPE_IDENTITY();
--END;
--UPDATE Library.Books SET AvailableCopies = TotalCopies WHERE BookID = @BookID_Suggested1;

---- کتاب ۳ (امانت گرفته شده): فانتزی
--SELECT TOP 1 @BookID_Borrowed2 = BookID FROM Library.Books WHERE Title = N'The Hobbit' AND CategoryID = @CategoryID_2;
--IF @BookID_Borrowed2 IS NULL
--BEGIN
--    INSERT INTO Library.Books (Title, ISBN, PublicationYear, TotalCopies, AvailableCopies, CategoryID)
--    VALUES (N'The Hobbit', '9780345339683', 1937, 4, 4, @CategoryID_2);
--    SELECT @BookID_Borrowed2 = SCOPE_IDENTITY();
--END;
--UPDATE Library.Books SET AvailableCopies = TotalCopies WHERE BookID = @BookID_Borrowed2;

---- کتاب ۴ (پیشنهادی، هم‌دسته‌بندی با کتاب ۳): فانتزی
--SELECT TOP 1 @BookID_Suggested2 = BookID FROM Library.Books WHERE Title = N'Mistborn: The Final Empire' AND CategoryID = @CategoryID_2;
--IF @BookID_Suggested2 IS NULL
--BEGIN
--    INSERT INTO Library.Books (Title, ISBN, PublicationYear, TotalCopies, AvailableCopies, CategoryID)
--    VALUES (N'Mistborn: The Final Empire', '9780765311788', 2006, 2, 2, @CategoryID_2);
--    SELECT @BookID_Suggested2 = SCOPE_IDENTITY();
--END;
--UPDATE Library.Books SET AvailableCopies = TotalCopies WHERE BookID = @BookID_Suggested2;

---- شبیه‌سازی امانت گرفتن کتاب‌ها توسط عضو برای ایجاد تاریخچه
--PRINT N'Simulating member borrowing some books to establish history...';
--BEGIN TRY
--    EXEC Library.BorrowBook @MemberID = @TestMemberID, @BookID = @BookID_Borrowed1;
--    EXEC Library.BorrowBook @MemberID = @TestMemberID, @BookID = @BookID_Borrowed2;
--END TRY
--BEGIN CATCH
--    PRINT N'Warning: Could not simulate borrowing for demo. Some books might already be borrowed or other issues. Proceeding with existing data.';
--    PRINT N'Error: ' + ERROR_MESSAGE();
--END CATCH;

---- فراخوانی پروسیجر پیشنهاد کتاب
--PRINT N'---------------------------------------------------';
--PRINT N'Calling Library.SuggestBooksForMember for MemberID ' + CAST(@TestMemberID AS NVARCHAR(10)) + N':';
--PRINT N'---------------------------------------------------';

--EXEC Library.SuggestBooksForMember @TestMemberID, 3; -- درخواست ۳ پیشنهاد

--PRINT N'---------------------------------------------------';
--PRINT N'End of Demonstration.';
--PRINT N'---------------------------------------------------';

---- بخش اختیاری پاکسازی:
---- اگر می‌خواهید پس از دمو، دیتابیس به حالت اولیه بازگردد،
---- می‌توانید خطوط زیر را از حالت کامنت خارج (uncomment) کرده و اجرا کنید.
--/*
--PRINT N'Cleaning up test data...';
---- فرض بر این است که BorrowBook تعداد AvailableCopies را کاهش می‌دهد، بنابراین باید افزایش یابد.
---- بهتر است قبل از اجرای این بخش، AvailableCopies واقعی کتاب‌ها را در نظر بگیرید.
---- این بخش برای سادگی در اینجا به صورت کامل پیاده‌سازی نشده و نیاز به دقت دارد.
---- برای بازگرداندن وضعیت کتاب‌ها به حالت قبل از تست
---- UPDATE Library.Books SET AvailableCopies = AvailableCopies + 1 WHERE BookID = @BookID_Borrowed1;
---- UPDATE Library.Books SET AvailableCopies = AvailableCopies + 1 WHERE BookID = @BookID_Borrowed2;

---- حذف رکوردهای امانت تستی
--DELETE FROM Library.Borrows WHERE MemberID = @TestMemberID AND BookID IN (@BookID_Borrowed1, @BookID_Borrowed2);
--PRINT N'Test data cleaned.';
--*/
--GO


--==============================================================================================================================================================






USE UniversityDB;
GO

-- بررسی وجود پروسیجر و حذف آن در صورت وجود
IF OBJECT_ID('Library.SuggestBooksForMember', 'P') IS NOT NULL
DROP PROCEDURE Library.SuggestBooksForMember;
GO

-- پروسیجر ذخیره شده: Library.SuggestBooksForMember
-- توضیحات: به یک عضو بر اساس الگوریتم فیلترینگ مشارکتی، کتاب پیشنهاد می‌دهد.
--          (یافتن کاربران مشابه و پیشنهاد کتاب‌هایی که آنها امانت گرفته‌اند و کاربر فعلی نگرفته است)
CREATE PROCEDURE Library.SuggestBooksForMember
    @_MemberID INT,
    @_TopN INT = 3 -- تعداد حداکثر پیشنهاداتی که باید برگردانده شود (پیش‌فرض: 3)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON; -- اطمینان از Rollback شدن تراکنش در صورت بروز خطا

    DECLARE @LogDescription NVARCHAR(MAX);
    DECLARE @EventUser NVARCHAR(50) = SUSER_SNAME();

    BEGIN TRY
        -- اعتبار سنجی MemberID
        IF NOT EXISTS (SELECT 1 FROM Library.Members WHERE MemberID = @_MemberID)
        BEGIN
            RAISERROR('Error: Member with ID %d does not exist.', 16, 1, @_MemberID);
            RETURN;
        END;

        -- ثبت تلاش برای پیشنهاد کتاب در AuditLog
        SET @LogDescription = N'تلاش برای پیشنهاد کتاب (فیلترینگ مشارکتی) برای MemberID: ' + CAST(@_MemberID AS NVARCHAR(10)) + N'.';
        INSERT INTO Library.AuditLog (EventType, EventDescription, UserID)
        VALUES (N'Book Suggestion Attempt (Collaborative)', @LogDescription, @EventUser);

        -- مرحله ۱: دریافت لیست کتاب‌های امانت گرفته شده توسط کاربر فعلی
        SELECT BookID
        INTO #CurrentMemberBorrows
        FROM Library.Borrows
        WHERE MemberID = @_MemberID;

        -- اگر کاربر فعلی هیچ کتابی امانت نگرفته باشد، نمی‌توانیم پیشنهاد مشارکتی بدهیم.
        IF NOT EXISTS (SELECT 1 FROM #CurrentMemberBorrows)
        BEGIN
            PRINT N'No books borrowed by MemberID ' + CAST(@_MemberID AS NVARCHAR(10)) + '. Cannot provide collaborative suggestions.';
            -- می‌توانید در اینجا به جای آن، کتاب‌های پرطرفدار را پیشنهاد دهید یا پیام خاصی برگردانید.
            -- برای این پیاده‌سازی، در صورت عدم وجود تاریخچه، هیچ پیشنهادی برگردانده نمی‌شود.
            DROP TABLE #CurrentMemberBorrows;
            RETURN;
        END;

        -- مرحله ۲: یافتن کاربران مشابه (حداقل دو کتاب مشترک)
        SELECT B.MemberID AS SimilarMemberID, COUNT(DISTINCT B.BookID) AS CommonBooksCount
        INTO #SimilarMembers
        FROM Library.Borrows B
        INNER JOIN #CurrentMemberBorrows CMB ON B.BookID = CMB.BookID
        WHERE B.MemberID <> @_MemberID -- نباید خود کاربر فعلی باشد
        GROUP BY B.MemberID
        HAVING COUNT(DISTINCT B.BookID) >= 2; -- حداقل دو کتاب مشترک

        -- اگر کاربر مشابهی یافت نشد
        IF NOT EXISTS (SELECT 1 FROM #SimilarMembers)
        BEGIN
            PRINT N'No similar members found for MemberID ' + CAST(@_MemberID AS NVARCHAR(10)) + '. Cannot provide collaborative suggestions.';
            DROP TABLE #CurrentMemberBorrows;
            RETURN;
        END;

        -- مرحله ۳ و ۴: استخراج کتاب‌های پیشنهادی از کاربران مشابه (که کاربر فعلی نگرفته است) و مرتب‌سازی بر اساس تکرار
        SELECT TOP (@_TopN)
            BK.BookID,
            BK.Title,
            BK.ISBN,
            C.CategoryName,
            BK.AvailableCopies,
            COUNT(DISTINCT SB.SimilarMemberID) AS BorrowCountBySimilarUsers -- تعداد دفعات امانت توسط کاربران مشابه
        FROM Library.Borrows B_Sim
        INNER JOIN #SimilarMembers SB ON B_Sim.MemberID = SB.SimilarMemberID
        INNER JOIN Library.Books BK ON B_Sim.BookID = BK.BookID
        LEFT JOIN Library.BookCategories C ON BK.CategoryID = C.CategoryID
        WHERE B_Sim.BookID NOT IN (SELECT BookID FROM #CurrentMemberBorrows) -- کتاب‌هایی که کاربر فعلی هنوز امانت نگرفته است
          AND BK.AvailableCopies > 0 -- باید نسخه‌های موجود داشته باشد
        GROUP BY
            BK.BookID, BK.Title, BK.ISBN, C.CategoryName, BK.AvailableCopies
        ORDER BY
            BorrowCountBySimilarUsers DESC, BK.Title; -- مرتب‌سازی بر اساس فراوانی امانت توسط کاربران مشابه

        -- پاک کردن جداول موقت
        DROP TABLE #CurrentMemberBorrows;
        DROP TABLE #SimilarMembers;

    END TRY
    BEGIN CATCH
        -- ثبت هرگونه خطا در AuditLog
        DECLARE @ErrorMessage NVARCHAR(MAX), @ErrorSeverity INT, @ErrorState INT;
        SELECT
            @ErrorMessage = ERROR_MESSAGE(),
            @ErrorSeverity = ERROR_SEVERITY(),
            @ErrorState = ERROR_STATE();

        SET @LogDescription = N'خطا در پیشنهاد کتاب (فیلترینگ مشارکتی) برای MemberID: ' + CAST(@_MemberID AS NVARCHAR(10)) + N'. خطا: ' + @ErrorMessage;
        INSERT INTO Library.AuditLog (EventType, EventDescription, UserID)
        VALUES (N'Book Suggestion Error (Collaborative)', @LogDescription, @EventUser);

        -- دوباره ارور را نمایش می‌دهد (Raise)
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);

        -- پاکسازی جداول موقت در صورت خطا
        IF OBJECT_ID('tempdb..#CurrentMemberBorrows') IS NOT NULL
            DROP TABLE #CurrentMemberBorrows;
        IF OBJECT_ID('tempdb..#SimilarMembers') IS NOT NULL
            DROP TABLE #SimilarMembers;
    END CATCH;
END;
GO






USE UniversityDB;
GO

PRINT N'-------------------------------------------------------------------------------------';
PRINT N'Demonstrating Library.SuggestBooksForMember Stored Procedure (Collaborative Filtering)';
PRINT N'This script will set up test data for collaborative filtering and then call the suggestion procedure.';
PRINT N'-------------------------------------------------------------------------------------';

-- Declare test variables
DECLARE @TestMemberID INT;
DECLARE @SimilarMemberID INT;
DECLARE @BookID_Common1 INT;
DECLARE @BookID_Common2 INT;
DECLARE @BookID_UniqueToSimilar INT;
DECLARE @BookID_OtherCategory INT;
DECLARE @BookID_Unavailable INT;

-- از MemberIDهای موجود برای دمو استفاده کنید یا ایجاد کنید
SELECT TOP 1 @TestMemberID = MemberID FROM Library.Members ORDER BY MemberID ASC;
IF @TestMemberID IS NULL
BEGIN
    PRINT N'Error: No members found. Please ensure you have members in Library.Members table to run this demo.';
    RETURN;
END;
PRINT N'Using TestMemberID: ' + CAST(@TestMemberID AS NVARCHAR(10));

-- پیدا کردن یک عضو دیگر به عنوان عضو "مشابه". اگر فقط یک عضو دارید، باید یکی دیگر اضافه کنید.
SELECT TOP 1 @SimilarMemberID = MemberID FROM Library.Members WHERE MemberID <> @TestMemberID ORDER BY MemberID DESC;
IF @SimilarMemberID IS NULL
BEGIN
    PRINT N'Creating a new similar member for demo purposes...';
    -- فرض می‌کنیم RegisterMember وجود دارد
    DECLARE @NewMemberNationalCode NVARCHAR(10) = '1234567890';
    DECLARE @NewMemberFirstName NVARCHAR(50) = 'سارا';
    DECLARE @NewMemberLastName NVARCHAR(50) = 'محمدی';
    DECLARE @NewMemberEmail NVARCHAR(100) = 'sara.mohammadi@example.com';
    DECLARE @NewMemberPhone NVARCHAR(20) = '09123456789';

    BEGIN TRY
        EXEC Library.RegisterMember
            @NationalCode = @NewMemberNationalCode,
            @FirstName = @NewMemberFirstName,
            @LastName = @NewMemberLastName,
            @MemberType = N'General',
            @Email = @NewMemberEmail,
            @PhoneNumber = @NewMemberPhone;
        SELECT @SimilarMemberID = MemberID FROM Library.Members WHERE NationalCode = @NewMemberNationalCode;
        PRINT N'Created SimilarMemberID: ' + CAST(@SimilarMemberID AS NVARCHAR(10));
    END TRY
    BEGIN CATCH
        PRINT N'Warning: Could not create new member. Ensure Library.RegisterMember exists and NationalCode is unique. Proceeding with existing data or stopping.';
        -- اگر نتوانستیم عضو جدید بسازیم و عضو دوم هم نبود، نمی‌توانیم دمو را ادامه دهیم.
        IF @SimilarMemberID IS NULL RETURN;
    END CATCH;
END;
PRINT N'Using SimilarMemberID: ' + CAST(@SimilarMemberID AS NVARCHAR(10));

-- پاکسازی امانت‌های هر دو عضو برای تست تمیز
DELETE FROM Library.Borrows WHERE MemberID IN (@TestMemberID, @SimilarMemberID);
PRINT N'Cleaned up existing borrows for demo members.';


-- اطمینان از وجود کتاب‌های تستی با دسته‌بندی‌های مختلف
-- کتاب مشترک 1
SELECT TOP 1 @BookID_Common1 = BookID FROM Library.Books WHERE Title = N'پاییز فصل آخر سال است' AND AvailableCopies > 0;
IF @BookID_Common1 IS NULL
BEGIN
    INSERT INTO Library.BookCategories (CategoryName, Description) VALUES (N'داستان کوتاه', N'مجموعه داستان‌های کوتاه');
    INSERT INTO Library.Books (Title, ISBN, PublicationYear, TotalCopies, AvailableCopies, CategoryID)
    VALUES (N'پاییز فصل آخر سال است', '9786001760456', 2013, 3, 3, (SELECT CategoryID FROM Library.BookCategories WHERE CategoryName = N'داستان کوتاه'));
    SELECT @BookID_Common1 = SCOPE_IDENTITY();
END;
UPDATE Library.Books SET AvailableCopies = TotalCopies WHERE BookID = @BookID_Common1;

-- کتاب مشترک 2
SELECT TOP 1 @BookID_Common2 = BookID FROM Library.Books WHERE Title = N'شازده کوچولو' AND AvailableCopies > 0;
IF @BookID_Common2 IS NULL
BEGIN
    INSERT INTO Library.BookCategories (CategoryName, Description) VALUES (N'فلسفه و داستان', N'کتاب‌های با محتوای فلسفی در قالب داستان');
    INSERT INTO Library.Books (Title, ISBN, PublicationYear, TotalCopies, AvailableCopies, CategoryID)
    VALUES (N'شازده کوچولو', '9789643510000', 1943, 3, 3, (SELECT CategoryID FROM Library.BookCategories WHERE CategoryName = N'فلسفه و داستان'));
    SELECT @BookID_Common2 = SCOPE_IDENTITY();
END;
UPDATE Library.Books SET AvailableCopies = TotalCopies WHERE BookID = @BookID_Common2;

-- کتاب منحصر به فرد برای کاربر مشابه (این کتاب باید به TestMember پیشنهاد شود)
SELECT TOP 1 @BookID_UniqueToSimilar = BookID FROM Library.Books WHERE Title = N'کیمیاگر' AND AvailableCopies > 0;
IF @BookID_UniqueToSimilar IS NULL
BEGIN
    INSERT INTO Library.BookCategories (CategoryName, Description) VALUES (N'رمان انگیزشی', N'رمان‌های با محتوای انگیزشی');
    INSERT INTO Library.Books (Title, ISBN, PublicationYear, TotalCopies, AvailableCopies, CategoryID)
    VALUES (N'کیمیاگر', '9789643513339', 1988, 3, 3, (SELECT CategoryID FROM Library.BookCategories WHERE CategoryName = N'رمان انگیزشی'));
    SELECT @BookID_UniqueToSimilar = SCOPE_IDENTITY();
END;
UPDATE Library.Books SET AvailableCopies = TotalCopies WHERE BookID = @BookID_UniqueToSimilar;

-- یک کتاب دیگر در دسته‌بندی متفاوت که انتظار نمی‌رود پیشنهاد شود.
SELECT TOP 1 @BookID_OtherCategory = BookID FROM Library.Books WHERE Title = N'تاریخ ایران باستان' AND AvailableCopies > 0;
IF @BookID_OtherCategory IS NULL
BEGIN
    INSERT INTO Library.BookCategories (CategoryName, Description) VALUES (N'تاریخ', N'کتاب‌های تاریخی');
    INSERT INTO Library.Books (Title, ISBN, PublicationYear, TotalCopies, AvailableCopies, CategoryID)
    VALUES (N'تاریخ ایران باستان', '9789640000001', 2000, 2, 2, (SELECT CategoryID FROM Library.BookCategories WHERE CategoryName = N'تاریخ'));
    SELECT @BookID_OtherCategory = SCOPE_IDENTITY();
END;
UPDATE Library.Books SET AvailableCopies = TotalCopies WHERE BookID = @BookID_OtherCategory;

-- یک کتاب که کپی موجود ندارد و نباید پیشنهاد شود
SELECT TOP 1 @BookID_Unavailable = BookID FROM Library.Books WHERE Title = N'اثر مرکب' AND AvailableCopies = 0;
IF @BookID_Unavailable IS NULL
BEGIN
    INSERT INTO Library.Books (Title, ISBN, PublicationYear, TotalCopies, AvailableCopies, CategoryID)
    VALUES (N'اثر مرکب', '9786000000001', 2010, 1, 0, (SELECT CategoryID FROM Library.BookCategories WHERE CategoryName = N'رشد شخصی'));
    SELECT @BookID_Unavailable = SCOPE_IDENTITY();
END;
UPDATE Library.Books SET AvailableCopies = 0 WHERE BookID = @BookID_Unavailable; -- اطمینان از عدم موجودی

PRINT N'Simulating borrowing history for TestMemberID and SimilarMemberID...';

-- شبیه‌سازی امانت گرفتن کتاب‌های مشترک توسط هر دو عضو
BEGIN TRY
    EXEC Library.BorrowBook @MemberID = @TestMemberID, @BookID = @BookID_Common1;
    EXEC Library.BorrowBook @MemberID = @TestMemberID, @BookID = @BookID_Common2;

    EXEC Library.BorrowBook @MemberID = @SimilarMemberID, @BookID = @BookID_Common1;
    EXEC Library.BorrowBook @MemberID = @SimilarMemberID, @BookID = @BookID_Common2;

    -- شبیه‌سازی امانت گرفتن یک کتاب منحصر به فرد توسط عضو مشابه
    EXEC Library.BorrowBook @MemberID = @SimilarMemberID, @BookID = @BookID_UniqueToSimilar;

    -- شبیه‌سازی امانت گرفتن یک کتاب دیگر توسط عضو مشابه (برای افزایش فراوانی و تست ترتیب)
    EXEC Library.BorrowBook @MemberID = @SimilarMemberID, @BookID = @BookID_UniqueToSimilar;

END TRY
BEGIN CATCH
    PRINT N'Warning: Could not simulate borrowing for demo. Some books might already be borrowed or other issues. Proceeding with existing data.';
    PRINT N'Error: ' + ERROR_MESSAGE();
END CATCH;

-- فراخوانی پروسیجر پیشنهاد کتاب
PRINT N'---------------------------------------------------';
PRINT N'Calling Library.SuggestBooksForMember for TestMemberID ' + CAST(@TestMemberID AS NVARCHAR(10)) + N':';
PRINT N'---------------------------------------------------';

EXEC Library.SuggestBooksForMember @TestMemberID, 3; -- درخواست ۳ پیشنهاد

PRINT N'---------------------------------------------------';
PRINT N'End of Demonstration.';
PRINT N'---------------------------------------------------';

-- Optional: Clean up test borrows (You might want to manually revert changes or keep for inspection)
-- برای پاکسازی داده‌های تست پس از اجرا، خطوط زیر را از حالت کامنت خارج کنید:

PRINT N'Cleaning up test data (borrow records)...';
DELETE FROM Library.Borrows WHERE MemberID = @TestMemberID AND BookID IN (@BookID_Common1, @BookID_Common2);
DELETE FROM Library.Borrows WHERE MemberID = @SimilarMemberID AND BookID IN (@BookID_Common1, @BookID_Common2, @BookID_UniqueToSimilar);

-- برای بازگرداندن AvailableCopies (اگر BorrowBook آنها را کاهش داده باشد)
-- این بخش نیاز به بررسی دقیق وضعیت قبل از تغییر دارد و در یک محیط واقعی باید با دقت بیشتری مدیریت شود.
-- UPDATE Library.Books SET AvailableCopies = AvailableCopies + (تعداد کاهش یافته) WHERE BookID = BookID_X;
PRINT N'Test borrow records cleaned.';

GO












USE UniversityDB;
GO

PRINT N'-------------------------------------------------------------------------------------';
PRINT N'Demonstrating Library.SuggestBooksForMember Stored Procedure (Collaborative Filtering)';
PRINT N'This script will set up test data for collaborative filtering and then call the suggestion procedure.';
PRINT N'-------------------------------------------------------------------------------------';

-- Declare test variables for Member IDs
DECLARE @TestMemberID INT;
DECLARE @SimilarMemberID INT;

-- Declare variables for Book and Category IDs
DECLARE @CategoryID_ShortStory INT;
DECLARE @CategoryID_PhilosophyAndStory INT;
DECLARE @CategoryID_MotivationalNovel INT;
DECLARE @CategoryID_History INT;
DECLARE @CategoryID_PersonalGrowth INT;

DECLARE @BookID_Common1 INT;
DECLARE @BookID_Common2 INT;
DECLARE @BookID_UniqueToSimilar INT;
DECLARE @BookID_OtherCategory INT;
DECLARE @BookID_Unavailable INT;

-- Find an existing MemberID for the demo. If none, display error and exit.
SELECT TOP 1 @TestMemberID = MemberID FROM Library.Members ORDER BY MemberID ASC;
IF @TestMemberID IS NULL
BEGIN
    PRINT N'Error: No members found. Please ensure you have members in Library.Members table to run this demo.';
    RETURN;
END;
PRINT N'Using TestMemberID: ' + CAST(@TestMemberID AS NVARCHAR(10));

-- Find another member to act as the "similar" member. If only one member exists, create another.
SELECT TOP 1 @SimilarMemberID = MemberID FROM Library.Members WHERE MemberID <> @TestMemberID ORDER BY MemberID DESC;
IF @SimilarMemberID IS NULL
BEGIN
    PRINT N'Creating a new similar member for demo purposes...';
    -- Assuming Library.RegisterMember procedure exists
    DECLARE @NewMemberNationalCode NVARCHAR(10) = '1234567890';
    DECLARE @NewMemberFirstName NVARCHAR(50) = 'Sara';
    DECLARE @NewMemberLastName NVARCHAR(50) = 'Mohammadi';
    DECLARE @NewMemberEmail NVARCHAR(100) = 'sara.mohammadi@example.com';
    DECLARE @NewMemberPhone NVARCHAR(20) = '09123456789';

    BEGIN TRY
        EXEC Library.RegisterMember
            @NationalCode = @NewMemberNationalCode,
            @FirstName = @NewMemberFirstName,
            @LastName = @NewMemberLastName,
            @MemberType = N'General',
            @Email = @NewMemberEmail,
            @PhoneNumber = @NewMemberPhone;
        SELECT @SimilarMemberID = MemberID FROM Library.Members WHERE NationalCode = @NewMemberNationalCode;
        PRINT N'Created SimilarMemberID: ' + CAST(@SimilarMemberID AS NVARCHAR(10));
    END TRY
    BEGIN CATCH
        PRINT N'Warning: Could not create new member. Ensure Library.RegisterMember exists and NationalCode is unique. Proceeding with existing data or stopping.';
        IF @SimilarMemberID IS NULL RETURN; -- Cannot proceed without a similar member
    END CATCH;
END;
PRINT N'Using SimilarMemberID: ' + CAST(@SimilarMemberID AS NVARCHAR(10));

-- Clean up any existing borrows for both demo members to ensure a clean test state
PRINT N'Cleaning up existing borrows for demo members...';
DELETE FROM Library.Borrows WHERE MemberID IN (@TestMemberID, @SimilarMemberID);
PRINT N'Existing borrows cleaned.';


-- Ensure test categories and books exist, or insert them if not.
-- This section now robustly checks for existence using UNIQUE constraints before inserting.

-- Category: Short Story
SELECT @CategoryID_ShortStory = CategoryID FROM Library.BookCategories WHERE CategoryName = N'Short Story';
IF @CategoryID_ShortStory IS NULL
BEGIN
    INSERT INTO Library.BookCategories (CategoryName, Description) VALUES (N'Short Story', N'Collection of short stories');
    SELECT @CategoryID_ShortStory = SCOPE_IDENTITY();
END;

-- Book: Autumn is the Last Season of the Year (Common Book 1)
SELECT @BookID_Common1 = BookID FROM Library.Books WHERE ISBN = '9786001760456';
IF @BookID_Common1 IS NULL
BEGIN
    INSERT INTO Library.Books (Title, ISBN, PublicationYear, TotalCopies, AvailableCopies, CategoryID)
    VALUES (N'Autumn is the Last Season of the Year', '9786001760456', 2013, 3, 3, @CategoryID_ShortStory);
    SELECT @BookID_Common1 = SCOPE_IDENTITY();
END;
-- Always ensure availability for demo purposes
UPDATE Library.Books SET AvailableCopies = TotalCopies WHERE BookID = @BookID_Common1;


-- Category: Philosophy and Story
SELECT @CategoryID_PhilosophyAndStory = CategoryID FROM Library.BookCategories WHERE CategoryName = N'Philosophy and Story';
IF @CategoryID_PhilosophyAndStory IS NULL
BEGIN
    INSERT INTO Library.BookCategories (CategoryName, Description) VALUES (N'Philosophy and Story', N'Books with philosophical content in story format');
    SELECT @CategoryID_PhilosophyAndStory = SCOPE_IDENTITY();
END;

-- Book: The Little Prince (Common Book 2)
SELECT @BookID_Common2 = BookID FROM Library.Books WHERE ISBN = '9789643510000';
IF @BookID_Common2 IS NULL
BEGIN
    INSERT INTO Library.Books (Title, ISBN, PublicationYear, TotalCopies, AvailableCopies, CategoryID)
    VALUES (N'The Little Prince', '9789643510000', 1943, 3, 3, @CategoryID_PhilosophyAndStory);
    SELECT @BookID_Common2 = SCOPE_IDENTITY();
END;
UPDATE Library.Books SET AvailableCopies = TotalCopies WHERE BookID = @BookID_Common2;


-- Category: Motivational Novel
SELECT @CategoryID_MotivationalNovel = CategoryID FROM Library.BookCategories WHERE CategoryName = N'Motivational Novel';
IF @CategoryID_MotivationalNovel IS NULL
BEGIN
    INSERT INTO Library.BookCategories (CategoryName, Description) VALUES (N'Motivational Novel', N'Novels with motivational content');
    SELECT @CategoryID_MotivationalNovel = SCOPE_IDENTITY();
END;

-- Book: The Alchemist (Unique to Similar User - expected suggestion)
SELECT @BookID_UniqueToSimilar = BookID FROM Library.Books WHERE ISBN = '9789643513339';
IF @BookID_UniqueToSimilar IS NULL
BEGIN
    INSERT INTO Library.Books (Title, ISBN, PublicationYear, TotalCopies, AvailableCopies, CategoryID)
    VALUES (N'The Alchemist', '9789643513339', 1988, 3, 3, @CategoryID_MotivationalNovel);
    SELECT @BookID_UniqueToSimilar = SCOPE_IDENTITY();
END;
UPDATE Library.Books SET AvailableCopies = TotalCopies WHERE BookID = @BookID_UniqueToSimilar;


-- Category: History
SELECT @CategoryID_History = CategoryID FROM Library.BookCategories WHERE CategoryName = N'History';
IF @CategoryID_History IS NULL
BEGIN
    INSERT INTO Library.BookCategories (CategoryName, Description) VALUES (N'History', N'History books');
    SELECT @CategoryID_History = SCOPE_IDENTITY();
END;

-- Book: Ancient History of Iran (Other category - not expected suggestion)
SELECT @BookID_OtherCategory = BookID FROM Library.Books WHERE ISBN = '9789640000001';
IF @BookID_OtherCategory IS NULL
BEGIN
    INSERT INTO Library.Books (Title, ISBN, PublicationYear, TotalCopies, AvailableCopies, CategoryID)
    VALUES (N'Ancient History of Iran', '9789640000001', 2000, 2, 2, @CategoryID_History);
    SELECT @BookID_OtherCategory = SCOPE_IDENTITY();
END;
UPDATE Library.Books SET AvailableCopies = TotalCopies WHERE BookID = @BookID_OtherCategory;


-- Category: Personal Growth
SELECT @CategoryID_PersonalGrowth = CategoryID FROM Library.BookCategories WHERE CategoryName = N'Personal Growth';
IF @CategoryID_PersonalGrowth IS NULL
BEGIN
    INSERT INTO Library.BookCategories (CategoryName, Description) VALUES (N'Personal Growth', N'Books on personal development');
    SELECT @CategoryID_PersonalGrowth = SCOPE_IDENTITY();
END;

-- Book: The Compound Effect (Unavailable - not expected suggestion)
SELECT @BookID_Unavailable = BookID FROM Library.Books WHERE ISBN = '9786000000001';
IF @BookID_Unavailable IS NULL
BEGIN
    INSERT INTO Library.Books (Title, ISBN, PublicationYear, TotalCopies, AvailableCopies, CategoryID)
    VALUES (N'The Compound Effect', '9786000000001', 2010, 1, 0, @CategoryID_PersonalGrowth);
    SELECT @BookID_Unavailable = SCOPE_IDENTITY();
END;
UPDATE Library.Books SET AvailableCopies = 0 WHERE BookID = @BookID_Unavailable; -- Ensure no copies are available for this specific book


PRINT N'Simulating borrowing history for TestMemberID and SimilarMemberID...';

-- Simulate borrowing history to set up collaborative filtering scenario
BEGIN TRY
    -- Test Member borrows common books
    EXEC Library.BorrowBook @MemberID = @TestMemberID, @BookID = @BookID_Common1;
    EXEC Library.BorrowBook @MemberID = @TestMemberID, @BookID = @BookID_Common2;

    -- Similar Member borrows common books (making them "similar")
    EXEC Library.BorrowBook @MemberID = @SimilarMemberID, @BookID = @BookID_Common1;
    EXEC Library.BorrowBook @MemberID = @SimilarMemberID, @BookID = @BookID_Common2;

    -- Similar Member borrows a unique book that Test Member has not (this is the expected suggestion)
    EXEC Library.BorrowBook @MemberID = @SimilarMemberID, @BookID = @BookID_UniqueToSimilar;

    -- Optionally, simulate the similar member borrowing the unique book again to increase its "frequency"
    -- This affects the ORDER BY in the suggestion procedure if multiple suggestions are possible
    EXEC Library.BorrowBook @MemberID = @SimilarMemberID, @BookID = @BookID_UniqueToSimilar;

END TRY
BEGIN CATCH
    -- Catch specific errors related to borrowing if any
    DECLARE @ErrorMessage NVARCHAR(MAX), @ErrorSeverity INT, @ErrorState INT;
    SELECT
        @ErrorMessage = ERROR_MESSAGE(),
        @ErrorSeverity = ERROR_SEVERITY(),
        @ErrorState = ERROR_STATE();

    PRINT N'Warning: Could not simulate borrowing for demo. Error: ' + @ErrorMessage;
    PRINT N'This might be due to a THROW error in your BorrowBook procedure. Please ensure THROW error numbers are >= 50000 if used.';
END CATCH;

-- Call the book suggestion procedure
PRINT N'---------------------------------------------------';
PRINT N'Calling Library.SuggestBooksForMember for TestMemberID ' + CAST(@TestMemberID AS NVARCHAR(10)) + N':';
PRINT N'---------------------------------------------------';

-- Execute the suggestion procedure, requesting 3 suggestions
EXEC Library.SuggestBooksForMember @TestMemberID, 3;

PRINT N'---------------------------------------------------';
PRINT N'End of Demonstration.';
PRINT N'---------------------------------------------------';

-- Optional: Clean up test borrows (Uncomment if you want to remove the demo borrow records after execution)

PRINT N'Cleaning up test data (borrow records)...';
DELETE FROM Library.Borrows WHERE MemberID = @TestMemberID AND BookID IN (@BookID_Common1, @BookID_Common2);
DELETE FROM Library.Borrows WHERE MemberID = @SimilarMemberID AND BookID IN (@BookID_Common1, @BookID_Common2, @BookID_UniqueToSimilar);

-- Note: Resetting AvailableCopies to original TotalCopies for these books might be needed for full cleanup.
-- This depends on your system's design for managing book copies after returns.
PRINT N'Test borrow records cleaned.';

GO