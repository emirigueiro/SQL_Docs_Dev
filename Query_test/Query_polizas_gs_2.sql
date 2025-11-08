--------------------------------------------------------------------------------------------------------------
--Summary:

--Query Name: sales_query

--Created Date: 2025/01/01

--Description: this query creates a table with all the new policies.

--References: for example Ticket Jira #1234

--<
--------------------------------------------------------------------------------------------------------------
--Related Programs:

--Query_sales.sql
--Query_sales_2.sql  

--<
---------------------------------------------------------------------------------------------------------------
--Sources:
          -- rod_bronze.trees.five
          -- rod_bronze.trees.five
          -- rod_bronze.trees.five
          -- rod_bronze.trees.five

--<
---------------------------------------------------------------------------------------------------------------
--Product 1: 

--Description: this table contains all the new policies 
--Name: hive_metastore.trees.five
--Type: Table
--Process: Create or Replace

------------------------------------------------------
--Product 2:

--Description: this table contains all the new policies 
--Name: hive_metastore.trees.five
--Type: Table
--Process: Create or Replace

--<
---------------------------------------------------------------------------------------------------------------
--Historical Versions:

-- 2025/01/01: (Emiliano Rigueiro) created Query.
-- 2025/02/01: (Emiliano Rigueiro) eliminated one of the IDs considered for the campaigns.
-- 2025/01/01: (Emiliano Rigueiro) created Query.
-- 2025/02/01: (Emiliano Rigueiro) eliminated one of the IDs considered for the campaigns.      
-- 2025/01/01: (Emiliano Rigueiro) created Query.
-- 2025/02/01: (Emiliano Rigueiro) eliminated one of the IDs considered for the campaigns.
-- 2025/01/01: (Emiliano Rigueiro) created Query.
-- 2025/02/01: (Emiliano Rigueiro) eliminated one of the IDs considered for the campaigns.

--<
---------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------
--Step 1: Process to obtain sales except those coming from campaigns--


CREATE OR REPLACE TABLE hive_metastore.default.sales AS

WITH tmp_1 AS
(
SELECT 

0           AS num_solicitud,
NPOLICY     AS num_pol,
NCERTIF     AS ncertifpol,
NPRODUCT    AS id_producto,
NBRANCH     AS id_branch,
ID_CANAL    AS id_canal,
ID_SUBCANAL AS id_subcanal,
0           AS id_campania,
VENDEDOR    AS vendedor,
0           AS flg_campania

FROM prod_bronze.ttt.ttt_estructuragestion

WHERE ID_ESTRUC_GESTION in (85,86)                                               --LC: We limited the sales by management structure ID--
AND NCERTIF = 0                                                                  --LC: We limit the universe to the first policy (certificate)--
)
---------------------------------------------------------------------------------------------------------------
--Step 2: Process to obtain the sales generated through campaigns-

--Step 2_1: Temporary table for campaign sales--
, tmp_2 AS 
(
SELECT * FROM prod_bronze.trdc.cust_gestiones

WHERE campana in (220,221,222,225,224)                                            --LC: We limit the universe only to HSBC campaigns--
AND ES_VENTA = 'SI'                                                               --LC: Only sales management--
)

-- Step 2_2: Crossover with quotes to obtain details of the request converted into policy--
, tmp_3 AS
(
SELECT 

gest.NRO_SOLICITUD              AS num_solicitud,            
coti.NPOLICYPOL                 AS num_pol,
coti.NCERTIFPOL                 AS ncertifpol,
CAST(gest.PRODUCTO AS INT)      AS id_producto,
coti.NBRANCH                    AS id_branch,
gest.canal                      AS id_canal,
gest.subcanal                   AS id_subcanal,
gest.CAMPANA                    AS id_campania,
gest.AGENTE                     AS vendedor,
1                               AS flg_campania                        --LC: We generate a flag to identify those policies coming from campaigns--

FROM tmp_2 AS gest LEFT JOIN prod_bronze.asdadf.3erqwe AS coti ON gest.NRO_SOLICITUD = COTI.NPOLICYSOL AND gest.PRODUCTO = coti.NPRODUCT
)

-- Step 2_3: Crossover with certificates using campaign request number and certificate NPOLICY to bring dimensions of ncertipol--
, tmp_3_5
(
SELECT 

tmp_3.num_solicitud,                                   
cert.NPOLICY                     AS num_pol,
cert.NCERTIF                     AS ncertifpol,
CAST(cert.NPRODUCT AS INT)       AS id_producto,
cert.NBRANCH                     AS id_branch,
NULL                             AS id_canal,
NULL                             AS id_subcanal,
tmp_3.id_campania,
tmp_3.vendedor,
1                                AS flg_campania                       --LC: We generate a flag to identify those policies coming from campaigns--

FROM tmp_3 LEFT JOIN (SELECT * FROM prod_gold_summarized.sderee.cero WHERE flg_traspaso is null) AS cert ON tmp_3.num_solicitud = cert.NPROPONUM AND tmp_3.id_producto = cert.NPRODUCT
)

-- Step 2_4: Crossover with quotes to bring the data of id_canal and id_subcanal since in certificates it is incomplete--
, tmp_3_6 AS
(
SELECT

tmp_3_5.num_solicitud,                                   
tmp_3_5.num_pol,
tmp_3_5.ncertifpol,
tmp_3_5.id_producto,
tmp_3_5.id_branch,
estr.id_canal                AS id_canal,
estr.id_subcanal             AS id_subcanal,
tmp_3_5.id_campania,
tmp_3_5.vendedor,
tmp_3_5.flg_campania                                                   --LC: We generate a flag to identify those policies coming from campaigns--

FROM tmp_3_5 LEFT JOIN prod_bronze.xxx.ersdfwe AS estr ON tmp_3_5.num_pol = estr.NPOLICY AND tmp_3_5.id_producto = estr.NPRODUCT
)

---------------------------------------------------------------------------------------------------------------
--Step 3: Unification between policies coming from "management structure" and "campaigns"--

, tmp_4 AS
(
SELECT * FROM tmp_1

UNION ALL

SELECT * FROM tmp_3_6
)
---------------------------------------------------------------------------------------------------------------
--Step 4: Crossover with certificates to sum dimensions: fec_emi, facturacion, tiene_siniestro, ramo, motivo_anulacion y punto de venta--

--Step 4_1: Table preparation for certificates to keep the latest update of each record--
, tmp_5 AS 
(
SELECT
      NPOLICY,
      NPROPONUM,
      UPDATED_AT,
      NBRANCH,
      NPRODUCT,
      NCERTIF,
      FLG_TRASPASO,
      FACTURACION                AS desc_facturacion,
      DISSUEDAT                  AS fec_emi, 
      TIENESINIESTRO             AS tiene_siniestro,
      RAMO                       AS desc_ramo,
      MOTIVO_ANULACION_PRINCIPAL AS mot_anulacion,
      PUNTO_VENTA,
      ESTADO_POLIZA
  
FROM prod_gold_summarized.trees.cuusatred

WHERE NCERTIF = 0
AND flg_traspaso is null                                                   --LC: We exclude those policies that were transfers since they should not be considered as new entries--
)

--Step 4_2: Join between policies and the certificates table--
, tmp_6 AS
(
SELECT
      tmp_4.*,
      CASE WHEN id_producto = 5000 THEN 1 ELSE cert.NCERTIF END AS NCERTIF, --LC: We modify the certif. number for SIP products (Id_producto 5000), because the prize is loaded with certif. number 1)--
      cert.desc_facturacion,
      cert.fec_emi,
      cert.tiene_siniestro,
      cert.desc_ramo,
      cert.mot_anulacion,
      TRIM(cert.PUNTO_VENTA) AS punto_venta,
      cert.estado_poliza  

FROM tmp_4 LEFT JOIN tmp_5 AS cert ON (tmp_4.num_pol = cert.NPOLICY AND tmp_4.id_branch = cert.NBRANCH AND tmp_4.id_producto = cert.NPRODUCT AND tmp_4.ncertifpol = cert.NCERTIF)                              
)
---------------------------------------------------------------------------------------------------------------
--Step 5: Crossover with emissions to bring the data of prize--

--Step 5_1: Preparation of the emissions table--
, tmp_7 AS
(
SELECT
       NPOLICY,
       NBRANCH,
       NPRODUCT,
       NCERTIF,
       NTYPE,
       CASE WHEN MIPREMIO > 0 THEN MIPREMIO       END AS premio,
       CASE WHEN MIPRIMA > 0 THEN  MIPRIMA        END AS prima,
       CASE WHEN MIPRIMAPURA > 0 THEN MIPRIMAPURA END AS primapura,
       ROW_NUMBER() OVER(PARTITION BY npolicy, NCERTIF, NTYPE, NBRANCH ORDER BY DISSUEDAT ASC) AS rw 

FROM prod_gold_summarized.trees.cuusatred
)

--Step 5_2: We filter the NTYPE and keep the records with the latest emission date--
, tmp_8 AS
(
SELECT 
      *
FROM tmp_7

WHERE NTYPE in (1,7,9,10,33)                                                        --LC: We filter the NTYPE and keep the records with the latest emission date--
AND rw = 1                                                                          --LC: These are the records with the latest emission date-- 
)

--Step 5_3: Join between policies and emissions--
, tmp_9 AS
(
SELECT
       tmp_6.*,
       emision.premio,
       emision.prima,
       emision.primapura,
       CASE WHEN tmp_6.NCERTIF IS NULL THEN 1 ELSE 0 END AS flg_no_esta_en_certificados,                                       --LC: Flg for policies not in certificates--
       CASE WHEN emision.premio is null THEN 1 ELSE 0 END AS flg_no_tiene_premio,                                              --LC: Flg for policies without prize data in emissions--
       CASE WHEN (num_solicitud != 0 OR num_solicitud is not null) AND num_pol is null THEN 1 ELSE 0 END AS flg_solic_sin_alta --LC: Flg for requests from campaigns that do not end in registration--

FROM tmp_6 LEFT JOIN tmp_8 AS emision ON tmp_6.num_pol = emision.NPOLICY AND tmp_6.id_branch = emision.NBRANCH AND tmp_6.id_producto = emision.NPRODUCT AND tmp_6.NCERTIF = emision.NCERTIF 
)

---------------------------------------------------------------------------------------------------------------
--Step 6: Crossover with management structure to sum code descriptions--

, tmp_10 AS
(
SELECT
      hsbc.*,
      lkp1.canal            AS desc_canal,
      lkp2.subcanal         AS desc_subcanal,
      lkp3.tipo_de_producto AS desc_producto

FROM tmp_9 AS hsbc LEFT JOIN (SELECT id_canal, canal FROM prod_bronze.trees.qertrecd GROUP BY id_canal,canal) AS lkp1 ON hsbc.id_canal = lkp1.id_canal
                   LEFT JOIN (SELECT id_subcanal, subcanal FROM prod_bronze.trees.qertrecd GROUP BY id_subcanal, subcanal) AS lkp2 ON hsbc.id_subcanal = lkp2.id_subcanal
                   LEFT JOIN (SELECT nproduct, tipo_de_Producto FROM prod_bronze.trees.qertrecd GROUP BY nproduct, tipo_de_Producto) AS lkp3 ON hsbc.id_producto = lkp3.nproduct                    
)
---------------------------------------------------------------------------------------------------------------
--Step 7: We correct the point_of_sale field so that CVT appears as Telemarketing--
, tmp_11 AS
(
SELECT
      num_solicitud,
      num_pol,
      id_producto,
      id_branch,
      id_canal,
      id_subcanal,
      id_campania,
      vendedor,
      flg_campania,
      ncertif,
      desc_facturacion,
      fec_emi,
      tiene_siniestro,
      desc_ramo,
      mot_anulacion,
      CASE WHEN punto_venta = 'CVT - Vta Tel GS' THEN 'Telemarketing' ELSE punto_venta END AS punto_venta,
      estado_poliza, 
      premio,
      prima,
      primapura,
      flg_no_esta_en_certificados,
      flg_no_tiene_premio,
      flg_solic_sin_alta,
      desc_canal,
      desc_subcanal,
      desc_producto

FROM tmp_10

)
---------------------------------------------------------------------------------------------------------------
--Step 8: Unification with budget table to sum the records with the corresponding data for budget by product and point of sale at the end of the table--

, tmp_12 AS
(
SELECT
      *,
      NULL AS cantidad_presupuesto,
      NULL AS premio_promedio,
      NULL AS permio_total_presupesto

FROM tmp_11

UNION ALL

SELECT
      NULL AS num_solicitud,
      NULL AS num_pol,
      id_producto AS id_producto,
      NULL AS id_branch,
      NULL AS id_canal,
      NULL AS id_subcanal,
      NULL AS id_campania,
      NULL AS vendedor,
      NULL AS flg_campania,
      NULL AS ncertif,
      NULL AS desc_facturacion,
      NULL AS fec_emi,
      NULL AS tiene_siniestro,
      NULL AS desc_ramo,
      NULL AS mot_anulacion,
      punto_venta AS punto_venta,
      NULL AS estado_poliza, 
      NULL AS premio,
      NULL AS prima,
      NULL AS primapura,
      NULL AS flg_no_esta_en_certificados,
      NULL AS flg_no_tiene_premio,
      NULL AS flg_solic_sin_alta,
      NULL AS desc_canal,
      NULL AS desc_subcanal,
      NULL AS desc_producto,
      cantidad_presupuesto,
      premio_promedio_presupuesto,
      premio_total_presupuesto

FROM hive_metastore.seveen.nuine
)
 
---------------------------------------------------------------------------------------------------------------
--Step 9: Final Select-- 
SELECT * FROM tmp_12 
