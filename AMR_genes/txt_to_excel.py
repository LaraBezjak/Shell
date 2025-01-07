#!/usr/bin/python
import pandas as pd
import os
import sys

pot=sys.argv[1]

txt_files = [f for f in os.listdir(f'{pot}') if f.endswith('.txt')]

all_data = pd.DataFrame()

for txt_file in txt_files:
    path = os.path.join(pot,txt_file)
    df = pd.read_csv(path, delimiter='\t')
    df.insert(0, 'Filename', txt_file.replace('.txt', ''))
    all_data = pd.concat([all_data, df], ignore_index=True)

all_data.to_excel(f'{pot}/rezultati.xlsx', index=False)