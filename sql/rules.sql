-- HR data quality rules. One SELECT per rule, all stacked with UNION ALL.
-- Output columns: EmpID, rule_id, rule, severity, value
-- Severity: 1 critical (wrong numbers in reports), 2 major (breaks joins or grouping), 3 minor (cosmetic)

-- R01 Required fields missing
SELECT EmpID, 'R01' AS rule_id, 'Required field missing (manager ID)' AS rule, '2 major' AS severity,
       CAST(ManagerName AS VARCHAR) AS value
FROM employees WHERE ManagerID IS NULL

UNION ALL
-- R02 Text with leading or trailing spaces (breaks grouping: 'Production' vs 'Production  ')
SELECT EmpID, 'R02', 'Leading or trailing spaces in Department / Position / Sex', '2 major',
       '[' || Department || '] [' || Position || '] [' || Sex || ']'
FROM employees
WHERE Department <> TRIM(Department) OR Position <> TRIM(Position) OR Sex <> TRIM(Sex)

UNION ALL
-- R03 Termination fields inconsistent with employment status
SELECT EmpID, 'R03', 'Status, termination flag and termination date disagree', '1 critical',
       EmploymentStatus || ' / Termd=' || CAST(Termd AS VARCHAR) || ' / ' || COALESCE(CAST(DateofTermination AS VARCHAR), 'no date')
FROM employees
WHERE (EmploymentStatus = 'Active' AND (Termd = 1 OR DateofTermination IS NOT NULL))
   OR (EmploymentStatus <> 'Active' AND (Termd = 0 OR DateofTermination IS NULL))

UNION ALL
-- R04 Termination date before hire date
SELECT EmpID, 'R04', 'Termination date before hire date', '1 critical',
       CAST(DateofHire AS VARCHAR) || ' > ' || CAST(DateofTermination AS VARCHAR)
FROM employees
WHERE DateofTermination IS NOT NULL
  AND strptime(DateofTermination, '%m/%d/%Y') < strptime(DateofHire, '%m/%d/%Y')

UNION ALL
-- R05 Birth date stored with a two-digit year (century is ambiguous)
SELECT EmpID, 'R05', 'Birth date has a two-digit year', '2 major', CAST(DOB AS VARCHAR)
FROM employees WHERE LENGTH(CAST(DOB AS VARCHAR)) = 8

UNION ALL
-- R06 Zip code lost its leading zero (stored as a number)
SELECT EmpID, 'R06', 'Zip code shorter than 5 digits', '3 minor', CAST(Zip AS VARCHAR)
FROM employees WHERE LENGTH(CAST(Zip AS VARCHAR)) < 5

UNION ALL
-- R07 One manager name linked to more than one manager ID
SELECT e.EmpID, 'R07', 'Manager name has more than one manager ID', '2 major',
       e.ManagerName || ' -> ' || CAST(e.ManagerID AS VARCHAR)
FROM employees e
JOIN (SELECT ManagerName FROM employees WHERE ManagerID IS NOT NULL
      GROUP BY ManagerName HAVING COUNT(DISTINCT ManagerID) > 1) m USING (ManagerName)

UNION ALL
-- R08 Salary far from the median of the same position (robust z-score above 3.5)
SELECT EmpID, 'R08', 'Salary outlier within position (robust z > 3.5)', '2 major',
       pos || ': ' || CAST(Salary AS VARCHAR)
FROM (
    SELECT e.EmpID, e.Salary, m.pos, m.med, m.mad
    FROM employees e
    JOIN (
        SELECT pos, med, MEDIAN(ABS(sal - med)) AS mad
        FROM (SELECT TRIM(Position) AS pos, Salary AS sal,
                     quantile_cont(Salary, 0.5) OVER (PARTITION BY TRIM(Position)) AS med
              FROM employees) q
        GROUP BY pos, med
        HAVING COUNT(*) >= 5
    ) m ON TRIM(e.Position) = m.pos
) t
WHERE mad > 0 AND ABS(0.6745 * (Salary - med) / mad) > 3.5

UNION ALL
-- R09 Hired before age 18 (needs a valid four-digit birth year)
SELECT EmpID, 'R09', 'Hired before age 18', '1 critical', CAST(DOB AS VARCHAR) || ' / ' || CAST(DateofHire AS VARCHAR)
FROM employees
WHERE LENGTH(CAST(DOB AS VARCHAR)) = 10
  AND date_diff('year', strptime(DOB, '%m/%d/%Y'), strptime(DateofHire, '%m/%d/%Y')) < 18

UNION ALL
-- R10 Still employed but has a termination reason
SELECT EmpID, 'R10', 'Active employee with a termination reason', '1 critical', TermReason
FROM employees WHERE EmploymentStatus = 'Active' AND TermReason <> 'N/A-StillEmployed'

ORDER BY rule_id, EmpID
