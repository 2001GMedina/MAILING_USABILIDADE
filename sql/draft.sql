SELECT
    'DEPENDENTE' AS TIPO,
    D.ID,
    D.DATA_CADASTRO AS DATA_INICIO_PLANO,
    D.DATA_NASCIMENTO,
    DATEDIFF(YEAR, D.DATA_NASCIMENTO, GETDATE()) - CASE
        WHEN DATEADD(
            YEAR,
            DATEDIFF(YEAR, D.DATA_NASCIMENTO, GETDATE()),
            D.DATA_NASCIMENTO
        ) > GETDATE() THEN 1
        ELSE 0
    END AS IDADE,
    NULL AS FAIXA_ETARIA,
    D.NOME,
    NULL AS GENERO,
    CASE
        WHEN REPLACE(
            REPLACE(
                REPLACE(REPLACE(D.TELEFONE_CELULAR, ' ', ''), '(', ''),
                ')',
                ''
            ),
            '-',
            ''
        ) LIKE '55%' THEN REPLACE(
            REPLACE(
                REPLACE(REPLACE(D.TELEFONE_CELULAR, ' ', ''), '(', ''),
                ')',
                ''
            ),
            '-',
            ''
        )
        ELSE CONCAT(
            '55',
            REPLACE(
                REPLACE(
                    REPLACE(REPLACE(D.TELEFONE_CELULAR, ' ', ''), '(', ''),
                    ')',
                    ''
                ),
                '-',
                ''
            )
        )
    END AS TELEFONE,
    D.CPF,
    D.EMAIL,
    TRIM(REPLACE(E.CEP, '	', '')) AS CEP,
    UPPER(TRIM(REPLACE(E.BAIRRO, '	', ''))) AS BAIRRO,
    UPPER(TRIM(REPLACE(E.CIDADE, '	', ''))) AS CIDADE,
    SC.NOME AS 'STATUS',
    FP.NOME AS FORMA_PAGAMENTO,
    P.NOME AS PLANO,
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
    ISNULL(C.TIPO_CONTRATO, 'Contrato digital') AS TIPO_CONTRATO
FROM
    DEPENDENTES D
    LEFT JOIN CLIENTES C ON D.CLIENTE_ID = C.ID
    LEFT JOIN ENDERECOS E ON C.ENDERECO_ID = E.ID
    LEFT JOIN STATUS_CLIENTE SC ON C.STATUS_CLIENTE_ID = SC.ID
    LEFT JOIN FORMAS_PAGAMENTO FP ON C.FORMA_PAGAMENTO_ID = FP.ID
    LEFT JOIN PLANOS P ON C.PLANO_ID = P.ID
WHERE
    C.STATUS_CLIENTE_ID = 3
    AND FORMA_PAGAMENTO_ID IN (13, 14)
    AND C.IDADE >= 18