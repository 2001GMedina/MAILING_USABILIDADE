WITH BASE AS (
    ----------------------------------------------------------------------
    -- TITULARES
    ----------------------------------------------------------------------
    SELECT
        'TITULAR' AS TIPO,
        C.ID,
        -- ID da linha (titular)
        C.ID AS CLIENTE_ID,
        -- ID do cliente (titular)
        C.DATA_INICIO_PLANO,
        C.DATA_NASCIMENTO,
        C.IDADE,
        C.NOME,
        C.GENERO,
        C.TELEFONE AS TELEFONE_RAW,
        C.CPF,
        C.EMAIL,
        E.CEP,
        E.BAIRRO,
        E.CIDADE,
        SC.NOME AS STATUS,
        FP.NOME AS FORMA_PAGAMENTO,
        P.NOME AS PLANO,
        C.FORMA_PAGAMENTO_ID,
        P.MENSALIDADE_CARNE,
        P.MENSALIDADE_CARTAO_CREDITO,
        C.VALOR_DESCONTO_CARNE,
        C.VALOR_DESCONTO_CARTAO_CREDITO,
        C.TIPO_CONTRATO
    FROM
        CLIENTES C
        LEFT JOIN ENDERECOS E ON C.ENDERECO_ID = E.ID
        LEFT JOIN STATUS_CLIENTE SC ON C.STATUS_CLIENTE_ID = SC.ID
        LEFT JOIN FORMAS_PAGAMENTO FP ON C.FORMA_PAGAMENTO_ID = FP.ID
        LEFT JOIN PLANOS P ON C.PLANO_ID = P.ID
    WHERE
        C.STATUS_CLIENTE_ID = 3
        AND C.FORMA_PAGAMENTO_ID IN (13, 14)
        AND C.IDADE >= 18
    UNION
    ALL ----------------------------------------------------------------------
    -- DEPENDENTES
    ----------------------------------------------------------------------
    SELECT
        'DEPENDENTE' AS TIPO,
        D.ID,
        -- ID da linha (dependente)
        C.ID AS CLIENTE_ID,
        -- ID do cliente (titular)
        C.DATA_INICIO_PLANO AS DATA_INICIO_PLANO,
        -- base contrato
        D.DATA_NASCIMENTO,
        DATEDIFF(YEAR, D.DATA_NASCIMENTO, GETDATE()) - CASE
            WHEN DATEADD(
                YEAR,
                DATEDIFF(YEAR, D.DATA_NASCIMENTO, GETDATE()),
                D.DATA_NASCIMENTO
            ) > GETDATE() THEN 1
            ELSE 0
        END AS IDADE,
        D.NOME,
        NULL AS GENERO,
        D.TELEFONE_CELULAR AS TELEFONE_RAW,
        D.CPF,
        D.EMAIL,
        E.CEP,
        E.BAIRRO,
        E.CIDADE,
        SC.NOME AS STATUS,
        FP.NOME AS FORMA_PAGAMENTO,
        P.NOME AS PLANO,
        C.FORMA_PAGAMENTO_ID,
        P.MENSALIDADE_CARNE,
        P.MENSALIDADE_CARTAO_CREDITO,
        C.VALOR_DESCONTO_CARNE,
        C.VALOR_DESCONTO_CARTAO_CREDITO,
        C.TIPO_CONTRATO
    FROM
        DEPENDENTES D
        LEFT JOIN CLIENTES C ON D.CLIENTE_ID = C.ID
        LEFT JOIN ENDERECOS E ON C.ENDERECO_ID = E.ID
        LEFT JOIN STATUS_CLIENTE SC ON C.STATUS_CLIENTE_ID = SC.ID
        LEFT JOIN FORMAS_PAGAMENTO FP ON C.FORMA_PAGAMENTO_ID = FP.ID
        LEFT JOIN PLANOS P ON C.PLANO_ID = P.ID
    WHERE
        C.STATUS_CLIENTE_ID = 3
        AND C.FORMA_PAGAMENTO_ID IN (13, 14)
        AND C.IDADE >= 18
),
NORMALIZADO AS (
    SELECT
        B.*,
        -- Telefone limpo sem espaços, parênteses e traços
        REPLACE(
            REPLACE(
                REPLACE(
                    REPLACE(B.TELEFONE_RAW, ' ', ''),
                    '(',
                    ''
                ),
                ')',
                ''
            ),
            '-',
            ''
        ) AS TELEFONE_LIMPO,
        -- Dias de "tempo de casa"
        DATEDIFF(
            DAY,
            B.DATA_INICIO_PLANO,
            CAST(GETDATE() AS DATE)
        ) AS DIAS_CASA,
        -- Campos de endereço já tratados (usando TAB como CHAR(9))
        TRIM(REPLACE(B.CEP, CHAR(9), '')) AS CEP_TRATADO,
        UPPER(TRIM(REPLACE(B.BAIRRO, CHAR(9), ''))) AS BAIRRO_TRATADO,
        UPPER(TRIM(REPLACE(B.CIDADE, CHAR(9), ''))) AS CIDADE_TRATADA
    FROM
        BASE B
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
)
SELECT
    N.TIPO,
    N.ID,
    N.DATA_INICIO_PLANO,
    N.DATA_NASCIMENTO,
    N.IDADE,
    -- Faixa etária (se quiser só para titular, colocar condição TIPO = 'TITULAR')
    CASE
        WHEN N.IDADE BETWEEN 0
        AND 18 THEN '0 a 18'
        WHEN N.IDADE BETWEEN 19
        AND 34 THEN '19 a 34'
        WHEN N.IDADE BETWEEN 35
        AND 55 THEN '35 a 55'
        WHEN N.IDADE BETWEEN 56
        AND 75 THEN '56 a 75'
        WHEN N.IDADE >= 76 THEN '75+'
        ELSE 'Idade inválida'
    END AS FAIXA_ETARIA,
    N.NOME,
    N.GENERO,
    -- Telefone já padronizado com 55
    CASE
        WHEN N.TELEFONE_LIMPO LIKE '55%' THEN N.TELEFONE_LIMPO
        ELSE CONCAT('55', N.TELEFONE_LIMPO)
    END AS TELEFONE,
    N.CPF,
    N.EMAIL,
    N.CEP_TRATADO AS CEP,
    N.BAIRRO_TRATADO AS BAIRRO,
    N.CIDADE_TRATADA AS CIDADE,
    N.STATUS,
    N.FORMA_PAGAMENTO,
    N.PLANO,
    -- Tempo de casa (mesma lógica, usando DIAS_CASA calculado uma vez)
    CASE
        WHEN N.DIAS_CASA < 2 THEN '1 Dia'
        WHEN N.DIAS_CASA <= 30 THEN CONCAT(N.DIAS_CASA, ' Dias')
        ELSE CASE
            WHEN CEILING(N.DIAS_CASA / 30.0) > 12 THEN CONCAT(
                FORMAT(
                    FLOOR(CEILING(N.DIAS_CASA / 30.0) / 12.0),
                    'N0',
                    'pt-BR'
                ),
                ' Anos'
            )
            ELSE CONCAT(
                FORMAT(
                    CEILING(N.DIAS_CASA / 30.0),
                    'N0',
                    'pt-BR'
                ),
                ' Meses'
            )
        END
    END AS TEMPO_DE_CASA,
    -- Desconto valor (sem duplicar lógica do UNION)
    CASE
        WHEN N.FORMA_PAGAMENTO_ID = 14 THEN ISNULL(
            NULLIF(N.VALOR_DESCONTO_CARNE, 0),
            N.MENSALIDADE_CARNE
        )
        WHEN N.FORMA_PAGAMENTO_ID = 13 THEN ISNULL(
            NULLIF(N.VALOR_DESCONTO_CARTAO_CREDITO, 0),
            N.MENSALIDADE_CARTAO_CREDITO
        )
        ELSE NULL
    END AS DESCONTO_VALOR,
    ISNULL(N.TIPO_CONTRATO, 'Contrato digital') AS TIPO_CONTRATO,
    CASE
        WHEN U.QTD > 0 THEN 'USOU'
        ELSE 'N.USOU'
    END AS USO
FROM
    NORMALIZADO N
    LEFT JOIN USO U ON N.CLIENTE_ID = U.CLIENTE_ID;