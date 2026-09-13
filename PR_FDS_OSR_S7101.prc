CREATE OR REPLACE PROCEDURE      PR_FDS_OSR_S7101 (
   P_DATA_DATE   IN     VARCHAR2,
   P_O_RESULT       OUT VARCHAR2)
IS
   /******************************************************************************
     AUTHOR :
     NAME   : PR_FDS_OSR_S7101 银行业普惠金融重点领域贷款情况表
             表I：普惠型小微企业和其它组织贷款（单户授信总额3000万元以下，含本数）
     FUNCTIONS :
     PURPOSE   :
     REVISIONS OR COMMENTS
     VER        DATE        AUTHOR           DESCRIPTION
   ---------  ----------  ---------------  ------------------------------------
     1.0      20180412     wangzuo           1. CREATED THIS PROCEDURE.

  ******************************************************************************/
   V_STEP                   VARCHAR2 (10 CHAR) := '0';
   V_PROC_NAME              VARCHAR2 (100 CHAR) := 'PR_FDS_OSR_S7101';
   V_TABLE_NAME             VARCHAR2 (30 CHAR) := 'FDS_REPORT_DATA';
   V_DATA_DATE              VARCHAR2 (8 CHAR);
   V_SUCCESS                VARCHAR2 (10 CHAR) := UTIL.SUCCESS;
   V_FAILED                 VARCHAR2 (10 CHAR) := UTIL.FAILED;
   V_LAST_MONTH_END_DATE    VARCHAR2(8 CHAR);
   V_START_TIME             VARCHAR2 (100 CHAR);
   V_END_TIME               VARCHAR2 (100 CHAR);
   V_RUN_DATE               DATE;
   V_FREQ                   VARCHAR2 (1 CHAR) := 'D';
BEGIN
   P_O_RESULT := V_SUCCESS;
   V_DATA_DATE := P_DATA_DATE;
   V_RUN_DATE := TO_DATE (P_DATA_DATE, 'YYYYMMDD');
   V_LAST_MONTH_END_DATE :=UTIL.GET_LAST_MONTH_END_DATE(V_DATA_DATE);
   V_START_TIME := TO_CHAR (SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF');
   V_STEP := '2';

   --删除当日（包括其他时间粒度数据）
   DELETE FROM FDS_REPORT_DATA
         WHERE     DATA_DT = TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD')
               AND REPORT_CODE = 'S7101';

   /*
   EXECUTE IMMEDIATE 'TRUNCATE TABLE ADM.INTF_CL_LOAN_ACCT_TMP';
   COMMIT;*/

     /****汇总贷款总额****/
    /*INSERT INTO VISE.INTF_CL_LOAN_ACCT_TMP
                  (
                    CLIENT_NO,
                    BALANCE
                   )
      SELECT T.CLIENT_NO,
             SUM(T.BALANCE)  AS BALANCE
      FROM   ADM.INTF_CL_LOAN_ACCT T
      WHERE  T.DATA_DATE ='20191031'
         AND T.BALANCE > 0
      GROUP BY T.CLIENT_NO;

      COMMIT;*/

   V_STEP := '3';
          /*
          贷款余额
           OSRS7101_1 (A,A1,A2,A3,A4)
             1.普惠型小微企业法人贷款
             1.2其中：普惠型科创小微企业法人贷款
             1.4 其中：普惠型农村集体经济组织贷款
             1.5 其中：普惠型农民专业合作社贷款
             2.普惠型其它组织贷款
          */
   V_STEP := '3.1';
    INSERT INTO FDS_REPORT_DATA (REPORT_CODE,
                                 ORG_CODE,
                                DATA_DT,
                                INDICATOR,
                                BALANCE)
                SELECT 'S7101',
                       A.BRANCH,
                       TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                       D.PROD_CODE,
                       SUM (A.BALANCE)
                FROM   ADM.INTF_CL_LOAN_ACCT A,
                       VISE.CLIENT_FACILITY_TMP B,
                       ADM.INTF_CIF_CLIENT_CORP C,
                       FDS_MOD_PROD_PARSE D
                WHERE  A.DATA_DATE = V_DATA_DATE              
                 AND   C.DATA_DATE = V_DATA_DATE
                 AND   B.DATA_DATE = V_DATA_DATE    --20200902 ZW add 
                 AND   A.CLIENT_NO = B.CLIENT_NO
                 AND   A.CLIENT_NO = C.CLIENT_NO
                 AND   B.FACILITY <= 30000000                             -- 单户授信金额小于30000000
                 AND   C.CORP_SIZE IN ('CS03','CS04')                     --CS03-小型企业，CSO4-微型企业
                 AND   B.FACILITY >  TO_NUMBER(D.SUBELEM1)
                 AND   B.FACILITY <= TO_NUMBER(D.SUBELEM2)                --单户合同汇总金额
				         AND   A.BUSINESS_TYPE = 'CL200'              --企业贷款组
                 AND   A.ON_OFF_BALANCE = 'ON'                            --ON-表内
               --AND   NVL(C.CORP_INVESTOR,'0') = NVL(NVL(D.SUBELEM4,  C.CORP_INVESTOR),'0')    --科技企业类型(企业出资人经济成分)--20200710            
                -- AND   C.DOCUMENT_TYPE = NVL(D.SUBELEM6, C.DOCUMENT_TYPE)                       --证件类型
                 AND   D.PARSE_CODE = 'OSRS7101_1'
                GROUP BY A.BRANCH, D.PROD_CODE;
                COMMIT;


          V_STEP := '3.2';
       /*
       贷款余额
        OSRS7101_2 (A,A1,A2,A3,A4)
        1.1其中：普惠型涉农小微企业法人贷款
      */--取农村企业
         INSERT INTO FDS_REPORT_DATA (REPORT_CODE,
                                ORG_CODE,
                                DATA_DT,
                                INDICATOR,
                                BALANCE)
                SELECT   'S7101',
                         A.BRANCH,
                         TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                         D.PROD_CODE,
                         SUM (A.BALANCE)
                FROM     ADM.INTF_CL_LOAN_ACCT A,
                         VISE.CLIENT_FACILITY_TMP B,
                         ADM.INTF_CIF_CLIENT_CORP C,
                         FDS_MOD_PROD_PARSE D
                WHERE    A.DATA_DATE = V_DATA_DATE
                     AND C.DATA_DATE = V_DATA_DATE
                     AND B.DATA_DATE = V_DATA_DATE    --20200902 ZW add 
                     AND A.CLIENT_NO = B.CLIENT_NO
                     AND A.CLIENT_NO = C.CLIENT_NO
                     AND B.FACILITY <= 30000000
                     AND C.CORP_SIZE IN ('CS03','CS04')                    --CS03-小型企业，CSO4-微型企业
                     AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                     AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)               --单户合同汇总金额
                     AND A.ON_OFF_BALANCE = 'ON'                           --ON-表内
                     AND A.BUSINESS_TYPE = 'CL200'              --企业贷款组
                     AND C.DISTRICT = 'V'      --V-农村
                     AND D.PARSE_CODE = 'OSRS7101_2'
               GROUP BY A.BRANCH,D.PROD_CODE
               --取城市企业，投向行业农林牧副渔
               UNION ALL
               SELECT   'S7101',
                         A.BRANCH,
                         TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                         D.PROD_CODE,
                         SUM (A.BALANCE)
                FROM     ADM.INTF_CL_LOAN_ACCT A,
                         VISE.CLIENT_FACILITY_TMP B,
                         ADM.INTF_CIF_CLIENT_CORP C,
                         FDS_MOD_PROD_PARSE D
                WHERE    A.DATA_DATE = V_DATA_DATE
                     AND C.DATA_DATE = V_DATA_DATE
                     AND B.DATA_DATE = V_DATA_DATE    --20200902 ZW add 
                     AND A.CLIENT_NO = B.CLIENT_NO
                     AND A.CLIENT_NO = C.CLIENT_NO
                     AND B.FACILITY <= 30000000
                     AND C.CORP_SIZE IN ('CS03','CS04')                    --CS03-小型企业，CSO4-微型企业
                     AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                     AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)               --单户合同汇总金额
                     AND A.ON_OFF_BALANCE = 'ON'                           --ON-表内
                     AND A.BUSINESS_TYPE = 'CL200'              --企业贷款组
                     AND C.DISTRICT = 'C' --D-城市
                     AND SUBSTR(A.INDUSTRY_CODE,1,1) = 'A' --A-农林牧渔业
                     AND D.PARSE_CODE = 'OSRS7101_2'
                GROUP BY A.BRANCH,D.PROD_CODE
                 --取城市企业，支持农田相关建设
               UNION ALL
               SELECT   'S7101',
                         A.BRANCH,
                         TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                         D.PROD_CODE,
                         SUM (A.BALANCE)
                FROM     ADM.INTF_CL_LOAN_ACCT A,
                         VISE.CLIENT_FACILITY_TMP B,
                         ADM.INTF_CIF_CLIENT_CORP C,
                         FDS_MOD_PROD_PARSE D
                WHERE    A.DATA_DATE = V_DATA_DATE
                     AND C.DATA_DATE = V_DATA_DATE
                     AND B.DATA_DATE = V_DATA_DATE    --20200902 ZW add 
                     AND A.CLIENT_NO = B.CLIENT_NO
                     AND A.CLIENT_NO = C.CLIENT_NO
                     AND B.FACILITY <= 30000000
                     AND C.CORP_SIZE IN ('CS03','CS04')                    --CS03-小型企业，CSO4-微型企业
                     AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                     AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)               --单户合同汇总金额
                     AND A.ON_OFF_BALANCE = 'ON'                           --ON-表内
                     AND A.BUSINESS_TYPE = 'CL200'              --企业贷款组
                     AND C.DISTRICT = 'C' --D-城市
                     AND A.FARM_LOAN_TYPE IN ('E1','E2','E3','E4','E5','E6','E7') --E1-农田基本建设贷款  E2-农产品加工贷款 E3-农业生产资料制造贷款
                                                                                  --E4-农产品出口贷款   E5-其他农用物资和农副产品流通贷款 --E6-农业科技贷款   E7-农村基础设施建设贷款
                     AND D.PARSE_CODE = 'OSRS7101_2'
                 GROUP BY A.BRANCH,D.PROD_CODE
                 ;
                   COMMIT;

          V_STEP := '3.3';
          /*
          贷款余额
          OSRS7101_3 (A,A1,A2,A3,A4)
          1.3其中：暂无小微企业法人创业担保贷款
          */
                /*  INSERT INTO FDS_REPORT_DATA (REPORT_CODE,
                                ORG_CODE,
                                DATA_DT,
                                INDICATOR,
                                BALANCE)
                    SELECT 'S7101',
                            A.BRANCH,
                            TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                            D.PROD_CODE,
                            SUM (A.BALANCE)
                    FROM    ADM.INTF_CL_LOAN_ACCT A,
                            VISE.CLIENT_FACILITY_TMP B,
                            ADM.INTF_CIF_CLIENT_CORP C,
                            FDS_MOD_PROD_PARSE D
                    WHERE   A.DATA_DATE = V_DATA_DATE
                        AND C.DATA_DATE = V_DATA_DATE
                        AND A.CLIENT_NO = B.CLIENT_NO
                        AND A.CLIENT_NO = C.CLIENT_NO
                        AND B.FACILITY <= 30000000
                        AND C.CORP_SIZE IN ('CS03','CS04')                  --CS03-小型企业，CSO4-微型企业
                        AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                        AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)            --单户合同汇总金额
						AND A.BUSINESS_TYPE = 'CL200'              --企业贷款组
                            --DELETE BY ZHOUDE ON 20190626 BELOW
                            --AND A.VENTURE_GUARANT_TYPE IN('1','2','3','4','5') --创业担保贷款主体类型1-城镇登记失业人员,2-就业困难人员（含残疾人）,3-复员转业退役军人
                            --DELETE BY ZHOUDE ON 20190626 ABOVE
                        AND A.ON_OFF_BALANCE = 'ON'                        --ON-表内
                        AND D.PARSE_CODE = 'OSRS7101_3'
                       GROUP BY A.BRANCH,D.PROD_CODE;
                       COMMIT;
                    */

        V_STEP := '3.4';
     /*
     贷款余额
     OSRS7101_4 (A,A1,A2,A3,A4)
     3.1其中：普惠型个体工商户贷款
     */ 
              INSERT INTO FDS_REPORT_DATA
                           (
                             REPORT_CODE,
                             ORG_CODE,
                             DATA_DT,
                             INDICATOR,
                             BALANCE
                             )
               SELECT 'S7101',
                       A.BRANCH,
                       TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                       D.PROD_CODE,
                       SUM (A.BALANCE)
                FROM   ADM.INTF_CL_LOAN_ACCT A,
                       VISE.CLIENT_FACILITY_TMPI B,
                       FDS_MOD_PROD_PARSE D
                WHERE  A.DATA_DATE = V_DATA_DATE
                  AND  B.DATA_DATE = V_DATA_DATE    --20200902 ZW add 
                  AND  A.CLIENT_NO = B.CLIENT_NO
									AND  A.BUSINESS_SUB_TYPE='A18'  -- A18-个体工商户
                  AND  B.FACILITY <= 30000000
                  AND  B.FACILITY > TO_NUMBER(D.SUBELEM1)
                  AND  B.FACILITY <= TO_NUMBER(D.SUBELEM2)    --单户合同汇总金额
				         -- AND  A.BUSINESS_TYPE = 'CL100'  --个人贷款组
                  AND  A.ON_OFF_BALANCE = 'ON'                --ON-表内
                  AND  D.PARSE_CODE = 'OSRS7101_4'
                GROUP BY  A.BRANCH,D.PROD_CODE
                        ;
                       COMMIT;
         
          V_STEP := '3.5';
        /*
        贷款余额
         OSRS7101_5 (A,A1,A2,A3,A4)
         3.2其中：普惠型小微企业主贷款
       */
           INSERT INTO FDS_REPORT_DATA
                      (
                        REPORT_CODE,
                        ORG_CODE,
                        DATA_DT,
                        INDICATOR,
                        BALANCE
                       )
                SELECT 'S7101',
                        A.BRANCH,
                        TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                        D.PROD_CODE,
                        SUM (A.BALANCE)
                 FROM   ADM.INTF_CL_LOAN_ACCT A,
                        VISE.CLIENT_FACILITY_TMPI B,
                        FDS_MOD_PROD_PARSE D
                 WHERE  A.DATA_DATE = V_DATA_DATE
                   AND B.DATA_DATE = V_DATA_DATE    --20200902 ZW add 
                   AND  A.CLIENT_NO = B.CLIENT_NO
									 AND  A.BUSINESS_SUB_TYPE='A17'  -- A17-小微企业主
                   AND  B.FACILITY <= 30000000
                   AND  B.FACILITY > TO_NUMBER(D.SUBELEM1)
                   AND  B.FACILITY <= TO_NUMBER(D.SUBELEM2)            --单户合同汇总金额
                   AND  A.ON_OFF_BALANCE = 'ON'                        --ON-表内
                   AND  D.PARSE_CODE = 'OSRS7101_5'
                GROUP BY A.BRANCH,D.PROD_CODE;
              COMMIT; 

      V_STEP := '4';
          /*
          贷款余额户数  --指标配置需要重新配置
           OSRS7101_1_B(B,B1,B2,B3,B4)
             1.普惠型小微企业法人贷款
             1.2其中：普惠型科创小微企业法人贷款
             1.1.1 其中：普惠型农村集体经济组织贷款
             1.1.2 其中：普惠型农民专业合作社贷款
             2.普惠型其它组织贷款
          */
   V_STEP := '4.1';
    INSERT INTO FDS_REPORT_DATA
                 (
                   REPORT_CODE,
                   ORG_CODE,
                   DATA_DT,
                   INDICATOR,
                   BALANCE
                 )
                SELECT 'S7101',
                        C.BRANCH,
                        TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                        D.PROD_CODE,
                        COUNT(DISTINCT A.CLIENT_NO)
                   FROM ADM.INTF_CL_LOAN_ACCT A,
                        VISE.CLIENT_FACILITY_TMP B,
                        ADM.INTF_CIF_CLIENT_CORP C,
                        FDS_MOD_PROD_PARSE D
                   WHERE A.DATA_DATE = V_DATA_DATE
                     AND C.DATA_DATE = V_DATA_DATE
                     AND B.DATA_DATE = V_DATA_DATE    --20200902 ZW add 
                     AND A.CLIENT_NO=B.CLIENT_NO
                     AND A.CLIENT_NO=C.CLIENT_NO
                     AND B.FACILITY <= 30000000
                     AND C.CORP_SIZE IN ('CS03','CS04')                    --CS03-小型企业，CSO4-微型企业
                     AND B.FACILITY >  TO_NUMBER(D.SUBELEM1)
                     AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)               --单户合同汇总金额
                     --AND NVL(C.CORP_INVESTOR,'0') = NVL(NVL(D.SUBELEM4,C.CORP_INVESTOR),'0')             --科技企业类型
                     --AND C.DOCUMENT_TYPE = NVL(D.SUBELEM6, C.DOCUMENT_TYPE) --证件类型
                     AND A.ON_OFF_BALANCE = 'ON'                           --ON-表内
                     AND A.BUSINESS_TYPE = 'CL200'              --企业贷款组
                     AND A.BALANCE > 0                                     --A.贷款余额>0
                     AND D.PARSE_CODE = 'OSRS7101_1_B'
                  GROUP BY C.BRANCH,D.PROD_CODE;
                COMMIT;

       V_STEP := '4.2';
       /*
       贷款余额户数
       OSRS7101_2_B(B,B1,B2,B3,B4)
       1.1其中：普惠型涉农小微企业法人贷款
       */
                  INSERT INTO FDS_REPORT_DATA (REPORT_CODE,
                                ORG_CODE,
                                DATA_DT,
                                INDICATOR,
                                BALANCE)
                         SELECT 'S7101',
                                C.BRANCH,
                                TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                D.PROD_CODE,
                                COUNT(DISTINCT A.CLIENT_NO)
                           FROM ADM.INTF_CL_LOAN_ACCT A,
                                VISE.CLIENT_FACILITY_TMP B,
                                ADM.INTF_CIF_CLIENT_CORP C,
                                FDS_MOD_PROD_PARSE D
                          WHERE A.DATA_DATE = V_DATA_DATE
                            AND C.DATA_DATE = V_DATA_DATE
                            AND B.DATA_DATE = V_DATA_DATE    --20200902 ZW add 
                            AND A.CLIENT_NO = B.CLIENT_NO
                            AND A.CLIENT_NO = C.CLIENT_NO
                            AND B.FACILITY <= 30000000
                            AND C.CORP_SIZE IN ('CS03','CS04')                    --CS03-小型企业，CSO4-微型企业
                            AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                            AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)               --单户合同汇总金额
                            AND A.ON_OFF_BALANCE = 'ON'                           --ON-表内
                            AND A.BUSINESS_TYPE = 'CL200'              --企业贷款组
                            AND A.BALANCE > 0                                     --A.贷款余额>0
                            AND C.DISTRICT = 'V'      --V-农村
                            AND D.PARSE_CODE = 'OSRS7101_2_B'
                       GROUP BY C.BRANCH,D.PROD_CODE
                        UNION ALL
                        SELECT 'S7101',
                                C.BRANCH,
                                TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                D.PROD_CODE,
                                COUNT(DISTINCT A.CLIENT_NO)
                           FROM ADM.INTF_CL_LOAN_ACCT A,
                                VISE.CLIENT_FACILITY_TMP B,
                                ADM.INTF_CIF_CLIENT_CORP C,
                                FDS_MOD_PROD_PARSE D
                          WHERE A.DATA_DATE = V_DATA_DATE
                            AND C.DATA_DATE = V_DATA_DATE
                            AND B.DATA_DATE = V_DATA_DATE    --20200902 ZW add 
                            AND A.CLIENT_NO = B.CLIENT_NO
                            AND A.CLIENT_NO = C.CLIENT_NO
                            AND B.FACILITY <= 30000000
                            AND C.CORP_SIZE IN ('CS03','CS04')                    --CS03-小型企业，CSO4-微型企业
                            AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                            AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)               --单户合同汇总金额
                            AND A.ON_OFF_BALANCE = 'ON'                           --ON-表内
                            AND A.BUSINESS_TYPE = 'CL200'              --企业贷款组
                            AND A.BALANCE > 0                                     --A.贷款余额>0
                            AND C.DISTRICT = 'C' --D-城市
                            AND SUBSTR(A.INDUSTRY_CODE,1,1) = 'A' --A%-农林牧渔业                                                             --E6-农业科技贷款   E7-农村基础设施建设贷款
                            AND D.PARSE_CODE = 'OSRS7101_2_B'
                       GROUP BY C.BRANCH,D.PROD_CODE
                       UNION ALL
                       SELECT 'S7101',
                                C.BRANCH,
                                TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                D.PROD_CODE,
                                COUNT(DISTINCT A.CLIENT_NO)
                           FROM ADM.INTF_CL_LOAN_ACCT A,
                                VISE.CLIENT_FACILITY_TMP B,
                                ADM.INTF_CIF_CLIENT_CORP C,
                                FDS_MOD_PROD_PARSE D
                          WHERE A.DATA_DATE = V_DATA_DATE
                            AND C.DATA_DATE = V_DATA_DATE
                            AND B.DATA_DATE = V_DATA_DATE    --20200902 ZW add 
                            AND A.CLIENT_NO = B.CLIENT_NO
                            AND A.CLIENT_NO = C.CLIENT_NO
                            AND B.FACILITY <= 30000000
                            AND C.CORP_SIZE IN ('CS03','CS04')                    --CS03-小型企业，CSO4-微型企业
                            AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                            AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)               --单户合同汇总金额
                            AND A.ON_OFF_BALANCE = 'ON'                           --ON-表内
                            AND A.BUSINESS_TYPE = 'CL200'              --企业贷款组
                            AND A.BALANCE > 0                                     --A.贷款余额>0
                            AND C.DISTRICT = 'C' --D-城市
                            AND A.FARM_LOAN_TYPE IN ('E1','E2','E3','E4','E5','E6','E7') --E1-农田基本建设贷款  E2-农产品加工贷款 E3-农业生产资料制造贷款
                                                                                         --E4-农产品出口贷款   E5-其他农用物资和农副产品流通贷款 --E6-农业科技贷款   E7-农村基础设施建设贷款
                            AND D.PARSE_CODE = 'OSRS7101_2_B'
                       GROUP BY C.BRANCH,D.PROD_CODE
                       ;
                        COMMIT;

                V_STEP := '4.3';
             /*
             贷款余额户数
             OSRS7101_3_B(B,B1,B2,B3,B4)
                1.3其中：小微企业法人创业担保贷款
            */
                /*  INSERT INTO FDS_REPORT_DATA (REPORT_CODE,
                                ORG_CODE,
                                DATA_DT,
                                INDICATOR,
                                BALANCE)
                         SELECT 'S7101',
                                C.BRANCH,
                                TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                D.PROD_CODE,
                                COUNT(DISTINCT A.CLIENT_NO)
                           FROM ADM.INTF_CL_LOAN_ACCT A,
                                VISE.CLIENT_FACILITY_TMP B,
                                ADM.INTF_CIF_CLIENT_CORP C,
                                FDS_MOD_PROD_PARSE D
                          WHERE A.DATA_DATE = V_DATA_DATE
                            AND C.DATA_DATE = V_DATA_DATE
                            AND A.CLIENT_NO = B.CLIENT_NO
                            AND A.CLIENT_NO = C.CLIENT_NO
                            AND B.FACILITY <= 30000000
                            AND C.CORP_SIZE IN ('CS03','CS04')                 --CS03-小型企业，CSO4-微型企业
                            AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                            AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)            --单户合同汇总金额
							AND A.BUSINESS_TYPE = 'CL200'              --企业贷款组
                            -- DELETE BY ZHOUDE ON 20190626 BELOW
                            --AND A.VENTURE_GUARANT_TYPE IN('1','2','3','4','5') --创业担保贷款主体类型1-城镇登记失业人员,2-就业困难人员（含残疾人）,3-复员转业退役军人
                            -- DELETE BY ZHOUDE ON 20190626 ABOVE
                            AND A.ON_OFF_BALANCE = 'ON'                        --ON-表内
                            AND A.BALANCE > 0                                  --A.贷款余额>0
                            AND D.PARSE_CODE = 'OSRS7101_3_B'
                       GROUP BY C.BRANCH,D.PROD_CODE;
                       COMMIT;
                   */
           V_STEP := '4.4';
            /*
            贷款余额户数
             OSRS7101_4_B(B,B1,B2,B3,B4)
            3.1其中：普惠型个体工商户贷款
            */
                  INSERT INTO FDS_REPORT_DATA (REPORT_CODE,
                                ORG_CODE,
                                DATA_DT,
                                INDICATOR,
                                BALANCE)
                         SELECT 'S7101',
                                A.BRANCH,
                                TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                D.PROD_CODE,
                                COUNT(DISTINCT A.CLIENT_NO)
                           FROM ADM.INTF_CL_LOAN_ACCT A,
                                VISE.CLIENT_FACILITY_TMPI B,
                                FDS_MOD_PROD_PARSE D
                          WHERE A.DATA_DATE = V_DATA_DATE
                            AND B.DATA_DATE = V_DATA_DATE    --20200902 ZW add 
                            AND A.CLIENT_NO = B.CLIENT_NO
                            AND B.FACILITY <= 30000000
														AND A.BUSINESS_SUB_TYPE='A18' -- A18-个体工商户
                            AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                            AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)             --单户合同汇总金额
                            AND A.ON_OFF_BALANCE = 'ON'                         --ON-表内
                            AND A.BALANCE > 0                                   --A.贷款余额>0
                            AND D.PARSE_CODE = 'OSRS7101_4_B'
                       GROUP BY A.BRANCH,D.PROD_CODE
                       ;
                       COMMIT;
                      
             V_STEP := '4.5';
             /*
             贷款余额户数
             OSRS7101_5_B(B,B1,B2,B3,B4)
              3.2其中：普惠型小微企业主贷款
             */
                  INSERT INTO FDS_REPORT_DATA (REPORT_CODE,
                                ORG_CODE,
                                DATA_DT,
                                INDICATOR,
                                BALANCE)
                         SELECT 'S7101',
                                A.BRANCH,
                                TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                D.PROD_CODE,
                                COUNT(DISTINCT A.CLIENT_NO)
                           FROM ADM.INTF_CL_LOAN_ACCT A,
                                VISE.CLIENT_FACILITY_TMPI B,
                                FDS_MOD_PROD_PARSE D
                          WHERE A.DATA_DATE = V_DATA_DATE
                            AND B.DATA_DATE = V_DATA_DATE    --20200902 ZW add 
                            AND A.CLIENT_NO = B.CLIENT_NO
														AND A.BUSINESS_SUB_TYPE='A17' -- A17-小微企业主
                            AND B.FACILITY <= 30000000
                            --AND A.BUSINESS_SUB_TYPE = D.SUBELEM3            --A19-个人经营性贷款
                            AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                            AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)         --单户合同汇总金额
                            AND A.ON_OFF_BALANCE = 'ON'                     --ON-表内
                            AND A.BALANCE > 0                               --A.贷款余额>0
                            AND D.PARSE_CODE = 'OSRS7101_5_B'
                       GROUP BY A.BRANCH,D.PROD_CODE;
              COMMIT; 

         V_STEP := '5';
          /*
          不良贷款余额
           OSRS7101_1_C(C,C1,C2,C3,C4)
             1.普惠型小微企业法人贷款
             1.2其中：普惠型科创小微企业法人贷款
             1.4 其中：普惠型农村集体经济组织贷款
             1.5 其中：普惠型农民专业合作社贷款
             2.普惠型其它组织贷款
          */
   V_STEP := '5.1';
    INSERT INTO FDS_REPORT_DATA (REPORT_CODE,
                                ORG_CODE,
                                DATA_DT,
                                INDICATOR,
                                BALANCE)
                         SELECT 'S7101',
                                A.BRANCH,
                                TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                D.PROD_CODE,
                                SUM (A.BALANCE)
                           FROM ADM.INTF_CL_LOAN_ACCT A,
                                VISE.CLIENT_FACILITY_TMP B,
                                ADM.INTF_CIF_CLIENT_CORP C,
                                FDS_MOD_PROD_PARSE D
                          WHERE A.DATA_DATE = V_DATA_DATE
                            AND C.DATA_DATE = V_DATA_DATE
                            AND B.DATA_DATE = V_DATA_DATE    --20200902 ZW add 
                            --AND TO_CHAR (V_RUN_DATE, 'YYYYMMDD') = D.DATA_DATE
                            AND A.CLIENT_NO=B.CLIENT_NO
                            AND A.CLIENT_NO=C.CLIENT_NO
                            AND B.FACILITY <= 30000000
                            AND C.CORP_SIZE IN ('CS03','CS04')                    --CS03-小型企业，CSO4-微型企业
                            AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                            AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)               --单户合同汇总金额
                            --AND NVL(C.CORP_INVESTOR,'0') = NVL(D.SUBELEM4, NVL(C.CORP_INVESTOR,'0'))             --科技企业类型
                           -- AND C.DOCUMENT_TYPE = NVL(D.SUBELEM6,C.DOCUMENT_TYPE) --证件类型
                            AND A.ON_OFF_BALANCE = 'ON'                           --ON-表内
                            AND A.BUSINESS_TYPE = 'CL200'                         --企业贷款组
                            AND A.FIVE_CLASS IN ('FQ03','FQ04','FQ05')            --FQ03-次级,FQ04-可疑,FQ05-损失
                            AND D.PARSE_CODE = 'OSRS7101_1_C'
                       GROUP BY A.BRANCH,D.PROD_CODE;
                COMMIT;

           V_STEP := '5.2';
           /*
           不良贷款余额
           OSRS7101_2_C(C,C1,C2,C3,C4)
           1.1其中：普惠型涉农小微企业法人贷款
           */
                  INSERT INTO FDS_REPORT_DATA (REPORT_CODE,
                                ORG_CODE,
                                DATA_DT,
                                INDICATOR,
                                BALANCE)
                         SELECT 'S7101',
                                A.BRANCH,
                                TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                D.PROD_CODE,
                                SUM (A.BALANCE)
                           FROM ADM.INTF_CL_LOAN_ACCT A,
                                VISE.CLIENT_FACILITY_TMP B,
                                ADM.INTF_CIF_CLIENT_CORP C,
                                FDS_MOD_PROD_PARSE D
                          WHERE A.DATA_DATE  = V_DATA_DATE
                            AND C.DATA_DATE  = V_DATA_DATE
                            AND B.DATA_DATE = V_DATA_DATE    --20200902 ZW add 
                            AND A.CLIENT_NO=B.CLIENT_NO
                            AND A.CLIENT_NO=C.CLIENT_NO
                            AND B.FACILITY <= 30000000
                            AND C.CORP_SIZE IN ('CS03','CS04')                    --CS03-小型企业，CSO4-微型企业
                            AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                            AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)               --单户合同汇总金额
                            AND A.ON_OFF_BALANCE = 'ON'                           --ON-表内
                            AND A.BUSINESS_TYPE = 'CL200'                         --企业贷款组
                            AND A.FIVE_CLASS IN ('FQ03','FQ04','FQ05')            --FQ03-次级,FQ04-可疑,FQ05-损失
                            AND C.DISTRICT = 'V'      --V-农村
                            AND D.PARSE_CODE = 'OSRS7101_2_C'
                       GROUP BY A.BRANCH,D.PROD_CODE
                       UNION ALL
                       SELECT 'S7101',
                                A.BRANCH,
                                TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                D.PROD_CODE,
                                SUM (A.BALANCE)
                           FROM ADM.INTF_CL_LOAN_ACCT A,
                                VISE.CLIENT_FACILITY_TMP B,
                                ADM.INTF_CIF_CLIENT_CORP C,
                                FDS_MOD_PROD_PARSE D
                          WHERE A.DATA_DATE  = V_DATA_DATE
                            AND C.DATA_DATE  = V_DATA_DATE
                            AND B.DATA_DATE = V_DATA_DATE    --20200902 ZW add 
                            AND A.CLIENT_NO=B.CLIENT_NO
                            AND A.CLIENT_NO=C.CLIENT_NO
                            AND B.FACILITY <= 30000000
                            AND C.CORP_SIZE IN ('CS03','CS04')                    --CS03-小型企业，CSO4-微型企业
                            AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                            AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)               --单户合同汇总金额
                            AND A.ON_OFF_BALANCE = 'ON'                           --ON-表内
                            AND A.BUSINESS_TYPE = 'CL200'                         --企业贷款组
                            AND A.FIVE_CLASS IN ('FQ03','FQ04','FQ05')            --FQ03-次级,FQ04-可疑,FQ05-损失
                            AND C.DISTRICT = 'C' --D-城市
                            AND SUBSTR(A.INDUSTRY_CODE,1,1) = 'A' --A%-农林牧渔业
                            AND D.PARSE_CODE = 'OSRS7101_2_C'
                       GROUP BY A.BRANCH,D.PROD_CODE
                       UNION ALL
                       SELECT 'S7101',
                                A.BRANCH,
                                TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                D.PROD_CODE,
                                SUM (A.BALANCE)
                           FROM ADM.INTF_CL_LOAN_ACCT A,
                                VISE.CLIENT_FACILITY_TMP B,
                                ADM.INTF_CIF_CLIENT_CORP C,
                                FDS_MOD_PROD_PARSE D
                          WHERE A.DATA_DATE  = V_DATA_DATE
                            AND C.DATA_DATE  = V_DATA_DATE
                            AND B.DATA_DATE = V_DATA_DATE    --20200902 ZW add 
                            AND A.CLIENT_NO=B.CLIENT_NO
                            AND A.CLIENT_NO=C.CLIENT_NO
                            AND B.FACILITY <= 30000000
                            AND C.CORP_SIZE IN ('CS03','CS04')                    --CS03-小型企业，CSO4-微型企业
                            AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                            AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)               --单户合同汇总金额
                            AND A.ON_OFF_BALANCE = 'ON'                           --ON-表内
                            AND A.BUSINESS_TYPE = 'CL200'                         --企业贷款组
                            AND A.FIVE_CLASS IN ('FQ03','FQ04','FQ05')            --FQ03-次级,FQ04-可疑,FQ05-损失
                            AND C.DISTRICT = 'C' --D-城市
                            AND A.FARM_LOAN_TYPE IN ('E1','E2','E3','E4','E5','E6','E7') --E1-农田基本建设贷款  E2-农产品加工贷款 E3-农业生产资料制造贷款
                                                                                  --E4-农产品出口贷款   E5-其他农用物资和农副产品流通贷款 --E6-农业科技贷款   E7-农村基础设施建设贷款
                            AND D.PARSE_CODE = 'OSRS7101_2_C'
                       GROUP BY A.BRANCH,D.PROD_CODE
                     ;
                    COMMIT;

          V_STEP := '5.3';
            /*
            不良贷款余额
           OSRS7101_3_C(C,C1,C2,C3,C4)
            1.3其中：小微企业法人创业担保贷款-不良贷款余额
            */
               /*   INSERT INTO FDS_REPORT_DATA (REPORT_CODE,
                                ORG_CODE,
                                DATA_DT,
                                INDICATOR,
                                BALANCE)
                         SELECT 'S7101',
                                A.BRANCH,
                                TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                D.PROD_CODE,
                                SUM (A.BALANCE)
                           FROM ADM.INTF_CL_LOAN_ACCT A,
                                VISE.CLIENT_FACILITY_TMP B,
                                ADM.INTF_CIF_CLIENT_CORP C,
                                FDS_MOD_PROD_PARSE D
                          WHERE A.DATA_DATE = V_DATA_DATE
                            AND C.DATA_DATE = V_DATA_DATE
                            AND A.CLIENT_NO = B.CLIENT_NO
                            AND A.CLIENT_NO = C.CLIENT_NO
                            AND B.FACILITY <= 30000000
                            AND C.CORP_SIZE IN ('CS03','CS04')                 --CS03-小型企业，CSO4-微型企业
                            AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                            AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)            --单户合同汇总金额
                            --DELETE BY ZHOUDE ON 20190629 BELOW
                           --AND A.VENTURE_GUARANT_TYPE IN('1','2','3','4','5') --创业担保贷款主体类型1-城镇登记失业人员,2-就业困难人员（含残疾人）,3-复员转业退役军人
                            --DELETE BY ZHOUDE ON 20190629 ABOVE                                                  --4-刑满释放人员,5-高校毕业生（不含大学生村官和留学回国学生
                            AND A.ON_OFF_BALANCE = 'ON'                        --ON-表内
                            AND A.BUSINESS_TYPE = 'CL200'                         --企业贷款组
                            AND A.FIVE_CLASS IN ('FQ03','FQ04','FQ05')         --FQ03-次级,FQ04-可疑,FQ05-损失
                            AND D.PARSE_CODE = 'OSRS7101_3_C'
                       GROUP BY A.BRANCH,D.PROD_CODE;
                       COMMIT; */

            V_STEP := '5.4';
         /*
         不良贷款余额
          OSRS7101_4_C(C,C1,C2,C3,C4)
         3.1其中：普惠型个体工商户贷款
        */
                  INSERT INTO FDS_REPORT_DATA (REPORT_CODE,
                                ORG_CODE,
                                DATA_DT,
                                INDICATOR,
                                BALANCE)
                         SELECT 'S7101',
                                A.BRANCH,
                                TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                D.PROD_CODE,
                                SUM (A.BALANCE)
                           FROM ADM.INTF_CL_LOAN_ACCT A,
                                VISE.CLIENT_FACILITY_TMPI B,
                                FDS_MOD_PROD_PARSE D
                          WHERE A.DATA_DATE = V_DATA_DATE
                            AND B.DATA_DATE = V_DATA_DATE    --20200902 ZW add 
                            AND A.CLIENT_NO = B.CLIENT_NO
														AND A.BUSINESS_SUB_TYPE='A18' -- A18-个体工商户
                            AND B.FACILITY <= 30000000
                            AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                            AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)             --单户合同汇总金额
                            AND A.ON_OFF_BALANCE = 'ON'                         --ON-表内
                            AND A.FIVE_CLASS IN ('FQ03','FQ04','FQ05')          --FQ03-次级,FQ04-可疑,FQ05-损失
                            AND D.PARSE_CODE = 'OSRS7101_4_C'
                       GROUP BY A.BRANCH,D.PROD_CODE ;
                       COMMIT;
             
           V_STEP := '5.5';
           /*
           不良贷款余额
          OSRS7101_5_C(C,C1,C2,C3,C4)
            3.2其中：普惠型小微企业主贷款
          */
                  INSERT INTO FDS_REPORT_DATA (REPORT_CODE,
                                ORG_CODE,
                                DATA_DT,
                                INDICATOR,
                                BALANCE)
                         SELECT 'S7101',
                                A.BRANCH,
                                TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                D.PROD_CODE,
                                SUM (A.BALANCE)
                           FROM ADM.INTF_CL_LOAN_ACCT A,
                                VISE.CLIENT_FACILITY_TMPI B,
                                FDS_MOD_PROD_PARSE D
                          WHERE A.DATA_DATE = V_DATA_DATE
                            AND B.DATA_DATE = V_DATA_DATE    --20200902 ZW add 
                            AND A.CLIENT_NO = B.CLIENT_NO
														AND A.BUSINESS_SUB_TYPE='A17' -- A17-小微企业主
                            AND B.FACILITY <= 30000000
                            AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                            AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)         --单户合同汇总金额
                            AND A.ON_OFF_BALANCE = 'ON'                     --ON-表内
                            AND A.FIVE_CLASS IN ('FQ03','FQ04','FQ05')      --FQ03-次级,FQ04-可疑,FQ05-损失
                            AND D.PARSE_CODE = 'OSRS7101_5_C'
                       GROUP BY A.BRANCH,D.PROD_CODE;
              COMMIT; 

     V_STEP := '6';
          /*
          当年累放贷款额
           OSRS7101_1_D(D,D1,D2,D3,D4)
             1.普惠型小微企业法人贷款
             1.2其中：普惠型科创小微企业法人贷款
             1.1.1 其中：普惠型农村集体经济组织贷款
             1.1.2 其中：普惠型农民专业合作社贷款
             2.普惠型其它组织贷款
          */
   V_STEP := '6.1';
    INSERT INTO FDS_REPORT_DATA (REPORT_CODE,
                                ORG_CODE,
                                DATA_DT,
                                INDICATOR,
                                BALANCE)
                              SELECT 'S7101',
                                      A.BRANCH BRANCH,
                                      TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                      D.PROD_CODE PROD_CODE,
                                      SUM (A.DD_AMT) BALANCE
                              FROM ADM.INTF_CL_LOAN_ACCT A,
                                   VISE.CLIENT_FACILITY_TMP B,
                                   ADM.INTF_CIF_CLIENT_CORP C,
                                   FDS_MOD_PROD_PARSE D
                              WHERE A.DATA_DATE = V_DATA_DATE                             
                                AND C.DATA_DATE = V_DATA_DATE
                                AND A.CLIENT_NO=B.CLIENT_NO
                                AND A.CLIENT_NO=C.CLIENT_NO
                                AND B.FACILITY <= 30000000
                                AND C.CORP_SIZE IN ('CS03','CS04')                    --CS03-小型企业，CSO4-微型企业
                                AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                                AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)               --单户合同汇总金额
                              --AND NVL(C.CORP_INVESTOR,'0') = NVL(D.SUBELEM4,NVL(C.CORP_INVESTOR,'0'))             --科技企业类型
                             -- AND C.DOCUMENT_TYPE = NVL(D.SUBELEM6,C.DOCUMENT_TYPE)  --证件类型
                                AND A.ON_OFF_BALANCE = 'ON'                           --ON-表内
                                AND A.BUSINESS_TYPE = 'CL200'                         --企业贷款组
                                AND SUBSTR(A.OCCUR_DATE,1,4) = SUBSTR(V_DATA_DATE,1,4) --发生日期=本年
                                AND B.DATA_DATE=UTIL.GET_MONTH_END_DATE(A.OCCUR_DATE) --数据日期=发生日期所在月月末 --20200902 zw add                                
                                AND D.PARSE_CODE = 'OSRS7101_1_D'
                           GROUP BY A.BRANCH,D.PROD_CODE ;
                          /* UNION ALL
                               SELECT 'S7101',
                                       A.ORG_CODE BRANCH,
                                       TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                       D.PROD_CODE PROD_CODE,
                                       CASE WHEN SUBSTR(V_DATA_DATE,1,6)='0131' THEN 0 --当年1月31日报送不需要上月报表数
                                            ELSE SUM (A.BALANCE)
                                       END BALANCE
                                  FROM FDS_REPORT_DATA A,
                                       FDS_MOD_PROD_PARSE D
                                  WHERE TO_CHAR (TO_DATE(V_LAST_MONTH_END_DATE,'YYYYMMDD'),'YYYY-MM-DD') = A.DATA_DT
                                    AND TO_CHAR (V_RUN_DATE, 'YYYYMMDD') = D.DATA_DATE
                                    AND A.INDICATOR=D.PROD_CODE
                                    AND D.PARSE_CODE = 'OSRS7101_1_D'
                               GROUP BY A.ORG_CODE,D.PROD_CODE*/
                COMMIT;

         V_STEP := '6.2';
         /*
         当年累放贷款额
           OSRS7101_2_D(D,D1,D2,D3,D4)
         1.1其中：普惠型涉农小微企业法人贷款
         */
                  INSERT INTO FDS_REPORT_DATA (REPORT_CODE,
                                ORG_CODE,
                                DATA_DT,
                                INDICATOR,
                                BALANCE)
                         SELECT 'S7101',
                            T.BRANCH,
                            TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                            T.PROD_CODE,
                            SUM (T.BALANCE)
                        FROM (
                             SELECT 'S7101',
                                    A.BRANCH,
                                    TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                    D.PROD_CODE PROD_CODE,
                                    SUM (A.DD_AMT) BALANCE
                               FROM ADM.INTF_CL_LOAN_ACCT A,
                                    VISE.CLIENT_FACILITY_TMP B,
                                    ADM.INTF_CIF_CLIENT_CORP C,
                                    FDS_MOD_PROD_PARSE D
                              WHERE A.DATA_DATE = V_DATA_DATE
                                AND C.DATA_DATE = V_DATA_DATE
                                AND A.CLIENT_NO=B.CLIENT_NO
                                AND A.CLIENT_NO=C.CLIENT_NO
                                AND B.FACILITY <= 30000000
                                AND C.CORP_SIZE IN ('CS03','CS04')                    --CS03-小型企业，CSO4-微型企业
                                AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                                AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)               --单户合同汇总金额
                                AND A.ON_OFF_BALANCE = 'ON'                           --ON-表内
                                AND A.BUSINESS_TYPE = 'CL200'                         --企业贷款组
                                AND SUBSTR(A.OCCUR_DATE,1,4) = SUBSTR(V_DATA_DATE,1,4) --发生日期=本年
                                AND B.DATA_DATE=UTIL.GET_MONTH_END_DATE(A.OCCUR_DATE) --数据日期=发生日期所在月月末 --20200902 zw add
                                AND C.DISTRICT = 'V'     --V-农村
                                AND D.PARSE_CODE = 'OSRS7101_2_D'
                           GROUP BY A.BRANCH,D.PROD_CODE
                           UNION ALL
                           SELECT 'S7101',
                                    A.BRANCH,
                                    TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                    D.PROD_CODE PROD_CODE,
                                    SUM (A.DD_AMT) BALANCE
                               FROM ADM.INTF_CL_LOAN_ACCT A,
                                    VISE.CLIENT_FACILITY_TMP B,
                                    ADM.INTF_CIF_CLIENT_CORP C,
                                    FDS_MOD_PROD_PARSE D
                              WHERE A.DATA_DATE = V_DATA_DATE
                                AND C.DATA_DATE = V_DATA_DATE
                                AND A.CLIENT_NO=B.CLIENT_NO
                                AND A.CLIENT_NO=C.CLIENT_NO
                                AND B.FACILITY <= 30000000
                                AND C.CORP_SIZE IN ('CS03','CS04')                    --CS03-小型企业，CSO4-微型企业
                                AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                                AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)               --单户合同汇总金额
                                AND A.ON_OFF_BALANCE = 'ON'                           --ON-表内
                                AND A.BUSINESS_TYPE = 'CL200'                         --企业贷款组
                                AND SUBSTR(A.OCCUR_DATE,1,4) = SUBSTR(V_DATA_DATE,1,4) --发生日期=本年
                                AND B.DATA_DATE=UTIL.GET_MONTH_END_DATE(A.OCCUR_DATE) --数据日期=发生日期所在月月末 --20200902 zw add
                                AND C.DISTRICT = 'C'--D-城市
                                AND SUBSTR(A.INDUSTRY_CODE,1,1) = 'A' --A%-农林牧渔业
                                AND D.PARSE_CODE = 'OSRS7101_2_D'
                           GROUP BY A.BRANCH,D.PROD_CODE
                           UNION ALL
                           SELECT 'S7101',
                                    A.BRANCH,
                                    TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                    D.PROD_CODE PROD_CODE,
                                    SUM (A.DD_AMT) BALANCE
                               FROM ADM.INTF_CL_LOAN_ACCT A,
                                    VISE.CLIENT_FACILITY_TMP B,
                                    ADM.INTF_CIF_CLIENT_CORP C,
                                    FDS_MOD_PROD_PARSE D
                              WHERE A.DATA_DATE = V_DATA_DATE
                                AND C.DATA_DATE = V_DATA_DATE
                                AND A.CLIENT_NO=B.CLIENT_NO
                                AND A.CLIENT_NO=C.CLIENT_NO
                                AND B.FACILITY <= 30000000
                                AND C.CORP_SIZE IN ('CS03','CS04')                    --CS03-小型企业，CSO4-微型企业
                                AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                                AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)               --单户合同汇总金额
                                AND A.ON_OFF_BALANCE = 'ON'                           --ON-表内
                                AND A.BUSINESS_TYPE = 'CL200'                         --企业贷款组
                                AND SUBSTR(A.OCCUR_DATE,1,4) = SUBSTR(V_DATA_DATE,1,4) --发生日期=本年
                                AND B.DATA_DATE=UTIL.GET_MONTH_END_DATE(A.OCCUR_DATE) --数据日期=发生日期所在月月末 --20200902 zw add
                                AND C.DISTRICT = 'C'--D-城市
                                AND A.FARM_LOAN_TYPE IN ('E1','E2','E3','E4','E5','E6','E7') --E1-农田基本建设贷款  E2-农产品加工贷款 E3-农业生产资料制造贷款
                                                                                          --E4-农产品出口贷款   E5-其他农用物资和农副产品流通贷款  --E6-农业科技贷款   E7-农村基础设施建设贷款
                                AND D.PARSE_CODE = 'OSRS7101_2_D'
                           GROUP BY A.BRANCH,D.PROD_CODE
                          /* UNION ALL
                           SELECT 'S7101',
                                       A.ORG_CODE BRANCH,
                                       TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                       D.PROD_CODE PROD_CODE,
                                       CASE WHEN SUBSTR(V_DATA_DATE,1,6)='0131' THEN 0 --当年1月31日报送不需要上月报表数
                                            ELSE SUM (A.BALANCE)
                                       END BALANCE
                                  FROM FDS_REPORT_DATA A,
                                       FDS_MOD_PROD_PARSE D
                                  WHERE TO_CHAR (TO_DATE(V_LAST_MONTH_END_DATE,'YYYYMMDD'),'YYYY-MM-DD') = A.DATA_DT
                                    AND D.DATA_DATE = V_DATA_DATE
                                    AND A.INDICATOR=D.PROD_CODE
                                    AND D.PARSE_CODE = 'OSRS7101_2_D'
                               GROUP BY A.ORG_CODE,D.PROD_CODE*/
                           )T
                           GROUP BY T.BRANCH,T.PROD_CODE;
                        COMMIT;

             V_STEP := '6.3';
              /*
              当年累放贷款额
              OSRS7101_3_D(D,D1,D2,D3,D4)
              1.3其中：小微企业法人创业担保贷款
              *//*
                  INSERT INTO FDS_REPORT_DATA (REPORT_CODE,
                                ORG_CODE,
                                DATA_DT,
                                INDICATOR,
                                BALANCE)
                         SELECT 'S7101',
                            T.BRANCH,
                            TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                            T.PROD_CODE,
                            SUM (T.BALANCE)
                        FROM (
                             SELECT 'S7101',
                                    A.BRANCH BRANCH,
                                    TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                    D.PROD_CODE PROD_CODE,
                                    SUM (A.DD_AMT) BALANCE
                               FROM ADM.INTF_CL_LOAN_ACCT A,
                                    VISE.CLIENT_FACILITY_TMP B,
                                    ADM.INTF_CIF_CLIENT_CORP C,
                                    FDS_MOD_PROD_PARSE D
                              WHERE A.DATA_DATE = V_DATA_DATE
                                AND C.DATA_DATE = V_DATA_DATE
                                AND A.CLIENT_NO = B.CLIENT_NO
                                AND A.CLIENT_NO = C.CLIENT_NO
                                AND B.FACILITY <= 30000000
                                AND C.CORP_SIZE IN ('CS03','CS04')                     --CS03-小型企业，CSO4-微型企业
                                AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                                AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)                --单户合同汇总金额
                                --DELETE BY ZHOUDE ON 20190626 BELOWN
                                --AND A.VENTURE_GUARANT_TYPE IN('1','2','3','4','5')     --创业担保贷款主体类型1-城镇登记失业人员,2-就业困难人员（含残疾人）,3-复员转业退役军人
                                --DELETE BY ZHOUDE ON 20190626 ABOVE                                                       --4-刑满释放人员,5-高校毕业生（不含大学生村官和留学回国学生
                                AND A.ON_OFF_BALANCE = 'ON'                            --ON-表内
                                AND A.BUSINESS_TYPE = 'CL200'                         --企业贷款组
                                AND SUBSTR(A.OCCUR_DATE,1,6) = SUBSTR(V_DATA_DATE,1,6) --发生日期=本月
                                AND D.PARSE_CODE = 'OSRS7101_3_D'
                           GROUP BY A.BRANCH,D.PROD_CODE
                           UNION ALL
                           SELECT 'S7101',
                                       A.ORG_CODE BRANCH,
                                       TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                       D.PROD_CODE PROD_CODE,
                                       CASE WHEN SUBSTR(V_DATA_DATE,1,6)='0131' THEN 0 --当年1月31日报送不需要上月报表数
                                            ELSE SUM (A.BALANCE)
                                       END BALANCE
                                  FROM FDS_REPORT_DATA A,
                                       FDS_MOD_PROD_PARSE D
                                  WHERE TO_CHAR (TO_DATE(V_LAST_MONTH_END_DATE,'YYYYMMDD'),'YYYY-MM-DD') = A.DATA_DT
                                    AND TO_CHAR (V_RUN_DATE, 'YYYYMMDD') = D.DATA_DATE
                                    AND A.INDICATOR=D.PROD_CODE
                                    AND D.PARSE_CODE = 'OSRS7101_3_D'
                               GROUP BY A.ORG_CODE,D.PROD_CODE
                           )T
                           GROUP BY T.BRANCH,T.PROD_CODE;
                       COMMIT;
                  */
            V_STEP := '6.4';
           /*
           当年累放贷款额
           OSRS7101_4_D(D,D1,D2,D3,D4)
            3.1其中：普惠型个体工商户贷款
            */
                  INSERT INTO FDS_REPORT_DATA (REPORT_CODE,
                                ORG_CODE,
                                DATA_DT,
                                INDICATOR,
                                BALANCE)
                         /*SELECT 'S7101',
                            T.BRANCH,
                            TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                            T.PROD_CODE,
                            SUM(T.BALANCE)
                        FROM (*/
                             SELECT 'S7101',
                                    A.BRANCH BRANCH,
                                    TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                    D.PROD_CODE PROD_CODE,
                                    SUM (A.DD_AMT) BALANCE
                               FROM ADM.INTF_CL_LOAN_ACCT A,
                                    VISE.CLIENT_FACILITY_TMPi B,
                                    FDS_MOD_PROD_PARSE D
                              WHERE A.DATA_DATE = V_DATA_DATE
                                AND A.CLIENT_NO = B.CLIENT_NO
																AND A.BUSINESS_SUB_TYPE='A18' -- A18-个体工商户
                                AND B.FACILITY <= 30000000
                                AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                                AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)                --单户合同汇总金额
                                AND A.ON_OFF_BALANCE = 'ON'                            --ON-表内
                                AND SUBSTR(A.OCCUR_DATE,1,4) = SUBSTR(V_DATA_DATE,1,4) --发生日期
                                AND B.DATA_DATE=UTIL.GET_MONTH_END_DATE(A.OCCUR_DATE) --数据日期=发生日期所在月月末 --20200902 zw add
                                AND D.PARSE_CODE = 'OSRS7101_4_D'
                           GROUP BY A.BRANCH,D.PROD_CODE;
                         /*  UNION ALL
                           SELECT 'S7101',
                                       A.ORG_CODE BRANCH,
                                       TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                       D.PROD_CODE PROD_CODE,
                                       CASE WHEN SUBSTR(V_DATA_DATE,1,6)='0131' THEN 0 --当年1月31日报送不需要上月报表数
                                            ELSE SUM (A.BALANCE)
                                       END BALANCE
                                  FROM FDS_REPORT_DATA A,
                                       FDS_MOD_PROD_PARSE D
                                  WHERE TO_CHAR (TO_DATE(V_LAST_MONTH_END_DATE,'YYYYMMDD'),'YYYY-MM-DD') = A.DATA_DT
                                    AND TO_CHAR (V_RUN_DATE, 'YYYYMMDD') = D.DATA_DATE
                                    AND A.INDICATOR=D.PROD_CODE
                                    AND D.PARSE_CODE = 'OSRS7101_4_D'
                               GROUP BY A.ORG_CODE,D.PROD_CODE)T
                               GROUP BY T.BRANCH,T.PROD_CODE; */
                       COMMIT;

           V_STEP := '6.5';
           /*
           当年累放贷款额
           OSRS7101_5_D(D,D1,D2,D3,D4)
            3.2其中：普惠型小微企业主贷款
            */
                  INSERT INTO FDS_REPORT_DATA (REPORT_CODE,
                                ORG_CODE,
                                DATA_DT,
                                INDICATOR,
                                BALANCE)
                       /*  SELECT 'S7101',
                            T.BRANCH,
                            TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                            T.PROD_CODE,
                            SUM (T.BALANCE)
                        FROM ( */
                             SELECT 'S7101',
                                    A.BRANCH BRANCH,
                                    TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                    D.PROD_CODE PROD_CODE,
                                    SUM (A.DD_AMT) BALANCE
                               FROM ADM.INTF_CL_LOAN_ACCT A,
                                    VISE.CLIENT_FACILITY_TMPI B,
                                    FDS_MOD_PROD_PARSE D
                              WHERE A.DATA_DATE = V_DATA_DATE
                                AND A.CLIENT_NO = B.CLIENT_NO
																AND A.BUSINESS_SUB_TYPE='A17' -- A17-小微企业主
                                AND B.FACILITY <= 30000000
                                --AND A.BUSINESS_SUB_TYPE = D.SUBELEM3
                                AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                                AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)                --单户合同汇总金额
                                AND A.ON_OFF_BALANCE = 'ON'                            --ON-表内
                                AND SUBSTR(A.OCCUR_DATE,1,4) = SUBSTR(V_DATA_DATE,1,4) --发生日期
                                AND B.DATA_DATE=UTIL.GET_MONTH_END_DATE(A.OCCUR_DATE) --数据日期=发生日期所在月月末 --20200902 zw add
                                AND D.PARSE_CODE = 'OSRS7101_5_D'
                           GROUP BY A.BRANCH,D.PROD_CODE;
                          /* UNION ALL
                           SELECT 'S7101',
                                       A.ORG_CODE BRANCH,
                                       TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                       D.PROD_CODE PROD_CODE,
                                       CASE WHEN SUBSTR(V_DATA_DATE,1,6)='0131' THEN 0 --当年1月31日报送不需要上月报表数
                                            ELSE SUM (A.BALANCE)
                                       END BALANCE
                                  FROM FDS_REPORT_DATA A,
                                       FDS_MOD_PROD_PARSE D
                                  WHERE TO_CHAR (TO_DATE(V_LAST_MONTH_END_DATE,'YYYYMMDD'),'YYYY-MM-DD') = A.DATA_DT
                                    AND TO_CHAR (V_RUN_DATE, 'YYYYMMDD') = D.DATA_DATE
                                    AND A.INDICATOR=D.PROD_CODE
                                    AND D.PARSE_CODE = 'OSRS7101_5_D'
                               GROUP BY A.ORG_CODE,D.PROD_CODE)T
                               GROUP BY T.BRANCH,T.PROD_CODE;*/

               COMMIT;


      V_STEP := '7';
          /*
          当年累放贷款户数
           OSRS7101_1_E(E,E1,E2,E3,E4)
             1.普惠型小微企业法人贷款
             1.2其中：普惠型科创小微企业法人贷款
             1.4 其中：普惠型农村集体经济组织贷款
             1.5 其中：普惠型农民专业合作社贷款
             2.普惠型其它组织贷款
          */
   V_STEP := '7.1';
    INSERT INTO FDS_REPORT_DATA (REPORT_CODE,
                                ORG_CODE,
                                DATA_DT,
                                INDICATOR,
                                BALANCE)
                       /*  SELECT 'S7101',
                            T.BRANCH,
                            TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                            T.PROD_CODE,
                            SUM (T.BALANCE)
                        FROM (*/
                             SELECT 'S7101',
                                    A.BRANCH BRANCH,
                                    TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                    D.PROD_CODE PROD_CODE,
                                    COUNT(DISTINCT A.CLIENT_NO) BALANCE
                               FROM ADM.INTF_CL_LOAN_ACCT A,
                                    VISE.CLIENT_FACILITY_TMP B,
                                    ADM.INTF_CIF_CLIENT_CORP C,
                                    FDS_MOD_PROD_PARSE D
                              WHERE A.DATA_DATE = V_DATA_DATE
                                AND C.DATA_DATE = V_DATA_DATE
                                AND A.CLIENT_NO = B.CLIENT_NO
                                AND A.CLIENT_NO = C.CLIENT_NO
                                AND B.FACILITY <= 30000000
                                AND C.CORP_SIZE IN ('CS03','CS04')                     --CS03-小型企业，CSO4-微型企业
                                AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                                AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)                --单户合同汇总金额
                             -- AND NVL(C.CORP_INVESTOR,'0') = NVL(NVL(D.SUBELEM4,C.CORP_INVESTOR),'0')    --科技企业类型
                             -- AND C.DOCUMENT_TYPE = NVL(D.SUBELEM6,C.DOCUMENT_TYPE)  --证件类型
                                AND A.ON_OFF_BALANCE = 'ON'                            --ON-表内
                                AND A.BUSINESS_TYPE = 'CL200'                         --企业贷款组
                                AND SUBSTR(A.OCCUR_DATE,1,4) = SUBSTR(V_DATA_DATE,1,4) --发生日期=本年
                                AND B.DATA_DATE=UTIL.GET_MONTH_END_DATE(A.OCCUR_DATE) --数据日期=发生日期所在月月末 --20200902 zw add
                                AND A.DD_AMT > 0                                         --发放金额>0
                                AND D.PARSE_CODE = 'OSRS7101_1_E'
                           GROUP BY A.BRANCH,D.PROD_CODE;
                          /* UNION ALL
                           SELECT 'S7101',
                                       A.ORG_CODE BRANCH,
                                       TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                       D.PROD_CODE PROD_CODE,
                                       CASE WHEN SUBSTR(V_DATA_DATE,1,6)='0131' THEN 0 --当年1月31日报送不需要上月报表数
                                            ELSE SUM (A.BALANCE)
                                       END BALANCE
                                  FROM FDS_REPORT_DATA A,
                                       FDS_MOD_PROD_PARSE D
                                  WHERE TO_CHAR (TO_DATE(V_LAST_MONTH_END_DATE,'YYYYMMDD'),'YYYY-MM-DD') = A.DATA_DT
                                    AND TO_CHAR (V_RUN_DATE, 'YYYYMMDD') = D.DATA_DATE
                                    AND A.INDICATOR=D.PROD_CODE
                                    AND D.PARSE_CODE = 'OSRS7101_1_E'
                               GROUP BY A.ORG_CODE,D.PROD_CODE)T
                               GROUP BY T.BRANCH,T.PROD_CODE;8/
                COMMIT;

            V_STEP := '7.2';
            /*
            当年累放贷款户数
           OSRS7101_2_E(E,E1,E2,E3,E4)
            1.1其中：普惠型涉农小微企业法人贷款
            */
                  INSERT INTO FDS_REPORT_DATA (REPORT_CODE,
                                ORG_CODE,
                                DATA_DT,
                                INDICATOR,
                                BALANCE)
                         SELECT 'S7101',
                            T.BRANCH,
                            TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                            T.PROD_CODE,
                            SUM (T.BALANCE)
                        FROM (
                             SELECT 'S7101',
                                    A.BRANCH BRANCH,
                                    TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                    D.PROD_CODE PROD_CODE,
                                    COUNT(DISTINCT A.CLIENT_NO) BALANCE
                               FROM ADM.INTF_CL_LOAN_ACCT A,
                                    VISE.CLIENT_FACILITY_TMP B,
                                    ADM.INTF_CIF_CLIENT_CORP C,
                                    FDS_MOD_PROD_PARSE D
                              WHERE A.DATA_DATE = V_DATA_DATE
                                AND C.DATA_DATE = V_DATA_DATE
                                AND A.CLIENT_NO = B.CLIENT_NO
                                AND A.CLIENT_NO = C.CLIENT_NO
                                AND B.FACILITY <= 30000000
                                AND C.CORP_SIZE IN ('CS03','CS04')                    --CS03-小型企业，CSO4-微型企业
                                AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                                AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)               --单户合同汇总金额
                                AND A.ON_OFF_BALANCE = 'ON'                           --ON-表内
                                AND A.BUSINESS_TYPE = 'CL200'                         --企业贷款组
                                AND SUBSTR(A.OCCUR_DATE,1,4) = SUBSTR(V_DATA_DATE,1,4) --发生日期=本年
                                AND B.DATA_DATE=UTIL.GET_MONTH_END_DATE(A.OCCUR_DATE) --数据日期=发生日期所在月月末 --20200902 zw add
                                AND A.DD_AMT>0                                          --发放金额>0
                                AND C.DISTRICT = 'V'      --V-农村
                                AND D.PARSE_CODE = 'OSRS7101_2_E'
                           GROUP BY A.BRANCH,D.PROD_CODE
                           UNION ALL
                           SELECT 'S7101',
                                    A.BRANCH BRANCH,
                                    TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                    D.PROD_CODE PROD_CODE,
                                    COUNT(DISTINCT A.CLIENT_NO) BALANCE
                               FROM ADM.INTF_CL_LOAN_ACCT A,
                                    VISE.CLIENT_FACILITY_TMP B,
                                    ADM.INTF_CIF_CLIENT_CORP C,
                                    FDS_MOD_PROD_PARSE D
                              WHERE A.DATA_DATE = V_DATA_DATE
                                AND C.DATA_DATE = V_DATA_DATE
                                AND A.CLIENT_NO = B.CLIENT_NO
                                AND A.CLIENT_NO = C.CLIENT_NO
                                AND B.FACILITY <= 30000000
                                AND C.CORP_SIZE IN ('CS03','CS04')                    --CS03-小型企业，CSO4-微型企业
                                AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                                AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)               --单户合同汇总金额
                                AND A.ON_OFF_BALANCE = 'ON'                           --ON-表内
                                AND A.BUSINESS_TYPE = 'CL200'                         --企业贷款组
                                AND SUBSTR(A.OCCUR_DATE,1,4) = SUBSTR(V_DATA_DATE,1,4) --发生日期=本年
                                AND B.DATA_DATE=UTIL.GET_MONTH_END_DATE(A.OCCUR_DATE) --数据日期=发生日期所在月月末 --20200902 zw add
                                AND A.DD_AMT>0                                          --发放金额>0
                                AND C.DISTRICT = 'C' --D-城市
                                AND SUBSTR(A.INDUSTRY_CODE,1,1) = 'A' --A%-农林牧渔业
                                AND D.PARSE_CODE = 'OSRS7101_2_E'
                           GROUP BY A.BRANCH,D.PROD_CODE
                           UNION ALL
                           SELECT 'S7101',
                                    A.BRANCH BRANCH,
                                    TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                    D.PROD_CODE PROD_CODE,
                                    COUNT(DISTINCT A.CLIENT_NO) BALANCE
                               FROM ADM.INTF_CL_LOAN_ACCT A,
                                    VISE.CLIENT_FACILITY_TMP B,
                                    ADM.INTF_CIF_CLIENT_CORP C,
                                    FDS_MOD_PROD_PARSE D
                              WHERE A.DATA_DATE = V_DATA_DATE
                                AND C.DATA_DATE = V_DATA_DATE
                                AND A.CLIENT_NO = B.CLIENT_NO
                                AND A.CLIENT_NO = C.CLIENT_NO
                                AND B.FACILITY <= 30000000
                                AND C.CORP_SIZE IN ('CS03','CS04')                    --CS03-小型企业，CSO4-微型企业
                                AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                                AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)               --单户合同汇总金额
                                AND A.ON_OFF_BALANCE = 'ON'                           --ON-表内
                                AND A.BUSINESS_TYPE = 'CL200'                         --企业贷款组
                                AND SUBSTR(A.OCCUR_DATE,1,4) = SUBSTR(V_DATA_DATE,1,4) --发生日期=本年
                                AND B.DATA_DATE=UTIL.GET_MONTH_END_DATE(A.OCCUR_DATE) --数据日期=发生日期所在月月末 --20200902 zw add
                                AND A.DD_AMT>0                                          --发放金额>0
                                AND C.DISTRICT = 'C' --D-城市
                                AND A.FARM_LOAN_TYPE IN ('E1','E2','E3','E4','E5','E6','E7') --E1-农田基本建设贷款  E2-农产品加工贷款 E3-农业生产资料制造贷款
                                                                                      --E4-农产品出口贷款   E5-其他农用物资和农副产品流通贷款  --E6-农业科技贷款   E7-农村基础设施建设贷款
                                AND D.PARSE_CODE = 'OSRS7101_2_E'
                           GROUP BY A.BRANCH,D.PROD_CODE
                          /* UNION ALL
                           SELECT 'S7101',
                                       A.ORG_CODE BRANCH,
                                       TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                       D.PROD_CODE PROD_CODE,
                                       CASE WHEN SUBSTR(V_DATA_DATE,1,6)='0131' THEN 0 --当年1月31日报送不需要上月报表数
                                            ELSE SUM (A.BALANCE)
                                       END BALANCE
                                  FROM FDS_REPORT_DATA A,
                                       FDS_MOD_PROD_PARSE D
                                  WHERE TO_CHAR (TO_DATE(V_LAST_MONTH_END_DATE,'YYYYMMDD'),'YYYY-MM-DD') = A.DATA_DT
                                    AND TO_CHAR (V_RUN_DATE, 'YYYYMMDD') = D.DATA_DATE
                                    AND A.INDICATOR=D.PROD_CODE
                                    AND D.PARSE_CODE = 'OSRS7101_2_E'
                               GROUP BY A.ORG_CODE,D.PROD_CODE*/
                               )T
                               GROUP BY T.BRANCH,T.PROD_CODE;
                        COMMIT;

            V_STEP := '7.3';
            /*
            当年累放贷款户数
           OSRS7101_3_E(E,E1,E2,E3,E4)
           1.3其中：小微企业法人创业担保贷款
           */
                /*  INSERT INTO FDS_REPORT_DATA (REPORT_CODE,
                                ORG_CODE,
                                DATA_DT,
                                INDICATOR,
                                BALANCE)
                        /* SELECT 'S7101',
                            T.BRANCH,
                            TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                            T.PROD_CODE,
                            SUM (T.BALANCE)
                        FROM (*/
                            /* SELECT 'S7101',
                                    A.BRANCH BRANCH,
                                    TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                    D.PROD_CODE PROD_CODE,
                                    COUNT(DISTINCT A.CLIENT_NO) BALANCE
                               FROM ADM.INTF_CL_LOAN_ACCT A,
                                    VISE.CLIENT_FACILITY_TMP B,
                                    ADM.INTF_CIF_CLIENT_CORP C,
                                    FDS_MOD_PROD_PARSE D
                              WHERE A.DATA_DATE = V_DATA_DATE
                                AND C.DATA_DATE = V_DATA_DATE
                                AND A.CLIENT_NO = B.CLIENT_NO
                                AND A.CLIENT_NO = C.CLIENT_NO
                                AND B.FACILITY <= 30000000
                                AND C.CORP_SIZE IN ('CS03','CS04')                     --CS03-小型企业，CSO4-微型企业
                                AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                                AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)                --单户合同汇总金额
                                --DELETE BY ZHOUDE ON 20190624 BELOW
                                --AND A.VENTURE_GUARANT_TYPE IN('1','2','3','4','5')     --创业担保贷款主体类型1-城镇登记失业人员,2-就业困难人员（含残疾人）,3-复员转业退役军人
                                --DELETE BY ZHOUDE ON 20190624 ABOVE                                                       --4-刑满释放人员,5-高校毕业生（不含大学生村官和留学回国学生
                                AND A.ON_OFF_BALANCE = 'ON'                            --ON-表内
                                AND A.BUSINESS_TYPE = 'CL200'                         --企业贷款组
                                AND SUBSTR(A.OCCUR_DATE,1,6) = SUBSTR(V_DATA_DATE,1,6) --发生日期=本月
                                AND A.DD_AMT>0                                         --发放金额>0
                                AND D.PARSE_CODE = 'OSRS7101_3_E'
                           GROUP BY A.BRANCH,D.PROD_CODE;
                          /* UNION ALL
                           SELECT 'S7101',
                                       A.ORG_CODE BRANCH,
                                       TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                       D.PROD_CODE PROD_CODE,
                                       CASE WHEN SUBSTR(V_DATA_DATE,1,6)='0131' THEN 0 --当年1月31日报送不需要上月报表数
                                            ELSE SUM (A.BALANCE)
                                       END BALANCE
                                  FROM FDS_REPORT_DATA A,
                                       FDS_MOD_PROD_PARSE D
                                  WHERE TO_CHAR (TO_DATE(V_LAST_MONTH_END_DATE,'YYYYMMDD'),'YYYY-MM-DD') = A.DATA_DT
                                    AND TO_CHAR (V_RUN_DATE, 'YYYYMMDD') = D.DATA_DATE
                                    AND A.INDICATOR=D.PROD_CODE
                                    AND D.PARSE_CODE = 'OSRS7101_3_E'
                               GROUP BY A.ORG_CODE,D.PROD_CODE)T
                               GROUP BY T.BRANCH,T.PROD_CODE;*/
--                        COMMIT;

           V_STEP := '7.4';
           /*
           当年累放贷款户数
           OSRS7101_4_E(E,E1,E2,E3,E4)
            3.1其中：普惠型个体工商户贷款
            */
                  INSERT INTO FDS_REPORT_DATA (REPORT_CODE,
                                ORG_CODE,
                                DATA_DT,
                                INDICATOR,
                                BALANCE)
                       /*  SELECT 'S7101',
                            T.BRANCH,
                            TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                            T.PROD_CODE,
                            SUM (T.BALANCE)
                        FROM (*/
                             SELECT 'S7101',
                                    A.BRANCH BRANCH,
                                    TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                    D.PROD_CODE PROD_CODE,
                                    COUNT(DISTINCT A.CLIENT_NO) BALANCE
                               FROM ADM.INTF_CL_LOAN_ACCT A,
                                    VISE.CLIENT_FACILITY_TMPI B, 
                                    FDS_MOD_PROD_PARSE D
                              WHERE A.DATA_DATE = V_DATA_DATE
                                AND A.CLIENT_NO = B.CLIENT_NO
                                AND B.FACILITY <= 30000000
																AND A.BUSINESS_SUB_TYPE='A18' -- A18-个体工商户
                                AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                                AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)                --单户合同汇总金额
                                AND A.ON_OFF_BALANCE = 'ON'                            --ON-表内
                                AND SUBSTR(A.OCCUR_DATE,1,4) = SUBSTR(V_DATA_DATE,1,4) --发生日期
                                AND B.DATA_DATE=UTIL.GET_MONTH_END_DATE(A.OCCUR_DATE) --数据日期=发生日期所在月月末 --20200902 zw add
                                AND A.DD_AMT>0                                         --发放金额>0
                                AND D.PARSE_CODE = 'OSRS7101_4_E'
                           GROUP BY A.BRANCH,D.PROD_CODE;
                         /*  UNION ALL
                           SELECT 'S7101',
                                       A.ORG_CODE BRANCH,
                                       TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                       D.PROD_CODE PROD_CODE,
                                       CASE WHEN SUBSTR(V_DATA_DATE,1,6)='0131' THEN 0 --当年1月31日报送不需要上月报表数
                                            ELSE SUM (A.BALANCE)
                                       END BALANCE
                                  FROM FDS_REPORT_DATA A,
                                       FDS_MOD_PROD_PARSE D
                                  WHERE TO_CHAR (TO_DATE(V_LAST_MONTH_END_DATE,'YYYYMMDD'),'YYYY-MM-DD') = A.DATA_DT
                                    AND TO_CHAR (V_RUN_DATE, 'YYYYMMDD') = D.DATA_DATE
                                    AND A.INDICATOR=D.PROD_CODE
                                    AND D.PARSE_CODE = 'OSRS7101_4_E'
                               GROUP BY A.ORG_CODE,D.PROD_CODE)T
                               GROUP BY T.BRANCH,T.PROD_CODE;*/
                       COMMIT;
                     
         V_STEP := '7.5';
         /*
          当年累放贷款户数
           OSRS7101_5_E(E,E1,E2,E3,E4)
          3.2其中：普惠型小微企业主贷款
          */
                  INSERT INTO FDS_REPORT_DATA (REPORT_CODE,
                                ORG_CODE,
                                DATA_DT,
                                INDICATOR,
                                BALANCE)
                        /* SELECT 'S7101',
                            T.BRANCH,
                            TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                            T.PROD_CODE,
                            SUM (T.BALANCE)
                        FROM */
                             SELECT 'S7101',
                                    A.BRANCH BRANCH,
                                    TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                    D.PROD_CODE PROD_CODE,
                                    COUNT(DISTINCT A.CLIENT_NO) BALANCE
                               FROM ADM.INTF_CL_LOAN_ACCT A,
                                    VISE.CLIENT_FACILITY_TMPI B,
                                    FDS_MOD_PROD_PARSE D
                              WHERE A.DATA_DATE = V_DATA_DATE
                                AND A.CLIENT_NO = B.CLIENT_NO
                                AND B.FACILITY <= 30000000
																AND A.BUSINESS_SUB_TYPE='A17' -- A17-小微企业主 
                                --AND A.BUSINESS_SUB_TYPE = D.SUBELEM3
                                AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                                AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)                --单户合同汇总金额
                                AND A.ON_OFF_BALANCE = 'ON'                            --ON-表内
                                AND SUBSTR(A.OCCUR_DATE,1,4) = SUBSTR(V_DATA_DATE,1,4) --发生日期
                                AND B.DATA_DATE=UTIL.GET_MONTH_END_DATE(A.OCCUR_DATE) --数据日期=发生日期所在月月末 --20200902 zw add
                                AND A.DD_AMT>0                                         --发放金额>0
                                AND D.PARSE_CODE = 'OSRS7101_5_E'
                           GROUP BY A.BRANCH,D.PROD_CODE;
                          /* UNION ALL
                           SELECT 'S7101',
                                       A.ORG_CODE BRANCH,
                                       TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                       D.PROD_CODE PROD_CODE,
                                       CASE WHEN SUBSTR(V_DATA_DATE,1,6)='0131' THEN 0 --当年1月31日报送不需要上月报表数
                                            ELSE SUM (A.BALANCE)
                                       END BALANCE
                                  FROM FDS_REPORT_DATA A,
                                       FDS_MOD_PROD_PARSE D
                                  WHERE TO_CHAR (TO_DATE(V_LAST_MONTH_END_DATE,'YYYYMMDD'),'YYYY-MM-DD') = A.DATA_DT
                                    AND TO_CHAR (V_RUN_DATE, 'YYYYMMDD') = D.DATA_DATE
                                    AND A.INDICATOR=D.PROD_CODE
                                    AND D.PARSE_CODE = 'OSRS7101_5_E'
                               GROUP BY A.ORG_CODE,D.PROD_CODE)T
                               GROUP BY T.BRANCH,T.PROD_CODE;*/
              COMMIT;


         V_STEP := '8';
          /*
          当年累放贷款年化利息收益
           OSRS7101_1_F(F,F1,F2,F3,F4)
             1.普惠型小微企业法人贷款
             1.2其中：普惠型科创小微企业法人贷款
             1.4 其中：普惠型农村集体经济组织贷款
             1.5 其中：普惠型农民专业合作社贷款
             2.普惠型其它组织贷款
          */
   V_STEP := '8.1';
    INSERT INTO FDS_REPORT_DATA (REPORT_CODE,
                                ORG_CODE,
                                DATA_DT,
                                INDICATOR,
                                BALANCE)
                        /* SELECT 'S7101',
                            T.BRANCH,
                            TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                            T.PROD_CODE,
                            SUM (T.BALANCE)
                        FROM (*/
                             SELECT 'S7101',
                                    A.BRANCH BRANCH,
                                    TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                    D.PROD_CODE PROD_CODE,
                                    SUM (A.DD_AMT*A.INT_RATE*0.01) BALANCE
                               FROM ADM.INTF_CL_LOAN_ACCT A,
                                    VISE.CLIENT_FACILITY_TMP B,
                                    ADM.INTF_CIF_CLIENT_CORP C,
                                    FDS_MOD_PROD_PARSE D
                              WHERE A.DATA_DATE = V_DATA_DATE
                                AND C.DATA_DATE = V_DATA_DATE
                                AND A.CLIENT_NO=C.CLIENT_NO
                                AND B.CLIENT_NO=C.CLIENT_NO
                                AND B.FACILITY <= 30000000
                                AND C.CORP_SIZE IN ('CS03','CS04')                     --CS03-小型企业，CSO4-微型企业
                                AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                                AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)                --单户合同汇总金额
                             --AND NVL(C.CORP_INVESTOR,'0') = NVL(NVL(D.SUBELEM4,C.CORP_INVESTOR),'0')               --科技企业类型
                             --AND C.DOCUMENT_TYPE = NVL(D.SUBELEM6,C.DOCUMENT_TYPE)  --证件类型
                                AND A.ON_OFF_BALANCE = 'ON'                            --ON-表内
                                AND A.BUSINESS_TYPE = 'CL200'                         --企业贷款组
                                AND SUBSTR(A.OCCUR_DATE,1,4) = SUBSTR(V_DATA_DATE,1,4) --发生日期=本年
                                AND B.DATA_DATE=UTIL.GET_MONTH_END_DATE(A.OCCUR_DATE) --数据日期=发生日期所在月月末 --20200902 zw add
                                AND D.PARSE_CODE = 'OSRS7101_1_F'
                           GROUP BY A.BRANCH,D.PROD_CODE;
                          /* UNION ALL
                           SELECT 'S7101',
                                       A.ORG_CODE BRANCH,
                                       TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                       D.PROD_CODE PROD_CODE,
                                       CASE WHEN SUBSTR(V_DATA_DATE,1,6)='0131' THEN 0 --当年1月31日报送不需要上月报表数
                                            ELSE SUM (A.BALANCE)
                                       END BALANCE
                                  FROM FDS_REPORT_DATA A,
                                       FDS_MOD_PROD_PARSE D
                                  WHERE TO_CHAR (TO_DATE(V_LAST_MONTH_END_DATE,'YYYYMMDD'),'YYYY-MM-DD') = A.DATA_DT
                                    AND TO_CHAR (V_RUN_DATE, 'YYYYMMDD') = D.DATA_DATE
                                    AND A.INDICATOR=D.PROD_CODE
                                    AND D.PARSE_CODE = 'OSRS7101_1_F'
                               GROUP BY A.ORG_CODE,D.PROD_CODE)T
                               GROUP BY T.BRANCH,T.PROD_CODE;*/
                COMMIT;

         V_STEP := '8.2';
          /*
          当年累放贷款年化利息收益
           OSRS7101_2_F(F,F1,F2,F3,F4)
          1.1其中：普惠型涉农小微企业法人贷款
          */
                  INSERT INTO FDS_REPORT_DATA (REPORT_CODE,
                                ORG_CODE,
                                DATA_DT,
                                INDICATOR,
                                BALANCE)
                         SELECT 'S7101',
                            T.BRANCH,
                            TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                            T.PROD_CODE,
                            SUM (T.BALANCE)
                        FROM (
                             SELECT 'S7101',
                                    A.BRANCH BRANCH,
                                    TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                    D.PROD_CODE PROD_CODE,
                                    SUM (A.DD_AMT*A.INT_RATE*0.01) BALANCE
                               FROM ADM.INTF_CL_LOAN_ACCT A,
                                    VISE.CLIENT_FACILITY_TMP B,
                                    ADM.INTF_CIF_CLIENT_CORP C,
                                    FDS_MOD_PROD_PARSE D
                              WHERE A.DATA_DATE = V_DATA_DATE
                                AND C.DATA_DATE = V_DATA_DATE
                                AND A.CLIENT_NO=B.CLIENT_NO
                                AND A.CLIENT_NO=C.CLIENT_NO
                                AND B.FACILITY <= 30000000
                                AND C.CORP_SIZE IN ('CS03','CS04')                     --CS03-小型企业，CSO4-微型企业
                                AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                                AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)                --单户合同汇总金额
                                AND A.ON_OFF_BALANCE = 'ON'                            --ON-表内
                                AND A.BUSINESS_TYPE = 'CL200'                         --企业贷款组
                                AND SUBSTR(A.OCCUR_DATE,1,4) = SUBSTR(V_DATA_DATE,1,4) --发生日期=本年
                                AND B.DATA_DATE=UTIL.GET_MONTH_END_DATE(A.OCCUR_DATE) --数据日期=发生日期所在月月末 --20200902 zw add
                                AND C.DISTRICT = 'V'      --V-农村
                                AND D.PARSE_CODE = 'OSRS7101_2_F'
                           GROUP BY A.BRANCH,D.PROD_CODE
                           UNION ALL
                            SELECT 'S7101',
                                    A.BRANCH BRANCH,
                                    TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                    D.PROD_CODE PROD_CODE,
                                    SUM (A.DD_AMT*A.INT_RATE*0.01) BALANCE
                               FROM ADM.INTF_CL_LOAN_ACCT A,
                                    VISE.CLIENT_FACILITY_TMP B,
                                    ADM.INTF_CIF_CLIENT_CORP C,
                                    FDS_MOD_PROD_PARSE D
                              WHERE A.DATA_DATE = V_DATA_DATE
                                AND C.DATA_DATE = V_DATA_DATE
                                AND A.CLIENT_NO=B.CLIENT_NO
                                AND A.CLIENT_NO=C.CLIENT_NO
                                AND B.FACILITY <= 30000000
                                AND C.CORP_SIZE IN ('CS03','CS04')                     --CS03-小型企业，CSO4-微型企业
                                AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                                AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)                --单户合同汇总金额
                                AND A.ON_OFF_BALANCE = 'ON'                            --ON-表内
                                AND A.BUSINESS_TYPE = 'CL200'                         --企业贷款组
                                AND SUBSTR(A.OCCUR_DATE,1,4) = SUBSTR(V_DATA_DATE,1,4) --发生日期=本年
                                AND B.DATA_DATE=UTIL.GET_MONTH_END_DATE(A.OCCUR_DATE) --数据日期=发生日期所在月月末 --20200902 zw add
                                AND C.DISTRICT = 'C' --D-城市
                                AND SUBSTR(A.INDUSTRY_CODE,1,1) = 'A' --A%-农林牧渔业
                                AND D.PARSE_CODE = 'OSRS7101_2_F'
                           GROUP BY A.BRANCH,D.PROD_CODE
                           UNION ALL
                            SELECT 'S7101',
                                    A.BRANCH BRANCH,
                                    TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                    D.PROD_CODE PROD_CODE,
                                    SUM (A.DD_AMT*A.INT_RATE*0.01) BALANCE
                               FROM ADM.INTF_CL_LOAN_ACCT A,
                                    VISE.CLIENT_FACILITY_TMP B,
                                    ADM.INTF_CIF_CLIENT_CORP C,
                                    FDS_MOD_PROD_PARSE D
                              WHERE A.DATA_DATE = V_DATA_DATE
                                AND C.DATA_DATE = V_DATA_DATE
                                AND A.CLIENT_NO=B.CLIENT_NO
                                AND A.CLIENT_NO=C.CLIENT_NO
                                AND B.FACILITY <= 30000000
                                AND C.CORP_SIZE IN ('CS03','CS04')                     --CS03-小型企业，CSO4-微型企业
                                AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                                AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)                --单户合同汇总金额
                                AND A.ON_OFF_BALANCE = 'ON'                            --ON-表内
                                AND A.BUSINESS_TYPE = 'CL200'                         --企业贷款组
                                AND SUBSTR(A.OCCUR_DATE,1,4) = SUBSTR(V_DATA_DATE,1,4) --发生日期=本年
                                AND B.DATA_DATE=UTIL.GET_MONTH_END_DATE(A.OCCUR_DATE) --数据日期=发生日期所在月月末 --20200902 zw add
                                AND C.DISTRICT = 'C' --D-城市
                                AND A.FARM_LOAN_TYPE IN ('E1','E2','E3','E4','E5','E6','E7') --E1-农田基本建设贷款  E2-农产品加工贷款 E3-农业生产资料制造贷款
                                                                                            --E4-农产品出口贷款   E5-其他农用物资和农副产品流通贷款   --E6-农业科技贷款   E7-农村基础设施建设贷款
                                AND D.PARSE_CODE = 'OSRS7101_2_F'
                           GROUP BY A.BRANCH,D.PROD_CODE
                          /* UNION ALL
                           SELECT 'S7101',
                                       A.ORG_CODE BRANCH,
                                       TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                       D.PROD_CODE PROD_CODE,
                                       CASE WHEN SUBSTR(V_DATA_DATE,1,6)='0131' THEN 0 --当年1月31日报送不需要上月报表数
                                            ELSE SUM (A.BALANCE)
                                       END BALANCE
                                  FROM FDS_REPORT_DATA A,
                                       FDS_MOD_PROD_PARSE D
                                  WHERE TO_CHAR (TO_DATE(V_LAST_MONTH_END_DATE,'YYYYMMDD'),'YYYY-MM-DD') = A.DATA_DT
                                    AND TO_CHAR (V_RUN_DATE, 'YYYYMMDD') = D.DATA_DATE
                                    AND A.INDICATOR=D.PROD_CODE
                                    AND D.PARSE_CODE = 'OSRS7101_2_F'
                               GROUP BY A.ORG_CODE,D.PROD_CODE*/
                               )T
                               GROUP BY T.BRANCH,T.PROD_CODE;
                  COMMIT;

              V_STEP := '8.3';
              /*
              当年累放贷款年化利息收益
              OSRS7101_3_F(F,F1,F2,F3,F4)
              1.3其中：小微企业法人创业担保贷款
              */
               /*   INSERT INTO FDS_REPORT_DATA (REPORT_CODE,
                                ORG_CODE,
                                DATA_DT,
                                INDICATOR,
                                BALANCE)
                       /*  SELECT 'S7101',
                            T.BRANCH,
                            TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                            T.PROD_CODE,
                            SUM (T.BALANCE)
                        FROM (*/
                           /*  SELECT 'S7101',
                                    A.BRANCH BRANCH,
                                    TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                    D.PROD_CODE PROD_CODE,
                                    SUM (A.DD_AMT*A.INT_RATE*0.01) BALANCE
                               FROM ADM.INTF_CL_LOAN_ACCT A,
                                    VISE.CLIENT_FACILITY_TMP B,
                                    ADM.INTF_CIF_CLIENT_CORP C,
                                    FDS_MOD_PROD_PARSE D
                              WHERE A.DATA_DATE = V_DATA_DATE
                                AND C.DATA_DATE = V_DATA_DATE
                                AND A.CLIENT_NO = B.CLIENT_NO
                                AND A.CLIENT_NO = C.CLIENT_NO
                                AND B.FACILITY <= 30000000
                                AND C.CORP_SIZE IN ('CS03','CS04')                    --CS03-小型企业，CSO4-微型企业
                                AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                                AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)               --单户合同汇总金额
                                --DELETE BY ZHOUDE ON 20190626 BELOWN
                                --AND A.VENTURE_GUARANT_TYPE IN('1','2','3','4','5')    --创业担保贷款主体类型1-城镇登记失业人员,2-就业困难人员（含残疾人）,3-复员转业退役军人
                                --DELETE BY ZHOUDE ON 20190626 ABOVE                                                     --4-刑满释放人员,5-高校毕业生（不含大学生村官和留学回国学生
                                AND A.ON_OFF_BALANCE = 'ON'                           --ON-表内
                                AND A.BUSINESS_TYPE = 'CL200'                         --企业贷款组
                                AND SUBSTR(A.OCCUR_DATE,1,6) = SUBSTR(V_DATA_DATE,1,6)--发生日期=本月
                                AND D.PARSE_CODE = 'OSRS7101_3_F'
                           GROUP BY A.BRANCH,D.PROD_CODE;
                          /* UNION ALL
                           SELECT 'S7101',
                                       A.ORG_CODE BRANCH,
                                       TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                       D.PROD_CODE PROD_CODE,
                                       CASE WHEN SUBSTR(V_DATA_DATE,1,6)='0131' THEN 0 --当年1月31日报送不需要上月报表数
                                            ELSE SUM (A.BALANCE)
                                       END BALANCE
                                  FROM FDS_REPORT_DATA A,
                                       FDS_MOD_PROD_PARSE D
                                  WHERE TO_CHAR (TO_DATE(V_LAST_MONTH_END_DATE,'YYYYMMDD'),'YYYY-MM-DD') = A.DATA_DT
                                    AND TO_CHAR (V_RUN_DATE, 'YYYYMMDD') = D.DATA_DATE
                                    AND A.INDICATOR=D.PROD_CODE
                                    AND D.PARSE_CODE = 'OSRS7101_3_F'
                               GROUP BY A.ORG_CODE,D.PROD_CODE
                               )T
                               GROUP BY T.BRANCH,T.PROD_CODE;*/
--                   COMMIT;

             V_STEP := '8.4';
           /*
           当年累放贷款年化利息收益
            OSRS7101_4_F(F,F1,F2,F3,F4)
           3.1其中：普惠型个体工商户贷款
           */ 
                  INSERT INTO FDS_REPORT_DATA (REPORT_CODE,
                                ORG_CODE,
                                DATA_DT,
                                INDICATOR,
                                BALANCE)
                        /* SELECT 'S7101',
                            T.BRANCH,
                            TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                            T.PROD_CODE,
                            SUM (T.BALANCE)
                        FROM (*/
                             SELECT 'S7101',
                                    A.BRANCH BRANCH,
                                    TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                    D.PROD_CODE PROD_CODE,
                                    SUM (A.DD_AMT*A.INT_RATE*0.01) BALANCE
                               FROM ADM.INTF_CL_LOAN_ACCT A,
                                    VISE.CLIENT_FACILITY_TMPi B,
                                    FDS_MOD_PROD_PARSE D
                              WHERE A.DATA_DATE = V_DATA_DATE
                                AND B.DATA_DATE = V_DATA_DATE
                                --AND TO_CHAR (V_RUN_DATE, 'YYYYMMDD') = D.DATA_DATE
                                AND A.CLIENT_NO = B.CLIENT_NO
                                AND B.FACILITY <= 30000000
																AND A.BUSINESS_SUB_TYPE='A18' -- A18-个体工商户
                                AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                                AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)                --单户合同汇总金额
                                AND A.ON_OFF_BALANCE = 'ON'                            --ON-表内
                                AND A.BUSINESS_TYPE <> 'CL300'                         --贴现
																AND A.BUSINESS_TYPE <> 'CL500'                         --委托贷款
                                AND SUBSTR(A.OCCUR_DATE,1,4) = SUBSTR(V_DATA_DATE,1,4) --发生日期=本年
                                AND B.DATA_DATE=UTIL.GET_MONTH_END_DATE(A.OCCUR_DATE) --数据日期=发生日期所在月月末 --20200902 zw add
                                AND D.PARSE_CODE = 'OSRS7101_4_F'
                           GROUP BY A.BRANCH,D.PROD_CODE;
--                           UNION ALL  --对私  个体工商户
--                           SELECT 'S7101',
--                                    A.BRANCH BRANCH,
--                                    TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
--                                    D.PROD_CODE PROD_CODE,
--                                    SUM (A.DD_AMT*A.INT_RATE*0.01) BALANCE
--                               FROM ADM.INTF_CL_LOAN_ACCT A,
--                                    VISE.CLIENT_FACILITY_TMP B,
--                                    ADM.INTF_CIF_CLIENT_PERSON C,
--                                    FDS_MOD_PROD_PARSE D
--                              WHERE TO_CHAR (V_RUN_DATE, 'YYYYMMDD') = A.DATA_DATE
--                                AND TO_CHAR (V_RUN_DATE, 'YYYYMMDD') = C.DATA_DATE
--                                --AND TO_CHAR (V_RUN_DATE, 'YYYYMMDD') = D.DATA_DATE
--                                AND A.CLIENT_NO = B.CLIENT_NO
--                                AND A.CLIENT_NO = C.CLIENT_NO
--                                AND C.SUB_CLIENT_TYPE = D.SUBELEM3                     --0320-个体工商户
--                                AND B.LOAN_AMT > TO_NUMBER(D.SUBELEM1)
--                                AND B.LOAN_AMT <= TO_NUMBER(D.SUBELEM2)                --单户合同汇总金额
--                                AND A.ON_OFF_BALANCE = 'ON'                            --ON-表内
--                                AND A.BUSINESS_SUB_TYPE NOT LIKE 'C%'                  --C%-委托贷款
--                                AND A.BUSINESS_SUB_TYPE NOT LIKE 'Z%'                  --Z%-资产转让
--                                AND SUBSTR(A.OCCUR_DATE,1,6) = SUBSTR(V_DATA_DATE,1,6) --发生日期=本月
--                                AND D.PARSE_CODE = 'OSRS7101_4_F'
--                           GROUP BY A.BRANCH,D.PROD_CODE
                     /*      UNION ALL
                           SELECT 'S7101',
                                       A.ORG_CODE BRANCH,
                                       TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                       D.PROD_CODE PROD_CODE,
                                       CASE WHEN SUBSTR(V_DATA_DATE,1,6)='0131' THEN 0 --当年1月31日报送不需要上月报表数
                                            ELSE SUM (A.BALANCE)
                                       END BALANCE
                                  FROM FDS_REPORT_DATA A,
                                       FDS_MOD_PROD_PARSE D
                                  WHERE TO_CHAR (TO_DATE(V_LAST_MONTH_END_DATE,'YYYYMMDD'),'YYYY-MM-DD') = A.DATA_DT
                                    AND TO_CHAR (V_RUN_DATE, 'YYYYMMDD') = D.DATA_DATE
                                    AND A.INDICATOR=D.PROD_CODE
                                    AND D.PARSE_CODE = 'OSRS7101_4_F'
                               GROUP BY A.ORG_CODE,D.PROD_CODE)T
                               GROUP BY T.BRANCH,T.PROD_CODE;*/
                       COMMIT;

           V_STEP := '8.5';
           /*
           当年累放贷款年化利息收益
            OSRS7101_5_F(F,F1,F2,F3,F4)
            3.2其中：普惠型小微企业主贷款
            */
                  INSERT INTO FDS_REPORT_DATA (REPORT_CODE,
                                ORG_CODE,
                                DATA_DT,
                                INDICATOR,
                                BALANCE)
                       /*  SELECT 'S7101',
                            T.BRANCH,
                            TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                            T.PROD_CODE,
                            SUM (T.BALANCE)
                        FROM (*/
                             SELECT 'S7101',
                                    A.BRANCH BRANCH,
                                    TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                    D.PROD_CODE PROD_CODE,
                                    SUM (A.DD_AMT*A.INT_RATE*0.01) BALANCE
                               FROM ADM.INTF_CL_LOAN_ACCT A,
                                    VISE.CLIENT_FACILITY_TMPI B,
                                    FDS_MOD_PROD_PARSE D
                              WHERE A.DATA_DATE = V_DATA_DATE
                                AND A.CLIENT_NO = B.CLIENT_NO
																AND A.BUSINESS_SUB_TYPE='A17' -- A17-小微企业主
                                AND B.FACILITY <= 30000000
                                AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                                AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)               --单户合同汇总金额
                                AND A.ON_OFF_BALANCE = 'ON'                           --ON-表内
                                AND SUBSTR(A.OCCUR_DATE,1,4) = SUBSTR(V_DATA_DATE,1,4)--发生日期=本年
                                AND B.DATA_DATE=UTIL.GET_MONTH_END_DATE(A.OCCUR_DATE) --数据日期=发生日期所在月月末 --20200902 zw add
																AND A.BUSINESS_TYPE <> 'CL300'                         --贴现
																AND A.BUSINESS_TYPE <> 'CL500'                         --委托贷款
                                AND D.PARSE_CODE = 'OSRS7101_5_F'
                           GROUP BY A.BRANCH,D.PROD_CODE;
                          /* UNION ALL
                           SELECT 'S7101',
                                       A.ORG_CODE BRANCH,
                                       TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                       D.PROD_CODE PROD_CODE,
                                       CASE WHEN SUBSTR(V_DATA_DATE,1,6)='0131' THEN 0 --当年1月31日报送不需要上月报表数
                                            ELSE SUM (A.BALANCE)
                                       END BALANCE
                                  FROM FDS_REPORT_DATA A,
                                       FDS_MOD_PROD_PARSE D
                                  WHERE TO_CHAR (TO_DATE(V_LAST_MONTH_END_DATE,'YYYYMMDD'),'YYYY-MM-DD') = A.DATA_DT
                                    AND TO_CHAR (V_RUN_DATE, 'YYYYMMDD') = D.DATA_DATE
                                    AND A.INDICATOR=D.PROD_CODE
                                    AND D.PARSE_CODE = 'OSRS7101_5_F'
                               GROUP BY A.ORG_CODE,D.PROD_CODE)T
                               GROUP BY T.BRANCH,T.PROD_CODE;*/
              COMMIT;

     V_STEP := '9';
      /***
      贷款余额
        OSRS7101_6(A,A1,A2,A3,A4)
      4.普惠型其他个人（非农户）经营性贷款
      ***/
       INSERT INTO FDS_REPORT_DATA (REPORT_CODE,
                                ORG_CODE,
                                DATA_DT,
                                INDICATOR,
                                BALANCE)
                         SELECT 'S7101',
                                A.BRANCH,
                                TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                D.PROD_CODE,
                                SUM (A.BALANCE)
                           FROM ADM.INTF_CL_LOAN_ACCT A,
                                VISE.CLIENT_FACILITY_TMPI B,
                                ADM.INTF_CIF_CLIENT_PERSON C,
                                FDS_MOD_PROD_PARSE D
                          WHERE A.DATA_DATE = V_DATA_DATE
                            AND C.DATA_DATE = V_DATA_DATE
                            AND B.DATA_DATE = V_DATA_DATE
                            AND A.CLIENT_NO = B.CLIENT_NO
                            AND A.CLIENT_NO = C.CLIENT_NO
                            AND B.FACILITY <= 30000000
                            AND A.IS_FARMER_LOAN='N'                               --非农户
                            AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                            AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)                --单户合同汇总金额
                            AND A.ON_OFF_BALANCE = 'ON'                            --ON-表内
                            AND A.BUSINESS_SUB_TYPE = 'A19'                        --个人经营性贷款
                            AND D.PARSE_CODE = 'OSRS7101_6'
                       GROUP BY A.BRANCH,D.PROD_CODE;
                COMMIT;

      V_STEP := '9.1';
      /***
      贷款余额户数
        OSRS7101_6_B(B,B1,B2,B3,B4)
      4.普惠型其他个人（非农户）经营性贷款
      ***/
       INSERT INTO FDS_REPORT_DATA (REPORT_CODE,
                                ORG_CODE,
                                DATA_DT,
                                INDICATOR,
                                BALANCE)
                         SELECT 'S7101',
                                A.BRANCH,
                                TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                D.PROD_CODE,
                                COUNT(DISTINCT A.CLIENT_NO)
                           FROM ADM.INTF_CL_LOAN_ACCT A,
                                VISE.CLIENT_FACILITY_TMPI B,
                                ADM.INTF_CIF_CLIENT_PERSON C,
                                FDS_MOD_PROD_PARSE D
                          WHERE A.DATA_DATE = V_DATA_DATE
                            AND C.DATA_DATE = V_DATA_DATE
                            AND B.DATA_DATE = V_DATA_DATE
                            AND A.CLIENT_NO = B.CLIENT_NO
                            AND A.CLIENT_NO = C.CLIENT_NO
                            AND B.FACILITY <= 30000000
                            AND A.IS_FARMER_LOAN='N'                               --非农户
                            AND A.BALANCE>0
                            AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                            AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)                --单户合同汇总金额
                            AND A.ON_OFF_BALANCE = 'ON'                            --ON-表内
                            AND A.BUSINESS_SUB_TYPE = 'A19'                        --个人经营性贷款
                            AND D.PARSE_CODE = 'OSRS7101_6_B'
                       GROUP BY A.BRANCH,D.PROD_CODE          ;
                COMMIT;

       V_STEP := '9.2';
      /***
      不良贷款余额
        OSRS7101_6_C(C,C1,C2,C3,C4)
      4.普惠型其他个人（非农户）经营性贷款
      ***/
       INSERT INTO FDS_REPORT_DATA (REPORT_CODE,
                                ORG_CODE,
                                DATA_DT,
                                INDICATOR,
                                BALANCE)
                         SELECT 'S7101',
                                A.BRANCH,
                                TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                D.PROD_CODE,
                                SUM(BALANCE)
                           FROM ADM.INTF_CL_LOAN_ACCT A,
                                VISE.CLIENT_FACILITY_TMPI B,   --20200710 此处应该是对私的授信
                                ADM.INTF_CIF_CLIENT_PERSON C,
                                FDS_MOD_PROD_PARSE D
                          WHERE A.DATA_DATE = V_DATA_DATE
                            AND C.DATA_DATE = V_DATA_DATE
                            AND B.DATA_DATE = V_DATA_DATE
                            AND A.CLIENT_NO = B.CLIENT_NO
                            AND A.CLIENT_NO = C.CLIENT_NO
                            AND B.FACILITY <= 30000000
                            AND A.IS_FARMER_LOAN='N'                               --非农户
                            AND A.FIVE_CLASS IN('FQ03','FQ04','FQ05')              --不良贷款
                            AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                            AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)                --单户合同汇总金额
                            AND A.ON_OFF_BALANCE = 'ON'                            --ON-表内
                            AND A.BUSINESS_SUB_TYPE = 'A19'                        --个人经营性贷款
                            AND D.PARSE_CODE = 'OSRS7101_6_C'
                       GROUP BY A.BRANCH,D.PROD_CODE          ;
                COMMIT;

         V_STEP := '9.3';
      /***
      当年累放贷款额
        OSRS7101_6_D(D,D1,D2,D3,D4)
      4.普惠型其他个人（非农户）经营性贷款
      ***/
       INSERT INTO FDS_REPORT_DATA (REPORT_CODE,
                                ORG_CODE,
                                DATA_DT,
                                INDICATOR,
                                BALANCE)
                             SELECT 'S7101',
                                    A.BRANCH BRANCH,
                                    TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                    D.PROD_CODE PROD_CODE,
                                    SUM(DD_AMT) BALANCE
                               FROM ADM.INTF_CL_LOAN_ACCT A,
                                    VISE.CLIENT_FACILITY_TMPI B,  ---20200710
                                    ADM.INTF_CIF_CLIENT_PERSON C,
                                    FDS_MOD_PROD_PARSE D
                              WHERE A.DATA_DATE = V_DATA_DATE
                                AND C.DATA_DATE = V_DATA_DATE
                                AND A.CLIENT_NO = B.CLIENT_NO
                                AND A.CLIENT_NO = C.CLIENT_NO
                                AND A.IS_FARMER_LOAN='N'                               --非农户
                                AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                                AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)                --单户合同汇总金额
                                AND A.ON_OFF_BALANCE = 'ON'                            --ON-表内
                                AND A.BUSINESS_SUB_TYPE = 'A19'                        --个人经营性贷款
                                AND SUBSTR(A.OCCUR_DATE,1,4) = SUBSTR(V_DATA_DATE,1,4) --发生日期=本年
                                AND B.DATA_DATE=UTIL.GET_MONTH_END_DATE(A.OCCUR_DATE) --数据日期=发生日期所在月月末 --20200902 zw add
                                AND D.PARSE_CODE = 'OSRS7101_6_D'
                           GROUP BY A.BRANCH,D.PROD_CODE;
                         /*  UNION ALL
                           SELECT 'S7101',
                                       A.ORG_CODE BRANCH,
                                       TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                       D.PROD_CODE PROD_CODE,
                                       CASE WHEN SUBSTR(V_DATA_DATE,1,6)='0131' THEN 0 --当年1月31日报送不需要上月报表数
                                            ELSE SUM (A.BALANCE)
                                       END BALANCE
                                  FROM FDS_REPORT_DATA A,
                                       FDS_MOD_PROD_PARSE D
                                  WHERE TO_CHAR (TO_DATE(V_LAST_MONTH_END_DATE,'YYYYMMDD'),'YYYY-MM-DD') = A.DATA_DT
                                    AND TO_CHAR (V_RUN_DATE, 'YYYYMMDD') = D.DATA_DATE
                                    AND A.INDICATOR=D.PROD_CODE
                                    AND D.PARSE_CODE = 'OSRS7101_6_D'
                               GROUP BY A.ORG_CODE,D.PROD_CODE)T
                               GROUP BY T.BRANCH,T.PROD_CODE;*/
                COMMIT;

          V_STEP := '9.4';
      /***
      当年累放贷款户数
        OSRS7101_6_E(E,E1,E2,E3,E4)
      4.普惠型其他个人（非农户）经营性贷款
      ***/
       INSERT INTO FDS_REPORT_DATA (REPORT_CODE,
                                ORG_CODE,
                                DATA_DT,
                                INDICATOR,
                                BALANCE)
                            SELECT 'S7101',
                                    A.BRANCH BRANCH,
                                    TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                    D.PROD_CODE PROD_CODE,
                                    COUNT(DISTINCT A.CLIENT_NO) BALANCE
                               FROM ADM.INTF_CL_LOAN_ACCT A,
                                    VISE.CLIENT_FACILITY_TMPI B, --20200710
                                    ADM.INTF_CIF_CLIENT_PERSON C,
                                    FDS_MOD_PROD_PARSE D
                              WHERE A.DATA_DATE = V_DATA_DATE
                                AND C.DATA_DATE = V_DATA_DATE
                                AND A.CLIENT_NO = B.CLIENT_NO
                                AND A.CLIENT_NO = C.CLIENT_NO
                                AND B.FACILITY <= 30000000
                                AND A.IS_FARMER_LOAN='N'                               --非农户
                                AND SUBSTR(A.OCCUR_DATE,1,4) = SUBSTR(V_DATA_DATE,1,4) --发生日期=本年
                                AND B.DATA_DATE=UTIL.GET_MONTH_END_DATE(A.OCCUR_DATE) --数据日期=发生日期所在月月末 --20200902 zw add
                                AND A.DD_AMT>0                                         --发放金额>0
                                AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                                AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)                --单户合同汇总金额
                                AND A.ON_OFF_BALANCE = 'ON'                            --ON-表内
                                AND A.BUSINESS_SUB_TYPE = 'A19'                        --个人经营性贷款
                                AND D.PARSE_CODE = 'OSRS7101_6_E'
                           GROUP BY A.BRANCH,D.PROD_CODE;
                          /* UNION ALL
                           SELECT 'S7101',
                                       A.ORG_CODE BRANCH,
                                       TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                       D.PROD_CODE PROD_CODE,
                                       CASE WHEN SUBSTR(V_DATA_DATE,1,6)='0131' THEN 0 --当年1月31日报送不需要上月报表数
                                            ELSE SUM (A.BALANCE)
                                       END BALANCE
                                  FROM FDS_REPORT_DATA A,
                                       FDS_MOD_PROD_PARSE D
                                  WHERE TO_CHAR (TO_DATE(V_LAST_MONTH_END_DATE,'YYYYMMDD'),'YYYY-MM-DD') = A.DATA_DT
                                    AND TO_CHAR (V_RUN_DATE, 'YYYYMMDD') = D.DATA_DATE
                                    AND A.INDICATOR=D.PROD_CODE
                                    AND D.PARSE_CODE = 'OSRS7101_6_E'
                               GROUP BY A.ORG_CODE,D.PROD_CODE)T
                               GROUP BY T.BRANCH,T.PROD_CODE;*/
                COMMIT;

     V_STEP := '9.4';
      /***
      当年累放贷款年化利息收益
        OSRS7101_6_F(F,F1,F2,F3,F4)
      4.普惠型其他个人（非农户）经营性贷款
      ***/
       INSERT INTO FDS_REPORT_DATA (REPORT_CODE,
                                ORG_CODE,
                                DATA_DT,
                                INDICATOR,
                                BALANCE)
                       /*  SELECT 'S7101',
                            T.BRANCH,
                            TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                            T.PROD_CODE,
                            SUM (T.BALANCE)
                        FROM (*/
                             SELECT 'S7101',
                                    A.BRANCH BRANCH,
                                    TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                    D.PROD_CODE PROD_CODE,
                                    SUM(A.DD_AMT*A.INT_RATE*0.01) BALANCE
                               FROM ADM.INTF_CL_LOAN_ACCT A,
                                    VISE.CLIENT_FACILITY_TMPI B, --20200710
                                    ADM.INTF_CIF_CLIENT_PERSON C,
                                    FDS_MOD_PROD_PARSE D
                              WHERE A.DATA_DATE = V_DATA_DATE
                                AND C.DATA_DATE = V_DATA_DATE
                                AND A.CLIENT_NO = B.CLIENT_NO
                                AND A.CLIENT_NO = C.CLIENT_NO
                                AND B.FACILITY <= 30000000
                                AND A.IS_FARMER_LOAN='N'                               --非农户
                                AND SUBSTR(A.OCCUR_DATE,1,4) = SUBSTR(V_DATA_DATE,1,4) --发生日期=本年
                                AND B.DATA_DATE=UTIL.GET_MONTH_END_DATE(A.OCCUR_DATE) --数据日期=发生日期所在月月末 --20200902 zw add
                                AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                                AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)                --单户合同汇总金额
                                AND A.ON_OFF_BALANCE = 'ON'                            --ON-表内
                                AND A.BUSINESS_SUB_TYPE = 'A19'                        --个人经营性贷款
                                AND D.PARSE_CODE = 'OSRS7101_6_F'
                           GROUP BY A.BRANCH,D.PROD_CODE;
                         /*  UNION ALL
                           SELECT 'S7101',
                                       A.ORG_CODE BRANCH,
                                       TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                       D.PROD_CODE PROD_CODE,
                                       CASE WHEN SUBSTR(V_DATA_DATE,1,6)='0131' THEN 0 --当年1月31日报送不需要上月报表数
                                            ELSE SUM (A.BALANCE)
                                       END BALANCE
                                  FROM FDS_REPORT_DATA A,
                                       FDS_MOD_PROD_PARSE D
                                  WHERE TO_CHAR (TO_DATE(V_LAST_MONTH_END_DATE,'YYYYMMDD'),'YYYY-MM-DD') = A.DATA_DT
                                    AND TO_CHAR (V_RUN_DATE, 'YYYYMMDD') = D.DATA_DATE
                                    AND A.INDICATOR=D.PROD_CODE
                                    AND D.PARSE_CODE = 'OSRS7101_6_F'
                               GROUP BY A.ORG_CODE,D.PROD_CODE)T
                               GROUP BY T.BRANCH,T.PROD_CODE;*/
                COMMIT;

              V_STEP := '9.5';
      /***
      当年累放贷款额
        OSRS7101_7_D(D1,D2,D3,D4)
      3.普惠型个体工商户和小微企业主贷款
      ***/
      INSERT INTO FDS_REPORT_DATA (REPORT_CODE,
                                ORG_CODE,
                                DATA_DT,
                                INDICATOR,
                                BALANCE)
                             SELECT 'S7101',
                                    A.BRANCH BRANCH,
                                    TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                    D.PROD_CODE PROD_CODE,
                                    SUM(A.DD_AMT) BALANCE
                               FROM ADM.INTF_CL_LOAN_ACCT A,
                                    VISE.CLIENT_FACILITY_TMPI B,
                                    FDS_MOD_PROD_PARSE D
                              WHERE A.DATA_DATE = V_DATA_DATE
                                AND A.CLIENT_NO = B.CLIENT_NO
																AND A.BUSINESS_SUB_TYPE IN('A17','A18')
                                AND B.FACILITY <= 30000000
                                AND SUBSTR(A.OCCUR_DATE,1,4) = SUBSTR(V_DATA_DATE,1,4) --发生日期=本年
                                AND B.DATA_DATE=UTIL.GET_MONTH_END_DATE(A.OCCUR_DATE) --数据日期=发生日期所在月月末 --20200902 zw add
                                AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                                AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)                --单户合同汇总金额
                                AND A.ON_OFF_BALANCE = 'ON'                            --ON-表内
                                AND D.PARSE_CODE = 'OSRS7101_7_D'
                           GROUP BY A.BRANCH,D.PROD_CODE; 
                         /*  UNION ALL
                           SELECT 'S7101',
                                       A.ORG_CODE BRANCH,
                                       TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                       D.PROD_CODE PROD_CODE,
                                       CASE WHEN SUBSTR(V_DATA_DATE,1,6)='0131' THEN 0 --当年1月31日报送不需要上月报表数
                                            ELSE SUM (A.BALANCE)
                                       END BALANCE
                                  FROM FDS_REPORT_DATA A,
                                       FDS_MOD_PROD_PARSE D
                                  WHERE TO_CHAR (TO_DATE(V_LAST_MONTH_END_DATE,'YYYYMMDD'),'YYYY-MM-DD') = A.DATA_DT
                                    AND TO_CHAR (V_RUN_DATE, 'YYYYMMDD') = D.DATA_DATE
                                    AND A.INDICATOR=D.PROD_CODE
                                    AND D.PARSE_CODE = 'OSRS7101_7_D'
                               GROUP BY A.ORG_CODE,D.PROD_CODE)T
                               GROUP BY T.BRANCH,T.PROD_CODE;*/
                COMMIT;

                V_STEP := '9.6';
      /***
      当年累放贷款户数
        OSRS7101_7_E(E1,E2,E3,E4)
      3.普惠型个体工商户和小微企业主贷款
      ***/
     INSERT INTO FDS_REPORT_DATA (REPORT_CODE,
                                ORG_CODE,
                                DATA_DT,
                                INDICATOR,
                                BALANCE)
                             SELECT 'S7101',
                                    A.BRANCH BRANCH,
                                    TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                    D.PROD_CODE PROD_CODE,
                                    COUNT(DISTINCT A.CLIENT_NO) BALANCE
                               FROM ADM.INTF_CL_LOAN_ACCT A,
                                    VISE.CLIENT_FACILITY_TMPI B,
                                    FDS_MOD_PROD_PARSE D
                              WHERE A.DATA_DATE = V_DATA_DATE
                                AND A.CLIENT_NO = B.CLIENT_NO
                                AND B.FACILITY <= 30000000
																AND A.BUSINESS_SUB_TYPE IN('A17','A18')
                                AND SUBSTR(A.OCCUR_DATE,1,4) = SUBSTR(V_DATA_DATE,1,4) --发生日期=本年
                                AND B.DATA_DATE=UTIL.GET_MONTH_END_DATE(A.OCCUR_DATE) --数据日期=发生日期所在月月末 --20200902 zw add
                                AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                                AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)                --单户合同汇总金额
                                AND A.ON_OFF_BALANCE = 'ON'                            --ON-表内
                                AND A.DD_AMT>0
                                AND D.PARSE_CODE = 'OSRS7101_7_E'
                           GROUP BY A.BRANCH,D.PROD_CODE;
                        /*   UNION ALL
                           SELECT 'S7101',
                                       A.ORG_CODE BRANCH,
                                       TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                       D.PROD_CODE PROD_CODE,
                                       CASE WHEN SUBSTR(V_DATA_DATE,1,6)='0131' THEN 0 --当年1月31日报送不需要上月报表数
                                            ELSE SUM (A.BALANCE)
                                       END BALANCE
                                  FROM FDS_REPORT_DATA A,
                                       FDS_MOD_PROD_PARSE D
                                  WHERE TO_CHAR (TO_DATE(V_LAST_MONTH_END_DATE,'YYYYMMDD'),'YYYY-MM-DD') = A.DATA_DT
                                    AND TO_CHAR (V_RUN_DATE, 'YYYYMMDD') = D.DATA_DATE
                                    AND A.INDICATOR=D.PROD_CODE
                                    AND D.PARSE_CODE = 'OSRS7101_7_E'
                               GROUP BY A.ORG_CODE,D.PROD_CODE)T
                               GROUP BY T.BRANCH,T.PROD_CODE;*/
--                 COMMIT;

             V_STEP := '9.7';
      /***
      当年累放贷款年化利息收益
        OSRS7101_7_F(F1,F2,F3,F4)
      3.普惠型个体工商户和小微企业主贷款
      ***/
      INSERT INTO FDS_REPORT_DATA (REPORT_CODE,
                                ORG_CODE,
                                DATA_DT,
                                INDICATOR,
                                BALANCE)
                             SELECT 'S7101',
                                    A.BRANCH BRANCH,
                                    TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                    D.PROD_CODE PROD_CODE,
                                    SUM(A.DD_AMT*A.INT_RATE*0.01) BALANCE
                               FROM ADM.INTF_CL_LOAN_ACCT A,
                                    VISE.CLIENT_FACILITY_TMPI B,
                                    FDS_MOD_PROD_PARSE D
                              WHERE A.DATA_DATE = V_DATA_DATE
                                AND B.CLIENT_NO = A.CLIENT_NO
																AND A.BUSINESS_SUB_TYPE IN('A17','A18')
                                AND B.FACILITY <= 30000000
                                AND SUBSTR(A.OCCUR_DATE,1,4) = SUBSTR(V_DATA_DATE,1,4) --发生日期=本年
                                AND B.DATA_DATE=UTIL.GET_MONTH_END_DATE(A.OCCUR_DATE) --数据日期=发生日期所在月月末 --20200902 zw add
                                AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                                AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)                --单户合同汇总金额
                                AND A.ON_OFF_BALANCE = 'ON'                            --ON-表内
                                AND D.PARSE_CODE = 'OSRS7101_7_F'
                           GROUP BY A.BRANCH,D.PROD_CODE;

                COMMIT; 

    /*     V_STEP := '10';
          /*
          贷款余额
           OSRS7101_8 (A,A1,A2,A3,A4)
             2.普惠型其它组织贷款

    INSERT INTO FDS_REPORT_DATA (REPORT_CODE,
                                ORG_CODE,
                                DATA_DT,
                                INDICATOR,
                                BALANCE)
                         SELECT 'S7101',
                                A.BRANCH,
                                TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                D.PROD_CODE,
                                SUM (A.BALANCE)
                           FROM ADM.INTF_CL_LOAN_ACCT A,
                                VISE.CLIENT_FACILITY_TMP B,
                                ADM.INTF_CIF_CLIENT_CORP C,
                                FDS_MOD_PROD_PARSE D
                          WHERE A.DATA_DATE = V_DATA_DATE
                            AND C.DATA_DATE = V_DATA_DATE
                            AND B.DATA_DATE = V_DATA_DATE
                            --AND TO_CHAR (V_RUN_DATE, 'YYYYMMDD') = D.DATA_DATE
                            AND A.CLIENT_NO = C.CLIENT_NO
                            AND B.CLIENT_NO = C.CLIENT_NO
                            AND B.FACILITY <= 30000000
                            AND C.SUB_CLIENT_TYPE IN('0340','0350','0360')   --0340-事业单位,0350-社会团体,0360-党政机关
                            AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                            AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)                --单户合同汇总金额
                            AND A.ON_OFF_BALANCE = 'ON'                            --ON-表内
                            AND A.BUSINESS_SUB_TYPE NOT LIKE 'C%'                  --C%-委托贷款
                            AND A.BUSINESS_SUB_TYPE NOT LIKE 'Z%'                  --Z%-资产转让
														AND   A.BUSINESS_SUB_TYPE NOT LIKE 'D%'
                            AND D.PARSE_CODE = 'OSRS7101_8'
                       GROUP BY A.BRANCH,D.PROD_CODE;
                COMMIT;*/

          /*
          贷款余额户数
           OSRS7101_8_B(B,B1,B2,B3,B4)
             2.普惠型其它组织贷款
          */
 /*  V_STEP := '10.1';
    INSERT INTO FDS_REPORT_DATA (REPORT_CODE,
                                ORG_CODE,
                                DATA_DT,
                                INDICATOR,
                                BALANCE)
                         SELECT 'S7101',
                                A.BRANCH,
                                TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                D.PROD_CODE,
                                COUNT(DISTINCT A.CLIENT_NO)
                           FROM ADM.INTF_CL_LOAN_ACCT A,
                                VISE.CLIENT_FACILITY_TMP B,
                                ADM.INTF_CIF_CLIENT_CORP C,
                                FDS_MOD_PROD_PARSE D
                          WHERE A.DATA_DATE = V_DATA_DATE
                            AND C.DATA_DATE = V_DATA_DATE
                            AND B.DATA_DATE = V_DATA_DATE
                            --AND TO_CHAR (V_RUN_DATE, 'YYYYMMDD') = D.DATA_DATE
                            AND A.CLIENT_NO=C.CLIENT_NO
                            AND B.CLIENT_NO=C.CLIENT_NO
                            AND B.FACILITY <= 30000000
                            AND C.SUB_CLIENT_TYPE IN('0340','0350','0360')   --0340-事业单位,0350-社会团体,0360-党政机关
                            AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                            AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)               --单户合同汇总金额
                            AND A.ON_OFF_BALANCE = 'ON'                           --ON-表内
                            AND A.BUSINESS_SUB_TYPE NOT LIKE 'C%'                 --C%-委托贷款
                            AND A.BUSINESS_SUB_TYPE NOT LIKE 'Z%'                 --Z%-资产转让
                            AND A.BALANCE > 0                                     --A.贷款余额>0
														AND   A.BUSINESS_SUB_TYPE NOT LIKE 'D%'
                            AND D.PARSE_CODE = 'OSRS7101_8_B'
                       GROUP BY A.BRANCH,D.PROD_CODE;
                COMMIT;*/

          /*
          不良贷款余额
           OSRS7101_8_C(C,C1,C2,C3,C4)
             2.普惠型其它组织贷款
          */
  /* V_STEP := '10.2';
    INSERT INTO FDS_REPORT_DATA (REPORT_CODE,
                                ORG_CODE,
                                DATA_DT,
                                INDICATOR,
                                BALANCE)
                         SELECT 'S7101',
                                A.BRANCH,
                                TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                D.PROD_CODE,
                                SUM (A.BALANCE)
                           FROM ADM.INTF_CL_LOAN_ACCT A,
                                VISE.CLIENT_FACILITY_TMP B,
                                ADM.INTF_CIF_CLIENT_CORP C,
                                FDS_MOD_PROD_PARSE D
                          WHERE A.DATA_DATE = V_DATA_DATE
                            AND C.DATA_DATE = V_DATA_DATE
                            AND B.DATA_DATE = V_DATA_DATE
                            --AND TO_CHAR (V_RUN_DATE, 'YYYYMMDD') = D.DATA_DATE
                            AND A.CLIENT_NO=C.CLIENT_NO
                            AND B.CLIENT_NO=C.CLIENT_NO
                            AND B.FACILITY <= 30000000
                            AND C.SUB_CLIENT_TYPE IN('0340','0350','0360')   --0340-事业单位,0350-社会团体,0360-党政机关
                            AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                            AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)               --单户合同汇总金额
                            AND A.ON_OFF_BALANCE = 'ON'                           --ON-表内
                            AND A.BUSINESS_SUB_TYPE NOT LIKE 'C%'                 --C%-委托贷款
                            AND A.BUSINESS_SUB_TYPE NOT LIKE 'Z%'                 --Z%-资产转让
														AND   A.BUSINESS_SUB_TYPE NOT LIKE 'D%'
                            AND A.FIVE_CLASS IN ('FQ03','FQ04','FQ05')            --FQ03-次级,FQ04-可疑,FQ05-损失
                            AND D.PARSE_CODE = 'OSRS7101_8_C'
                       GROUP BY A.BRANCH,D.PROD_CODE;
                COMMIT;
*/
           /*
          当年累放贷款额
           OSRS7101_8_D(D,D1,D2,D3,D4)
             2.普惠型其它组织贷款
          */
  /* V_STEP := '10.3';
    INSERT INTO FDS_REPORT_DATA (REPORT_CODE,
                                ORG_CODE,
                                DATA_DT,
                                INDICATOR,
                                BALANCE)
                         SELECT 'S7101',
                            T.BRANCH,
                            TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                            T.PROD_CODE,
                            SUM (T.BALANCE)
                        FROM (
                             SELECT 'S7101',
                                    A.BRANCH BRANCH,
                                    TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                    D.PROD_CODE PROD_CODE,
                                    SUM (A.DD_AMT) BALANCE
                               FROM ADM.INTF_CL_LOAN_ACCT A,
                                    VISE.CLIENT_FACILITY_TMP B,
                                    ADM.INTF_CIF_CLIENT_CORP C,
                                    FDS_MOD_PROD_PARSE D
                              WHERE A.DATA_DATE = V_DATA_DATE
                                AND C.DATA_DATE = V_DATA_DATE
                                AND B.DATA_DATE = V_DATA_DATE
                                --AND TO_CHAR (V_RUN_DATE, 'YYYYMMDD') = D.DATA_DATE
                                AND A.CLIENT_NO=C.CLIENT_NO
                                AND B.CLIENT_NO=C.CLIENT_NO
                                AND B.FACILITY <= 30000000
                                AND C.SUB_CLIENT_TYPE IN('0340','0350','0360')   --0340-事业单位,0350-社会团体,0360-党政机关
                                AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                                AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)               --单户合同汇总金额
                                AND A.ON_OFF_BALANCE = 'ON'                           --ON-表内
                                AND A.BUSINESS_SUB_TYPE NOT LIKE 'C%'                 --C%-委托贷款
                                AND A.BUSINESS_SUB_TYPE NOT LIKE 'Z%'                 --Z%-资产转让
																AND   A.BUSINESS_SUB_TYPE NOT LIKE 'D%'
                                AND SUBSTR(A.OCCUR_DATE,1,6) = SUBSTR(V_DATA_DATE,1,6) --发生日期=本月
                                AND D.PARSE_CODE = 'OSRS7101_8_D'
                           GROUP BY A.BRANCH,D.PROD_CODE
                           UNION ALL
                           SELECT 'S7101',
                                       A.ORG_CODE BRANCH,
                                       TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                       D.PROD_CODE PROD_CODE,
                                       CASE WHEN SUBSTR(V_DATA_DATE,1,6)='0131' THEN 0 --当年1月31日报送不需要上月报表数
                                            ELSE SUM (A.BALANCE)
                                       END BALANCE
                                  FROM FDS_REPORT_DATA A,
                                       FDS_MOD_PROD_PARSE D
                                  WHERE TO_CHAR (TO_DATE(V_LAST_MONTH_END_DATE,'YYYYMMDD'),'YYYY-MM-DD') = A.DATA_DT
                                    AND TO_CHAR (V_RUN_DATE, 'YYYYMMDD') = D.DATA_DATE
                                    AND A.INDICATOR=D.PROD_CODE
                                    AND D.PARSE_CODE = 'OSRS7101_8_D'
                               GROUP BY A.ORG_CODE,D.PROD_CODE)T
                               GROUP BY T.BRANCH,T.PROD_CODE;
                COMMIT;
*/
           /*
          当年累放贷款户数
           OSRS7101_8_E(E,E1,E2,E3,E4)
             2.普惠型其它组织贷款
          */
  /* V_STEP := '10.4';
    INSERT INTO FDS_REPORT_DATA (REPORT_CODE,
                                ORG_CODE,
                                DATA_DT,
                                INDICATOR,
                                BALANCE)
                         SELECT 'S7101',
                            T.BRANCH,
                            TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                            T.PROD_CODE,
                            SUM (T.BALANCE)
                        FROM (
                             SELECT 'S7101',
                                    A.BRANCH BRANCH,
                                    TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                    D.PROD_CODE PROD_CODE,
                                    COUNT(DISTINCT A.CLIENT_NO) BALANCE
                               FROM ADM.INTF_CL_LOAN_ACCT A,
                                    VISE.CLIENT_FACILITY_TMP B,
                                    ADM.INTF_CIF_CLIENT_CORP C,
                                    FDS_MOD_PROD_PARSE D
                              WHERE A.DATA_DATE = V_DATA_DATE
                                AND C.DATA_DATE = V_DATA_DATE
                                AND B.DATA_DATE = V_DATA_DATE
                                --AND TO_CHAR (V_RUN_DATE, 'YYYYMMDD') = D.DATA_DATE
                                AND A.CLIENT_NO=C.CLIENT_NO
                                AND B.CLIENT_NO=C.CLIENT_NO
                                AND B.FACILITY <= 30000000
                                AND C.SUB_CLIENT_TYPE IN('0340','0350','0360')   --0340-事业单位,0350-社会团体,0360-党政机关
                                AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                                AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)                --单户合同汇总金额
                                AND A.ON_OFF_BALANCE = 'ON'                            --ON-表内
                                AND A.BUSINESS_SUB_TYPE NOT LIKE 'C%'                  --C%-委托贷款
                                AND A.BUSINESS_SUB_TYPE NOT LIKE 'Z%'                  --Z%-资产转让
																AND   A.BUSINESS_SUB_TYPE NOT LIKE 'D%'
                                AND SUBSTR(A.OCCUR_DATE,1,6) = SUBSTR(V_DATA_DATE,1,6) --发生日期=本月
                                AND A.DD_AMT>0                                         --发放金额>0
                                AND D.PARSE_CODE = 'OSRS7101_8_E'
                           GROUP BY A.BRANCH,D.PROD_CODE
                           UNION ALL
                           SELECT 'S7101',
                                       A.ORG_CODE BRANCH,
                                       TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                       D.PROD_CODE PROD_CODE,
                                       CASE WHEN SUBSTR(V_DATA_DATE,1,6)='0131' THEN 0 --当年1月31日报送不需要上月报表数
                                            ELSE SUM (A.BALANCE)
                                       END BALANCE
                                  FROM FDS_REPORT_DATA A,
                                       FDS_MOD_PROD_PARSE D
                                  WHERE TO_CHAR (TO_DATE(V_LAST_MONTH_END_DATE,'YYYYMMDD'),'YYYY-MM-DD') = A.DATA_DT
                                    AND TO_CHAR (V_RUN_DATE, 'YYYYMMDD') = D.DATA_DATE
                                    AND A.INDICATOR=D.PROD_CODE
                                    AND D.PARSE_CODE = 'OSRS7101_8_E'
                               GROUP BY A.ORG_CODE,D.PROD_CODE)T
                               GROUP BY T.BRANCH,T.PROD_CODE;
                COMMIT;*/

            /*
          当年累放贷款年化利息收益
           OSRS7101_8_F(F,F1,F2,F3,F4)
             2.普惠型其它组织贷款
          */
  /* V_STEP := '10.5';
    INSERT INTO FDS_REPORT_DATA (REPORT_CODE,
                                ORG_CODE,
                                DATA_DT,
                                INDICATOR,
                                BALANCE)
                         SELECT 'S7101',
                            T.BRANCH,
                            TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                            T.PROD_CODE,
                            SUM (T.BALANCE)
                        FROM (
                             SELECT 'S7101',
                                    A.BRANCH BRANCH,
                                    TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                    D.PROD_CODE PROD_CODE,
                                    SUM (A.DD_AMT*A.INT_RATE*0.01) BALANCE
                               FROM ADM.INTF_CL_LOAN_ACCT A,
                                    VISE.CLIENT_FACILITY_TMP B,
                                    ADM.INTF_CIF_CLIENT_CORP C,
                                    FDS_MOD_PROD_PARSE D
                              WHERE A.DATA_DATE = V_DATA_DATE
                                AND C.DATA_DATE = V_DATA_DATE
                                AND A.CLIENT_NO=B.CLIENT_NO
                                AND A.CLIENT_NO=C.CLIENT_NO
                                AND B.FACILITY <= 30000000
                                AND C.SUB_CLIENT_TYPE IN('0340','0350','0360')   --0340-事业单位,0350-社会团体,0360-党政机关
                                AND B.FACILITY > TO_NUMBER(D.SUBELEM1)
                                AND B.FACILITY <= TO_NUMBER(D.SUBELEM2)                --单户合同汇总金额
                                AND A.ON_OFF_BALANCE = 'ON'                            --ON-表内
                                AND C.CORP_SIZE IN ('CS03','CS04')                    --CS03-小型企业，CSO4-微型企业
                                AND SUBSTR(A.OCCUR_DATE,1,6) = SUBSTR(V_DATA_DATE,1,6) --发生日期=本月
                                AND D.PARSE_CODE = 'OSRS7101_8_F'
                           GROUP BY A.BRANCH,D.PROD_CODE
                           UNION ALL
                           SELECT 'S7101',
                                       A.ORG_CODE BRANCH,
                                       TO_CHAR (V_RUN_DATE, 'YYYY-MM-DD'),
                                       D.PROD_CODE PROD_CODE,
                                       CASE WHEN SUBSTR(V_DATA_DATE,1,6)='0131' THEN 0 --当年1月31日报送不需要上月报表数
                                            ELSE SUM (A.BALANCE)
                                       END BALANCE
                                  FROM FDS_REPORT_DATA A,
                                       FDS_MOD_PROD_PARSE D
                                  WHERE TO_CHAR (TO_DATE(V_LAST_MONTH_END_DATE,'YYYYMMDD'),'YYYY-MM-DD') = A.DATA_DT
                                    AND TO_CHAR (V_RUN_DATE, 'YYYYMMDD') = D.DATA_DATE
                                    AND A.INDICATOR=D.PROD_CODE
                                    AND D.PARSE_CODE = 'OSRS7101_8_F'
                               GROUP BY A.ORG_CODE,D.PROD_CODE)T
                               GROUP BY T.BRANCH,T.PROD_CODE;
                COMMIT;
*/

   /*处理结束，记录日志信息*/
   V_STEP := 'N';
   V_END_TIME := TO_CHAR (SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF');
   ETL.WRITE_TRACE (V_PROC_NAME,
                    V_START_TIME,
                    V_END_TIME,
                    P_O_RESULT);
EXCEPTION
   WHEN OTHERS
   THEN
      P_O_RESULT := V_FAILED;
      ETL.WRITE_LOG (V_PROC_NAME,
                     V_STEP,
                     'ERROR OCURR:' || SQLERRM,
                     P_O_RESULT);
      RAISE_APPLICATION_ERROR (-20001, V_PROC_NAME);
END PR_FDS_OSR_S7101;
/