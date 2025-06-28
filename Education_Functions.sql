USE UniversityDB;
GO

-- Function to calculate the GPA for a given student
CREATE FUNCTION Education.CalculateStudentGPA (@StudentID INT)
RETURNS DECIMAL(4,2)
AS
BEGIN
    DECLARE @GPA DECIMAL(4,2);
    DECLARE @TotalCredits DECIMAL(10,2);
    DECLARE @WeightedSum DECIMAL(10,2);

    -- Calculate the weighted sum of grades and total credits for completed courses
    SELECT
        @WeightedSum = ISNULL(SUM(G.FinalGrade * C.Credits), 0),
        @TotalCredits = ISNULL(SUM(C.Credits), 0)
    FROM
        Education.Grades AS G
    INNER JOIN
        Education.Enrollments AS E ON G.EnrollmentID = E.EnrollmentID
    INNER JOIN
        Education.CourseOfferings AS CO ON E.OfferingID = CO.OfferingID
    INNER JOIN
        Education.Courses AS C ON CO.CourseID = C.CourseID
    WHERE
        E.StudentID = @StudentID
        AND E.Status = 'Completed'; -- Only consider completed courses for GPA

    -- Calculate GPA
    IF @TotalCredits > 0
        SET @GPA = @WeightedSum / @TotalCredits;
    ELSE
        SET @GPA = 0.00; -- No completed courses, GPA is 0

    RETURN @GPA;
END;
GO


-- Function to calculate the number of remaining credits for a student's major
CREATE FUNCTION Education.GetRemainingCredits (@StudentID INT)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @MajorID INT;
    DECLARE @TotalRequiredCredits DECIMAL(10,2);
    DECLARE @CompletedCredits DECIMAL(10,2);
    DECLARE @RemainingCredits DECIMAL(10,2);

    -- Get the student's MajorID
    SELECT @MajorID = MajorID
    FROM Education.Students
    WHERE StudentID = @StudentID;

    -- If student's major is not defined or student does not exist, return 0
    IF @MajorID IS NULL
        RETURN 0.00;

    -- Calculate total credits required for the student's major based on curriculum
    SELECT @TotalRequiredCredits = ISNULL(SUM(C.Credits), 0)
    FROM Education.Curriculum AS CUR
    INNER JOIN Education.Courses AS C ON CUR.CourseID = C.CourseID
    WHERE CUR.MajorID = @MajorID;

    -- Calculate credits for courses the student has already completed successfully
    SELECT @CompletedCredits = ISNULL(SUM(COURSES.Credits), 0)
    FROM Education.Students AS S
    INNER JOIN Education.Enrollments AS E ON S.StudentID = E.StudentID
    INNER JOIN Education.Grades AS G ON E.EnrollmentID = G.EnrollmentID
    INNER JOIN Education.CourseOfferings AS CO ON E.OfferingID = CO.OfferingID
    INNER JOIN Education.Courses AS COURSES ON CO.CourseID = COURSES.CourseID
    WHERE S.StudentID = @StudentID
      AND E.Status = 'Completed'
      AND G.FinalGrade >= 10; -- Assuming a passing grade is 10 or above

    -- Calculate remaining credits
    SET @RemainingCredits = @TotalRequiredCredits - @CompletedCredits;

    -- Ensure remaining credits are not negative
    IF @RemainingCredits < 0
        SET @RemainingCredits = 0.00;

    RETURN @RemainingCredits;
END;
GO



-- Description: Determines the status of a student for a specific academic year and semester based on the number of credits they are enrolled in.
-- Rules:
--   - 'Full-time': 12 credits or more (assuming standard full-time load)
--   - 'Part-time': More than 0 and less than 12 credits
--   - 'On Leave': 0 credits enrolled, but student's overall status is 'Active'
--   - 'Not Enrolled / Other Status': If student doesn't exist, not active, or no enrollments for the semester.
CREATE FUNCTION Education.fn_GetStudentSemesterStatus
(
    @StudentID INT,
    @AcademicYear INT,
    @Semester NVARCHAR(20)
)
RETURNS NVARCHAR(50)
AS
BEGIN
    DECLARE @StudentOverallStatus NVARCHAR(20);
    DECLARE @EnrolledCredits DECIMAL(10,2);
    DECLARE @SemesterStatus NVARCHAR(50);

    -- 1. Get the student's overall status
    SELECT @StudentOverallStatus = Status
    FROM Education.Students
    WHERE StudentID = @StudentID;

    IF @StudentOverallStatus IS NULL
    BEGIN
        RETURN N'Student Not Found';
    END

    -- 2. Calculate total credits the student is ENROLLED in for the specified semester
    SELECT @EnrolledCredits = ISNULL(SUM(C.Credits), 0)
    FROM Education.Enrollments AS E
    INNER JOIN Education.CourseOfferings AS CO ON E.OfferingID = CO.OfferingID
    INNER JOIN Education.Courses AS C ON CO.CourseID = C.CourseID
    WHERE E.StudentID = @StudentID
      AND CO.AcademicYear = @AcademicYear
      AND CO.Semester = @Semester
      AND E.Status = 'Enrolled'; -- Only count currently enrolled courses

    -- 3. Determine semester status based on enrolled credits and overall status
    IF @EnrolledCredits >= 12.0
    BEGIN
        SET @SemesterStatus = N'Full-time';
    END
    ELSE IF @EnrolledCredits > 0 AND @EnrolledCredits < 12.0
    BEGIN
        SET @SemesterStatus = N'Part-time';
    END
    ELSE IF @EnrolledCredits = 0 AND @StudentOverallStatus = 'Active'
    BEGIN
        SET @SemesterStatus = N'On Leave'; -- Active student, but no courses this semester
    END
    ELSE
    BEGIN
        SET @SemesterStatus = N'Not Enrolled / Other Status'; -- Student might be inactive, graduated, etc., or simply not enrolled
    END

    RETURN @SemesterStatus;
END;
GO
