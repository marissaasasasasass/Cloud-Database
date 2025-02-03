-- STORED PROCEDURE
/*Check Member’s Credit Points :
Use: Retrieves and displays the total credit points for a specific member
Columns Shown: mem_id, mem_name, lib_id, credit_point, Computer_Product Table
Justification: Allows members to view their eligibility for discounts in exchange for items. */

CREATE OR ALTER PROC uspCreditPoints (@mem_name VARCHAR(50))
AS
	-- Verify if member exists
	IF NOT EXISTS (SELECT * FROM Member WHERE mem_name = @mem_name)
	BEGIN
		SELECT 'Member name does not exist' AS 'Message'
		RETURN
	END

	IF @@ERROR <> 0 
	BEGIN
		  RETURN -108
	END
	
	-- Retrieve Member details
	SELECT mem_id, mem_name, lib_id, credit_point 
	FROM Member
	WHERE mem_name = @mem_name;

	-- Retrieve Computer Products that Member is eligible for
	SELECT * FROM Computer_Product
	WHERE points_required < (SELECT credit_point FROM Member	WHERE mem_name = @mem_name);
GO


/*Member Registration Summary :
Use: Compile a comprehensive summary of all courses that a specific member has attended previously.
Columns Shown: mem_id, mem_name, lib_id, course_title, course_date, course_level, credit_points
Justification: Shows the previous booking they have made to avoid going for the same course. They are able to check the credit points gained and the course difficulty.*/

CREATE OR ALTER PROC uspRegSummary (@mem_name VARCHAR(50))
AS
	DECLARE @mem_id VARCHAR(10);

	-- Verify if member exists
	IF NOT EXISTS (SELECT * FROM Member WHERE mem_name = @mem_name)
		BEGIN
			SELECT 'Member does not exist' AS 'Message'
			RETURN
		END

	IF @@ERROR <> 0 
		BEGIN
			RETURN -105
		END
	
	-- Retrieve mem_id
	SELECT @mem_id = mem_id
	FROM Member 
	WHERE mem_name = @mem_name

	-- Print the rows member have attended
	SELECT MCR.course_id, MCR.lib_id, R.course_date, C.course_level, (C.course_level * 1000) AS 'Credit Points'
	FROM Member_Course_Reg MCR
	INNER JOIN Registration R on MCR.mem_id = R.mem_id AND MCR.course_id = R.course_id AND MCR.lib_id = R.lib_id 
	INNER JOIN Course C on C.course_id = MCR.course_id

	WHERE MCR.status = 'Completed' AND MCR.mem_id = @mem_id
GO


/*Add New Course Schedule:
Use: Insert a new course schedule into the system.
Columns Shown: Course Table, Course Schedule Table
Justification: Staff can use this procedure to add upcoming courses to the system. The procedure automatically adds into course and course_schedule to avoid adding on seperate occasion. */

CREATE OR ALTER PROC uspNewCourse (@course_id CHAR(5), @course_title VARCHAR(50), @lib_name VARCHAR(50), @course_date SMALLDATETIME, @course_level TINYINT, @room CHAR(10), @class_size TINYINT)
AS
    DECLARE @lib_id CHAR(5);

    -- Validate course date
    IF @course_date < GETDATE()
    BEGIN
        SELECT 'Course date is not allowed' AS 'Message';
        RETURN;
    END

    -- Validate library existence
    IF NOT EXISTS (SELECT * FROM Library WHERE lib_name = @lib_name)
    BEGIN
        SELECT 'Library does not exist' AS 'Message';
        RETURN;
    END

    -- Validate class size
    IF @class_size < 10 OR @class_size > 40
    BEGIN
        SELECT 'Class size must be between 10 and 40' AS 'Message';
        RETURN;
    END

	-- Check if room is in use on that day
    IF EXISTS ( SELECT * FROM Course_Schedule WHERE lib_id = @lib_id AND course_date = @course_date AND room = @room)
    BEGIN
        SELECT 'Room is already in use on the same date and library' AS 'Message';
        RETURN;
    END

	-- Retrieve lib_id
    SELECT @lib_id = lib_id FROM Library WHERE lib_name = @lib_name;

	-- Insert into Course and Course_Schedule if validations pass
	IF EXISTS(SELECT * FROM Course WHERE course_id = @course_id)
	BEGIN
	    INSERT INTO Course_Schedule (course_id, lib_id, course_date, room, class_size)
		VALUES (@course_id, @lib_id, @course_date, @room, @class_size);
	END
	
	ELSE IF NOT EXISTS (SELECT * FROM Course WHERE course_id = @course_id)
	BEGIN
		INSERT INTO Course (course_id, course_title, course_level)
		VALUES (@course_id, @course_title, @course_level);

		INSERT INTO Course_Schedule (course_id, lib_id, course_date, room, class_size)
		VALUES (@course_id, @lib_id, @course_date, @room, @class_size);
	END

    -- Show the inserted row for confirmation
    SELECT * FROM Course WHERE course_id = @course_id;
    SELECT * FROM Course_Schedule WHERE course_id = @course_id;
GO


/*Course Capacity Check :
Use: Check current course capacity and calculates the percentage of total capacity in a course.
Columns Shown: course_title, count of registered, class_size, percentage of registered capacity
Justification: Allows staff to check whether a specific IT course has reached its maximum enrollment capacity. This procedure is critical for ensuring that courses do not exceed the allowed number of participants. */

CREATE OR ALTER PROC uspCapacityCheck (@course_title VARCHAR(50), @lib_name VARCHAR(50), @course_date SMALLDATETIME)
AS
	DECLARE @course_id VARCHAR(10);
	DECLARE @lib_id VARCHAR(5);

	DECLARE @class_size INT;
	DECLARE @registered INT;
	DECLARE @percentage FLOAT;
	
	-- Verify if course exists
	IF NOT EXISTS (SELECT * FROM Course WHERE course_title = @course_title)
	BEGIN
		SELECT 'Course does not exist' AS 'Message'
		RETURN
	END

	-- Verify if library exists
	IF NOT EXISTS (SELECT * FROM Library WHERE lib_name = @lib_name)
	BEGIN
		SELECT 'Library does not exist' AS 'Message'
		RETURN
	END

	IF @@ERROR <> 0 
	BEGIN
		  RETURN -105
	END

	-- Retrieve course_id and lib_id
	SELECT @lib_id = lib_id
	FROM Library
	WHERE lib_name = @lib_name

	SELECT @course_id = course_id
	FROM Course
	WHERE course_title = @course_title

	-- Count number of Registered Members
	SELECT @registered = COUNT(*) 
	FROM Registration 
	WHERE course_id = @course_id AND lib_id = @lib_id AND course_date = @course_date;

	-- Check for class size
	SELECT @class_size = class_size 
	FROM Course_Schedule 
	WHERE course_id = @course_id AND lib_id = @lib_id AND course_date = @course_date;

	-- Zero Registered
	IF (@registered = 0)
	BEGIN
		SELECT 'Course has zero attendees' AS 'Message'
		RETURN
	END

	-- Course registered percentage
	ELSE
	BEGIN
		SET @percentage = (@registered*100)/@class_size

		SELECT  @course_title AS 'Course Title', 
				@registered AS 'Enrolled Numbers', 
				@class_size AS 'Class Size',
				@percentage AS 'Class Percentage'
		RETURN
	END;
GO


/*Delete Courses From Course_Schedule:
Use: Delete courses once course date has passed.
Columns Shown: Course_Schedule Table
Justification: To show that course has been completed and no longer available.*/

CREATE OR ALTER PROC uspDeleteCourse (@course_title VARCHAR(50), @lib_name VARCHAR(50), @course_date SMALLDATETIME)
AS	
	DECLARE @course_id CHAR(5);
	DECLARE @lib_id CHAR(5);

	-- Verify if course exists
	IF NOT EXISTS (SELECT * FROM Course WHERE course_title = @course_title)
	BEGIN
		SELECT 'Course ID does not exists' AS 'Message'
		RETURN
	END

	-- Verify if library exists
	IF NOT EXISTS (SELECT * FROM Library WHERE lib_name = @lib_name)
	BEGIN
		SELECT 'Library does not exists' AS 'Message'
		RETURN
	END

	-- Verify that course data has passed, if haven't course details is not allowed to be deleted
	IF @course_date> GETDATE()
	BEGIN 
		SELECT 'Course cannot be removed as course has not been completed' AS 'Message'
		RETURN
	END

	IF @@ERROR <> 0 
	BEGIN
		  RETURN -105
	END

	-- Retrieve course_id and lib_id
	SELECT @course_id = course_id
	FROM Course
	WHERE course_title = @course_title;

	SELECT @lib_id = lib_id
	FROM Library
	WHERE lib_name = @lib_name;

	-- Delete Course
	DELETE Registration WHERE course_id = @course_id AND lib_id = @lib_id AND course_date = @course_date
	DELETE Course_Schedule WHERE course_id = @course_id AND lib_id = @lib_id AND course_date = @course_date

	-- Show Course_Schedule for confirmation
    SELECT * FROM Course_Schedule
	SELECT * FROM Registration;
GO


/*Delete Item :
Use: Delete item once product quantity hits zero 
Columns Shown: Computer_Product Table
Justification: Make way to bring in new products and show that the product is no longer available for purchase*/

CREATE OR ALTER PROC uspDeleteItem (@product_name VARCHAR(50))
AS
	DECLARE @stock_quantity INT;

	-- Verify if product exists
	IF NOT EXISTS (SELECT * FROM Computer_Product WHERE product_name = @product_name)
	BEGIN
		SELECT 'Product does not exist' AS 'Message'
		RETURN
	END

	SELECT @stock_quantity = stock_quantity 
	FROM Computer_Product 
	WHERE product_name = @product_name

	-- Product quantity is above 0
	IF @stock_quantity <> 0 
	BEGIN
		SELECT @product_name AS 'Product Name', @stock_quantity AS 'Stock Quantity'
		RETURN
	END

	IF @@ERROR <> 0 
	BEGIN
		  RETURN -105
	END

	-- Delete product from table
	DELETE Computer_Product
	WHERE product_name = @product_name AND stock_quantity = 0 AND is_active = 0

	-- Show Computer_Product for confirmation
	SELECT * FROM Computer_Product;
GO


/*Delete course from Member Course Registration :
Use: Delete course once course date has passed.
Columns Shown: Once triggered has been triggered, status will be changed from 'Pending' to 'Completed' 
Justification: To show that registered members have successfully completed the course*/

CREATE OR ALTER PROC uspDeleteMemReg (@course_title VARCHAR(50), @lib_name VARCHAR(50), @course_date SMALLDATETIME)
AS
	DECLARE @course_id CHAR(5);
	DECLARE @lib_id CHAR(5);

	--Check if course exist
	IF NOT EXISTS (SELECT * FROM Course WHERE course_title = @course_title)
	BEGIN
		SELECT 'Course title does not exist' AS 'Message'
		RETURN
	END

	--Check if library exist
	IF NOT EXISTS (SELECT * FROM Library WHERE lib_name = @lib_name)
	BEGIN
		SELECT 'Library does not exists' AS 'Message'
		RETURN
	END

	--Check if course date is in the future 
	IF @course_date > GETDATE()
	BEGIN
		SELECT 'Course data is not allowed to be deleted' AS 'Message'
		RETURN
	END

	-- Retrieve course_id and lib_id
	SELECT @course_id = course_id
	FROM Course
	WHERE course_title = @course_title

	SELECT @lib_id = lib_id
	FROM Library
	WHERE lib_name = @lib_name

	IF @@ERROR <> 0 
	BEGIN
		  RETURN -105
	END

	-- Delete from Table
	DELETE FROM Member_Course_Reg
	WHERE course_id = @course_id AND lib_id = @lib_id
	AND EXISTS (SELECT * FROM Course_Schedule WHERE course_date = @course_date AND course_id = @course_id AND lib_id = @lib_id);
GO


/*Update course room:
Use: Update course room when changes are made.
Columns Shown: Course_Schedule table where row details have been made changes to
Justification: Update members that have registered for the class that course details have been made changes*/

CREATE OR ALTER PROC uspUpdateLocation (@course_title VARCHAR(50), @lib_name VARCHAR(50), @course_date SMALLDATETIME, @room CHAR(10) NULL)
AS
    DECLARE @course_id CHAR(5);
    DECLARE @lib_id CHAR(5);

    -- Check if course exists
    IF NOT EXISTS (SELECT * FROM Course WHERE course_title = @course_title)
    BEGIN
        SELECT 'Course title does not exist' AS 'Message';
        RETURN;
    END

    -- Check if library exists
    IF NOT EXISTS (SELECT * FROM Library WHERE lib_name = @lib_name)
    BEGIN
        SELECT 'Library does not exist' AS 'Message';
        RETURN;
    END

    -- Check if course date is allowed to be updated
    IF DATEDIFF(DAY, GETDATE(), @course_date) <= 7
    BEGIN
        SELECT 'Course date is not allowed to be updated' AS 'Message';
        RETURN;
    END

	-- Check if room is in use on that day
    IF EXISTS ( SELECT * FROM Course_Schedule WHERE lib_id = @lib_id AND course_date = @course_date AND room = @room)
    BEGIN
        SELECT 'Room is already in use on the same date and library' AS 'Message';
        RETURN;
    END

    -- Retrieve course_id and lib_id
    SELECT @course_id = course_id FROM Course WHERE course_title = @course_title;
    SELECT @lib_id = lib_id FROM Library WHERE lib_name = @lib_name;

    -- Change course room
    UPDATE Course_Schedule 
    SET room = @room
    WHERE course_id = @course_id AND lib_id = @lib_id AND course_date = @course_date;
GO

-- VIEW
/*Top Libraries by Course Offering :
Displays the ranks of libraries based on the number of courses that are offered.
Helpful to showcase whether all the library offers similar amount of courses so that all members are offered equal amount of opportunities.*/

CREATE OR ALTER VIEW LibRank
AS
    SELECT L.lib_name, COUNT(S.course_id) AS course_count
    FROM Library L
    INNER JOIN Course_Schedule S ON S.lib_id = L.lib_id
    GROUP BY L.lib_name;
GO


/*Member Attendance by Month :
Displays the member’s attendance of different courses and library that they have previously registered.
Displays the year and month they attended on.*/

CREATE OR ALTER VIEW AttendanceView
AS
    SELECT cr.mem_id, c.course_title, s.lib_id, YEAR(s.course_date) AS year_attended, MONTH(s.course_date) AS month_attended, COUNT(*) AS attendance_count

    FROM Member_Course_Reg cr
    INNER JOIN Course_Schedule s ON cr.course_id = s.course_id
    INNER JOIN Course c ON c.course_id = s.course_id
    GROUP BY cr.mem_id, s.lib_id, c.course_title, YEAR(s.course_date), MONTH(s.course_date);
GO


/*Library Performance Overview 
Summarizes total count of course completions and cancellation per library, allowing for performance comparisons.*/

CREATE OR ALTER VIEW LibOverview
AS	
    SELECT c.course_title, l.lib_id, s.course_date,

        -- Count Completed and Cancelled registrations for each course and library
        COUNT(CASE WHEN cr.status = 'Completed' THEN 1 END) AS Completed,
        COUNT(CASE WHEN cr.status = 'Cancelled' THEN 1 END) AS Cancelled

    FROM COURSE c
    INNER JOIN Course_Schedule s ON s.course_id = c.course_id
    INNER JOIN Library l ON l.lib_id = s.lib_id
    LEFT JOIN Member_Course_Reg cr ON cr.course_id = c.course_id AND cr.lib_id = l.lib_id  -- Join to count statuses
    GROUP BY c.course_title, l.lib_id, s.course_date;
GO


/*Course Attendance Completion Rate 
Provides completion rates by course and library, showing how many registrants successfully completed each course.*/

CREATE OR ALTER VIEW CompletionRate
AS
SELECT c.course_title, l.lib_name,

	--  Count number of completed members
    COUNT(CASE WHEN r.status = 'Completed' THEN 1 END) AS 'Number of Students Completed',

	-- Percentage of completed members
    CAST(COUNT(CASE WHEN r.status = 'Completed' THEN 1 END) * 100.0 / s.class_size AS DECIMAL(5, 2)) AS 'Percentage of Completed'

	FROM Member_Course_Reg r
	INNER JOIN Course_Schedule s ON r.course_id = s.course_id AND r.lib_id = s.lib_id
	INNER JOIN Library l ON l.lib_id = s.lib_id
	INNER JOIN Course c ON c.course_id = s.course_id
	GROUP BY c.course_title, l.lib_name, s.class_size;
GO


--TRIGGER
/*Update Course Completion Status:
Automatically updates the status of Member Course Registration to “Completed” once the course date has passed */

CREATE OR ALTER TRIGGER trgUpdateMemberRegStatus
ON Member_Course_Reg
AFTER DELETE
AS
BEGIN
    -- Update the status of affected records to 'Completed'
    UPDATE MCR
    SET status = 'Completed'
    FROM Member_Course_Reg MCR
    INNER JOIN Deleted D ON MCR.mem_id = D.mem_id AND MCR.course_id = D.course_id AND MCR.lib_id = D.lib_id
    WHERE MCR.status <> 'Completed';

    -- Display the affected rows from the Deleted table
    SELECT * 
    FROM Deleted D
    WHERE EXISTS (
        SELECT *
        FROM Member_Course_Reg MCR
        WHERE MCR.mem_id = D.mem_id AND MCR.course_id = D.course_id AND MCR.lib_id = D.lib_id AND MCR.status = 'Completed'
    );

    PRINT 'Member course registration status updated to Completed.';
END;
GO



/*Notify Course Update when room has been made changes*/
CREATE OR ALTER TRIGGER trgNotifyCourseUpdate
ON Course_Schedule
AFTER UPDATE
AS
BEGIN
    -- Check if the room or course_date has changed
    IF UPDATE(room) 
    BEGIN
        PRINT 'Course details room have been updated. Please notify registered members.';
        
        -- Show affected rows
        SELECT course_id, lib_id, course_date AS 'New Course Date', room 
        FROM Inserted;
    END
END;
GO


/*Notify When Product Stock Hits 5 or 1
To inform staff that product stock levels is low.*/

CREATE OR ALTER TRIGGER trgProductStock
ON Computer_Product
AFTER UPDATE, INSERT
AS

    DECLARE @stock_quantity INT;
    DECLARE @product_name VARCHAR(50);

    -- Select the affected rows and check stock quantity
    SELECT @stock_quantity = stock_quantity, @product_name = product_name
    FROM INSERTED;

    -- Notify when stock hits 5
    IF @stock_quantity = 5
    BEGIN
        PRINT 'Warning: Stock for "' + @product_name + '" is critically low at 5 units.';
    END

    -- Notify when stock hits 1
    IF @stock_quantity = 1
    BEGIN
        PRINT 'ALERT: Stock for "' + @product_name + '" is at 1 unit.';
    END;
GO


/*Notify on High-Credit Members
Inform members that they are eligible for product discounts and credit points have reached the limit.*/
CREATE OR ALTER TRIGGER trgNotifyHighCredit
ON Member
AFTER UPDATE
AS
    DECLARE @threshold INT = 100000;

	-- Once Credit Point > 100000, message would be printed as a reminder
    IF EXISTS (SELECT * FROM INSERTED WHERE credit_point > @threshold)
    BEGIN
        PRINT 'Notification: A member has exceeded the credit point threshold. Review for rewards.';
    END;
GO




-- TESTING:
-- STORED PROCEDURE
/*Check Member’s Credit Points :
Use: Retrieves and displays the total credit points for a specific member.
Columns Shown: mem_id, mem_name, lib_id, credit_point
Justification: Allows members to view their eligibility for discounts in exchange for items. */

-- Member Exists: Passed
EXEC uspCreditPoints 'Betty Phua'

-- Member does not exists: Failed
EXEC uspCreditPoints 'Julia Zhou'


/*Member Registration Summary :
Use: Compile a comprehensive summary of all courses that a specific member has attended previously.
Columns Shown: mem_id, mem_name, lib_id, course_title, course_date, course_level, credit_points
Justification: Shows the previous booking they have made to avoid going for the same course. They are able to check the credit points gained and the course difficulty.*/

-- Member Exists: Passed
EXEC uspRegSummary 'Angelia Chew'

-- Member does not exists: Failed
EXEC uspRegSummary 'Chuah Shida'


/*Add New Course :
Use: Insert a new course offering into the system.
Columns Shown: Course Table, Course Schedule Table
Justification: Staff can use this procedure to add upcoming courses to the system. The procedure automatically adds into course and course_schedule to avoid adding on seperate occasion. */

-- Register New Course Schedule: Passed
EXEC uspNewCourse 'INT10', 'Introduction to English', 'Queenstown Community Library', '2024-12-27 00:00:00', 1, '04-01', 20

--Check Course Date: Failed
EXEC uspNewCourse 'WEB01', 'Introduction to C#', 'Queenstown Community Library', '2023-12-12 00:00:00', 1, '04-01', 20

--Check Library Exists: Failed
EXEC uspNewCourse 'WEB01', 'Introduction to C#', 'Orchard Community Library', '2024-12-12 00:00:00', 1, '04-01', 20

--Check Class Size: Failed
EXEC uspNewCourse 'WEB06', 'Introduction to C++', 'Queenstown Community Library', '2024-12-12 00:00:00', 1, '04-01', 5


/*Course Capacity Check :
Use: Check current course capacity and calculates the percentage of total capacity in a course.
Columns Shown: course_title, count of registered, class_size, percentage of registered capacity
Justification: Allows staff to check whether a specific IT course has reached its maximum enrollment capacity. This procedure is critical for ensuring that courses do not exceed the allowed number of participants. */

-- Check Course Exists: Passed
EXEC uspCapacityCheck 'Introduction to Databases', 'Central Community Library', '2024-02-02 00:00:00'

-- Check Course Exists: Failed
EXEC uspCapacityCheck 'Introduction to HTML', 'Central Community Library', '2024-02-04 00:00:00'

-- Check Course Doesn't Exists: Failed
EXEC uspCapacityCheck 'Introduction to Robotics', 'Central Community Library', '2024-02-04 00:00:00'

-- Check Library Doesn't Exists: Failed
EXEC uspCapacityCheck 'Introduction to HTML', 'Clementi Community Library', '2024-02-04 00:00:00'


/*Delete Courses From Course_Schedule:
Use: Delete courses once course date has passed.
Columns Shown: Course_Schedule Table
Justification: To show that course has been completed and no longer available.*/

-- Delete from Course: Passed
EXEC uspDeleteCourse 'Introduction to Databases', 'Central Community Library', '2024-02-02 00:00:00'

-- Check Library Doesn't Exists: Failed
EXEC uspDeleteCourse 'Introduction to Databases', 'Clementi Community Library', '2024-04-04 00:00:00'

-- Check Course Doesn't Exists: Failed
EXEC uspDeleteCourse 'Introduction to Robotics', 'Ang Mo Kio Community Library', '2024-04-04 00:00:00'

-- Check date has not passed: Failed
EXEC uspDeleteCourse 'JavaScript Programming', 'Toa Payoh Community Library', '2025-01-02 00:00:00'


/*Delete Item :
Use: Delete item once product quantity hits zero 
Columns Shown: Computer_Product Table
Justification: Make way to bring in new products and show that the product is no longer available for purchase*/

-- Check if item exists and has zero quantity: Passed
INSERT Computer_Product VALUES ('Lenovo Laptop', '1200', '10000', '10', 0, 0)
EXEC uspDeleteItem 'Lenovo Laptop'

-- Check if item exists and should print the stock quantity: Passed
EXEC uspDeleteItem 'HD Webcam with Privacy Cover'

-- Item does not exists: Failed
EXEC uspDeleteItem 'Nehaa'


/*Delete course from Member Course Registration :
Use: Delete course once course date has passed.
Columns Shown: Once triggered has been triggered, status will be changed from 'Pending' to 'Completed'
Justification: To show that member has successfully completed the course*/

-- Check Course, Library, Date: Passed
EXEC uspDeleteMemReg 'Advanced HTML & CSS', 'Ang Mo Kio Community Library', '2024-12-02 00:00:00'

-- Check Library Doesn't Exists: Failed
EXEC uspDeleteCourse 'Introduction to Databases', 'Clementi Community Library', '2024-04-04 00:00:00'

-- Check Course Doesn't Exists: Failed
EXEC uspDeleteCourse 'Introduction to Robotics', 'Ang Mo Kio Community Library', '2024-04-04 00:00:00'

-- Check date has not passed: Failed
EXEC uspDeleteCourse 'JavaScript Programming', 'Toa Payoh Community Library', '2025-01-02 00:00:00'


/*Update course date or room :
Use: Update course room when changes are made.
Columns Shown: Course_Schedule table where row details have been made changes to
Justification: Update members that have registered for the class that course details have been made changes*/

-- Change room: Passed
EXEC uspUpdateLocation 'JavaScript Programming', 'Toa Payoh Community Library', '2024-12-03 09:00:00', '12-05'

-- Not allowed to change date <7 days: Failed
EXEC uspUpdateLocation 'Introduction to Windows 11', 'Central Community Library', '2024-12-01 09:00:00', '10-10'

-- VIEW
/*Top Libraries by Course Offering :
Displays the ranks of libraries based on the number of courses that are offered.
Helpful to showcase whether all the library offers similar amount of courses so that all members are offered equal amount of opportunities.*/

SELECT * FROM LibRank
ORDER BY course_count DESC;


/*Member Attendance by Month :
Displays the member’s attendance of different courses and library that they have previously registered.
Displays the year and month they attended on.*/

SELECT * FROM AttendanceView
WHERE mem_id = 'S1111111A '
ORDER BY mem_id, year_attended, month_attended;


/*Library Performance Overview 
Summarizes total count of course completions and cancellation per library, allowing for performance comparisons.*/

SELECT * FROM LibOverview
ORDER BY Completed DESC;


/*Course Attendance Completion Rate 
Provides completion rates by course and library, showing how many registrants successfully completed each course. */

SELECT * FROM CompletionRate
WHERE course_title = 'Python Programming' AND lib_name = 'Ang Mo Kio Community Library'

-- TRIGGER
/*Update Course Completion Status:
Automatically updates the status of Member Course Registration to “Completed” once the course date has passed */

EXEC uspDeleteMemReg 'Introduction to Databases', 'Central Community Library', '2024-02-02'

/*Notify When Product Stock Hits 5 or 1
To inform staff that product stock levels is low.*/

-- Stock level at 5
UPDATE Computer_Product
SET stock_quantity = 5
WHERE product_name = 'HD Webcam with Privacy Cover';

-- Stock levl at 1
UPDATE Computer_Product
SET stock_quantity = 1
WHERE product_name = 'HD Webcam with Privacy Cover';


/*Notify on High-Credit Members
Inform members that they are eligible for product discounts and credit points have reached the limit.*/

UPDATE Member
SET credit_point = 100001
WHERE mem_name = 'Darren Wang';