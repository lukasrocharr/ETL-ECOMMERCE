import csv

input_file = 'olist_order_reviews_dataset.csv'
output_file = 'reviews_limpo.csv'

with open(input_file, 'r', encoding='utf-8') as f_in, \
     open(output_file, 'w', encoding='utf-8', newline='') as f_out:
    
    reader = csv.DictReader(f_in)
    writer = csv.writer(f_out)
    writer.writerow(['review_id', 'order_id', 'review_score', 'review_creation_date', 'review_answer_timestamp'])
    
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
            continue
    
    print(f'{count} reviews validos exportados para {output_file}')
