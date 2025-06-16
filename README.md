Project Description:

The goal of this project is to design and implement an integrated database system for two main university domains: University Education and Library.

Each section will be implemented separately but with logical interaction, with tables designed based on normalization principles. The implementation must prevent data redundancy and should be carried out in the SSMS environment. For each of the two schemas, the implementation includes designing tables, defining useful functions, stored procedures, and logical triggers.

Main Project Requirements
Two separate schemas with the titles Education and Library.
Minimum 15 tables in the Education schema and minimum 10 tables in the Library schema.
Tables must be designed in normalized form without redundancy.
Minimum implementation for each schema (in addition to table design, other requested items are listed below):
At least 3 useful Functions
At least 3 useful Stored Procedures
At least 3 logical Triggers
Logging important events in a log table (separate for each schema).
Interaction Between Schemas
For logical communication between the Education and Library systems, the following items will be implemented in the form of triggers:

Student registration in Education should automatically lead to the creation of a library account for them.
Student withdrawal or expulsion from academic studies should result in the deactivation of their library access.
During initial student registration, the national code's validity must be checked, and the operation halted if incorrect.
Proposed Implementations: Course Selection for Students
A course suggestion system should be defined for each academic year and semester intake, so that during course selection, the system proposes unpassed courses based on that semester's prerequisites and the student's priorities (at least for Computer Science major, the course chart must be recorded).

Proposed Implementations: Book Suggestion for Students
For student book suggestions, a simple technique using Collaborative Filtering will be implemented as follows:

Suggestion Algorithm:

Get the list of books borrowed by the current student.
Find students who have shared books with them (at least two common books).
Extract the list of books borrowed by these students that the current student has not yet borrowed.
Order this list based on the number of repetitions or borrowing frequency among similar users.
Present 3 top books as the final output.
Optional (Bonus) Items
(For bonus items, you need to record a video demonstrating the correct performance of the implemented items within the uploaded file. If more than one group member participated in a bonus item, it is mandatory for both members to appear in the video.)

Defining different user access levels for the database (0.5 points):
Only the Admin role in the Education schema should be allowed to add new students.
Only the Librarian role should be allowed to register or return books.
The "Student" role should be able to:
Use functions such as "view GPA", "remaining credits", and "semester status".
Proceed with course selection only through an authorized stored procedure, and not by directly writing to the registration table.
Full implementation of the book suggestion Stored Procedure in the SSIS environment (0.5 points).
Ability to Import and Export important data in Excel format using BULK INSERT (0.25 points):
For suitable tables such as student lists, curriculum, or books.
Calling written Stored Procedures in a job (0.25 points):
For example, running the book suggestion stored procedure on a nightly or weekly schedule.
Required Deliverables
SQL file for creating database structure and tables.
SQL file containing test data for key tables.
SQL file including definitions for functions, triggers, and Stored Procedures.
SQL file for testing the execution of functions, stored procedures, and triggers (to be presented during the presentation time).
PDF file with a brief explanation of the functionality of functions, stored procedures, and triggers.
Final database backup file with .bak format.
Video(s) + files related to bonus items.
