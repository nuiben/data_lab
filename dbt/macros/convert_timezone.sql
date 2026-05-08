{% macro convert_timezone(source_tz, target_tz, column) %}
    {% if target.type == 'snowflake' %}
        convert_timezone('{{ source_tz }}', '{{ target_tz }}', {{ column }})
    {% elif target.type == 'duckdb' %}
        timezone('{{ target_tz }}', timezone('{{ source_tz }}', {{ column }}))
    {% else %}
        {{ exceptions.raise_compiler_error(
            "convert_timezone macro not implemented for adapter: " ~ target.type
        ) }}
    {% endif %}
{% endmacro %}
