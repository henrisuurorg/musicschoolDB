-- CREATE LAST_BACKUP
INSERT INTO last_backup (date) VALUES (current_date);

-- CREATE VIEW students_with_siblings
CREATE VIEW students_with_siblings AS 
SELECT DISTINCT UNNEST(ARRAY[first_student_id, second_student_id]) AS student_id
FROM sibling_relationship sr;

-- INDIVIDUAL LESSON
-- lesson_historic table
INSERT INTO lesson_historic (lesson_id, time, date, "type", genre, "level", instrument, last_backup_id)
SELECT individual_lesson_id AS lesson_id, time, date, 'individual' AS "type", NULL AS genre, (SELECT "level" FROM "level" AS l WHERE l.level_id = il.level_id) ,(SELECT instrument FROM instrument i WHERE i.instrument_id = il.instrument_id), (SELECT last_backup_id FROM last_backup WHERE date = (SELECT max(date) FROM last_backup))
FROM individual_lesson il 
WHERE date > (SELECT MAX (date)
FROM last_backup
WHERE date NOT IN (SELECT Max (date)
FROM last_backup))
AND date <= current_date
AND student_id IS NOT NULL;

-- student_lesson
INSERT INTO student_lesson(student_id, lesson_id, price)
SELECT student_id, individual_lesson_id,(CASE WHEN EXISTS (SELECT 1
FROM students_with_siblings sws
WHERE sws.student_id = il.student_id) THEN (SELECT(base_price * individual_lesson_quanitifier * (100 - discount_percentage)/ 100) AS price
FROM pricing_schema pr
WHERE pr.pricing_schema_id = il.pricing_schema_id)
ELSE (SELECT(base_price * individual_lesson_quanitifier) AS price
FROM pricing_schema pr
WHERE pr.pricing_schema_id = il.pricing_schema_id)
END 
)
FROM individual_lesson il
WHERE date > (SELECT max(date)
FROM last_backup)
AND date <= current_date
AND student_id IS NOT NULL;

-- GROUP LESSON
-- lesson_historic table

-- all group lessons between now and last update
INSERT INTO lesson_historic (lesson_id, time, date, "type", genre, "level", instrument, last_backup_id)
SELECT group_lesson_id AS lesson_id, time, date, 'group' AS "type", NULL AS genre, (SELECT "level" FROM "level" AS l WHERE l.level_id = gl.level_id) ,(SELECT instrument FROM instrument i WHERE i.instrument_id = gl.instrument_id), (SELECT last_backup_id FROM last_backup WHERE date = (SELECT max(date) FROM last_backup))
FROM group_lesson gl 
WHERE date > (SELECT MAX (date)
FROM last_backup
WHERE date NOT IN (SELECT Max (date)
FROM last_backup))
AND date <= current_date
AND (SELECT count(*)
FROM student_group_lesson sgl
WHERE gl.group_lesson_id = sgl.group_lesson_id) >= gl.min_no_of_students;


-- student_lesson
INSERT INTO student_lesson(student_id, lesson_id, price)
SELECT  student_id, sgl.group_lesson_id AS lesson_id ,(CASE WHEN EXISTS (SELECT 1
FROM students_with_siblings sws
WHERE sws.student_id = sgl.student_id) THEN (SELECT(base_price * group_lesson_quantifier * (100 - discount_percentage)/ 100) AS price
FROM pricing_schema pr
WHERE pr.pricing_schema_id = gl.pricing_schema_id)
ELSE (SELECT(base_price * group_lesson_quantifier) AS price
FROM pricing_schema pr
WHERE pr.pricing_schema_id = gl.pricing_schema_id)
END 
)
FROM student_group_lesson sgl
LEFT JOIN group_lesson gl
ON sgl.group_lesson_id = gl.group_lesson_id
WHERE gl.date > (SELECT MAX (date)
FROM last_backup
WHERE date NOT IN (SELECT Max (date)
FROM last_backup))
AND gl.date <= current_date
AND (SELECT count(*)
FROM student_group_lesson sgl
WHERE gl.group_lesson_id = sgl.group_lesson_id) >= gl.min_no_of_students;


-- ENSEMBLE
-- lesson_historic table
INSERT INTO lesson_historic (lesson_id, time, date, "type", genre, "level", instrument, last_backup_id)
SELECT ensemble_id AS lesson_id, time, date, 'ensemble' AS "type", genre, NULL AS "level" , NULL AS instrument, (SELECT last_backup_id FROM last_backup WHERE date = (SELECT max(date) FROM last_backup))
FROM ensemble e 
WHERE date > (SELECT MAX (date)
FROM last_backup
WHERE date NOT IN (SELECT Max (date)
FROM last_backup))
AND date <= current_date
AND (SELECT count(*)
FROM student_ensemble se 
WHERE e.ensemble_id = se.ensemble_id) >= e.min_no_of_students;

-- student_lesson
INSERT INTO student_lesson(student_id, lesson_id, price)
SELECT student_id, e.ensemble_id AS lesson_id, (CASE WHEN EXISTS (SELECT 1
FROM students_with_siblings sws
WHERE sws.student_id = se.student_id) THEN (SELECT(base_price * ensemble_quantifier * (100 - discount_percentage)/ 100) AS price
FROM pricing_schema pr
WHERE pr.pricing_schema_id = e.pricing_schema_id)
ELSE (SELECT(base_price * ensemble_quantifier) AS price
FROM pricing_schema pr
WHERE pr.pricing_schema_id = e.pricing_schema_id)
END 
)
FROM student_ensemble se
LEFT JOIN ensemble e
ON se.ensemble_id = e.ensemble_id
WHERE e.date > (SELECT MAX (date)
FROM last_backup
WHERE date NOT IN (SELECT Max (date)
FROM last_backup))
AND e.date <= current_date
AND (SELECT count(*)
FROM student_ensemble se
WHERE e.ensemble_id = se.ensemble_id) >= e.min_no_of_students;
