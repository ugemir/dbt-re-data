{{
    config(
        materialized='view'
    )
}}
select
    z.id,
    z.table_name,
    z.column_name,
    z.metric,
    z.z_score_value,
    z.modified_z_score_value,
    m.anomaly_detector,
    {{ fivetran_utils.json_extract('m.anomaly_detector', 'name') }} as anomaly_name,
    {{ fivetran_utils.json_extract('m.anomaly_detector', 'threshold') }} as anomaly_threshold,
    z.last_value,
    z.last_avg,
    z.last_median,
    z.last_stddev,
    z.last_median_absolute_deviation,
    z.last_mean_absolute_deviation,
    z.last_iqr,
    z.last_first_quartile - (cast( {{ fivetran_utils.json_extract('m.anomaly_detector', 'whisker_boundary_multiplier') }} as {{numeric_type()}} ) * z.last_iqr) lower_bound,
    z.last_third_quartile + (cast( {{ fivetran_utils.json_extract('m.anomaly_detector', 'whisker_boundary_multiplier') }} as {{numeric_type()}} ) * z.last_iqr) upper_bound,
    z.last_first_quartile,
    z.last_third_quartile,
    z.time_window_end,
    z.interval_length_sec,
    z.computed_on,
    {{ re_data.generate_anomaly_message('z.column_name', 'z.metric', 'z.last_value', 'z.last_avg') }} as message,
    {{ re_data.generate_metric_value_text('z.metric', 'z.last_value') }} as last_value_text
from
    {{ ref('re_data_z_score')}} z 
left join {{ ref('re_data_monitored') }} m 
on z.table_name = {{ full_table_name('m.name', 'm.schema', 'm.database') }}
where
    case 
        when {{ fivetran_utils.json_extract('m.anomaly_detector', 'name') }} = 'z_score' 
            then abs(z_score_value) > cast({{ fivetran_utils.json_extract('m.anomaly_detector', 'threshold') }} as {{ numeric_type() }})
        when {{ fivetran_utils.json_extract('m.anomaly_detector', 'name') }} = 'modified_z_score' 
            then abs(modified_z_score_value) > cast( {{ fivetran_utils.json_extract('m.anomaly_detector', 'threshold') }} as {{numeric_type()}} )
        when {{ fivetran_utils.json_extract('m.anomaly_detector', 'name') }} = 'boxplot' 
            then (
                z.last_value < z.last_first_quartile - (cast( {{ fivetran_utils.json_extract('m.anomaly_detector', 'whisker_boundary_multiplier') }} as {{numeric_type()}} ) * z.last_iqr)
                or 
                z.last_value > z.last_third_quartile + (cast( {{ fivetran_utils.json_extract('m.anomaly_detector', 'whisker_boundary_multiplier') }} as {{numeric_type()}} ) * z.last_iqr)
            )
        else false
    end
