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