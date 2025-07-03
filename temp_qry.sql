-- غیر فعال کردن تریگر trg_Education_Students_CreateLibraryMember روی جدول Education.Students
ENABLE TRIGGER Education.trg_Education_Students_CreateLibraryMember ON Education.Students;
GO

PRINT 'Trigger trg_Education_Students_CreateLibraryMember on Education.Students has been DISABLED.';
GO

