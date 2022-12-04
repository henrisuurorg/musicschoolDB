-------------- INFO ----------------------
/*
 * To test this program you need to:
 * 	1. run create_sgms.sql
 * 	2. run populate.sql
 *  3. run this file
 * */

-------- DELETE AND RECREATE VIEWS --------
DROP SCHEMA IF EXISTS dbview_schema CASCADE;
CREATE SCHEMA dbview_schema;

-- Query 1
-------------- VIEWS ----------------------
CREATE VIEW dbview_schema.individual_lessons_per_month AS
SELECT(TO_CHAR(il.date, 'Month')) il_month, COUNT(*)  il_count
FROM individual_lesson il
WHERE EXTRACT(YEAR
FROM date) = 2022 -- 	<- enter YEAR here
GROUP BY il_month;

CREATE VIEW dbview_schema.group_lessons_per_month AS
SELECT(TO_CHAR(gl.date, 'Month')) gl_month, COUNT(*) gl_count
FROM group_lesson gl
WHERE EXTRACT(YEAR
FROM date) = 2022 -- 	<- enter YEAR here
GROUP BY gl_month;

CREATE VIEW dbview_schema.ensembles_per_month AS
SELECT(TO_CHAR(e.date, 'Month')) e_month, COUNT(*) e_count
FROM ensemble e
WHERE EXTRACT(YEAR
FROM date) = 2022 -- 	<- enter YEAR here
GROUP BY e_month;

-------------- QUERY ----------------------
CREATE VIEW dbview_schema.query1 AS
SELECT TO_CHAR(month, 'Month') AS MONTH, COALESCE(il.il_count, 0) AS il_count, COALESCE(gl.gl_count, 0) AS gl_count, COALESCE(e.e_count, 0) AS e_count, COALESCE(il.il_count, 0)+ COALESCE(gl.gl_count, 0)+ COALESCE(e.e_count, 0) AS total
FROM generate_series(
    '2008-01-01' :: DATE, '2008-12-01' :: DATE , '1 month'
) AS month
LEFT JOIN individual_lessons_per_month il 
ON TO_CHAR(month, 'Month') = il.il_month
LEFT JOIN group_lessons_per_month gl 
ON TO_CHAR(month, 'Month') = gl.gl_month
LEFT JOIN ensembles_per_month e 
ON TO_CHAR(MONTH, 'Month') = e.e_month;

-- Query 2
-------------- VIEWS ----------------------
CREATE VIEW dbview_schema.siblings_per_student AS 
SELECT UNNEST(ARRAY[first_student_id, second_student_id]) id, count(*) AS nof_siblings
FROM sibling_relationship sr
GROUP BY id;

-------------- QUERY ----------------------
CREATE VIEW dbview_schema.query2 AS
SELECT COALESCE(sps.nof_siblings, 0) nof_siblings, count(*) AS nof_students
FROM student s
FULL JOIN siblings_per_student sps
ON s.student_id = sps.id
GROUP BY nof_siblings
ORDER BY COALESCE(sps.nof_siblings, 0);

-- Query 3
-------------- VIEWS ----------------------
CREATE VIEW dbview_schema.instructor_il_count AS
SELECT instructor_id , count(*) AS instructor_il_count
FROM individual_lesson il
WHERE date >= date_trunc('month', current_date)
AND date <= current_date
AND student_id IS NOT NULL
GROUP BY instructor_id ;

CREATE VIEW dbview_schema.nof_students_in_group_lessons AS
SELECT group_lesson_id, count(*) AS nof_students
FROM student_group_lesson sgl 
GROUP BY sgl.group_lesson_id;

CREATE VIEW dbview_schema.instructor_gl_count AS
SELECT instructor_id , count(*) AS instructor_gl_count
FROM group_lesson gl 
LEFT JOIN dbview_schema.nof_students_in_group_lessons nsigl
ON gl.group_lesson_id = nsigl.group_lesson_id
WHERE date >= date_trunc('month', current_date)
AND date <= current_date
AND nsigl.nof_students >= gl.min_no_of_students 
GROUP BY instructor_id;

CREATE VIEW dbview_schema.nof_students_in_ensembles AS
SELECT ensemble_id, count(*) AS nof_students
FROM student_ensemble se
GROUP BY se.ensemble_id;

CREATE VIEW dbview_schema.instructor_e_count AS
SELECT instructor_id , count(*) AS instructor_e_count
FROM ensemble e
LEFT JOIN dbview_schema.nof_students_in_ensembles nsie
ON e.ensemble_id = nsie.ensemble_id
WHERE date >= date_trunc('month', current_date)
AND date <= current_date
AND nsie.nof_students >= e.min_no_of_students 
GROUP BY instructor_id;

-------------- QUERY ----------------------
CREATE VIEW dbview_schema.query3 AS
SELECT i.name, 
(COALESCE(instructor_il_count, 0) + COALESCE(instructor_gl_count, 0) + COALESCE(instructor_e_count, 0)) AS instructor_total_lessons_count
FROM instructor i
LEFT JOIN dbview_schema.instructor_il_count ilc
ON i.instructor_id = ilc.instructor_id
LEFT JOIN dbview_schema.instructor_gl_count glc 
ON i.instructor_id = glc.instructor_id
LEFT JOIN dbview_schema.instructor_e_count ec 
ON i.instructor_id = ec.instructor_id
WHERE (COALESCE(instructor_il_count, 0) + COALESCE(instructor_gl_count, 0) + COALESCE(instructor_e_count, 0)) > 0 -- the LAST number can be chosen arbitrarily
ORDER BY instructor_total_lessons_count DESC;

-- Query 4
-------------- VIEWS ----------------------
CREATE VIEW dbview_schema.students_in_ensembles AS
SELECT e.ensemble_id, time, to_char(date, 'Day') AS dow, date, genre, max_no_of_students, count(student_id) AS nof_students
FROM ensemble e
FULL JOIN student_ensemble se 
ON e.ensemble_id = se.ensemble_id
WHERE date >= date_trunc('week', now()) + INTERVAL '7days'
AND date < date_trunc('week', now()) + INTERVAL '14days'
GROUP BY e.ensemble_id;

-------------- QUERY ----------------------
CREATE VIEW dbview_schema.query4 AS 
SELECT x.ensemble_id, x.time, x.dow, x.genre,(
CASE WHEN x.nof_students >= x.max_no_of_students THEN '0'
WHEN x.max_no_of_students - x.nof_students <= 2 THEN '1 or 2'
ELSE 'more than 2'
END) AS nof_place_left
FROM dbview_schema.students_in_ensembles x
ORDER BY date, genre;

-------- COMMANDS TO TEST ALL THE QUERIES -------- 
VACUUM ANALYZE;

EXPLAIN SELECT * FROM dbview_schema.query1;
EXPLAIN SELECT * FROM dbview_schema.query2;
EXPLAIN SELECT * FROM dbview_schema.query3;
EXPLAIN SELECT * FROM dbview_schema.query4;



