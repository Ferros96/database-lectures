-- =====================================================================
--  Introduction to Database Systems (62153)
--  Lecture 4, Part 3: Update Operations and Constraint Violations
--  Live SQL demo, in the same order as the slides.
--  Instructor: Mohamed Al-Kumati
--
--  Engine: Microsoft SQL Server 2022 (T-SQL), run from SSMS or Azure Data Studio.
--  (A PostgreSQL version of the same demo is in this folder: "... - SQL Demo (PostgreSQL).sql".)
--
--  HOW TO RUN
--    Whole file: open it in SSMS and press F5. Errors are listed in the
--    Messages tab and the script carries on with the next batch.
--    Step by step while teaching (recommended): run STEP 1 and PART 0 once,
--    then highlight one example block at a time and press F5.
--    Tip: the Messages tab shows the error text; the Results tab shows the
--    SELECTs that come after accepted operations.
--
--  RESET: run STEP 1 and PART 0 again at any time. They rebuild the
--  database in the Figure 5.6 state, so you can repeat the demo as often
--  as you like.
--
--  IMPORTANT: every example is applied to the original Figure 5.6 state,
--  as in the lecture. Operations that are ACCEPTED are wrapped in
--      BEGIN TRAN; ... ROLLBACK;
--  so you can show the change and then undo it. Operations that are
--  REJECTED change nothing, so they need no wrapper.
--
--  How each constraint shows up in SQL Server's error message:
--    Domain constraint ..... "conflicted with the CHECK constraint" or
--                            "Error converting data type ..."
--    Key constraint ........ "Violation of PRIMARY KEY constraint ...
--                             Cannot insert duplicate key"
--    Entity integrity ...... "Cannot insert the value NULL into column ..."
--    Referential integrity . "conflicted with the FOREIGN KEY constraint" (insert/update)
--                            "conflicted with the REFERENCE constraint"   (delete/update
--                                                                          of a referenced key)
-- =====================================================================


-- =====================================================================
-- STEP 1. Create the database
-- =====================================================================
USE master;
GO
IF DB_ID('company') IS NOT NULL
BEGIN
    ALTER DATABASE company SET SINGLE_USER WITH ROLLBACK IMMEDIATE;  -- close other connections
    DROP DATABASE company;
END;
GO
CREATE DATABASE company;
GO
USE company;
GO


-- =====================================================================
-- PART 0. Build the COMPANY tables (Figure 5.6 state). Run first.
-- =====================================================================

-- Drop old tables (only matters if you re-run PART 0 without STEP 1).
-- SQL Server has no DROP ... CASCADE, so the foreign keys between
-- EMPLOYEE and DEPARTMENT are removed first.
DROP TABLE IF EXISTS shipment, order_item, orders, item, warehouse, customer;
DROP TABLE IF EXISTS dependent, works_on, project, dept_locations;
IF OBJECT_ID('employee')   IS NOT NULL ALTER TABLE employee   DROP CONSTRAINT IF EXISTS emp_dept_fk, emp_super_fk;
IF OBJECT_ID('department') IS NOT NULL ALTER TABLE department DROP CONSTRAINT IF EXISTS dept_mgr_fk;
DROP TABLE IF EXISTS employee, department;
GO

-- Primary key = entity integrity (NOT NULL) + key constraint (UNIQUE).
-- CHECK constraints and data types = domain constraints.
-- Foreign keys are added after the data is loaded (EMPLOYEE and DEPARTMENT
-- refer to each other, so one of them has to go in first).

CREATE TABLE employee (
    fname      VARCHAR(15)   NOT NULL,
    minit      CHAR(1),
    lname      VARCHAR(15)   NOT NULL,
    ssn        CHAR(9)       NOT NULL,
    bdate      DATE,
    address    VARCHAR(40),
    sex        CHAR(1)       CONSTRAINT emp_sex_domain    CHECK (sex IN ('M', 'F')),
    salary     DECIMAL(10,2) CONSTRAINT emp_salary_domain CHECK (salary > 0),
    super_ssn  CHAR(9),
    dno        INT           NOT NULL,
    CONSTRAINT emp_pk PRIMARY KEY (ssn)
);

CREATE TABLE department (
    dname          VARCHAR(15) NOT NULL,
    dnumber        INT         NOT NULL CONSTRAINT dept_dnumber_domain CHECK (dnumber BETWEEN 1 AND 20),
    mgr_ssn        CHAR(9)     NOT NULL,
    mgr_start_date DATE,
    CONSTRAINT dept_pk         PRIMARY KEY (dnumber),
    CONSTRAINT dept_dname_uniq UNIQUE (dname)
);

CREATE TABLE dept_locations (
    dnumber   INT         NOT NULL,
    dlocation VARCHAR(15) NOT NULL,
    CONSTRAINT dloc_pk PRIMARY KEY (dnumber, dlocation)
);

CREATE TABLE project (
    pname     VARCHAR(15) NOT NULL,
    pnumber   INT         NOT NULL,
    plocation VARCHAR(15),
    dnum      INT         NOT NULL,
    CONSTRAINT proj_pk         PRIMARY KEY (pnumber),
    CONSTRAINT proj_pname_uniq UNIQUE (pname)
);

CREATE TABLE works_on (
    essn  CHAR(9)      NOT NULL,
    pno   INT          NOT NULL,
    hours DECIMAL(3,1) CONSTRAINT works_hours_domain CHECK (hours >= 0),
    CONSTRAINT works_on_pk PRIMARY KEY (essn, pno)
);

CREATE TABLE dependent (
    essn           CHAR(9)     NOT NULL,
    dependent_name VARCHAR(15) NOT NULL,
    sex            CHAR(1)     CONSTRAINT dep_sex_domain CHECK (sex IN ('M', 'F')),
    bdate          DATE,
    relationship   VARCHAR(8),
    CONSTRAINT dependent_pk PRIMARY KEY (essn, dependent_name)
);
GO

-- ---------- Figure 5.6 data ----------

INSERT INTO employee VALUES
 ('John',     'B', 'Smith',   '123456789', '1965-01-09', '731 Fondren, Houston, TX',  'M', 30000, '333445555', 5),
 ('Franklin', 'T', 'Wong',    '333445555', '1955-12-08', '638 Voss, Houston, TX',     'M', 40000, '888665555', 5),
 ('Alicia',   'J', 'Zelaya',  '999887777', '1968-01-19', '3321 Castle, Spring, TX',   'F', 25000, '987654321', 4),
 ('Jennifer', 'S', 'Wallace', '987654321', '1941-06-20', '291 Berry, Bellaire, TX',   'F', 43000, '888665555', 4),
 ('Ramesh',   'K', 'Narayan', '666884444', '1962-09-15', '975 Fire Oak, Humble, TX',  'M', 38000, '333445555', 5),
 ('Joyce',    'A', 'English', '453453453', '1972-07-31', '5631 Rice, Houston, TX',    'F', 25000, '333445555', 5),
 ('Ahmad',    'V', 'Jabbar',  '987987987', '1969-03-29', '980 Dallas, Houston, TX',   'M', 25000, '987654321', 4),
 ('James',    'E', 'Borg',    '888665555', '1937-11-10', '450 Stone, Houston, TX',    'M', 55000, NULL,        1);

INSERT INTO department VALUES
 ('Research',       5, '333445555', '1988-05-22'),
 ('Administration', 4, '987654321', '1995-01-01'),
 ('Headquarters',   1, '888665555', '1981-06-19');

INSERT INTO dept_locations VALUES
 (1, 'Houston'), (4, 'Stafford'), (5, 'Bellaire'), (5, 'Sugarland'), (5, 'Houston');

INSERT INTO project VALUES
 ('ProductX',        1,  'Bellaire',  5),
 ('ProductY',        2,  'Sugarland', 5),
 ('ProductZ',        3,  'Houston',   5),
 ('Computerization', 10, 'Stafford',  4),
 ('Reorganization',  20, 'Houston',   1),
 ('Newbenefits',     30, 'Stafford',  4);

INSERT INTO works_on VALUES
 ('123456789', 1, 32.5), ('123456789', 2, 7.5),
 ('666884444', 3, 40.0),
 ('453453453', 1, 20.0), ('453453453', 2, 20.0),
 ('333445555', 2, 10.0), ('333445555', 3, 10.0), ('333445555', 10, 10.0), ('333445555', 20, 10.0),
 ('999887777', 30, 30.0), ('999887777', 10, 10.0),
 ('987987987', 10, 35.0), ('987987987', 30, 5.0),
 ('987654321', 30, 20.0), ('987654321', 20, 15.0),
 ('888665555', 20, NULL);

INSERT INTO dependent VALUES
 ('333445555', 'Alice',     'F', '1986-04-05', 'Daughter'),
 ('333445555', 'Theodore',  'M', '1983-10-25', 'Son'),
 ('333445555', 'Joy',       'F', '1958-05-03', 'Spouse'),
 ('987654321', 'Abner',     'M', '1942-02-28', 'Spouse'),
 ('123456789', 'Michael',   'M', '1988-01-04', 'Son'),
 ('123456789', 'Alice',     'F', '1988-12-30', 'Daughter'),
 ('123456789', 'Elizabeth', 'F', '1967-05-05', 'Spouse');
GO

-- ---------- Referential integrity: the foreign keys ----------
-- No ON DELETE / ON UPDATE action is given, so the default applies
-- (NO ACTION): REJECT any operation that would leave a reference
-- pointing at nothing.

ALTER TABLE employee       ADD CONSTRAINT emp_super_fk  FOREIGN KEY (super_ssn) REFERENCES employee (ssn);
ALTER TABLE employee       ADD CONSTRAINT emp_dept_fk   FOREIGN KEY (dno)       REFERENCES department (dnumber);
ALTER TABLE department     ADD CONSTRAINT dept_mgr_fk   FOREIGN KEY (mgr_ssn)   REFERENCES employee (ssn);
ALTER TABLE dept_locations ADD CONSTRAINT dloc_dept_fk  FOREIGN KEY (dnumber)   REFERENCES department (dnumber);
ALTER TABLE project        ADD CONSTRAINT proj_dept_fk  FOREIGN KEY (dnum)      REFERENCES department (dnumber);
ALTER TABLE works_on       ADD CONSTRAINT works_emp_fk  FOREIGN KEY (essn)      REFERENCES employee (ssn);
ALTER TABLE works_on       ADD CONSTRAINT works_proj_fk FOREIGN KEY (pno)       REFERENCES project (pnumber);
ALTER TABLE dependent      ADD CONSTRAINT dep_emp_fk    FOREIGN KEY (essn)      REFERENCES employee (ssn);
GO

-- Look at the starting state (the tables on the slides)
SELECT fname, lname, ssn, salary, super_ssn, dno FROM employee ORDER BY dno, ssn;
SELECT * FROM department ORDER BY dnumber;
SELECT * FROM project    ORDER BY pnumber;
SELECT * FROM works_on   ORDER BY essn, pno;
GO


-- =====================================================================
-- SECTION 02. The Insert operation
--   Insert can violate all four constraints.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Slide: Insert example 1
-- Insert <'Cecilia','F','Kolonsky',NULL,'1960-04-05','6357 Windy Lane, Katy, TX',F,28000,NULL,4>
-- EXPECTED: REJECTED, entity integrity (primary key Ssn is NULL)
-- SQL Server says: Cannot insert the value NULL into column 'ssn'
-- ---------------------------------------------------------------------
PRINT '--- Insert example 1 ---';
INSERT INTO employee VALUES
 ('Cecilia', 'F', 'Kolonsky', NULL, '1960-04-05', '6357 Windy Lane, Katy, TX', 'F', 28000, NULL, 4);
GO

-- ---------------------------------------------------------------------
-- Slide: Insert example 2
-- Insert <'Alicia','J','Zelaya','999887777',...,'987654321',4>
-- EXPECTED: REJECTED, key constraint (Ssn 999887777 already exists)
-- SQL Server says: Violation of PRIMARY KEY constraint 'emp_pk'
-- ---------------------------------------------------------------------
PRINT '--- Insert example 2 ---';
INSERT INTO employee VALUES
 ('Alicia', 'J', 'Zelaya', '999887777', '1960-04-05', '6357 Windy Lane, Katy, TX', 'F', 28000, '987654321', 4);
GO

-- ---------------------------------------------------------------------
-- Slide: Insert example 3
-- Insert <'Cecilia','F','Kolonsky','677678989',...,'987654321',7>
-- EXPECTED: REJECTED, referential integrity (no DEPARTMENT with Dnumber = 7)
-- SQL Server says: conflicted with the FOREIGN KEY constraint "emp_dept_fk"
-- ---------------------------------------------------------------------
PRINT '--- Insert example 3 ---';
INSERT INTO employee VALUES
 ('Cecilia', 'F', 'Kolonsky', '677678989', '1960-04-05', '6357 Windswept, Katy, TX', 'F', 28000, '987654321', 7);
GO

-- ---------------------------------------------------------------------
-- Slide: Insert example 4
-- Insert <'Cecilia','F','Kolonsky','677678989',...,NULL,4>
-- EXPECTED: ACCEPTED (Ssn new and not NULL, Dno 4 exists, Super_ssn may be NULL)
-- ---------------------------------------------------------------------
PRINT '--- Insert example 4 ---';
BEGIN TRAN;
INSERT INTO employee VALUES
 ('Cecilia', 'F', 'Kolonsky', '677678989', '1960-04-05', '6357 Windy Lane, Katy, TX', 'F', 28000, NULL, 4);
SELECT fname, lname, ssn, super_ssn, dno FROM employee WHERE ssn = '677678989';
ROLLBACK;   -- undo, back to the Figure 5.6 state
GO

-- ---------------------------------------------------------------------
-- Extra (not on a slide): the fourth kind of insert violation
-- Insert an employee with a negative salary.
-- EXPECTED: REJECTED, domain constraint
-- SQL Server says: conflicted with the CHECK constraint "emp_salary_domain"
-- ---------------------------------------------------------------------
PRINT '--- Extra: domain constraint ---';
INSERT INTO employee VALUES
 ('Omar', 'K', 'Saleh', '111222333', '1990-01-01', 'Houston, TX', 'M', -500, '333445555', 5);
GO

-- Same idea with a value outside the domain of Sex ('M' or 'F').
-- EXPECTED: REJECTED, domain constraint ("emp_sex_domain")
INSERT INTO employee VALUES
 ('Omar', 'K', 'Saleh', '111222333', '1990-01-01', 'Houston, TX', 'X', 30000, '333445555', 5);
GO

-- ---------------------------------------------------------------------
-- Slide: Quick check (insert)
-- Insert <'Sara','M','Hadi','123456789','1990-02-11','Houston, TX',F,30000,'333445555',5>
-- EXPECTED: REJECTED, key constraint (123456789 is John Smith's Ssn)
-- ---------------------------------------------------------------------
PRINT '--- Quick check (insert) ---';
INSERT INTO employee VALUES
 ('Sara', 'M', 'Hadi', '123456789', '1990-02-11', 'Houston, TX', 'F', 30000, '333445555', 5);
GO


-- =====================================================================
-- SECTION 03. The Delete operation
--   Delete can violate only referential integrity.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Slide: Delete example 1
-- Delete the WORKS_ON tuple with Essn = '999887777' and Pno = 10
-- EXPECTED: ACCEPTED, deletes exactly one tuple (nothing references WORKS_ON)
-- ---------------------------------------------------------------------
PRINT '--- Delete example 1 ---';
BEGIN TRAN;
DELETE FROM works_on WHERE essn = '999887777' AND pno = 10;   -- "(1 row affected)"
SELECT * FROM works_on WHERE essn = '999887777';
ROLLBACK;
GO

-- ---------------------------------------------------------------------
-- Slide: Delete example 2
-- Delete the EMPLOYEE tuple with Ssn = '999887777'
-- EXPECTED: REJECTED, referential integrity (WORKS_ON tuples refer to her)
-- SQL Server says: conflicted with the REFERENCE constraint "works_emp_fk"
-- ---------------------------------------------------------------------
PRINT '--- Delete example 2 ---';
SELECT * FROM works_on WHERE essn = '999887777';   -- who points at Alicia?
DELETE FROM employee WHERE ssn = '999887777';
GO

-- ---------------------------------------------------------------------
-- Slide: Delete example 3
-- Delete the EMPLOYEE tuple with Ssn = '333445555'
-- EXPECTED: REJECTED, referential integrity, "even worse": referenced from
--           EMPLOYEE, DEPARTMENT, WORKS_ON and DEPENDENT.
-- SQL Server stops at the FIRST broken reference it finds, so the query
-- after it lists all of them.
-- ---------------------------------------------------------------------
PRINT '--- Delete example 3 ---';
DELETE FROM employee WHERE ssn = '333445555';

SELECT 'EMPLOYEE.Super_ssn' AS referenced_by,
       STRING_AGG(CONCAT(fname, ' ', lname), ', ') AS tuples
  FROM employee WHERE super_ssn = '333445555'
UNION ALL
SELECT 'DEPARTMENT.Mgr_ssn', STRING_AGG(dname, ', ')
  FROM department WHERE mgr_ssn = '333445555'
UNION ALL
SELECT 'WORKS_ON.Essn', CONCAT(COUNT(*), ' tuples (projects ',
       STRING_AGG(CAST(pno AS VARCHAR(5)), ', ') WITHIN GROUP (ORDER BY pno), ')')
  FROM works_on WHERE essn = '333445555'
UNION ALL
SELECT 'DEPENDENT.Essn', STRING_AGG(dependent_name, ', ')
  FROM dependent WHERE essn = '333445555';
GO

-- ---------------------------------------------------------------------
-- Slide: Quick check (delete)
-- Delete the DEPARTMENT tuple with Dnumber = 4 (Administration)
-- EXPECTED: REJECTED, referential integrity (employees, projects and
--           locations refer to department 4)
-- ---------------------------------------------------------------------
PRINT '--- Quick check (delete) ---';
DELETE FROM department WHERE dnumber = 4;
GO


-- =====================================================================
-- SECTION 04. The Update operation
--   What it can violate depends on which attribute changes.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Slide: Update example 1
-- Update the Salary of the EMPLOYEE tuple with Ssn = '999887777' to 28000
-- EXPECTED: ACCEPTED (Salary is neither a key nor a foreign key)
-- ---------------------------------------------------------------------
PRINT '--- Update example 1 ---';
BEGIN TRAN;
UPDATE employee SET salary = 28000 WHERE ssn = '999887777';
SELECT fname, lname, ssn, salary FROM employee WHERE ssn = '999887777';
ROLLBACK;
GO

-- ---------------------------------------------------------------------
-- Slide: Update example 2
-- Update the Dno of the EMPLOYEE tuple with Ssn = '999887777' to 1
-- EXPECTED: ACCEPTED (Dnumber 1, Headquarters, exists)
-- ---------------------------------------------------------------------
PRINT '--- Update example 2 ---';
BEGIN TRAN;
UPDATE employee SET dno = 1 WHERE ssn = '999887777';
SELECT fname, lname, ssn, dno FROM employee WHERE ssn = '999887777';
ROLLBACK;
GO

-- ---------------------------------------------------------------------
-- Slide: Update example 3
-- Update the Dno of the EMPLOYEE tuple with Ssn = '999887777' to 7
-- EXPECTED: REJECTED, referential integrity (no Dnumber 7)
-- ---------------------------------------------------------------------
PRINT '--- Update example 3 ---';
UPDATE employee SET dno = 7 WHERE ssn = '999887777';
GO

-- ---------------------------------------------------------------------
-- Slide: Update example 4
-- Update the Ssn of the EMPLOYEE tuple with Ssn = '999887777' to '987654321'
-- EXPECTED: REJECTED, key constraint AND referential integrity.
-- SQL Server reports the key violation first
-- ("Violation of PRIMARY KEY constraint 'emp_pk'": 987654321 is Jennifer Wallace).
-- ---------------------------------------------------------------------
PRINT '--- Update example 4 ---';
UPDATE employee SET ssn = '987654321' WHERE ssn = '999887777';
GO

-- The other violation, on its own: change her Ssn to an unused value.
-- The key is now fine, but WORKS_ON still refers to the old value 999887777.
-- EXPECTED: REJECTED, referential integrity (REFERENCE constraint "works_emp_fk")
UPDATE employee SET ssn = '999000111' WHERE ssn = '999887777';
GO

-- ---------------------------------------------------------------------
-- Slide: Quick check (update)
-- Update the Super_ssn of John Smith (Ssn 123456789) to '888665555'
-- EXPECTED: ACCEPTED (888665555, James Borg, exists; Super_ssn is not a key)
-- ---------------------------------------------------------------------
PRINT '--- Quick check (update) ---';
BEGIN TRAN;
UPDATE employee SET super_ssn = '888665555' WHERE ssn = '123456789';
SELECT fname, lname, ssn, super_ssn FROM employee WHERE ssn = '123456789';
ROLLBACK;
GO


-- =====================================================================
-- SECTION 05. Handling a violation
--   Reject (restrict) / Cascade / Set NULL or default / Correct it.
--   Everything below runs inside BEGIN TRAN ... ROLLBACK. In SQL Server
--   ALTER TABLE is undone by ROLLBACK too, so the database returns to the
--   Figure 5.6 state with the default "reject" (NO ACTION) foreign keys.
--
--   SQL Server limits on these actions (other DBMSs differ):
--   * A foreign key that refers to its own table (EMPLOYEE.Super_ssn)
--     cannot have CASCADE / SET NULL / SET DEFAULT.
--   * A table cannot be reached by two different cascade paths
--     ("may cause cycles or multiple cascade paths"). Example 4 below
--     shows both.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) REJECT (restrict): the default. This is what you saw in Delete example 2.
-- EXPECTED: REJECTED, referential integrity
-- ---------------------------------------------------------------------
PRINT '--- Handling 1: reject ---';
DELETE FROM employee WHERE ssn = '999887777';
GO

-- ---------------------------------------------------------------------
-- 2) CASCADE: deleting Alicia also deletes her WORKS_ON tuples.
-- EXPECTED: ACCEPTED, 1 employee and 2 WORKS_ON tuples removed
-- ---------------------------------------------------------------------
PRINT '--- Handling 2: cascade ---';
BEGIN TRAN;
ALTER TABLE works_on DROP CONSTRAINT works_emp_fk;
ALTER TABLE works_on ADD  CONSTRAINT works_emp_fk FOREIGN KEY (essn)
      REFERENCES employee (ssn) ON DELETE CASCADE;

DELETE FROM employee WHERE ssn = '999887777';               -- "(1 row affected)"
SELECT * FROM works_on WHERE essn = '999887777';            -- 0 rows: cascaded
ROLLBACK;
GO

-- ---------------------------------------------------------------------
-- 3) SET NULL is NOT possible on WORKS_ON.Essn: it is part of the primary
--    key, so making it NULL would break entity integrity.
--    SQL Server catches this already when the rule is created.
-- EXPECTED: REJECTED when the constraint is created ("Cannot create the
--           foreign key ... with the SET NULL referential action, because
--           one or more referencing columns are not nullable")
-- ---------------------------------------------------------------------
PRINT '--- Handling 3: set NULL on a key column ---';
BEGIN TRAN;
ALTER TABLE works_on DROP CONSTRAINT works_emp_fk;
ALTER TABLE works_on ADD  CONSTRAINT works_emp_fk FOREIGN KEY (essn)
      REFERENCES employee (ssn) ON DELETE SET NULL;      -- rejected here
ROLLBACK;
GO
IF @@TRANCOUNT > 0 ROLLBACK;   -- safety net: make sure nothing is left open
GO

-- ---------------------------------------------------------------------
-- 4) All options together, on Delete example 3 (Franklin Wong, 333445555).
--    The textbook's COMPANY DDL (Figure 5.7) uses:
--      EMPLOYEE.Super_ssn  -> SET NULL     (his staff lose their supervisor)
--      DEPARTMENT.Mgr_ssn  -> SET DEFAULT  (James Borg, 888665555, takes over)
--      WORKS_ON.Essn       -> CASCADE      (his project rows go)
--      DEPENDENT.Essn      -> CASCADE      (his dependents go)
-- ---------------------------------------------------------------------

-- 4a) SQL Server refuses SET NULL on the self-referencing Super_ssn.
-- EXPECTED: REJECTED when the constraint is created
--           ("may cause cycles or multiple cascade paths")
PRINT '--- Handling 4a: SET NULL on Super_ssn (SQL Server limit) ---';
BEGIN TRAN;
ALTER TABLE employee DROP CONSTRAINT emp_super_fk;
ALTER TABLE employee ADD  CONSTRAINT emp_super_fk FOREIGN KEY (super_ssn)
      REFERENCES employee (ssn) ON DELETE SET NULL;      -- rejected here
ROLLBACK;
GO
IF @@TRANCOUNT > 0 ROLLBACK;   -- safety net: make sure nothing is left open
GO

-- 4b) So for Super_ssn we "correct it" by hand, and let the DBMS do the rest.
-- EXPECTED: ACCEPTED, and the referencing tuples change as listed above.
PRINT '--- Handling 4b: cascade + set default + manual set NULL ---';
BEGIN TRAN;
ALTER TABLE department ADD CONSTRAINT dept_mgr_default DEFAULT '888665555' FOR mgr_ssn;
ALTER TABLE department DROP CONSTRAINT dept_mgr_fk;
ALTER TABLE department ADD  CONSTRAINT dept_mgr_fk FOREIGN KEY (mgr_ssn)
      REFERENCES employee (ssn) ON DELETE SET DEFAULT;
ALTER TABLE works_on   DROP CONSTRAINT works_emp_fk;
ALTER TABLE works_on   ADD  CONSTRAINT works_emp_fk FOREIGN KEY (essn)
      REFERENCES employee (ssn) ON DELETE CASCADE;
ALTER TABLE dependent  DROP CONSTRAINT dep_emp_fk;
ALTER TABLE dependent  ADD  CONSTRAINT dep_emp_fk FOREIGN KEY (essn)
      REFERENCES employee (ssn) ON DELETE CASCADE;

UPDATE employee SET super_ssn = NULL WHERE super_ssn = '333445555';  -- manual "set NULL" (3 rows)
DELETE FROM employee WHERE ssn = '333445555';                        -- "(1 row affected)"

SELECT fname, lname, super_ssn FROM employee
 WHERE ssn IN ('123456789', '666884444', '453453453');               -- Super_ssn now NULL
SELECT dname, dnumber, mgr_ssn FROM department WHERE dnumber = 5;    -- manager now 888665555
SELECT COUNT(*) AS franklin_works_on   FROM works_on  WHERE essn = '333445555';  -- 0
SELECT COUNT(*) AS franklin_dependents FROM dependent WHERE essn = '333445555';  -- 0
ROLLBACK;
GO

-- 4c) Multiple cascade paths: WORKS_ON already cascades from EMPLOYEE.
--     Make it cascade from PROJECT too, and PROJECT cascade from DEPARTMENT,
--     and DEPARTMENT cascade from EMPLOYEE: now WORKS_ON can be reached from
--     EMPLOYEE by two paths, which SQL Server does not allow.
-- EXPECTED: the last ALTER is REJECTED ("may cause cycles or multiple cascade paths")
PRINT '--- Handling 4c: multiple cascade paths (SQL Server limit) ---';
BEGIN TRAN;
ALTER TABLE works_on   DROP CONSTRAINT works_emp_fk;
ALTER TABLE works_on   ADD  CONSTRAINT works_emp_fk FOREIGN KEY (essn)
      REFERENCES employee (ssn) ON DELETE CASCADE;
ALTER TABLE works_on   DROP CONSTRAINT works_proj_fk;
ALTER TABLE works_on   ADD  CONSTRAINT works_proj_fk FOREIGN KEY (pno)
      REFERENCES project (pnumber) ON DELETE CASCADE;
ALTER TABLE project    DROP CONSTRAINT proj_dept_fk;
ALTER TABLE project    ADD  CONSTRAINT proj_dept_fk FOREIGN KEY (dnum)
      REFERENCES department (dnumber) ON DELETE CASCADE;
ALTER TABLE department DROP CONSTRAINT dept_mgr_fk;
ALTER TABLE department ADD  CONSTRAINT dept_mgr_fk FOREIGN KEY (mgr_ssn)
      REFERENCES employee (ssn) ON DELETE CASCADE;          -- rejected here
ROLLBACK;
GO
IF @@TRANCOUNT > 0 ROLLBACK;   -- safety net: make sure nothing is left open
GO

-- ---------------------------------------------------------------------
-- 5) ON UPDATE CASCADE: the fix for the referential half of Update example 4.
--    Change Alicia's Ssn to an unused value; her WORKS_ON rows follow.
-- EXPECTED: ACCEPTED
-- ---------------------------------------------------------------------
PRINT '--- Handling 5: on update cascade ---';
BEGIN TRAN;
ALTER TABLE works_on DROP CONSTRAINT works_emp_fk;
ALTER TABLE works_on ADD  CONSTRAINT works_emp_fk FOREIGN KEY (essn)
      REFERENCES employee (ssn) ON UPDATE CASCADE;

UPDATE employee SET ssn = '999000111' WHERE ssn = '999887777';
SELECT * FROM works_on WHERE essn IN ('999887777', '999000111');   -- now 999000111
ROLLBACK;
GO

-- ---------------------------------------------------------------------
-- 6) CORRECT IT: fix the data first, then redo the operation.
--    Insert example 3 failed because department 7 did not exist.
-- EXPECTED: both statements ACCEPTED
-- ---------------------------------------------------------------------
PRINT '--- Handling 6: correct it ---';
BEGIN TRAN;
INSERT INTO department VALUES ('Marketing', 7, '987654321', CAST(GETDATE() AS DATE));
INSERT INTO employee VALUES
 ('Cecilia', 'F', 'Kolonsky', '677678989', '1960-04-05', '6357 Windswept, Katy, TX', 'F', 28000, '987654321', 7);
SELECT e.fname, e.lname, e.dno, d.dname FROM employee e JOIN department d ON d.dnumber = e.dno
 WHERE e.ssn = '677678989';
ROLLBACK;
GO


-- =====================================================================
-- SECTION 06. Exercise 1 (from the lecture): operations on Figure 5.6
--   Each one is applied directly to the Figure 5.6 state.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Exercise 1.1
-- Insert <'Robert','F','Scott','943775543','1972-06-21','2365 Newcastle Rd, Bellaire, TX',M,58000,'888665555',1>
-- EXPECTED: ACCEPTED (Ssn new, Super_ssn 888665555 exists, Dno 1 exists)
-- ---------------------------------------------------------------------
PRINT '--- Exercise 1.1 ---';
BEGIN TRAN;
INSERT INTO employee VALUES
 ('Robert', 'F', 'Scott', '943775543', '1972-06-21', '2365 Newcastle Rd, Bellaire, TX', 'M', 58000, '888665555', 1);
SELECT fname, lname, ssn, super_ssn, dno FROM employee WHERE ssn = '943775543';
ROLLBACK;
GO

-- ---------------------------------------------------------------------
-- Exercise 1.2
-- Insert <'677678989', NULL, '40.0'> into WORKS_ON
-- EXPECTED: REJECTED, TWO violations:
--   entity integrity (Pno is part of the primary key and is NULL)
--   referential integrity (no employee 677678989)
-- SQL Server reports the NULL first.
-- ---------------------------------------------------------------------
PRINT '--- Exercise 1.2 ---';
INSERT INTO works_on VALUES ('677678989', NULL, 40.0);
GO

-- The second violation, on its own: give a valid Pno (1). Essn still refers to nobody.
-- EXPECTED: REJECTED, referential integrity ("works_emp_fk")
INSERT INTO works_on VALUES ('677678989', 1, 40.0);
GO

-- ---------------------------------------------------------------------
-- Exercise 1.3
-- Delete the WORKS_ON tuples with Essn = '333445555'
-- EXPECTED: ACCEPTED, deletes 4 tuples (nothing references WORKS_ON)
-- ---------------------------------------------------------------------
PRINT '--- Exercise 1.3 ---';
BEGIN TRAN;
DELETE FROM works_on WHERE essn = '333445555';   -- "(4 rows affected)"
ROLLBACK;
GO

-- ---------------------------------------------------------------------
-- Exercise 1.4
-- Delete the PROJECT tuple with Pname = 'ProductX'
-- EXPECTED: REJECTED, referential integrity (WORKS_ON rows for project 1)
-- ---------------------------------------------------------------------
PRINT '--- Exercise 1.4 ---';
SELECT * FROM works_on WHERE pno = 1;
DELETE FROM project WHERE pname = 'ProductX';
GO

-- Enforcing it another way: CASCADE removes the two WORKS_ON rows too.
-- (SET NULL is impossible: Pno is part of WORKS_ON's primary key.)
-- EXPECTED: ACCEPTED
BEGIN TRAN;
ALTER TABLE works_on DROP CONSTRAINT works_proj_fk;
ALTER TABLE works_on ADD  CONSTRAINT works_proj_fk FOREIGN KEY (pno)
      REFERENCES project (pnumber) ON DELETE CASCADE;
DELETE FROM project WHERE pname = 'ProductX';
SELECT COUNT(*) AS rows_left_for_project_1 FROM works_on WHERE pno = 1;   -- 0
ROLLBACK;
GO

-- ---------------------------------------------------------------------
-- Exercise 1.5
-- Modify Super_ssn of the EMPLOYEE tuple with Ssn = '999887777' to '908763451'
-- EXPECTED: REJECTED, referential integrity (no employee 908763451)
-- ---------------------------------------------------------------------
PRINT '--- Exercise 1.5 ---';
UPDATE employee SET super_ssn = '908763451' WHERE ssn = '999887777';
GO

-- Enforcing it another way: Super_ssn is not part of a key, so the user
-- may set it to NULL instead. EXPECTED: ACCEPTED
BEGIN TRAN;
UPDATE employee SET super_ssn = NULL WHERE ssn = '999887777';
ROLLBACK;
GO

-- ---------------------------------------------------------------------
-- Exercise 1.6
-- Modify Hours of the WORKS_ON tuple with Essn = '999887777' and Pno = 10 to '5.0'
-- EXPECTED: ACCEPTED (Hours is neither a key nor a foreign key)
-- ---------------------------------------------------------------------
PRINT '--- Exercise 1.6 ---';
BEGIN TRAN;
UPDATE works_on SET hours = 5.0 WHERE essn = '999887777' AND pno = 10;
SELECT * FROM works_on WHERE essn = '999887777' AND pno = 10;
ROLLBACK;
GO


-- =====================================================================
-- Exercise page, part B: Accepted or rejected? (bonus)
-- =====================================================================

-- B1. INSERT into PROJECT <'ProductW', 40, 'Houston', 5>
-- EXPECTED: ACCEPTED
PRINT '--- B1 ---';
BEGIN TRAN;
INSERT INTO project VALUES ('ProductW', 40, 'Houston', 5);
ROLLBACK;
GO

-- B2. INSERT into PROJECT <'ProductV', 30, 'Houston', 4>
-- EXPECTED: REJECTED, key constraint (Pnumber 30 is Newbenefits)
PRINT '--- B2 ---';
INSERT INTO project VALUES ('ProductV', 30, 'Houston', 4);
GO

-- B3. INSERT into WORKS_ON <'987987987', 40, 10.0>
-- EXPECTED: REJECTED, referential integrity (no project 40)
PRINT '--- B3 ---';
INSERT INTO works_on VALUES ('987987987', 40, 10.0);
GO

-- B4. DELETE the PROJECT tuple with Pnumber = 20
-- EXPECTED: REJECTED, referential integrity (WORKS_ON rows for project 20)
PRINT '--- B4 ---';
DELETE FROM project WHERE pnumber = 20;
GO

-- B5. DELETE the EMPLOYEE tuple with Ssn = '453453453' (Joyce English)
-- EXPECTED: REJECTED, referential integrity (her WORKS_ON rows)
PRINT '--- B5 ---';
DELETE FROM employee WHERE ssn = '453453453';
GO

-- B6. UPDATE the Plocation of ProductY to 'Houston'
-- EXPECTED: ACCEPTED
PRINT '--- B6 ---';
BEGIN TRAN;
UPDATE project SET plocation = 'Houston' WHERE pname = 'ProductY';
ROLLBACK;
GO

-- B7. UPDATE the Hours of WORKS_ON (123456789, 1) to 'many'
-- EXPECTED: REJECTED, domain constraint (not a number)
-- SQL Server says: Error converting data type varchar to numeric.
PRINT '--- B7 ---';
UPDATE works_on SET hours = 'many' WHERE essn = '123456789' AND pno = 1;
GO

-- B8. UPDATE the Pnumber of ProductZ from 3 to NULL
-- EXPECTED: REJECTED, entity integrity (primary key cannot be NULL)
PRINT '--- B8 ---';
UPDATE project SET pnumber = NULL WHERE pname = 'ProductZ';
GO


-- =====================================================================
-- Exercise 2 (from the lecture): the order-processing database
--   One possible answer, written as SQL. Assumptions:
--   * an item appears at most once per order        -> PK (order_no, item_no)
--   * an order ships at most once from a warehouse  -> PK (order_no, warehouse_no)
--   * ORDER is a reserved word in SQL, so the table is called ORDERS,
--     and Cust# is written cust_no (# is not allowed in a plain name).
-- =====================================================================

CREATE TABLE customer (
    cust_no INT          PRIMARY KEY,
    cname   VARCHAR(30)  NOT NULL,
    city    VARCHAR(20)
);

CREATE TABLE orders (
    order_no INT           PRIMARY KEY,
    odate    DATE          NOT NULL,
    cust_no  INT           NOT NULL CONSTRAINT orders_cust_fk REFERENCES customer (cust_no),
    ord_amt  DECIMAL(10,2) NOT NULL DEFAULT 0 CONSTRAINT orders_amt_domain CHECK (ord_amt >= 0)
);

CREATE TABLE item (
    item_no    INT           PRIMARY KEY,
    unit_price DECIMAL(10,2) NOT NULL CONSTRAINT item_price_domain CHECK (unit_price > 0)
);

CREATE TABLE order_item (
    order_no INT NOT NULL CONSTRAINT oi_order_fk REFERENCES orders (order_no),
    item_no  INT NOT NULL CONSTRAINT oi_item_fk  REFERENCES item (item_no),
    qty      INT NOT NULL CONSTRAINT oi_qty_domain CHECK (qty > 0),
    CONSTRAINT order_item_pk PRIMARY KEY (order_no, item_no)
);

CREATE TABLE warehouse (
    warehouse_no INT PRIMARY KEY,
    city         VARCHAR(20)
);

CREATE TABLE shipment (
    order_no     INT  NOT NULL CONSTRAINT ship_order_fk REFERENCES orders (order_no),
    warehouse_no INT  NOT NULL CONSTRAINT ship_wh_fk    REFERENCES warehouse (warehouse_no),
    ship_date    DATE NOT NULL,
    CONSTRAINT shipment_pk PRIMARY KEY (order_no, warehouse_no)
);
GO
-- Other constraints that need more than one table (Ship_date >= Odate,
-- Ord_amt = sum of Qty * Unit_price) cannot be a simple CHECK; a DBMS
-- enforces them with triggers or assertions.

-- A little sample data
INSERT INTO customer   VALUES (1, 'Nour Trading', 'Amman'), (2, 'Blue Sky Ltd', 'Irbid');
INSERT INTO item       VALUES (100, 2.50), (200, 10.00);
INSERT INTO warehouse  VALUES (1, 'Amman'), (2, 'Zarqa');
INSERT INTO orders     VALUES (5001, '2026-10-01', 1, 45.00);
INSERT INTO order_item VALUES (5001, 100, 10), (5001, 200, 2);
INSERT INTO shipment   VALUES (5001, 1, '2026-10-03'), (5001, 2, '2026-10-04');
GO

-- (a) Delete a CUSTOMER who has orders
-- EXPECTED: REJECTED, referential integrity (ORDERS.cust_no refers to customer 1)
PRINT '--- Exercise 2 (a) ---';
DELETE FROM customer WHERE cust_no = 1;
GO

-- (b) Insert an ORDER_ITEM for an Item# that is not in ITEM
-- EXPECTED: REJECTED, referential integrity (no item 999)
PRINT '--- Exercise 2 (b) ---';
INSERT INTO order_item VALUES (5001, 999, 1);
GO

-- (c) Update a WAREHOUSE's City
-- EXPECTED: ACCEPTED (City is neither a key nor a foreign key)
PRINT '--- Exercise 2 (c) ---';
BEGIN TRAN;
UPDATE warehouse SET city = 'Aqaba' WHERE warehouse_no = 2;
ROLLBACK;
GO

-- Extra: a domain check from "other constraints"
-- EXPECTED: REJECTED, domain constraint (Qty must be > 0)
PRINT '--- Exercise 2 extra ---';
UPDATE order_item SET qty = 0 WHERE order_no = 5001 AND item_no = 100;
GO

-- Check: nothing left open, and the database is back in the Figure 5.6 state
SELECT @@TRANCOUNT AS open_transactions,          -- 0
       (SELECT COUNT(*) FROM employee) AS employees,   -- 8
       (SELECT COUNT(*) FROM works_on) AS works_on_rows; -- 16
GO

-- ======================= End of the demo =======================
