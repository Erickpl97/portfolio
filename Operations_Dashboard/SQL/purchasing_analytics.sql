-- Purchasing Order Line History with PPV and Delivery Status Calculations
-- This query retrieves purchasing order line details along with PPV calculations and delivery status.
SELECT 
    ol_phkey AS PO_Number,
    ol_ref_no AS PO_Line_Number,
    ol_part_no AS Item_Number,
    ol_status AS Line_Status,
    CASE 
        WHEN ol_status = -1 THEN 'Pre-Released'
        WHEN ol_status = 0 THEN 'Open'
        WHEN ol_status = 1 THEN 'Released'
        WHEN ol_status = 3 THEN 'Closed'
        WHEN ol_status = 4 THEN 'Canceled'
        ELSE 'Unknown'
    END AS Line_Status_Descr,
    ol_qty AS Quantity_Ordered,
    ol_qty_rec AS Quantity_Received,
    ol_qty_inv AS Quantity_Invoiced,
    ol_unit_s AS UOM_Stock,
    ol_rqty AS Qty_Rec_Supplier_UOM,
    ol_unit_r AS UOM_Receiving,
    ol_price AS Unit_Price_Supplier,
    (ol_price * ol_c_recv) AS Unit_Price_Stock,
    vn_cur_id AS Currency,
    ROUND((ol_price * ol_c_recv)/er_rate, 4) AS Unit_Price_CAD_Stock,
    ROUND((ol_price * ol_c_recv * ol_qty)/er_rate, 4) AS Total_Price_CAD_Stock,
    ol_exp_acct AS Expense_Account,
    im_std_mat AS Item_Standard_Cost,
    -- PPV Calculations
    ROUND((ol_price * ol_c_recv/er_rate) - im_std_mat, 4) AS PPV_Per_Unit,
    ROUND(((ol_price * ol_c_recv/er_rate) - im_std_mat) * ol_qty, 4) AS PPV_Total,
    CASE 
        WHEN im_std_mat > 0 THEN
            ROUND(((ol_price * ol_c_recv/er_rate) - im_std_mat)/im_std_mat, 4)
        ELSE NULL
    END AS PPV_Percentage,
    -- Dates
    mos.MOS_DATE_REL AS Release_Date_PO, 
    mos.MOS_WANTDATE AS Due_Date, 
    mos.MOS_ORD_FINIS AS Promise_Date, 
    CASE 
        WHEN mos.MOS_DATE_REC IS NULL THEN NULL
        WHEN mos.MOS_DATE_REC < DATE '1950-01-01' THEN NULL  -- Filter out invalid dates
        ELSE mos.MOS_DATE_REC
    END AS Date_Received,
    -- DELIVERY STATUS CALCULATIONS
    CASE 
        WHEN mos.MOS_DATE_REC IS NULL OR mos.MOS_DATE_REC < DATE '1950-01-01' THEN 'Not Received'
        WHEN mos.MOS_DATE_REC <= mos.MOS_ORD_FINIS THEN 'On Time'
        WHEN mos.MOS_DATE_REC > mos.MOS_ORD_FINIS THEN 'Late'
        ELSE 'Unknown'
    END AS Delivery_Status,
    CASE 
        WHEN mos.MOS_DATE_REC IS NOT NULL 
             AND mos.MOS_DATE_REC >= DATE '1950-01-01'
             AND mos.MOS_DATE_REC > mos.MOS_ORD_FINIS THEN
            mos.MOS_DATE_REC - mos.MOS_ORD_FINIS
        ELSE NULL
    END AS Days_Late,
    CASE 
        WHEN mos.MOS_DATE_REC IS NOT NULL 
             AND mos.MOS_DATE_REC >= DATE '1950-01-01'
             AND mos.MOS_DATE_REC < mos.MOS_ORD_FINIS THEN
            mos.MOS_ORD_FINIS - mos.MOS_DATE_REC
        ELSE NULL
    END AS Days_Early

FROM company.ol -- Purchasing Order Line Table
JOIN company.ph ON ol_phkey = ph_key -- Purchasing Order Header Table
LEFT JOIN company.vn ON ph_vnkey = vn_key -- Vendor Information
LEFT JOIN company.er ON vn_cur_id = er_cur_id -- Exchange Rate Information
LEFT JOIN company.im ON ol_part_no = im_key -- Item Master Information
LEFT JOIN company.mos ON mos_olphkey = ph_key AND mos_olrefno = ol_ref_no -- Delivery Order Information
WHERE ol_crdate >= ADD_MONTHS(TRUNC(ADD_MONTHS(SYSDATE, -6), 'YEAR'), -36) -- Last 3.5 years from start of current year
ORDER BY ol_date_rec DESC;

