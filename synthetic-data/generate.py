#!/usr/bin/env python3

import sys
import os.path
from synthcity.plugins.core.dataloader import GenericDataLoader
from synthcity.plugins import Plugins
from synthcity.benchmark import Benchmarks
import pandas as pd
from datetime import date


from synthcity.plugins import Plugins

plugins_list = Plugins(categories=["generic", "privacy"]).list()
print(plugins_list)

file_name=sys.argv[-1]
file_root, file_extension = os.path.splitext(file_name)

csv = pd.read_csv(file_name)
input_data = csv.iloc[1:]  # Remove the garbage json row
#input_data = input_data.drop("IPAddress", axis=1)  # Remove the "IPAddress" column

loader = GenericDataLoader(
    data=input_data,
    target_column="research_id",
    sensitive_features=["LocationLatitude","LocationLongitude", "IP Address"]
    # sensitive_columns=["sex"],
)

#
plugins = [ "marginal_distributions" ] #, "marginal_distributions", "adsgan", "ddpm", "dpgan"]

for name in plugins:
  syn_model = Plugins().get(name)
  print(type(syn_model))
  syn_model.fit(input_data)
  syn_model.generate(count=100).dataframe().to_csv(
    file_root + '_' + date.today().strftime("%Y-%m-%d")+'_'+syn_model.name()+'.csv', index=False
  )


# score = Benchmarks.evaluate(
#     [
#         (f"{model}", model, {})  # testname, plugin name, plugin args
#         for model in plugins #["adsgan", "ctgan", "tvae"]
#     ],
#     loader,
#     synthetic_size=200,
#     metrics={
#       "performance": ["linear_model"],
#       "privacy": ["distinct l-diversity", "k-anonymization"],
#     },
#     repeats=3,
# )
# Benchmarks.print(score)
