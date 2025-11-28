WITH CLIENTES_MES_ATUAL AS (
    SELECT
        DISTINCT HS.CLIENTE_ID
    FROM
        HISTORICO_STATUS HS
    WHERE
        HS.STATUS_ALTERADO = 34
        AND HS.DATA_ALTERACAO >= DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1)
        AND HS.DATA_ALTERACAO < DATEADD(DAY, 1, EOMONTH(GETDATE()))
),
HIST AS (
    SELECT
        DISTINCT CAST(HS.DATA_ALTERACAO AS DATE) AS DATA_ALTERACAO,
        HS.CLIENTE_ID,
        HS.STATUS_ANTERIOR,
        HS.STATUS_ALTERADO,
        CASE
            WHEN HS.STATUS_ANTERIOR = 3
            AND HS.STATUS_ALTERADO = 33 THEN 'INADIMPLENCIA'
            WHEN HS.STATUS_ANTERIOR IN (2, 34)
            AND HS.STATUS_ALTERADO = 3 THEN 'REATIVACAO'
            ELSE 'REATIVACAO'
        END AS ALTERACAO
    FROM
        HISTORICO_STATUS HS
    WHERE
        HS.STATUS_ALTERADO IN (3, 33)
        AND HS.STATUS_ANTERIOR IN (2, 3, 33, 34)
),
CLUSTERS AS (
    SELECT
        CLIENTE_ID,
        COUNT(*) AS QTD_REATIVACOES,
        CASE
            WHEN COUNT(*) <= 1 THEN 'OCASIONAL'
            WHEN COUNT(*) <= 2 THEN 'MEDIANO'
            ELSE 'OFENSOR'
        END AS CLUSTER_ATUAL
    FROM
        HIST
    WHERE
        DATA_ALTERACAO BETWEEN DATEADD(MONTH, -30, GETDATE())
        AND GETDATE()
    GROUP BY
        CLIENTE_ID
),
HIST_COM_CLUSTER AS (
    SELECT
        H.*,
        CASE
            WHEN H.ALTERACAO = 'INADIMPLENCIA'
            AND C.CLUSTER_ATUAL IS NULL THEN 'SEM REATIVACAO'
            ELSE C.CLUSTER_ATUAL
        END AS CLUSTER_ATUAL
    FROM
        HIST H
        LEFT JOIN CLUSTERS C ON H.CLIENTE_ID = C.CLIENTE_ID
),
PARCELAS AS (
    SELECT
        CLIENTE_ID,
        COUNT(*) AS QTD_FATURAS_ABERTO
    FROM
        (
            SELECT
                CLIENTE_ID
            FROM
                FATURAS_CARTAO_CREDITO
            WHERE
                STATUS_PROVIDER = 'pending'
                AND DATA_VENCIMENTO >= DATEADD(MONTH, -30, GETDATE())
            UNION
            ALL
            SELECT
                CLIENTE_ID
            FROM
                FATURAS_CARNE
            WHERE
                STATUS_PROVIDER = 'overdue'
                AND DATA_VENCIMENTO >= DATEADD(MONTH, -30, GETDATE())
        ) AS FATURAS_ABERTAS
    GROUP BY
        CLIENTE_ID
),
DEP AS (
    SELECT
        DP.CLIENTE_ID,
        COUNT (*) AS QTD
    FROM
        DEPENDENTES DP
    WHERE
        INATIVO = 0
    GROUP BY
        DP.CLIENTE_ID
),
USO AS (
    SELECT
        HC.CLIENTE_ID,
        COUNT(*) AS QTD
    FROM
        HISTORICO_CONVERSA HC
        INNER JOIN HISTORICO_CONVERSA_TIPO_ASSUNTO ASSU ON HC.HISTORICO_CONVERSA_TIPO_ASSUNTO_ID = ASSU.ID
    WHERE
        ASSU.ID IN (
            1,
            2,
            4,
            5,
            6,
            7,
            8,
            9,
            10,
            11,
            14,
            15,
            16,
            17,
            18,
            19,
            20,
            21,
            24,
            27,
            28,
            29,
            30,
            33,
            34,
            36,
            39,
            41,
            42,
            43,
            44,
            45,
            46,
            47,
            55,
            61,
            62,
            64,
            65,
            66,
            71,
            77,
            78,
            81,
            82,
            84,
            87,
            90,
            94,
            96,
            97
        )
    GROUP BY
        HC.CLIENTE_ID
),
TEMPO_PAGANTE AS (
    SELECT
        CLIENTE_ID,
        COUNT(DISTINCT FORMAT(DATA_PAGAMENTO, 'yyyyMM')) AS MESES_PAGANTE,
        CASE
            WHEN COUNT(DISTINCT FORMAT(DATA_PAGAMENTO, 'yyyyMM')) = 1 THEN '1 mês'
            WHEN COUNT(DISTINCT FORMAT(DATA_PAGAMENTO, 'yyyyMM')) < 12 THEN CONCAT(
                COUNT(DISTINCT FORMAT(DATA_PAGAMENTO, 'yyyyMM')),
                ' meses'
            )
            WHEN COUNT(DISTINCT FORMAT(DATA_PAGAMENTO, 'yyyyMM')) = 12 THEN '1 ano'
            WHEN COUNT(DISTINCT FORMAT(DATA_PAGAMENTO, 'yyyyMM')) > 12 THEN CONCAT(
                FLOOR(
                    COUNT(DISTINCT FORMAT(DATA_PAGAMENTO, 'yyyyMM')) / 12
                ),
                ' ',
                CASE
                    WHEN FLOOR(
                        COUNT(DISTINCT FORMAT(DATA_PAGAMENTO, 'yyyyMM')) / 12
                    ) = 1 THEN 'ano'
                    ELSE 'anos'
                END,
                ' e ',
                COUNT(DISTINCT FORMAT(DATA_PAGAMENTO, 'yyyyMM')) % 12,
                ' ',
                CASE
                    WHEN COUNT(DISTINCT FORMAT(DATA_PAGAMENTO, 'yyyyMM')) % 12 = 1 THEN 'mês'
                    WHEN COUNT(DISTINCT FORMAT(DATA_PAGAMENTO, 'yyyyMM')) % 12 = 0 THEN ''
                    ELSE 'meses'
                END
            )
        END AS TEMPO_PAGANTE
    FROM
        (
            SELECT
                CLIENTE_ID,
                DATA_PAGAMENTO
            FROM
                FATURAS_CARTAO_CREDITO
            WHERE
                STATUS_PROVIDER = 'paid'
            UNION
            ALL
            SELECT
                CLIENTE_ID,
                DATA_PAGAMENTO
            FROM
                FATURAS_CARNE
            WHERE
                STATUS_PROVIDER = 'paid'
        ) AS PAGAMENTOS
    GROUP BY
        CLIENTE_ID
),
TEMPO_INAD AS (
    SELECT
        CLIENTE_ID,
        MAX(DATA_VENCIMENTO) AS DATA_ULTIMA_EM_ABERTO,
        DATEDIFF(MONTH, MAX(DATA_VENCIMENTO), GETDATE()) AS MESES_INADIMPLENTE
    FROM
        (
            SELECT
                CLIENTE_ID,
                DATA_VENCIMENTO
            FROM
                FATURAS_CARTAO_CREDITO
            WHERE
                STATUS_PROVIDER = 'pending'
            UNION
            ALL
            SELECT
                CLIENTE_ID,
                DATA_VENCIMENTO
            FROM
                FATURAS_CARNE
            WHERE
                STATUS_PROVIDER = 'overdue'
        ) AS INADIMPLENTES
    GROUP BY
        CLIENTE_ID
),
HIST_INAD AS (
    SELECT
        C.ID,
        C.DATA_INICIO_PLANO,
        CASE
            WHEN DATEDIFF(
                DAY,
                C.DATA_INICIO_PLANO,
                CAST(GETDATE() AS DATE)
            ) < 2 THEN '1 Dia'
            WHEN DATEDIFF(
                DAY,
                C.DATA_INICIO_PLANO,
                CAST(GETDATE() AS DATE)
            ) <= 30 THEN CONCAT(
                DATEDIFF(
                    DAY,
                    C.DATA_INICIO_PLANO,
                    CAST(GETDATE() AS DATE)
                ),
                ' Dias'
            )
            ELSE CASE
                WHEN CEILING(
                    DATEDIFF(
                        DAY,
                        C.DATA_INICIO_PLANO,
                        CAST(GETDATE() AS DATE)
                    ) / 30.0
                ) > 12 THEN CONCAT(
                    FORMAT(
                        FLOOR(
                            CEILING(
                                DATEDIFF(
                                    DAY,
                                    C.DATA_INICIO_PLANO,
                                    CAST(GETDATE() AS DATE)
                                ) / 30.0
                            ) / 12.0
                        ),
                        'N0',
                        'pt-BR'
                    ),
                    ' Anos'
                )
                ELSE CONCAT(
                    FORMAT(
                        CEILING(
                            DATEDIFF(
                                DAY,
                                C.DATA_INICIO_PLANO,
                                CAST(GETDATE() AS DATE)
                            ) / 30.0
                        ),
                        'N0',
                        'pt-BR'
                    ),
                    ' Meses'
                )
            END
        END AS TEMPO_DE_CASA,
        C.DATA_NASCIMENTO,
        C.IDADE,
        CASE
            WHEN C.IDADE BETWEEN 0
            AND 18 THEN '0 a 18'
            WHEN C.IDADE BETWEEN 19
            AND 34 THEN '19 a 34'
            WHEN C.IDADE BETWEEN 35
            AND 55 THEN '35 a 55'
            WHEN C.IDADE BETWEEN 56
            AND 75 THEN '56 a 75'
            WHEN C.IDADE >= 76 THEN '75+'
            ELSE 'Idade inválida'
        END AS FAIXA_ETARIA,
        C.NOME,
        CASE
            WHEN REPLACE(C.TELEFONE, ' ', '') LIKE '55%' THEN REPLACE(C.TELEFONE, ' ', '')
            ELSE CONCAT('55', REPLACE(C.TELEFONE, ' ', ''))
        END AS TELEFONE,
        CASE
            WHEN REPLACE(C.TELEFONE_3, ' ', '') LIKE '55%' THEN REPLACE(C.TELEFONE_3, ' ', '')
            ELSE CONCAT('55', REPLACE(C.TELEFONE_3, ' ', ''))
        END AS TELEFONE_3,
        CASE
            WHEN REPLACE(C.TELEFONE_4, ' ', '') LIKE '55%' THEN REPLACE(C.TELEFONE_4, ' ', '')
            ELSE CONCAT('55', REPLACE(C.TELEFONE_4, ' ', ''))
        END AS TELEFONE_4,
        CASE
            WHEN REPLACE(C.TELEFONE_FIXO, ' ', '') LIKE '55%' THEN REPLACE(C.TELEFONE_FIXO, ' ', '')
            ELSE CONCAT('55', REPLACE(C.TELEFONE_FIXO, ' ', ''))
        END AS TELEFONE_FIXO,
        C.CPF,
        C.ENDERECO_ID,
        TRIM(REPLACE(E.CEP, CHAR(9), '')) AS CEP,
        TRIM(REPLACE(E.BAIRRO, CHAR(9), '')) AS BAIRRO,
        TRIM(REPLACE(E.CIDADE, CHAR(9), '')) AS CIDADE,
        C.STATUS_CLIENTE_ID,
        SC.NOME AS STATUS_CLIENTE,
        C.FORMA_PAGAMENTO_ID,
        FP.NOME AS FORMA_PAGAMENTO,
        C.PLANO_ID,
        P.NOME AS PLANO,
        ISNULL(C.TIPO_CONTRATO, 'Contrato digital') AS TIPO_CONTRATO,
        C.GENERO,
        CASE
            WHEN C.FORMA_PAGAMENTO_ID = 14 THEN ISNULL(
                NULLIF(C.VALOR_DESCONTO_CARNE, 0),
                P.MENSALIDADE_CARNE
            )
            WHEN C.FORMA_PAGAMENTO_ID = 13 THEN ISNULL(
                NULLIF(C.VALOR_DESCONTO_CARTAO_CREDITO, 0),
                P.MENSALIDADE_CARTAO_CREDITO
            )
            ELSE NULL
        END AS DESCONTO_VALOR,
        CAST(I.DATA_ALTERACAO AS DATETIME) AS DATA_ALTERACAO,
        I.STATUS_ANTERIOR,
        I.STATUS_ALTERADO,
        I.ALTERACAO,
        I.CLUSTER_ATUAL AS CLUSTER,
        PC.QTD_FATURAS_ABERTO,
        DP.QTD AS DEPENDENTES_CADASTRADOS,
        CASE
            WHEN USO.QTD IS NULL THEN 0
            ELSE USO.QTD
        END AS USABILIDADE,
        TP.MESES_PAGANTE,
        TP.TEMPO_PAGANTE,
        TI.DATA_ULTIMA_EM_ABERTO,
        TI.MESES_INADIMPLENTE
    FROM
        CLIENTES C
        LEFT JOIN PLANOS P ON C.PLANO_ID = P.ID
        LEFT JOIN FORMAS_PAGAMENTO FP ON C.FORMA_PAGAMENTO_ID = FP.ID
        LEFT JOIN STATUS_CLIENTE SC ON C.STATUS_CLIENTE_ID = SC.ID
        LEFT JOIN ENDERECOS E ON C.ENDERECO_ID = E.ID
        LEFT JOIN HIST_COM_CLUSTER I ON C.ID = I.CLIENTE_ID
        LEFT JOIN PARCELAS PC ON C.ID = PC.CLIENTE_ID
        LEFT JOIN DEP DP ON C.ID = DP.CLIENTE_ID
        LEFT JOIN USO ON C.ID = USO.CLIENTE_ID
        LEFT JOIN TEMPO_PAGANTE TP ON C.ID = TP.CLIENTE_ID
        LEFT JOIN TEMPO_INAD TI ON C.ID = TI.CLIENTE_ID
    WHERE
        C.STATUS_CLIENTE_ID IN (33, 34)
        AND C.FORMA_PAGAMENTO_ID IN (13, 14)
        AND C.ID NOT IN ('111295', '111302', '111304', '91225')
        AND P.ID NOT IN('19', '10', '20')
        AND (
            C.STATUS_CLIENTE_ID <> 34 -- todos que não são 34
            OR EXISTS (
                SELECT
                    1
                FROM
                    CLIENTES_MES_ATUAL CMA
                WHERE
                    CMA.CLIENTE_ID = C.ID
            )
        )
),
HIST_NUMERADO AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY ID
            ORDER BY
                DATA_ALTERACAO DESC
        ) AS RN
    FROM
        HIST_INAD
)
SELECT
    DATA_INICIO_PLANO,
    TEMPO_DE_CASA,
    DATA_NASCIMENTO,
    IDADE,
    FAIXA_ETARIA,
    NOME,
    TELEFONE,
    TELEFONE_3,
    TELEFONE_4,
    TELEFONE_FIXO,
    FORMA_PAGAMENTO,
    PLANO,
    GENERO,
    DESCONTO_VALOR,
    CLUSTER,
    QTD_FATURAS_ABERTO,
    DEPENDENTES_CADASTRADOS,
    USABILIDADE,
    MESES_PAGANTE,
    TEMPO_PAGANTE,
    DATA_ULTIMA_EM_ABERTO,
    MESES_INADIMPLENTE
FROM
    HIST_NUMERADO
WHERE
    RN = 1
ORDER BY
    ID;