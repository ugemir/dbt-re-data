import os
import copy
import yaml

CHECK_DBS = ['postgres', 'snowflake', 'redshift', 'bigquery']

DBT_VARS = {
    're_data:alerting_z_score': 3,
    're_data:schemas': ['re_data_raw'],
    're_data:time_window_start': '2021-05-01 00:00:00',
    're_data:time_window_end': '2021-05-02 00:00:00',
    're_data:anomaly_detection_window_start': '2021-04-01 00:00:00',
    're_data:activey_monitored_by_default': True
}

def test_dbt(debug=True):

    load_deps = 'dbt deps'
    os.system(load_deps)

    for db in CHECK_DBS:
        dbt_vars = copy.deepcopy(DBT_VARS)
        print (f"Running setup and tests for {db}")

        profile_part = f' --profile re_data_{db}'

        print (f"Running init seed for {db}") 
        init_seeds = 'dbt seed --full-refresh {} --vars "{}"'.format(profile_part, yaml.dump(dbt_vars))
        os.system(init_seeds)
        print (f"Init seed completed for {db}") 
        
        print (f"Computing re_data metrics for {db}") 
        if db == 'snowflake':
            schemas = dbt_vars['re_data:schemas']
            schemas = [el.upper() for el in schemas]
            dbt_vars['re_data:schemas'] = schemas

        run_re_data = 'dbt run --full-refresh {} --vars "{}"'.format(profile_part, yaml.dump(dbt_vars))
        if debug:
            run_re_data = 'DBT_MACRO_DEBUGGING=1 ' + run_re_data

        os.system(run_re_data)
        print (f"Computing re_data metrics completed for {db}")

        print (f"Running tests for {db}")
        test_re_data = 'dbt test {} --vars "{}"'.format(profile_part, yaml.dump(dbt_vars))
        os.system(test_re_data)

        print (f"Running tests completed for {db}")


test_dbt()