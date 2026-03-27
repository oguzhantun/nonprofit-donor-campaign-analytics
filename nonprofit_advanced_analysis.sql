-- ============================================================
-- Advanced Nonprofit Donor & Campaign Analytics
-- Author: Oguz Tuncel
-- Description: Comprehensive SQL analysis covering donor
--              behaviour, campaign ROI, RFM segmentation,
--              retention, churn, and communication analytics
-- ============================================================

-- ============================================================
-- 1. DATABASE SETUP
-- ============================================================

CREATE TABLE IF NOT EXISTS donors (
    donor_id                VARCHAR(10) PRIMARY KEY,
    donor_name              VARCHAR(100),
    donor_type              VARCHAR(20),
    city                    VARCHAR(50),
    state                   VARCHAR(10),
    email                   VARCHAR(100),
    phone                   VARCHAR(20),
    acquisition_date        DATE,
    acquisition_channel     VARCHAR(30),
    age_group               VARCHAR(10),
    gender                  VARCHAR(20),
    occupation              VARCHAR(30),
    wealth_score            DECIMAL(5,1),
    engagement_score        DECIMAL(5,1),
    is_major_donor          SMALLINT,
    is_recurring            SMALLINT,
    communication_preference VARCHAR(10),
    opted_out               SMALLINT
);

CREATE TABLE IF NOT EXISTS campaigns (
    campaign_id             VARCHAR(10) PRIMARY KEY,
    campaign_name           VARCHAR(100),
    campaign_type           VARCHAR(30),
    cause                   VARCHAR(50),
    start_date              DATE,
    end_date                DATE,
    budget                  DECIMAL(12,2),
    revenue_target          DECIMAL(12,2),
    actual_revenue          DECIMAL(12,2),
    total_donations         INT,
    unique_donors           INT,
    avg_donation            DECIMAL(10,2),
    roi                     DECIMAL(8,1),
    target_achieved         DECIMAL(8,1),
    cost_per_donor          DECIMAL(10,2),
    channel                 VARCHAR(30),
    target_segment          VARCHAR(30),
    status                  VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS donations (
    donation_id             VARCHAR(12) PRIMARY KEY,
    donor_id                VARCHAR(10) REFERENCES donors(donor_id),
    campaign_id             VARCHAR(10) REFERENCES campaigns(campaign_id),
    donation_date           DATE,
    amount                  DECIMAL(12,2),
    payment_method          VARCHAR(20),
    is_recurring            SMALLINT,
    status                  VARCHAR(20),
    channel                 VARCHAR(30),
    fiscal_year             VARCHAR(10),
    quarter                 VARCHAR(5),
    month                   VARCHAR(15),
    year                    INT
);

CREATE TABLE IF NOT EXISTS communications (
    comm_id                 VARCHAR(12) PRIMARY KEY,
    donor_id                VARCHAR(10) REFERENCES donors(donor_id),
    campaign_id             VARCHAR(10) REFERENCES campaigns(campaign_id),
    comm_date               DATE,
    comm_type               VARCHAR(20),
    outcome                 VARCHAR(20),
    resulted_in_donation    SMALLINT,
    cost                    DECIMAL(8,2)
);

CREATE TABLE IF NOT EXISTS rfm_segments (
    donor_id                VARCHAR(10) REFERENCES donors(donor_id),
    recency                 INT,
    frequency               INT,
    monetary                DECIMAL(12,2),
    r_score                 INT,
    f_score                 INT,
    m_score                 INT,
    rfm_score               INT,
    segment                 VARCHAR(30),
    ltv_score               DECIMAL(5,1)
);

-- ============================================================
-- 2. EXECUTIVE KPI OVERVIEW
-- ============================================================

SELECT
    COUNT(DISTINCT d.donor_id)                          AS total_donors,
    COUNT(DISTINCT CASE WHEN d.is_major_donor=1
          THEN d.donor_id END)                          AS major_donors,
    COUNT(dn.donation_id)                               AS total_donations,
    ROUND(SUM(dn.amount), 2)                            AS total_raised,
    ROUND(AVG(dn.amount), 2)                            AS avg_donation,
    ROUND(SUM(dn.amount)/COUNT(DISTINCT d.donor_id), 2) AS revenue_per_donor,
    ROUND(SUM(CASE WHEN dn.is_recurring=1
          THEN dn.amount ELSE 0 END)*100.0/
          SUM(dn.amount), 1)                            AS recurring_revenue_pct,
    COUNT(DISTINCT c.campaign_id)                       AS total_campaigns
FROM donors d
LEFT JOIN donations dn ON d.donor_id = dn.donor_id
    AND dn.status = 'Completed'
LEFT JOIN campaigns c  ON dn.campaign_id = c.campaign_id;

-- ============================================================
-- 3. DONOR LIFETIME VALUE ANALYSIS
-- ============================================================

-- LTV by donor type
SELECT
    d.donor_type,
    COUNT(DISTINCT d.donor_id)                          AS donor_count,
    ROUND(SUM(dn.amount), 2)                            AS total_raised,
    ROUND(AVG(dn.amount), 2)                            AS avg_donation,
    ROUND(SUM(dn.amount)/COUNT(DISTINCT d.donor_id), 2) AS avg_ltv,
    ROUND(AVG(d.wealth_score), 1)                       AS avg_wealth_score,
    ROUND(AVG(d.engagement_score), 1)                   AS avg_engagement_score
FROM donors d
JOIN donations dn ON d.donor_id = dn.donor_id
    AND dn.status = 'Completed'
GROUP BY d.donor_type
ORDER BY avg_ltv DESC;

-- Top 20 donors by lifetime value
SELECT
    d.donor_id,
    d.donor_name,
    d.donor_type,
    d.city,
    d.acquisition_channel,
    COUNT(dn.donation_id)           AS total_donations,
    ROUND(SUM(dn.amount), 2)        AS lifetime_value,
    ROUND(AVG(dn.amount), 2)        AS avg_donation,
    MIN(dn.donation_date)           AS first_donation,
    MAX(dn.donation_date)           AS last_donation,
    DATEDIFF(MAX(dn.donation_date),
             MIN(dn.donation_date)) AS donor_lifespan_days
FROM donors d
JOIN donations dn ON d.donor_id = dn.donor_id
    AND dn.status = 'Completed'
GROUP BY d.donor_id, d.donor_name, d.donor_type,
         d.city, d.acquisition_channel
ORDER BY lifetime_value DESC
LIMIT 20;

-- ============================================================
-- 4. RFM SEGMENTATION ANALYSIS
-- ============================================================

-- Segment summary
SELECT
    segment,
    COUNT(donor_id)                                     AS donor_count,
    ROUND(COUNT(donor_id)*100.0/SUM(COUNT(donor_id))
          OVER(), 1)                                    AS pct_of_donors,
    ROUND(AVG(monetary), 2)                             AS avg_monetary,
    ROUND(AVG(recency), 0)                              AS avg_recency_days,
    ROUND(AVG(frequency), 1)                            AS avg_frequency,
    ROUND(AVG(rfm_score), 1)                            AS avg_rfm_score,
    ROUND(AVG(ltv_score), 1)                            AS avg_ltv_score
FROM rfm_segments
GROUP BY segment
ORDER BY avg_rfm_score DESC;

-- Champions vs Lapsed comparison
SELECT
    r.segment,
    d.donor_type,
    COUNT(DISTINCT d.donor_id)                          AS donor_count,
    ROUND(AVG(r.monetary), 2)                           AS avg_monetary,
    ROUND(AVG(d.engagement_score), 1)                   AS avg_engagement,
    ROUND(AVG(d.wealth_score), 1)                       AS avg_wealth
FROM rfm_segments r
JOIN donors d ON r.donor_id = d.donor_id
WHERE r.segment IN ('Champion', 'Lapsed', 'At Risk')
GROUP BY r.segment, d.donor_type
ORDER BY r.segment, donor_count DESC;

-- ============================================================
-- 5. CAMPAIGN ROI ANALYSIS
-- ============================================================

-- Campaign performance ranked by ROI
SELECT
    campaign_id,
    campaign_name,
    campaign_type,
    cause,
    budget,
    revenue_target,
    actual_revenue,
    roi,
    target_achieved,
    unique_donors,
    avg_donation,
    cost_per_donor,
    CASE
        WHEN roi > 500  THEN 'Exceptional'
        WHEN roi > 200  THEN 'Strong'
        WHEN roi > 100  THEN 'Good'
        WHEN roi > 0    THEN 'Break Even'
        ELSE 'Loss'
    END                                                 AS performance_rating
FROM campaigns
WHERE status = 'Completed'
ORDER BY roi DESC;

-- Campaign type performance summary
SELECT
    campaign_type,
    COUNT(campaign_id)                                  AS num_campaigns,
    ROUND(AVG(budget), 2)                               AS avg_budget,
    ROUND(SUM(actual_revenue), 2)                       AS total_revenue,
    ROUND(AVG(roi), 1)                                  AS avg_roi,
    ROUND(AVG(target_achieved), 1)                      AS avg_target_achieved_pct,
    ROUND(AVG(cost_per_donor), 2)                       AS avg_cost_per_donor
FROM campaigns
GROUP BY campaign_type
ORDER BY avg_roi DESC;

-- Cause performance
SELECT
    cause,
    COUNT(campaign_id)                                  AS num_campaigns,
    ROUND(SUM(actual_revenue), 2)                       AS total_revenue,
    ROUND(AVG(roi), 1)                                  AS avg_roi,
    ROUND(SUM(actual_revenue)/SUM(budget)*100, 1)       AS revenue_to_cost_ratio
FROM campaigns
GROUP BY cause
ORDER BY total_revenue DESC;

-- ============================================================
-- 6. DONOR RETENTION & CHURN ANALYSIS
-- ============================================================

-- Year over year donor retention
WITH donor_years AS (
    SELECT
        donor_id,
        year,
        LAG(year) OVER (PARTITION BY donor_id ORDER BY year) AS prev_year
    FROM (
        SELECT DISTINCT donor_id, year
        FROM donations
        WHERE status = 'Completed'
    ) t
)
SELECT
    year,
    COUNT(CASE WHEN prev_year IS NULL     THEN 1 END) AS new_donors,
    COUNT(CASE WHEN year-prev_year = 1    THEN 1 END) AS retained_donors,
    COUNT(CASE WHEN year-prev_year > 1    THEN 1 END) AS reactivated_donors,
    ROUND(COUNT(CASE WHEN year-prev_year=1 THEN 1 END)*100.0/
          NULLIF(COUNT(*),0), 1)                       AS retention_rate_pct
FROM donor_years
GROUP BY year
ORDER BY year;

-- Churn risk analysis
SELECT
    r.segment,
    COUNT(r.donor_id)                                   AS donor_count,
    ROUND(AVG(r.recency), 0)                            AS avg_days_since_donation,
    ROUND(AVG(r.monetary), 2)                           AS avg_lifetime_value,
    ROUND(SUM(r.monetary), 2)                           AS total_at_risk_revenue,
    ROUND(AVG(d.engagement_score), 1)                   AS avg_engagement_score
FROM rfm_segments r
JOIN donors d ON r.donor_id = d.donor_id
WHERE r.segment IN ('At Risk', 'Lapsed', 'Cannot Lose')
GROUP BY r.segment
ORDER BY total_at_risk_revenue DESC;

-- ============================================================
-- 7. ACQUISITION CHANNEL ANALYSIS
-- ============================================================

SELECT
    d.acquisition_channel,
    COUNT(DISTINCT d.donor_id)                          AS total_donors,
    COUNT(DISTINCT CASE WHEN d.is_major_donor=1
          THEN d.donor_id END)                          AS major_donors,
    ROUND(SUM(dn.amount), 2)                            AS total_raised,
    ROUND(AVG(dn.amount), 2)                            AS avg_donation,
    ROUND(SUM(dn.amount)/COUNT(DISTINCT d.donor_id), 2) AS revenue_per_donor,
    ROUND(AVG(d.engagement_score), 1)                   AS avg_engagement,
    ROUND(AVG(d.wealth_score), 1)                       AS avg_wealth_score
FROM donors d
JOIN donations dn ON d.donor_id = dn.donor_id
    AND dn.status = 'Completed'
GROUP BY d.acquisition_channel
ORDER BY total_raised DESC;

-- ============================================================
-- 8. COMMUNICATION EFFECTIVENESS
-- ============================================================

-- Response rate by communication type
SELECT
    comm_type,
    COUNT(comm_id)                                      AS total_sent,
    SUM(resulted_in_donation)                           AS resulted_in_donation,
    ROUND(SUM(resulted_in_donation)*100.0/
          COUNT(comm_id), 1)                            AS conversion_rate_pct,
    ROUND(SUM(cost), 2)                                 AS total_cost,
    ROUND(SUM(cost)/NULLIF(SUM(resulted_in_donation),0),2) AS cost_per_conversion
FROM communications
GROUP BY comm_type
ORDER BY conversion_rate_pct DESC;

-- Communication outcome distribution
SELECT
    outcome,
    COUNT(comm_id)                                      AS count,
    ROUND(COUNT(comm_id)*100.0/SUM(COUNT(comm_id))
          OVER(), 1)                                    AS pct_of_total,
    ROUND(AVG(cost), 2)                                 AS avg_cost
FROM communications
GROUP BY outcome
ORDER BY count DESC;

-- ============================================================
-- 9. GEOGRAPHIC ANALYSIS
-- ============================================================

SELECT
    d.state,
    COUNT(DISTINCT d.donor_id)                          AS total_donors,
    COUNT(dn.donation_id)                               AS total_donations,
    ROUND(SUM(dn.amount), 2)                            AS total_raised,
    ROUND(AVG(dn.amount), 2)                            AS avg_donation,
    ROUND(SUM(dn.amount)/COUNT(DISTINCT d.donor_id), 2) AS revenue_per_donor,
    COUNT(DISTINCT CASE WHEN d.is_major_donor=1
          THEN d.donor_id END)                          AS major_donors
FROM donors d
JOIN donations dn ON d.donor_id = dn.donor_id
    AND dn.status = 'Completed'
GROUP BY d.state
ORDER BY total_raised DESC;

-- ============================================================
-- 10. PAYMENT METHOD ANALYSIS
-- ============================================================

SELECT
    payment_method,
    COUNT(donation_id)                                  AS total_donations,
    ROUND(SUM(amount), 2)                               AS total_raised,
    ROUND(AVG(amount), 2)                               AS avg_donation,
    SUM(is_recurring)                                   AS recurring_count,
    ROUND(SUM(is_recurring)*100.0/COUNT(donation_id),1) AS recurring_pct
FROM donations
WHERE status = 'Completed'
GROUP BY payment_method
ORDER BY total_raised DESC;

-- ============================================================
-- 11. MONTHLY & SEASONAL TRENDS
-- ============================================================

-- Monthly donation trend with YoY growth
WITH monthly AS (
    SELECT
        year,
        month,
        MIN(donation_date)                              AS month_date,
        COUNT(donation_id)                              AS donations,
        ROUND(SUM(amount), 2)                           AS revenue
    FROM donations
    WHERE status = 'Completed'
    GROUP BY year, month
)
SELECT
    year,
    month,
    donations,
    revenue,
    LAG(revenue) OVER (PARTITION BY month ORDER BY year) AS prev_year_revenue,
    ROUND((revenue - LAG(revenue) OVER
          (PARTITION BY month ORDER BY year))*100.0/
          NULLIF(LAG(revenue) OVER
          (PARTITION BY month ORDER BY year), 0), 1)   AS yoy_growth_pct
FROM monthly
ORDER BY year, month_date;

-- ============================================================
-- 12. MAJOR DONOR ANALYSIS
-- ============================================================

SELECT
    d.donor_id,
    d.donor_name,
    d.donor_type,
    d.city,
    d.wealth_score,
    d.engagement_score,
    r.segment,
    r.rfm_score,
    COUNT(dn.donation_id)                               AS total_donations,
    ROUND(SUM(dn.amount), 2)                            AS lifetime_value,
    MAX(dn.donation_date)                               AS last_donation_date,
    r.recency                                           AS days_since_last_donation
FROM donors d
JOIN rfm_segments r  ON d.donor_id = r.donor_id
JOIN donations dn    ON d.donor_id = dn.donor_id
    AND dn.status = 'Completed'
WHERE d.is_major_donor = 1
GROUP BY d.donor_id, d.donor_name, d.donor_type,
         d.city, d.wealth_score, d.engagement_score,
         r.segment, r.rfm_score, r.recency
ORDER BY lifetime_value DESC;

-- ============================================================
-- 13. DATA QUALITY CHECKS
-- ============================================================

-- Duplicate donations
SELECT donor_id, donation_date, amount, COUNT(*) AS duplicates
FROM donations
GROUP BY donor_id, donation_date, amount
HAVING COUNT(*) > 1;

-- Failed and refunded donations
SELECT status, COUNT(*) AS count, ROUND(SUM(amount),2) AS total_amount
FROM donations
GROUP BY status;

-- Donors with no donations
SELECT d.donor_id, d.donor_name, d.donor_type, d.acquisition_date
FROM donors d
LEFT JOIN donations dn ON d.donor_id = dn.donor_id
WHERE dn.donation_id IS NULL;

-- Campaigns with no donations
SELECT c.campaign_id, c.campaign_name, c.campaign_type, c.budget
FROM campaigns c
WHERE c.total_donations = 0;
