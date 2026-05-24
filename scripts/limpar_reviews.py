"""
limpar_reviews.py
===============================================================
Trata o CSV de reviews do Olist removendo os comentários
em texto livre que contêm vírgulas e quebras de linha
(que quebram o BULK INSERT do SQL Server).

O script mantém apenas as colunas essenciais para análise:
- review_id
- order_id
- review_score (validado como int entre 1 e 5)
- review_creation_date (truncado para 19 chars)
- review_answer_timestamp (truncado para 19 chars)

Uso:
    cd data/
    python3 ../scripts/limpar_reviews.py
===============================================================
"""

import csv

input_file = 'olist_order_reviews_dataset.csv'
output_file = 'reviews_limpo.csv'

with open(input_file, 'r', encoding='utf-8') as f_in, \
     open(output_file, 'w', encoding='utf-8', newline='') as f_out:

    reader = csv.DictReader(f_in)
    writer = csv.writer(f_out)
    writer.writerow([
        'review_id', 
        'order_id', 
        'review_score', 
        'review_creation_date', 
        'review_answer_timestamp'
    ])

    count = 0
    for row in reader:
        try:
            score = int(row['review_score'])
            if 1 <= score <= 5:
                writer.writerow([
                    row['review_id'],
                    row['order_id'],
                    score,
                    row['review_creation_date'][:19],
                    row['review_answer_timestamp'][:19]
                ])
                count += 1
        except (ValueError, KeyError):
            # Pula linhas malformadas ou com score inválido
            continue

    print(f'{count} reviews válidos exportados para {output_file}')
