-- Inventory Transactions with Detailed Logic for Quantity and Cost Calculations

SELECT 
    ROWNUM AS transaction_id,
    tx_imkey AS item_number,
    tx_date AS transaction_date,
    tx_type AS transaction_type_code,
    CASE 
        WHEN tx_type = 'I' THEN 'Issue'
        WHEN tx_type = 'R' THEN 'Receipt'
        WHEN tx_type = 'A' THEN 'Adjustment'
        ELSE 'Unknown'
    END AS transaction_type,
    tx_qty AS quantity,
    /* ---- INVENTORY QUANTITY LOGIC ---- */
    CASE 
        /* RECEIPTS */
        WHEN tx_type = 'R' AND tx_dest_status = 'A' THEN tx_qty -- PO receipt (+)
        WHEN tx_type = 'R' AND tx_origin_status = 'A' THEN tx_qty * -1 -- Return to vendor (-)
        /* ISSUES */
        WHEN tx_type = 'I' AND tx_origin_status = 'A' THEN tx_qty * -1 -- Issue to project (-)
        WHEN tx_type = 'I' AND tx_dest_status = 'A' THEN tx_qty -- Return from project (+)
        /* ADJUSTMENTS */
        WHEN tx_type = 'A' AND UPPER(tx_origin) = 'ADJUSTMENT' THEN tx_qty -- Count increase (+)
        WHEN tx_type = 'A' AND UPPER(tx_dest) = 'ADJUSTMENT' THEN tx_qty * -1 -- Count decrease (-)
        WHEN tx_type = 'A' AND (UPPER(tx_origin) LIKE 'RESERVE%' OR UPPER(tx_origin) = 'HOLD') THEN 0 -- Reserve/Hold (no change)
        WHEN tx_type = 'A' AND (UPPER(tx_dest) LIKE 'RESERVE%' OR UPPER(tx_dest) = 'HOLD') THEN 0 -- Reserve/Hold (no change)
        ELSE 0
    END AS inventory_quantity,
    
    /* ---- TRANSACTION DETAIL ---- */
    CASE
        WHEN tx_type = 'R' AND (REGEXP_LIKE(tx_dest, '^[0-9]') OR REGEXP_LIKE(tx_dest, '^[A-Za-z]')) THEN 'Receipt: PO to Inventory'
        WHEN tx_type = 'R' AND (REGEXP_LIKE(tx_origin, '^[0-9]') OR REGEXP_LIKE(tx_origin, '^[A-Za-z]')) THEN 'Receipt: Return to Vendor'
        WHEN tx_type = 'I' AND tx_origin_status = 'A' THEN 'Issue: To Project/Job'
        WHEN tx_type = 'I' AND tx_dest_status = 'A' THEN 'Issue: Return from Project'
        WHEN tx_type = 'A' AND UPPER(tx_origin) = 'ADJUSTMENT' THEN 'Adjustment: Count Increase'
        WHEN tx_type = 'A' AND UPPER(tx_dest) = 'ADJUSTMENT' THEN 'Adjustment: Count Decrease'
        WHEN tx_type = 'A' AND UPPER(tx_dest) LIKE 'RESERVE%' THEN 'Adjustment: Reserve Movement'
        WHEN tx_type = 'A' AND UPPER(tx_origin) LIKE 'RESERVE%' THEN 'Adjustment: Unreserved Movement'
        WHEN tx_type = 'A' AND UPPER(tx_origin) = 'HOLD' OR UPPER(tx_dest) = 'HOLD'THEN 'Adjustment: Hold Movement'
        ELSE 'Other/Unknown'
    END AS transaction_detail,
    tx_unit_I_R as uom_stock,
    tx_origin AS location_from,
    tx_dest AS location_to,
    tx_origin_status AS origin_status_code,
    CASE 
        WHEN tx_origin_status = 'A' THEN 'Available'
        WHEN tx_origin_status = 'H' THEN 'On Hold'
        WHEN tx_origin_status = 'U' THEN 'Unavailable'
        WHEN tx_origin_status = 'J' THEN 'Adjustment'
        WHEN tx_origin_status = 'I' THEN 'Unplanned Issue'
        WHEN tx_origin_status = 'D' THEN 'Independent Demand'
        ELSE 'Unknown'
    END AS origin_status_description,
    tx_dest_status AS dest_status_code,
    CASE 
        WHEN tx_dest_status = 'A' THEN 'Available'
        WHEN tx_dest_status = 'H' THEN 'On Hold'
        WHEN tx_dest_status = 'U' THEN 'Unavailable'
        WHEN tx_dest_status = 'J' THEN 'Adjustment'
        WHEN tx_dest_status = 'I' THEN 'Unplanned Issue'
        WHEN tx_dest_status = 'D' THEN 'Independent Demand'
        ELSE 'Unknown'
    END AS dest_status_description,
    tx_mosjob AS job_number,
    tx_mocnumber AS order_number,
    tx_moslot AS lot_number,
    tx_cukey AS customer_id,
    tx_rma_number AS rma_number,
    tx_act_mat AS material_cost,
    tx_act_lab AS labor_cost,
    tx_act_bur AS burden_cost,
    (tx_act_mat + tx_act_lab + tx_act_bur) AS aggregated_cost,
    ((tx_act_mat + tx_act_lab + tx_act_bur) * tx_qty) AS total_cost,
    /* ---- TOTAL INVENTORY COST ---- */
    (tx_act_mat + tx_act_lab + tx_act_bur) * 
        (CASE 
            WHEN tx_type = 'R' AND tx_dest_status = 'A' THEN tx_qty
            WHEN tx_type = 'R' AND tx_origin_status = 'A' THEN tx_qty * -1
            WHEN tx_type = 'I' AND tx_origin_status = 'A' THEN tx_qty * -1
            WHEN tx_type = 'I' AND tx_dest_status = 'A' THEN tx_qty
            WHEN tx_type = 'A' AND UPPER(tx_origin) = 'ADJUSTMENT' THEN tx_qty
            WHEN tx_type = 'A' AND UPPER(tx_dest) = 'ADJUSTMENT' THEN tx_qty * -1
            ELSE 0 -- Reserve/Hold/Other
        END) AS total_inventory_cost,
    tx_comment AS transaction_comment,
    tx_userid AS created_by_user
FROM company.TX -- Inventory Transactions Table
WHERE tx_date IS NOT NULL
    AND tx_date >= ADD_MONTHS(TRUNC(ADD_MONTHS(SYSDATE, -6), 'YEAR'),-36)
ORDER BY tx_date DESC, tx_crdate DESC